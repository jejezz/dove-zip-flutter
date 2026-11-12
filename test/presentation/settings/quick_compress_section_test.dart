import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/settings/quick_compress_format_provider.dart';
import 'package:dove_zip/presentation/settings/quick_compress_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 설정의 "압축하기" 구역 — 우클릭 메뉴가 바로 만들 형식을 고른다.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: QuickCompressSection()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('기본은 ZIP, 고르면 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.text('압축하기'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'ZIP');

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TAR').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(quickCompressFormatKey), 'tar');
  });

  testWidgets('저장된 형식을 읽어 보여 준다', (tester) async {
    SharedPreferences.setMockInitialValues({quickCompressFormatKey: 'sevenZip'});
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '7Z');
  });

  test('모르는 값이 저장돼 있으면 ZIP', () async {
    SharedPreferences.setMockInitialValues({quickCompressFormatKey: 'rar'});
    expect((await QuickCompressFormatController.read()).name, 'zip');
  });
}
