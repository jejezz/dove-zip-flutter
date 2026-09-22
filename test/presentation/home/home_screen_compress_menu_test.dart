import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `openFiles()`(file_selector)는 macOS에서 `canChooseDirectories`를 항상
/// false로 고정해 둬 폴더를 통째로 고를 수 없다 — 그래서 "새 압축 만들기"는
/// 파일 피커/폴더 피커 중 고를 수 있는 작은 메뉴가 됐다. 실제 네이티브
/// 피커 호출(`_pickFilesAndCompress`/`_pickFolderAndCompress`)은 이
/// 테스트 환경에 플랫폼 채널이 없어 검증할 수 없으니, 메뉴 자체가 올바른
/// 두 항목과 함께 열리는지만 확인한다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('"새 압축 만들기"를 누르면 파일/폴더 선택 메뉴가 뜬다', (tester) async {
    await pumpHome(tester);

    expect(find.text('파일 선택...'), findsNothing);
    expect(find.text('폴더 선택...'), findsNothing);

    await tester.tap(find.text('새 압축 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('파일 선택...'), findsOneWidget);
    expect(find.text('폴더 선택...'), findsOneWidget);
  });
}
