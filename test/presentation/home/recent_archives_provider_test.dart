import 'package:dove_zip/presentation/home/recent_archives_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('기본값은 빈 목록이다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(recentArchivesProvider), isEmpty);
  });

  testWidgets('addRecent는 맨 앞에 추가한다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(recentArchivesProvider.notifier).addRecent('/a.zip');
    await container.read(recentArchivesProvider.notifier).addRecent('/b.zip');

    expect(container.read(recentArchivesProvider), ['/b.zip', '/a.zip']);
  });

  testWidgets('같은 경로를 다시 열면 중복 없이 맨 앞으로 옮긴다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(recentArchivesProvider.notifier).addRecent('/a.zip');
    await container.read(recentArchivesProvider.notifier).addRecent('/b.zip');
    await container.read(recentArchivesProvider.notifier).addRecent('/a.zip');

    expect(container.read(recentArchivesProvider), ['/a.zip', '/b.zip']);
  });

  testWidgets('최대 개수를 넘으면 오래된 것부터 잘라낸다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recentArchivesProvider.notifier);

    for (var i = 0; i < 12; i++) {
      await notifier.addRecent('/$i.zip');
    }

    final result = container.read(recentArchivesProvider);
    expect(result, hasLength(10));
    expect(result.first, '/11.zip');
    expect(result.contains('/0.zip'), isFalse);
    expect(result.contains('/1.zip'), isFalse);
  });

  testWidgets('remove는 목록에서 제거한다', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(recentArchivesProvider.notifier);
    await notifier.addRecent('/a.zip');
    await notifier.addRecent('/b.zip');

    await notifier.remove('/a.zip');

    expect(container.read(recentArchivesProvider), ['/b.zip']);
  });

  testWidgets('저장된 값이 있으면 그대로 불러온다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_archives': ['/x.zip', '/y.zip'],
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(recentArchivesProvider);
    await tester.pumpAndSettle();

    expect(container.read(recentArchivesProvider), ['/x.zip', '/y.zip']);
  });
}
