import 'package:dove_zip/main.dart';
import 'package:dove_zip/settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('빈 상태 화면이 열기/새 압축 만들기 버튼과 함께 뜬다', (WidgetTester tester) async {
    // 테스트 환경의 시스템 로케일에 관계없이 항상 한국어로 고정한다 —
    // AppSettings가 SharedPreferences의 'app_locale'을 읽는다.
    SharedPreferences.setMockInitialValues({AppSettings.localeKey: 'ko'});
    final settings = await AppSettings.load();

    await tester.pumpWidget(ProviderScope(child: DoveZipApp(settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('Dove Zip'), findsOneWidget);
    expect(find.text('열기'), findsOneWidget);
    expect(find.text('새 압축 만들기'), findsOneWidget);
  });

  testWidgets("v0.1.x의 'locale' 키에 저장된 언어를 이어받는다", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final settings = await AppSettings.load(legacyKeys: {'locale': AppSettings.localeKey});

    await tester.pumpWidget(ProviderScope(child: DoveZipApp(settings: settings)));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettings.localeKey), 'en');
    expect(prefs.containsKey('locale'), isFalse);
  });
}
