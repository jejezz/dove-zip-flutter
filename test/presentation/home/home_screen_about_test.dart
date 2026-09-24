import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/home/home_screen.dart';
import 'package:dove_zip/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 바 오른쪽 끝은 테마 | 언어 | 정보 순서이고 (conventions/theming.md §3),
/// 정보 버튼은 공통 정보 창을 [PackageInfo]의 버전과 함께 연다.
void main() {
  late AppSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Dove Zip',
      packageName: 'dove_zip',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
    settings = await AppSettings.load();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      child: AppSettingsScope(
        settings: settings,
        child: const MaterialApp(
          locale: Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('앱 바 오른쪽 끝이 테마 | 언어 | 정보 순서다', (tester) async {
    await pumpHome(tester);

    final tooltips = [
      for (final w in tester.widgetList(find.descendant(of: find.byType(AppBar), matching: find.byType(Tooltip))))
        (w as Tooltip).message,
    ];
    expect(tooltips.sublist(tooltips.length - 3), ['테마', '언어', '정보']);
  });

  testWidgets('테마 메뉴는 체크 표시 메뉴이고 고르면 저장된다', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('테마'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<ThemeMode>), findsNWidgets(3));

    await tester.tap(find.text('다크'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettings.themeModeKey), 'dark');
  });

  testWidgets('정보 버튼을 누르면 공통 정보 창이 뜨고 닫기로 닫힌다', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();

    expect(find.text('Dove Zip'), findsWidgets);
    expect(find.text('광고 없는 올인원 압축/해제 유틸리티'), findsOneWidget);
    expect(find.text('버전 0.1.0 (빌드 1)'), findsOneWidget);
    expect(find.text('Copyright © 2026 Jongyun Ahn'), findsOneWidget);
    expect(find.text('MIT License'), findsOneWidget);
    expect(find.text('오픈소스 라이선스'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    expect(find.text('오픈소스 라이선스'), findsNothing);
  });
}
