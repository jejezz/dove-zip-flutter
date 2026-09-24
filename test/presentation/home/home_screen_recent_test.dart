import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_settings_scope.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'recent_archives': ['/tmp/photos.zip', '/tmp/docs.tar.gz'],
    });
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(await withAppSettings(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('저장된 최근 목록을 보여준다', (tester) async {
    await pumpHome(tester);

    expect(find.text('최근 연 압축파일'), findsOneWidget);
    expect(find.text('photos.zip'), findsOneWidget);
    expect(find.text('docs.tar.gz'), findsOneWidget);
  });

  testWidgets('x를 누르면 목록에서 사라진다', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('photos.zip'), findsNothing);
    expect(find.text('docs.tar.gz'), findsOneWidget);
  });

  testWidgets('목록이 비어 있으면 최근 연 압축파일 영역이 없다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester);

    expect(find.text('최근 연 압축파일'), findsNothing);
  });
}
