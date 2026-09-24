import 'package:dove_zip/settings/app_settings.dart';
import 'package:flutter/widgets.dart';

/// 홈 화면의 테마·언어 메뉴는 [AppSettingsScope]를 읽는다 — 앱처럼 설정을
/// 불러와 [app]을 감싼다. SharedPreferences 목 값을 넣은 뒤에 부른다.
Future<Widget> withAppSettings(Widget app) async =>
    AppSettingsScope(settings: await AppSettings.load(), child: app);
