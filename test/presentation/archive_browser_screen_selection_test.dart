import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/entities/extract_progress.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "선택 항목만 해제"(PLAN.md 1.2) 배선만 검증하는 가짜 리더 — 실제로
/// 넘어온 [entryPaths]를 그대로 기록해 둔다. 실제 디스크 I/O나 압축 해제
/// 자체의 정확성은 dart_archive_reader_extract_test.dart가 맡는다.
class _RecordingReader implements ArchiveReader {
  List<String>? lastEntryPaths;

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
    lastEntryPaths = entryPaths;
    onProgress?.call(const ExtractProgress(done: 1, total: 1, currentName: 'a.txt'));
    return const [];
  }

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

Future<void> _tapWithModifier(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  Finder finder,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.tap(finder);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/photos.zip'),
    format: ArchiveFormat.zip,
    entries: const [
      ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false),
      ArchiveEntry(pathInArchive: 'b.txt', isDirectory: false),
      ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
      ArchiveEntry(pathInArchive: 'docs/c.txt', isDirectory: false),
    ],
  );

  Future<_RecordingReader> pumpScreen(WidgetTester tester) async {
    final reader = _RecordingReader();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(reader),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return reader;
  }

  testWidgets('Ctrl+클릭으로 선택하면 상태바와 해제 버튼 라벨이 바뀐다', (tester) async {
    await pumpScreen(tester);

    expect(find.text('3개 항목'), findsOneWidget);
    expect(find.text('알아서 압축 해제'), findsOneWidget);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('a.txt'));

    expect(find.text('1개 선택됨 (0 B)'), findsOneWidget);
    expect(find.text('선택 항목 알아서 해제'), findsOneWidget);
    // Ctrl+클릭은 선택만 하고 미리보기로 넘어가지 않아야 한다.
    expect(find.text('a.txt'), findsOneWidget); // 여전히 목록 화면
  });

  testWidgets('같은 항목을 다시 Ctrl+클릭하면 선택이 풀린다', (tester) async {
    await pumpScreen(tester);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('a.txt'));
    expect(find.text('1개 선택됨 (0 B)'), findsOneWidget);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('a.txt'));
    expect(find.text('3개 항목'), findsOneWidget);
    expect(find.text('알아서 압축 해제'), findsOneWidget);
  });

  testWidgets('앱바의 선택 해제 버튼을 누르면 선택이 모두 풀린다', (tester) async {
    await pumpScreen(tester);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('a.txt'));
    expect(find.byIcon(Icons.deselect), findsOneWidget);

    await tester.tap(find.byIcon(Icons.deselect));
    await tester.pump();

    expect(find.text('3개 항목'), findsOneWidget);
    expect(find.byIcon(Icons.deselect), findsNothing);
  });

  testWidgets('선택 항목만 해제를 누르면 선택된 경로만 entryPaths로 넘어간다', (tester) async {
    final reader = await pumpScreen(tester);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('a.txt'));
    await tester.tap(find.text('선택 항목 알아서 해제'));
    await tester.pumpAndSettle();

    expect(reader.lastEntryPaths, ['a.txt']);
    // 성공적으로 끝났으니 선택 상태가 정리돼 다음엔 다시 전체 해제 라벨이다.
    expect(find.text('알아서 압축 해제'), findsOneWidget);
  });

  testWidgets('폴더를 선택해서 해제하면 그 안의 파일까지 전부 entryPaths에 펼쳐진다', (tester) async {
    final reader = await pumpScreen(tester);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('docs'));
    await tester.tap(find.text('선택 항목 알아서 해제'));
    await tester.pumpAndSettle();

    expect(reader.lastEntryPaths, unorderedEquals(['docs/', 'docs/c.txt']));
  });

  testWidgets('Shift+클릭은 마지막으로 누른 항목부터 범위로 선택한다', (tester) async {
    await pumpScreen(tester);

    // 목록 순서: docs(폴더), a.txt, b.txt — 폴더 우선 정렬(archive_browser_entries.dart).
    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('docs'));
    await _tapWithModifier(tester, LogicalKeyboardKey.shiftLeft, find.text('b.txt'));

    expect(find.text('3개 선택됨 (0 B)'), findsOneWidget);
  });

  testWidgets('Ctrl+A를 누르면 현재 폴더의 모든 항목을 선택한다', (tester) async {
    await pumpScreen(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('3개 선택됨 (0 B)'), findsOneWidget);
  });

  testWidgets('일반 클릭은 선택 상태를 바꾸지 않고 폴더 진입/미리보기로 그대로 이어간다', (tester) async {
    await pumpScreen(tester);

    await _tapWithModifier(tester, LogicalKeyboardKey.controlLeft, find.text('a.txt'));
    expect(find.text('1개 선택됨 (0 B)'), findsOneWidget);

    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();

    // 폴더 안으로 들어왔지만 선택은 (다른 폴더 항목이라도) 유지된다.
    expect(find.text('c.txt'), findsOneWidget); // docs 폴더 안으로 이동했음
    expect(find.text('1개 선택됨 (0 B)'), findsOneWidget);
  });
}
