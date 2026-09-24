import 'dart:async';
import 'dart:io';

import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 끌어내기 준비(임시 폴더 해제)가 [gate]가 열릴 때까지 끝나지 않는 리더 —
/// "준비가 끝나기 전에 드래그가 끝나는" 경우를 재현한다. 넘어온
/// [entryPaths]는 [started]로 알린다. 게이트가 열리면 실제 리더처럼
/// [destination] 아래에 압축 안 경로 그대로 빈 파일을 만든다.
class _GatedReader implements ArchiveReader {
  final started = Completer<List<String>?>();
  final gate = Completer<void>();
  final finished = Completer<void>();

  @override
  bool supports(ArchiveFormat format) => true;

  @override
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password}) async => [];

  @override
  Future<List<ExtractFailure>> extractAll(
    Uri archiveLocation, {
    required Uri destination,
    List<String>? entryPaths,
    String? password,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    started.complete(entryPaths);
    try {
      await gate.future;
      cancelToken?.throwIfCancelled();
      for (final path in entryPaths ?? const <String>[]) {
        await File(p.joinAll([destination.toFilePath(), ...path.split('/')])).create(recursive: true);
      }
      return const [];
    } finally {
      finished.complete();
    }
  }

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

void main() {
  late Directory root;
  const channel = MethodChannel('flutter_drag_out');
  late List<MethodCall> pluginCalls;

  setUp(() async {
    FlutterDragOut.debugReset();
    pluginCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      pluginCalls.add(call);
      return true;
    });
    // 마지막 해제 모드를 읽는 provider가 shared_preferences를 쓴다.
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('dove_zip_drag_out_screen_test_');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<_GatedReader> pumpScreen(WidgetTester tester, List<ArchiveEntry> entries) async {
    final reader = _GatedReader();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: ArchiveHandle(location: Uri.file('/tmp/photos.zip'), format: ArchiveFormat.zip, entries: entries),
          extractEntries: ExtractEntries(reader),
          dragOutRootPath: root.path,
          // 이 파일은 미리 풀어 두는 방식을 검증한다(파일 프로미스는
          // archive_browser_screen_drag_out_promise_test.dart).
          dragOutWithPromises: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return reader;
  }

  const plainEntries = [
    ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false),
    ArchiveEntry(pathInArchive: 'b.txt', isDirectory: false),
  ];

  /// 끌어내기 준비는 실제 파일 I/O를 한다. I/O는 진짜 시간이 흘러야
  /// 끝나고, 그 뒤를 잇는 코드는 테스트의 가짜 비동기 영역에 있어 pump를
  /// 해야 진행된다 — 둘을 번갈아 하며 [done]이 될 때까지 기다린다.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(done(), isTrue, reason: '끌어내기 준비가 제때 진행되지 않았다');
  }

  /// 행을 끌기 시작하고, 준비가 리더까지 닿을 때까지 기다린다.
  Future<TestGesture> startDrag(WidgetTester tester, String name, _GatedReader reader) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text(name)), kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await settle(tester, () => reader.started.isCompleted);
    return gesture;
  }

  /// 막아 둔 해제를 풀고 준비가 끝날 때까지 기다린다.
  Future<void> openGate(WidgetTester tester, _GatedReader reader) async {
    reader.gate.complete();
    await settle(tester, () => reader.finished.isCompleted);
  }

  testWidgets('선택되지 않은 행을 끌면 그 항목 하나만 임시 폴더로 풀기 시작한다', (tester) async {
    final reader = await pumpScreen(tester, plainEntries);

    final gesture = await startDrag(tester, 'b.txt', reader);
    expect(await reader.started.future, ['b.txt']);

    await gesture.up();
    await openGate(tester, reader);
  });

  testWidgets('선택된 행을 끌면 선택 전체를 푼다', (tester) async {
    final reader = await pumpScreen(tester, plainEntries);
    for (final name in ['a.txt', 'b.txt']) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text(name));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    final gesture = await startDrag(tester, 'b.txt', reader);
    expect(await reader.started.future, unorderedEquals(['a.txt', 'b.txt']));
    // 여러 항목이면 드래그 미리보기에 개수가 보인다.
    expect(find.text('2개 항목'), findsOneWidget);

    await gesture.up();
    await openGate(tester, reader);
  });

  testWidgets('창 안에서 놓으면 준비를 취소하고 임시 폴더를 지운다', (tester) async {
    final reader = await pumpScreen(tester, plainEntries);

    final gesture = await startDrag(tester, 'a.txt', reader);
    expect(root.listSync().whereType<Directory>(), hasLength(1)); // 세션 폴더

    await gesture.up();
    await tester.pump();
    await openGate(tester, reader);
    // 취소 예외를 받은 DragOutStaging이 세션 폴더를 지운다.
    await settle(tester, () => root.listSync().whereType<Directory>().isEmpty);

    // 창 밖으로 나간 적이 없으니 안내도 없다.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('준비가 끝나기 전에 창 밖에서 놓으면 아직 푸는 중이라고 알려 준다', (tester) async {
    final reader = await pumpScreen(tester, plainEntries);

    final gesture = await startDrag(tester, 'a.txt', reader);
    await gesture.moveTo(const Offset(-20, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.textContaining('아직 압축을 푸는 중'), findsOneWidget, skip: !_hasNativeDragOut);

    await openGate(tester, reader);
  });

  testWidgets('비밀번호를 모르는 암호화 항목을 창 밖에서 놓으면 비밀번호 안내를 보여준다', (tester) async {
    final reader = await pumpScreen(tester, const [
      ArchiveEntry(pathInArchive: 'secret.txt', isDirectory: false, isEncrypted: true),
    ]);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('secret.txt')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveTo(const Offset(-20, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.textContaining('비밀번호가 필요한 항목'), findsOneWidget, skip: !_hasNativeDragOut);
    expect(reader.started.isCompleted, isFalse);
  });

  /// 네이티브 쪽이 드래그 세션 종료를 알리는 것을 흉내 낸다.
  Future<void> sendDragEnded({required bool dropped}) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('dragEnded', {'session': 1, 'dropped': dropped})),
        (_) {},
      );

  /// a.txt를 끌어 준비를 마친 뒤 창 밖으로 나가, 플러그인이 받은 경로를
  /// 돌려준다.
  Future<List<String>> dragOutReadyItem(WidgetTester tester) async {
    final reader = await pumpScreen(tester, plainEntries);
    final gesture = await startDrag(tester, 'a.txt', reader);
    await openGate(tester, reader);
    // 준비가 끝나 상태가 ready가 되면 스피너가 사라진다.
    await settle(tester, () => find.byType(CircularProgressIndicator).evaluate().isEmpty);

    await gesture.moveTo(const Offset(-20, 100));
    await tester.pump();
    await settle(tester, () => pluginCalls.isNotEmpty);
    // 실제로는 플러그인이 합성 mouse-up으로 Flutter 드래그를 끝낸다.
    await gesture.up();
    await tester.pump();

    final call = pluginCalls.single;
    expect(call.method, 'startDrag');
    final items = (call.arguments as Map)['items'] as List;
    return [for (final item in items) (item as Map)['path'] as String];
  }

  testWidgets('준비가 끝난 뒤 창 밖으로 나가면 풀린 파일 경로로 OS 드래그를 시작한다', (tester) async {
    final paths = await dragOutReadyItem(tester);

    expect(paths, hasLength(1));
    expect(p.basename(paths.single), 'a.txt');
    expect(p.isWithin(root.path, paths.single), isTrue);
    expect(File(paths.single).existsSync(), isTrue);
    // 넘겼으니 안내 스낵바는 없다.
    expect(find.byType(SnackBar), findsNothing);
  }, skip: !_hasNativeDragOut);

  testWidgets('다른 앱이 드롭을 받지 않으면 임시 폴더를 지운다', (tester) async {
    final paths = await dragOutReadyItem(tester);

    await sendDragEnded(dropped: false);
    await settle(tester, () => !File(paths.single).existsSync());
    expect(FlutterDragOut.inProgress, isFalse);
  }, skip: !_hasNativeDragOut);

  testWidgets('다른 앱이 드롭을 받으면 복사 중일 수 있어 임시 폴더를 남긴다', (tester) async {
    final paths = await dragOutReadyItem(tester);

    await sendDragEnded(dropped: true);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(File(paths.single).existsSync(), isTrue);
  }, skip: !_hasNativeDragOut);
}

/// 끌어내기 안내는 플러그인이 동작하는 데스크톱에서만 보여준다.
final _hasNativeDragOut = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
