import 'dart:async';

import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/entities/extract_progress.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 디스크에 아무것도 쓰지 않고, `ExtractModeBar` → `ExtractEntries` →
/// 리더로 이어지는 배선(진행률 다이얼로그, 충돌 다이얼로그, 완료/에러
/// 스낵바)만 검증하기 위한 가짜 리더. 진짜 압축 해제 동작 자체는
/// dart_archive_reader_extract_test.dart가 실제 파일로 검증한다.
class _FakeReader implements ArchiveReader {
  _FakeReader({
    this.conflictOnFirstFile = false,
    this.failWith,
    this.gate,
    this.entryFailures = const [],
  });

  final bool conflictOnFirstFile;
  final Object? failWith;

  /// [extractAll]이 정상적으로 끝나되 일부 항목은 손상돼 건너뛴 것처럼
  /// 보고하게 한다 — PLAN.md 1.2 "손상된 압축파일 복구/부분 해제 시도"의
  /// UI 배선(부분 성공 스낵바)만 검증하기 위한 장치.
  final List<ExtractFailure> entryFailures;

  /// 넘기면 이 Future가 완료될 때까지 해제를 멈춰둔다 — 테스트가 "진행
  /// 중" 상태(진행률 다이얼로그가 실제로 보이는 순간)를 직접 통제하기
  /// 위한 장치. 실제 시간 지연(`Future.delayed`)에 기대면 위젯테스트의
  /// 가짜 시계와 얽혀 타이밍이 불안정해지므로 `Completer`로 대신한다.
  final Future<void>? gate;

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
    if (gate != null) await gate;
    if (failWith != null) throw failWith!;

    onProgress?.call(const ExtractProgress(done: 0, total: 1, currentName: 'a.txt'));
    if (conflictOnFirstFile) {
      final action = await onConflict(const ExtractConflict(
        entryPath: 'a.txt',
        destinationPath: '/tmp/out/a.txt',
      ));
      if (action == ConflictAction.cancel) {
        throw const OperationCancelledException();
      }
    }
    onProgress?.call(const ExtractProgress(done: 1, total: 1, currentName: 'a.txt'));
    return entryFailures;
  }

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/photos.zip'),
    format: ArchiveFormat.zip,
    entries: const [ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false)],
  );

  testWidgets('알아서 압축 해제를 누르면 진행률 다이얼로그 후 완료 스낵바가 뜬다', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(_FakeReader(gate: gate.future)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('알아서 압축 해제'));
    await tester.pump(); // 해제는 gate에 막혀 대기 중 — 진행률 다이얼로그만 뜬 상태
    expect(find.text('압축 해제 중...'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('압축 해제 중...'), findsNothing);
    expect(find.textContaining('압축 해제 완료'), findsOneWidget);
  });

  testWidgets('autoExtractMode가 있으면 버튼을 누르지 않아도 화면이 뜨자마자 자동으로 해제된다', (tester) async {
    // macOS Finder 서비스 메뉴 "여기에 풀기"(PLAN.md 1.4 "OS 컨텍스트
    // 메뉴", HomeScreen._openArchiveForAutoExtract) 전용 경로 — 버튼 탭
    // 없이도 initState의 postFrameCallback이 곧장 _runExtraction을
    // 실행해야 한다.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(_FakeReader()),
          autoExtractMode: ExtractDestinationMode.here,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('압축 해제 완료'), findsOneWidget);
  });

  testWidgets('충돌이 나면 충돌 다이얼로그가 뜬다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(_FakeReader(conflictOnFirstFile: true)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('여기에 압축 해제'));
    await tester.pumpAndSettle();

    expect(find.text('이미 같은 이름의 파일이 있습니다'), findsOneWidget);

    await tester.tap(find.text('덮어쓰기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('압축 해제 완료'), findsOneWidget);
  });

  testWidgets('충돌 다이얼로그에서 취소를 고르면 취소 스낵바가 뜬다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(_FakeReader(conflictOnFirstFile: true)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('여기에 압축 해제'));
    await tester.pumpAndSettle();

    // 진행률 다이얼로그에도 '취소' 버튼이 있어 충돌 다이얼로그로 범위를
    // 좁혀야 한다 — 두 다이얼로그가 동시에 스택에 떠 있는 상태.
    final conflictDialog = find.ancestor(
      of: find.text('이미 같은 이름의 파일이 있습니다'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(find.descendant(of: conflictDialog, matching: find.text('취소')));
    await tester.pumpAndSettle();

    expect(find.text('압축 해제를 취소했습니다.'), findsOneWidget);
  });

  testWidgets('일부 항목만 손상돼 건너뛰면 완료 스낵바에 손상 개수와 목록이 함께 뜬다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(_FakeReader(
            entryFailures: const [
              ExtractFailure(entryPath: 'broken.txt', message: '압축 스트림이 손상됨'),
            ],
          )),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('알아서 압축 해제'));
    await tester.pumpAndSettle();

    expect(find.textContaining('압축 해제 완료'), findsOneWidget);
    expect(find.textContaining('1개 항목은 손상되어 건너뜀'), findsOneWidget);
    expect(find.textContaining('broken.txt: 압축 스트림이 손상됨'), findsOneWidget);
    // 복사할 정보가 있는 부분 실패는 완료 스낵바가 아니라 copy 버튼이 있는
    // showErrorSnackBar 쪽 경로를 타야 한다(PLAN.md 1.2).
    expect(find.text('복사'), findsOneWidget);
  });

  testWidgets('리더가 실패하면 에러 스낵바가 뜬다', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(
          handle: handle,
          extractEntries: ExtractEntries(_FakeReader(failWith: Exception('디스크가 가득 참'))),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('알아서 압축 해제'));
    await tester.pumpAndSettle();

    expect(find.textContaining('압축 해제 실패'), findsOneWidget);
  });
}
