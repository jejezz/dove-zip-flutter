import 'package:dove_zip/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 상대 명도 기반 대비율. `Color.computeLuminance()`가 이미 그
/// 공식을 구현하고 있어 그대로 쓴다.
double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // `showErrorSnackBar`의 "복사" 액션이 SnackBar 배경과 거의 구분되지
  // 않던 회귀 버그(colorScheme에 inverseSurface/inversePrimary를 지정하지
  // 않아 브랜드 팔레트와 무관한 Material 3 기본값이 쓰이던 문제) 재발
  // 방지용 — snackBarTheme을 명시적으로 지정한 이후 대비가 실제로
  // 충분한지 두 테마 모두 확인한다.
  for (final MapEntry(key: name, value: theme) in {
    'dark': AppTheme.dark(),
    'light': AppTheme.light(),
  }.entries) {
    group('AppTheme.$name()의 snackBarTheme', () {
      final snackBarTheme = theme.snackBarTheme;

      test('배경과 본문 텍스트의 대비가 WCAG AA(4.5:1) 이상이다', () {
        final background = snackBarTheme.backgroundColor!;
        final content = snackBarTheme.contentTextStyle!.color!;
        expect(_contrastRatio(background, content), greaterThanOrEqualTo(4.5));
      });

      test('배경과 "복사" 액션 버튼 글자색의 대비가 최소 3:1 이상이다(WCAG UI 컴포넌트 기준)', () {
        final background = snackBarTheme.backgroundColor!;
        final action = snackBarTheme.actionTextColor!;
        expect(_contrastRatio(background, action), greaterThanOrEqualTo(3.0));
      });

      test('액션 버튼 글자색이 본문 텍스트와 다르다(버튼임을 구분할 수 있어야 함)', () {
        expect(snackBarTheme.actionTextColor, isNot(snackBarTheme.contentTextStyle!.color));
      });
    });
  }
}
