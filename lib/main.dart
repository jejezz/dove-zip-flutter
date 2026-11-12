import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'about/app_menu_bar.dart';
import 'about/dove_zip_about.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'application/launch_request.dart';
import 'data/launch_spool.dart';
import 'l10n/app_localizations.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/window/window_placement.dart';
import 'settings/app_settings.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';

final bool _isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 탐색기에서 여러 항목을 골라 "압축하기"/"여기에 풀기"를 누르면 항목마다
  // 프로세스가 따로 뜬다 — 창을 띄우기 전에 하나로 모으고, 나머지는 끝낸다.
  var launchArgs = args;
  if (Platform.isWindows) {
    final request = LaunchRequest.parse(args);
    if (request.action != LaunchAction.openFiles && request.paths.isNotEmpty) {
      final spool = LaunchSpool(Directory(p.join(Directory.systemTemp.path, 'dove_zip_launch', request.action.name)));
      final paths = await spool.gather(request.paths);
      if (paths == null) exit(0);
      launchArgs = LaunchRequest(request.action, paths).toArgs();
    }
  }

  registerExtraLicenses();

  // 저장해 둔 크기·위치로 창을 연다 (UI_UX.md 9장).
  Future<void> Function()? showWindow;
  if (_isDesktop) showWindow = await prepareWindow();

  // v0.1.x는 언어를 'locale' 키에 저장했다 — 한 번 옮겨서 사용자 설정을
  // 유지한다 (conventions/localization.md §5). 테마 키 'theme_mode'는 같다.
  final settings = await AppSettings.load(legacyKeys: {'locale': AppSettings.localeKey});
  // 데스크톱이 아니거나 UPDATE_SERVER 가 비어 있으면 null — 업데이트 확인 없음.
  final updates = await UpdateService.create();
  // UpdateScope 는 MaterialApp 위 — 정보 창이 이것을 읽어 "업데이트 확인" 단추를 붙인다.
  runApp(
    UpdateScope(
      service: updates,
      child: ProviderScope(
        child: DoveZipApp(settings: settings, launchPaths: launchArgs, updates: updates),
      ),
    ),
  );

  if (showWindow != null) {
    final show = showWindow;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(show()));
  }
}

class DoveZipApp extends StatefulWidget {
  const DoveZipApp({super.key, required this.settings, this.launchPaths = const [], this.updates});

  final AppSettings settings;

  /// 명령줄 인자 — 파일 연결(경로만)이나 탐색기 우클릭 메뉴(`--compress-here` 등).
  final List<String> launchPaths;

  /// 시작할 때 새 버전을 확인한다. null 이면 업데이트 확인을 쓰지 않는다.
  final UpdateService? updates;

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
    widget.updates?.startAutomaticCheck(_navigatorKey);
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

  void _checkForUpdates() {
    final context = _navigatorKey.currentContext;
    if (context != null) widget.updates?.checkManually(context);
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
          theme: AppTheme.light(palette: widget.settings.accentPalette),
          darkTheme: AppTheme.dark(palette: widget.settings.accentPalette),
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: AppSettings.resolveLocale,
          // macOS 앱 메뉴의 "About Dove Zip"이 앱 바의 정보 버튼과 같은 창을 연다.
          // 설정의 화면 글자 크기가 앱 전체 글자에 곱해진다.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(widget.settings.textScale)),
            child: AppMenuBar(
              onAbout: _showAbout,
              onCheckForUpdates: widget.updates == null ? null : _checkForUpdates,
              child: child!,
            ),
          ),
          home: HomeScreen(launchPaths: widget.launchPaths),
        ),
      ),
    );
  }
}
