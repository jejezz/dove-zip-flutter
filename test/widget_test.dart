import 'package:dove_zip/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('빈 상태 화면이 열기/새 압축 만들기 버튼과 함께 뜬다', (WidgetTester tester) async {
    // 테스트 환경의 시스템 로케일에 관계없이 항상 한국어로 고정한다 —
    // localeProvider가 SharedPreferences에서 읽어오는 값을 미리 넣어준다
    // (다른 Riverpod persistence provider 테스트와 동일한 패턴).
    SharedPreferences.setMockInitialValues({'locale': 'ko'});

    await tester.pumpWidget(const ProviderScope(child: DoveZipApp()));
    await tester.pumpAndSettle();

    expect(find.text('Dove Zip'), findsOneWidget);
    expect(find.text('열기'), findsOneWidget);
    expect(find.text('새 압축 만들기'), findsOneWidget);
  });
}
