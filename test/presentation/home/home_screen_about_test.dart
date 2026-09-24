import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 정보 버튼은 홈 화면 앱바의 가장 오른쪽에 있고, 누르면 앱 정보
/// 다이얼로그가 [PackageInfo]에서 읽은 버전과 함께 뜬다.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Dove Zip',
      packageName: 'dove_zip',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
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

  testWidgets('정보 버튼이 앱바의 가장 오른쪽 아이콘이다', (tester) async {
    await pumpHome(tester);

    final actions = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(IconButton),
    );
    final lastAction = tester.widget<IconButton>(actions.last);
    expect(lastAction.tooltip, '정보');
  });

  testWidgets('정보 버튼을 누르면 앱 정보 다이얼로그가 뜨고 닫기로 닫힌다', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('정보'));
    await tester.pumpAndSettle();

    expect(find.text('Dove Zip 정보'), findsOneWidget);
    expect(find.text('광고 없는 올인원 압축/해제 유틸리티'), findsOneWidget);
    expect(find.text('버전 0.1.0+1'), findsOneWidget);
    expect(find.text('주요 기능'), findsOneWidget);
    expect(find.text('Flutter(Dart)로 제작'), findsOneWidget);
    expect(find.text('라이선스: MIT'), findsOneWidget);
    expect(find.text('GitHub 저장소 열기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    expect(find.text('Dove Zip 정보'), findsNothing);
  });
}
