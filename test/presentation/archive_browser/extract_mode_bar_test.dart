import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/extract_mode_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required ExtractDestinationMode highlightedMode,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ExtractModeBar(
          onSelectMode: (_) {},
          highlightedMode: highlightedMode,
        ),
      ),
    ),
  );
}

void main() {
  // 강조된(마지막 선택) 버튼이 나머지보다 넓게 그려지던 회귀 버그 —
  // 강조 모드가 바뀔 때마다(PLAN.md 1.2 P1 "마지막으로 고른 모드를 기억")
  // 버튼 너비가 들썩였다. 이제는 스타일(Filled/Outlined)로만 강조하고
  // 셋 다 항상 같은 너비를 쓴다(UI_UX.md 7장 "3개를 동급으로 노출").
  for (final mode in ExtractDestinationMode.values) {
    testWidgets('강조 모드가 $mode여도 세 버튼의 너비가 모두 같다', (tester) async {
      await _pumpBar(tester, highlightedMode: mode);

      final width1 = tester.getSize(find.byType(FilledButton)).width;
      final outlinedWidths = tester
          .getSize(find.byType(OutlinedButton).first)
          .width;

      // FilledButton은 정확히 하나(강조된 모드), OutlinedButton은 둘 —
      // 셋 다 같은 Expanded 폭을 나눠 가지므로 전부 같은 너비여야 한다.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
      expect(width1, outlinedWidths);
      expect(
        tester.getSize(find.byType(OutlinedButton).last).width,
        outlinedWidths,
      );
    });
  }
}
