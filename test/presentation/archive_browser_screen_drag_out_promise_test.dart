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

/// 넘어온 [entryPaths]를 기록하고 실제 리더처럼 [destination] 아래에 압축
/// 안 경로 그대로 파일을 만든다. [failures]를 채우면 손상된 항목을 흉내 낸다.
class _WritingReader implements ArchiveReader {
  final calls = <List<String>?>[];
  List<ExtractFailure> failures = const [];

  @override
  bool supports(ArchiveFormat format) => true;

  @override
  Future<List<ArchiveEntry>> listEntries(
    Uri archiveLocation, {
    String? password,
  }) async => [];

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
    calls.add(entryPaths);
    if (failures.isNotEmpty) return failures;
    for (final path in entryPaths ?? const <String>[]) {
      final target = p.joinAll([
        destination.toFilePath(),
        ...path.split('/').where((s) => s.isNotEmpty),
      ]);
      if (path.endsWith('/')) {
        await Directory(target).create(recursive: true);
      } else {
        await File(target).create(recursive: true);
      }
    }
    return const [];
  }

  @override
  Future<Uri> extractEntryToTemp(
    Uri archiveLocation,
    String entryPath, {
    String? password,
  }) => throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_drag_out');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dest;
  late List<MethodCall> pluginCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterDragOut.debugReset();
    pluginCalls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      pluginCalls.add(call);
      return true;
    });
    dest = await Directory.systemTemp.createTemp('dove_zip_promise_dest_');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    if (await dest.exists()) await dest.delete(recursive: true);
  });

  const entries = [
    ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false),
    ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
    ArchiveEntry(pathInArchive: 'docs/c.txt', isDirectory: false),
    ArchiveEntry(
      pathInArchive: 'secret.txt',
      isDirectory: false,
      isEncrypted: true,
    ),
  ];

  Future<_WritingReader> pumpScreen(WidgetTester tester) async {
    final reader = _WritingReader();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveBrowserScreen(
            handle: ArchiveHandle(
              location: Uri.file('/tmp/photos.zip'),
              format: ArchiveFormat.zip,
              entries: entries,
            ),
            extractEntries: ExtractEntries(reader),
            dragOutWithPromises: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return reader;
  }

  /// [name] 행을 끌어 창 밖으로 나갔다가 놓는다(실제로는 플러그인이
  /// OS 드래그로 넘기며 Flutter 드래그를 끝낸다).
  Future<void> dragOut(WidgetTester tester, String name) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(name)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveTo(const Offset(-20, 100));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  List<Map<Object?, Object?>> sentItems() => [
    for (final item in (pluginCalls.single.arguments as Map)['items'] as List)
      item as Map<Object?, Object?>,
  ];

  /// Finder가 드롭된 위치에 [id]번 항목을 써 달라고 요청하는 것을 흉내 내고,
  /// Dart 쪽 응답(성공이면 null, 실패면 PlatformException)을 돌려준다.
  Future<Object?> requestWrite(
    WidgetTester tester,
    int id,
    String targetPath,
  ) async {
    ByteData? reply;
    await tester.runAsync(() async {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('writePromise', {
            'session': 1,
            'id': id,
            'targetPath': targetPath,
            'final': true,
          }),
        ),
        (data) => reply = data,
      );
    });
    for (var i = 0; i < 100 && reply == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    // 결과 스낵바가 그려지도록.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    try {
      return channel.codec.decodeEnvelope(reply!);
    } on PlatformException catch (e) {
      return e;
    }
  }

  // 플러그인은 macOS에서만 파일 프로미스를 받는다(supportsPromises).
  group('파일 프로미스', () {
    testWidgets('창 밖으로 나가면 미리 풀지 않고 곧바로 파일 프로미스로 넘긴다', (tester) async {
      final reader = await pumpScreen(tester);

      await dragOut(tester, 'a.txt');

      expect(sentItems(), [
        {'type': 'promise', 'id': 0, 'name': 'a.txt', 'directory': false},
      ]);
      expect(reader.calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('폴더는 폴더 프로미스로 넘긴다', (tester) async {
      await pumpScreen(tester);

      await dragOut(tester, 'docs');

      expect(sentItems(), [
        {'type': 'promise', 'id': 0, 'name': 'docs', 'directory': true},
      ]);
    });

    testWidgets('Finder가 쓰기를 요청하면 그 위치에 풀고 완료를 알린다', (tester) async {
      final reader = await pumpScreen(tester);
      await dragOut(tester, 'docs');

      final target = p.join(dest.path, 'docs 2'); // Finder가 고른 겹치지 않는 이름
      expect(await requestWrite(tester, 0, target), isNull);

      expect(reader.calls.single, unorderedEquals(['docs/', 'docs/c.txt']));
      expect(File(p.join(target, 'c.txt')).existsSync(), isTrue);
      expect(find.text('압축 해제 완료: ${dest.path}'), findsOneWidget);
    });

    testWidgets('풀기에 실패하면 Finder에 실패로 알리고 오류를 보여준다', (tester) async {
      final reader = await pumpScreen(tester);
      reader.failures = const [
        ExtractFailure(entryPath: 'a.txt', message: '깨짐'),
      ];
      await dragOut(tester, 'a.txt');

      final reply = await requestWrite(tester, 0, p.join(dest.path, 'a.txt'));

      expect(reply, isA<PlatformException>());
      expect(find.textContaining('끌어내기를 준비하지 못했습니다'), findsOneWidget);
      expect(dest.listSync(), isEmpty);
    });

    testWidgets('비밀번호를 모르는 암호화 항목은 넘기지 않고 비밀번호 안내를 보여준다', (tester) async {
      await pumpScreen(tester);

      await dragOut(tester, 'secret.txt');

      expect(pluginCalls, isEmpty);
      expect(find.textContaining('비밀번호가 필요한 항목'), findsOneWidget);
    });
  }, skip: !Platform.isMacOS);
}
