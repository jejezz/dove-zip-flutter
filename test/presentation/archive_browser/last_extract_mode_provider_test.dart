import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:dove_zip/presentation/archive_browser/last_extract_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// theme_mode_provider와 마찬가지로 SharedPreferences.getInstance()를 쓰는
// StateNotifier라 순수 test()보다 testWidgets() 안에서 pump()로 비동기
// 로드를 흘려보내는 쪽이 안정적이다(daylight-commander-flutter 계열
// 프로젝트에서 반복적으로 검증된 방식).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('기본값은 smart다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(lastExtractModeProvider), ExtractDestinationMode.smart);
  });

  testWidgets('remember를 호출하면 상태가 즉시 바뀐다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(lastExtractModeProvider.notifier).remember(
          ExtractDestinationMode.here,
        );

    expect(container.read(lastExtractModeProvider), ExtractDestinationMode.here);
  });

  testWidgets('remember는 shared_preferences에도 실제로 저장한다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(lastExtractModeProvider.notifier).remember(
          ExtractDestinationMode.chooseFolder,
        );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_extract_mode'), 'chooseFolder');
  });

  testWidgets('저장된 값이 있으면 새 컨트롤러가 그 값으로 초기화된다', (tester) async {
    SharedPreferences.setMockInitialValues({'last_extract_mode': 'here'});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(lastExtractModeProvider); // provider 생성(생성자의 비동기 로드 시작)
    await tester.pumpAndSettle();

    expect(container.read(lastExtractModeProvider), ExtractDestinationMode.here);
  });
}
