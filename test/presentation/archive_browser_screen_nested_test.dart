import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/application/usecases/preview_archive_entry.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// PLAN.md 1.1 "중첩 압축 드릴다운" — 바깥 압축파일 안에 실제로 유효한
/// 또 다른 zip이 들어있는 상황을 재현한다. `extractEntryToTemp`가 그
/// 진짜 zip 바이트를 임시 파일로 꺼내주면, `_openFile`이 이름으로 형식을
/// 인식해 `OpenArchive`(기본값 = 진짜 `DartArchiveReader`)로 곧장 열어야
/// 한다 — 이 테스트는 그 열기 단계만 가짜로 대체하고, 실제 안쪽 압축
/// 해석은 진짜 백엔드에 맡긴다.
class _FakeReader implements ArchiveReader {
  _FakeReader(this.tempDir, this.entryContents);

  final Directory tempDir;
  final Map<String, List<int>> entryContents;

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
  }) => throw UnimplementedError('이 테스트에서는 쓰지 않음');

  @override
  Future<Uri> extractEntryToTemp(
    Uri archiveLocation,
    String entryPath, {
    String? password,
  }) async {
    final file = File(p.join(tempDir.path, p.basename(entryPath)));
    await file.writeAsBytes(entryContents[entryPath]!);
    return file.uri;
  }
}

List<int> _sampleZipBytes(String innerName, String innerContent) {
  final archive = Archive()
    ..addFile(ArchiveFile.string(innerName, innerContent));
  return ZipEncoder().encode(archive);
}

Future<void> _pumpAndTap(WidgetTester tester, String label) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(label));
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

void main() {
  late Directory tempDir;

  setUp(() async {
    // ArchiveBrowserScreen이 watch하는 lastExtractModeProvider가
    // SharedPreferences를 읽는다 — tester.runAsync로 진짜 비동기 경로를
    // 타면(아래 _pumpAndTap) 목(mock) 채널이 없을 때의
    // MissingPluginException이 조용히 묻히지 않고 테스트 실패로
    // 드러난다(다른 archive_browser_screen 테스트들은 runAsync를
    // 쓰지 않아 이 문제를 겪지 않았다).
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('dove_zip_nested_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  testWidgets('압축파일 안의 진짜 zip을 탭하면 미리보기 대신 그 안으로 곧장 들어간다', (tester) async {
    final handle = ArchiveHandle(
      location: Uri.file('/tmp/outer.zip'),
      format: ArchiveFormat.zip,
      entries: const [
        ArchiveEntry(pathInArchive: 'nested.zip', isDirectory: false),
      ],
    );
    final reader = _FakeReader(tempDir, {
      'nested.zip': _sampleZipBytes('inner.txt', 'hello from inside'),
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveBrowserScreen(
            handle: handle,
            previewArchiveEntry: PreviewArchiveEntry(reader),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _pumpAndTap(tester, 'nested.zip');

    // 미리보기(EntryViewerScreen)가 아니라 또 다른 탐색 화면으로 들어가고,
    // 그 화면엔 안쪽 zip의 항목이 그대로 보여야 한다.
    expect(find.widgetWithText(AppBar, 'nested.zip'), findsOneWidget);
    expect(find.text('inner.txt'), findsOneWidget);
  });

  testWidgets('압축 형식으로는 인식되지만 아직 못 읽는 포맷은 평소 미리보기로 대체된다', (tester) async {
    // .iso(iso9660)는 FormatRegistry엔 등록돼 있지만 DartArchiveReader가
    // 아직 읽을 수 없는 형식이다 — UnsupportedArchiveFormatException을
    // 잡아 평소 미리보기(지원 안 함 + OS 기본 앱 열기 폴백)로 이어져야
    // 한다.
    final handle = ArchiveHandle(
      location: Uri.file('/tmp/outer.zip'),
      format: ArchiveFormat.zip,
      entries: const [
        ArchiveEntry(pathInArchive: 'disk.iso', isDirectory: false),
      ],
    );
    final reader = _FakeReader(tempDir, {
      'disk.iso': 'fake iso bytes'.codeUnits,
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveBrowserScreen(
            handle: handle,
            previewArchiveEntry: PreviewArchiveEntry(reader),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _pumpAndTap(tester, 'disk.iso');

    expect(find.widgetWithText(AppBar, 'disk.iso'), findsOneWidget);
    expect(find.text('이 형식은 아직 미리보기를 지원하지 않습니다'), findsOneWidget);
  });

  testWidgets(
    '이름은 압축파일이지만 실제로 깨진 데이터면 빈 압축파일로 열린다(알려진 한계)',
    (tester) async {
      // archive 패키지의 ZipDecoder/TarDecoder는 매직 바이트가 전혀 없는
      // 쓰레기 데이터도 에러 없이 "항목 0개"로 관대하게 디코딩한다 — 이
      // 앱 전체(최상위 "열기" 포함)의 기존 특성이지 드릴다운이 새로
      // 만든 문제가 아니다. 그래서 진짜로 깨진 zip 이름 파일은 에러
      // 대신 빈 폴더로 열린다.
      final handle = ArchiveHandle(
        location: Uri.file('/tmp/outer.zip'),
        format: ArchiveFormat.zip,
        entries: const [
          ArchiveEntry(pathInArchive: 'fake.zip', isDirectory: false),
        ],
      );
      final reader = _FakeReader(tempDir, {
        'fake.zip': 'not actually a zip'.codeUnits,
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ArchiveBrowserScreen(
              handle: handle,
              previewArchiveEntry: PreviewArchiveEntry(reader),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _pumpAndTap(tester, 'fake.zip');

      expect(find.widgetWithText(AppBar, 'fake.zip'), findsOneWidget);
      expect(find.text('빈 폴더입니다'), findsOneWidget);
    },
  );
}
