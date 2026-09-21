import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 첫 시도(비밀번호 없음)는 항상 실패하고, [correctPassword]와 일치하는
/// 비밀번호로만 성공하는 가짜 리더 — 비밀번호 재시도 UI 배선만 검증한다.
/// 진행률 콜백을 부르기 전에 실패하므로(진행률 다이얼로그가 계속
/// 불확정 상태) 이 파일의 테스트는 pumpAndSettle 대신 고정 횟수의 pump를
/// 쓴다 — archive_browser_screen_test.dart에서 이미 겪은 것과 같은 함정
/// (불확정 LinearProgressIndicator는 절대 "settle"되지 않는다).
class _PasswordProtectedReader implements ArchiveReader {
  _PasswordProtectedReader(this.correctPassword);

  final String correctPassword;

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
  }) async {
    if (password != correctPassword) {
      throw const ArchivePasswordRequiredException('a.txt');
    }
  }

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/protected.zip'),
    format: ArchiveFormat.zip,
    entries: const [ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false)],
  );

  Future<void> pumpScreen(WidgetTester tester, ArchiveReader reader) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(handle: handle, extractEntries: ExtractEntries(reader)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndShowPasswordDialog(WidgetTester tester) async {
    await tester.tap(find.text('알아서 압축 해제'));
    await tester.pump(); // 진행률 다이얼로그 표시
    await tester.pump(); // extractAll이 곧바로 실패 → 비밀번호 다이얼로그 표시
    expect(find.text('비밀번호가 필요합니다'), findsOneWidget);
  }

  Finder passwordDialogDescendant(Finder matching) => find.descendant(
        of: find.ancestor(
          of: find.text('비밀번호가 필요합니다'),
          matching: find.byType(AlertDialog),
        ),
        matching: matching,
      );

  testWidgets('비밀번호를 물어보고 올바르게 입력하면 해제가 성공한다', (tester) async {
    await pumpScreen(tester, _PasswordProtectedReader('hunter2'));
    await tapAndShowPasswordDialog(tester);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('확인'));
    await tester.pump(); // 다이얼로그 pop
    await tester.pump(); // extractAll 재시도(성공) → 진행률 다이얼로그 pop
    await tester.pump(); // 완료 스낵바 애니메이션 시작

    expect(find.textContaining('압축 해제 완료'), findsOneWidget);
  });

  testWidgets('틀린 비밀번호를 입력하면 다시 물어본다', (tester) async {
    await pumpScreen(tester, _PasswordProtectedReader('hunter2'));
    await tapAndShowPasswordDialog(tester);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('확인'));
    await tester.pump(); // 다이얼로그 pop
    await tester.pump(); // extractAll 재시도(실패) → 비밀번호 다이얼로그 다시 표시

    expect(find.text('비밀번호가 틀렸습니다. 다시 시도해 주세요.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('압축 해제 완료'), findsOneWidget);
  });

  testWidgets('비밀번호 입력을 취소하면 취소 스낵바가 뜬다', (tester) async {
    await pumpScreen(tester, _PasswordProtectedReader('hunter2'));
    await tapAndShowPasswordDialog(tester);

    // 진행률 다이얼로그에도 '취소' 버튼이 있어(그 밑에 깔려 있는 상태)
    // 비밀번호 다이얼로그로 범위를 좁혀야 한다.
    await tester.tap(passwordDialogDescendant(find.text('취소')));
    await tester.pump();
    await tester.pump();

    expect(find.text('압축 해제를 취소했습니다.'), findsOneWidget);
  });
}
