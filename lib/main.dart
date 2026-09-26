import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'about/app_menu_bar.dart';
import 'about/dove_zip_about.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'l10n/app_localizations.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/window/dock_window.dart';
import 'settings/app_settings.dart';

final bool _isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();

  // 화면 옆에 세우는 세로 창 (UI_UX.md 9장).
  if (_isDesktop) await showDockWindow();

  // v0.1.x는 언어를 'locale' 키에 저장했다 — 한 번 옮겨서 사용자 설정을
  // 유지한다 (conventions/localization.md §5). 테마 키 'theme_mode'는 같다.
  final settings = await AppSettings.load(legacyKeys: {'locale': AppSettings.localeKey});
  runApp(ProviderScope(child: DoveZipApp(settings: settings)));
}

class DoveZipApp extends StatefulWidget {
  const DoveZipApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<DoveZipApp> createState() => _DoveZipAppState();
}

class _DoveZipAppState extends State<DoveZipApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncWindowBrightness);
    _syncWindowBrightness();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncWindowBrightness);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱에서 다크를 골라도 OS가 라이트면 제목 표시줄은 밝게 남는다
  // (conventions/theming.md §4). Linux는 window_manager가 지원하지 않는다.
  @override
  void didChangePlatformBrightness() => _syncWindowBrightness();

  void _syncWindowBrightness() {
    // flutter test에는 window_manager 플러그인이 없다.
    if (!_isDesktop || Platform.isLinux || Platform.environment.containsKey('FLUTTER_TEST')) return;
    final brightness = switch (widget.settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    windowManager.setBrightness(brightness);
  }

  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context != null) showDoveZipAbout(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: AppIdentity.displayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: AppSettings.resolveLocale,
          // macOS 앱 메뉴의 "About Dove Zip"이 앱 바의 정보 버튼과 같은 창을 연다.
          builder: (context, child) => AppMenuBar(onAbout: _showAbout, child: child!),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
