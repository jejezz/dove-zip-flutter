import 'dart:io';

import 'package:dove_zip/application/usecases/preview_archive_entry.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 이 파일은 폴더 탐색/닫기 같은 순수 UI 동작만 확인한다 — 미리보기
/// 자체의 상세 동작(텍스트/이미지/폴백)은
/// archive_browser_screen_preview_test.dart가 맡는다. 그래도
/// `PreviewArchiveEntry`가 실제 디스크(`/tmp/photos.zip`, 존재하지 않음)를
/// 건드리지 않도록 가짜 리더를 넣어준다 — 실제로 존재하는 임시 파일을
/// 만들어 반환해서 뷰어가 정상적으로 내용을 읽을 수 있게 한다.
class _FakeReader implements ArchiveReader {
  _FakeReader(this.tempDir);

  final Directory tempDir;

  @override
  bool supports(ArchiveFormat format) => true;

  @override
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password}) async => [];

  @override
  Future<void> extractAll(
    Uri archiveLocation, {
    required Uri destination,
    List<String>? entryPaths,
    String? password,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) async {
    final file = File(p.join(tempDir.path, p.basename(entryPath)));
    await file.writeAsString('fake preview content');
    return file.uri;
  }
}

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/photos.zip'),
    format: ArchiveFormat.zip,
    entries: const [
      ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
      ArchiveEntry(
        pathInArchive: 'docs/a.txt',
        isDirectory: false,
        uncompressedSize: 5,
      ),
      ArchiveEntry(pathInArchive: 'root.txt', isDirectory: false, uncompressedSize: 5),
    ],
  );

  late Directory previewTempDir;

  setUp(() async {
    previewTempDir = await Directory.systemTemp.createTemp('dove_zip_screen_test_');
  });

  tearDown(() async {
    if (await previewTempDir.exists()) {
      await previewTempDir.delete(recursive: true);
    }
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveBrowserScreen(
            handle: handle,
            previewArchiveEntry: PreviewArchiveEntry(_FakeReader(previewTempDir)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('루트에서는 docs 폴더와 root.txt만 보인다', (tester) async {
    await pumpScreen(tester);

    expect(find.text('docs'), findsOneWidget);
    expect(find.text('root.txt'), findsOneWidget);
    expect(find.text('a.txt'), findsNothing);
    expect(find.text('2개 항목'), findsOneWidget);
  });

  testWidgets('폴더를 탭하면 그 안의 항목만 보이고 뒤로가기가 나타난다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();

    expect(find.text('a.txt'), findsOneWidget);
    expect(find.text('root.txt'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('1개 항목'), findsOneWidget);
  });

  testWidgets('뒤로가기를 누르면 루트로 돌아간다', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('root.txt'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('파일을 탭하면 미리보기 화면으로 이동한다', (tester) async {
    await pumpScreen(tester);

    // 탭이 실제 dart:io 파일 읽기(EntryViewerScreen의 텍스트 뷰어)로
    // 이어지므로 tester.runAsync 밖에서는 pump()만으로 끝나지 않는다
    // (daylight-commander-flutter의 archive_viewer_screen_test.dart에서
    // 이미 발견된 동일한 함정 — PLAN.md 8번 항목 참고). pumpAndSettle은
    // 실제 비동기 I/O와 섞이면 안정적으로 멈추지 않아, 고정 횟수의
    // pump로 대신한다.
    await tester.runAsync(() async {
      await tester.tap(find.text('root.txt'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    // AppBar 제목으로 미리보기 화면(EntryViewerScreen)에 도착했는지 확인 —
    // 세부 렌더링(텍스트/이미지/폴백)은 archive_browser_screen_preview_test.dart가 맡는다.
    expect(find.widgetWithText(AppBar, 'root.txt'), findsOneWidget);
  });

  testWidgets('닫기 버튼을 누르면 화면이 pop된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ArchiveBrowserScreen(handle: handle)),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('root.txt'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
