import 'package:flutter/material.dart';

/// 고를 수 있는 색 구성 (settings-screen.md §4). 기본 [saturn]은 이 파일의 고정 팔레트
/// 그대로이고, [highContrast] 전을 뺀 나머지는 주색(primary)만 바꾼다(다크·라이트 한 쌍).
enum AccentPalette {
  saturn(Color(0xFF4C9DFF), Color(0xFF2C6BE0)),
  teal(Color(0xFF2DD4BF), Color(0xFF0F766E)),
  amber(Color(0xFFFBBF24), Color(0xFFB45309)),
  rose(Color(0xFFFB7185), Color(0xFFBE123C)),
  slate(Color(0xFF94A3B8), Color(0xFF475569)),
  highContrast(Color(0xFFFFD60A), Color(0xFF0000CC));

  const AccentPalette(this.darkPrimary, this.lightPrimary);

  final Color darkPrimary;
  final Color lightPrimary;

  Color primaryFor(Brightness b) => b == Brightness.dark ? darkPrimary : lightPrimary;

  ColorScheme apply(ColorScheme scheme) {
    if (this == saturn || this == highContrast) return scheme;
    final dark = scheme.brightness == Brightness.dark;
    return scheme.copyWith(
      primary: dark ? darkPrimary : lightPrimary,
      onPrimary: dark ? AppColors.bg : Colors.white,
      inversePrimary: dark ? lightPrimary : darkPrimary,
    );
  }
}

/// Dove Zip의 팔레트 + 테마.
///
/// daylight-commander-flutter의 `AppColors`/`AppRadius`/`AppTheme`를 색상 값
/// 변경 없이 그대로 이식했다 — 자매 앱으로서 동일한 비주얼 아이덴티티를
/// 공유하기 위함. 이 앱만의 의미 부여(Success = 생성+해제 가능 배지,
/// Warning = 해제 전용 배지)는 UI_UX.md 2장 참고.
class AppColors {
  const AppColors._();

  // Dark surfaces
  static const bg = Color(0xFF0A0E14);
  static const surface = Color(0xFF151D27);
  static const surfaceHi = Color(0xFF1D2733);
  static const stroke = Color(0x1AFFFFFF);
  static const strokeStrong = Color(0x33FFFFFF);

  // Light surfaces
  static const bgLight = Color(0xFFF4F6FA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceHiLight = Color(0xFFE3E8EF);
  static const strokeLight = Color(0x14000000);
  static const strokeStrongLight = Color(0x24000000);

  // Brand
  static const primary = Color(0xFF4C9DFF);
  static const primaryDeep = Color(0xFF2C6BE0);
  static const accent = Color(0xFF7C5CFF);

  // Semantics
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5A5F);

  static const textHi = Color(0xFFF1F5F9);
  static const textMid = Color(0xFFA9B4C4);
  static const textLow = Color(0xFF6B7787);
  static const textHiLight = Color(0xFF101828);
  static const textMidLight = Color(0xFF5B6676);

  // 파일 유형 색상 (daylight UI_UX.md 3장 계승 — 압축파일 내부 항목 아이콘 폴백용)
  static const imageDark = Color(0xFFFFC24B);
  static const imageLight = Color(0xFFB4750B);
  static const videoDark = Color(0xFF38BDF8);
  static const videoLight = Color(0xFF2590C5);
  static const audioDark = Color(0xFF22D3EE);
  static const audioLight = Color(0xFF1BA8BC);
  static const archiveDark = Color(0xFFC084FC);
  static const archiveLight = Color(0xFF7C5CFF);
  static const codeDark = Color(0xFF4ADE80);
  static const codeLight = Color(0xFF3B9959);
  static const documentDark = Color(0xFFFF5A5F);
  static const documentLight = Color(0xFFD9373C);
  static const executableDark = Color(0xFFFF7A59);
  static const executableLight = Color(0xFFC2531F);
}

class AppRadius {
  const AppRadius._();
  static const card = 24.0;
  static const tile = 20.0;
  static const iconChip = 7.0;
  static const chip = 999.0;
  static const sheet = 32.0;
}

/// [AccentPalette.highContrast] 전용 ColorScheme: 주색만이 아니라 배경·글자·테두리를 순흑/순백 최대
/// 대비로 바꾼다 (settings.md). 반투명 테두리는 꽉 찬 outline 색으로 대신한다.
abstract final class _HighContrast {
  static const dimDark = Color(0xFFBFBFBF);
  static const surfaceHiDark = Color(0xFF262626);
  static const errorDark = Color(0xFFFF6B6B);
  static const dimLight = Color(0xFF404040);
  static const surfaceHiLight = Color(0xFFE0E0E0);
  static const errorLight = Color(0xFFCC0000);

  static ColorScheme scheme(Brightness b) {
    final dark = b == Brightness.dark;
    final fg = dark ? Colors.white : Colors.black;
    final bg = dark ? Colors.black : Colors.white;
    final dim = dark ? dimDark : dimLight;
    final hi = dark ? surfaceHiDark : surfaceHiLight;
    final primary = AccentPalette.highContrast.primaryFor(b);
    return ColorScheme(
      brightness: b,
      primary: primary,
      onPrimary: bg,
      secondary: primary,
      onSecondary: bg,
      error: dark ? errorDark : errorLight,
      onError: bg,
      surface: bg,
      onSurface: fg,
      onSurfaceVariant: dim,
      surfaceContainerHighest: hi,
      surfaceContainerHigh: hi,
      surfaceContainer: bg,
      surfaceContainerLow: bg,
      surfaceContainerLowest: bg,
      outline: fg,
      outlineVariant: dim,
      inverseSurface: fg,
      onInverseSurface: bg,
      inversePrimary: AccentPalette.highContrast.primaryFor(dark ? Brightness.light : Brightness.dark),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const _fontFamily = 'SeoulNamsan';

  /// SeoulNamsan에 없는 글자(일부 한자·기호·다른 언어의 파일 이름)를 OS 한글
  /// 글꼴로 넘긴다 — 없으면 두부(□)로 보인다 (conventions/fonts.md §2).
  static const _fontFallback = ['Apple SD Gothic Neo', 'Malgun Gothic', 'Noto Sans CJK KR', 'Noto Sans KR'];

  static ThemeData dark({AccentPalette palette = AccentPalette.saturn}) {
    final hc = palette == AccentPalette.highContrast;
    final scheme = hc
        ? _HighContrast.scheme(Brightness.dark)
        : palette.apply(const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textHi,
      error: AppColors.danger,
      onError: Colors.white,
    ));
    return _base(
      scheme,
      hc ? Colors.black : AppColors.bg,
      hc ? Colors.white : AppColors.textHi,
      hc ? _HighContrast.dimDark : AppColors.textMid,
    );
  }

  static ThemeData light({AccentPalette palette = AccentPalette.saturn}) {
    final hc = palette == AccentPalette.highContrast;
    final scheme = hc
        ? _HighContrast.scheme(Brightness.light)
        : palette.apply(const ColorScheme.light(
      primary: AppColors.primaryDeep,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textHiLight,
      error: AppColors.danger,
      onError: Colors.white,
    ));
    return _base(
      scheme,
      hc ? Colors.white : AppColors.bgLight,
      hc ? Colors.black : AppColors.textHiLight,
      hc ? _HighContrast.dimLight : AppColors.textMidLight,
    );
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color background,
    Color textHi,
    Color textMid,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        // 앱 바 높이는 앱마다 따로 정하지 않고 여기서만 정한다 (ui-ux.md §4).
        toolbarHeight: 44,
        foregroundColor: textHi,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textHi,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.stroke : AppColors.strokeLight,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: textHi),
        bodyLarge:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textHi),
        bodyMedium:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textMid),
        labelLarge:
            TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textMid),
        labelSmall:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: textMid),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          textStyle: const TextStyle(
              fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          side: BorderSide(
              color: isDark ? AppColors.strokeStrong : AppColors.strokeStrongLight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          textStyle: const TextStyle(
              fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceHi : AppColors.surfaceHiLight,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: BorderSide(
            color: isDark ? AppColors.strokeStrong : AppColors.strokeStrongLight,
          ),
        ),
      ),
      // colorScheme에 inverseSurface/inversePrimary를 직접 지정하지 않아
      // SnackBar가 Material 3 기본값(우리 브랜드 팔레트와 무관한 값)을
      // 쓰면 액션 버튼 글자색이 배경과 거의 구분되지 않는 문제가 있었다
      // (showErrorSnackBar의 "복사" 버튼이 거의 안 보이던 원인) — 팝업
      // 메뉴와 같은 surfaceHi 계열로 명시해 항상 대비를 보장한다.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceHi : AppColors.surfaceHiLight,
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          color: textHi,
        ),
        actionTextColor: isDark ? AppColors.primary : AppColors.primaryDeep,
      ),
    );
  }
}
