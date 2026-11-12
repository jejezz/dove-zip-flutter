import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../app_identity.dart';
import '../application/usecases/open_url.dart';
import '../domain/repositories/default_app_registrar.dart';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// 이 플랫폼의 [DefaultAppRegistrar]. 데스크톱이 아니면 null — 설정에 "기본 앱"
/// 구역을 보이지 않는다.
DefaultAppRegistrar? platformDefaultAppRegistrar() {
  if (Platform.isMacOS) return MacDefaultAppRegistrar();
  if (Platform.isWindows) return WindowsDefaultAppRegistrar();
  if (Platform.isLinux) return LinuxDefaultAppRegistrar();
  return null;
}

/// macOS: `MainFlutterWindow.swift`의 `DefaultAppBridge`가 확장자마다
/// `NSWorkspace.setDefaultApplication`을 부르고 실패한 확장자를 돌려준다.
class MacDefaultAppRegistrar implements DefaultAppRegistrar {
  MacDefaultAppRegistrar({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('dove_zip/default_app');

  final MethodChannel _channel;

  @override
  bool get opensSystemSettings => false;

  @override
  Future<void> makeDefault() async {
    final failed = (await _channel.invokeListMethod<String>('setAsDefault', associatedExtensions)) ?? const [];
    if (failed.isNotEmpty) {
      throw DefaultAppFailedException(failed.map((e) => '.$e').join(', '));
    }
  }
}

/// Windows: 앱이 기본 앱을 바꾸는 것을 OS가 막는다(UserChoice 해시). 설치
/// 프로그램(`installer/windows/app.iss`)이 `RegisteredApplications`에 올려 둔
/// "Dove Zip" 페이지를 설정 앱에서 열고, 사용자가 "기본값 설정"을 누른다.
/// 설치 프로그램은 관리자 설치면 HKLM, 아니면 HKCU에 쓴다 — 쓴 쪽에 맞는
/// 링크 인자를 고른다.
class WindowsDefaultAppRegistrar implements DefaultAppRegistrar {
  WindowsDefaultAppRegistrar({ProcessRunner? run, Future<void> Function(String url)? openUrl})
    : _run = run ?? Process.run,
      _openUrl = openUrl ?? const OpenUrl().call;

  final ProcessRunner _run;
  final Future<void> Function(String url) _openUrl;

  @override
  bool get opensSystemSettings => true;

  @override
  Future<void> makeDefault() async {
    const name = AppIdentity.displayName;
    for (final (root, parameter) in const [('HKLM', 'registeredAppMachine'), ('HKCU', 'registeredAppUser')]) {
      final result = await _run('reg', ['query', '$root\\Software\\RegisteredApplications', '/v', name]);
      if (result.exitCode == 0) {
        await _openUrl('ms-settings:defaultapps?$parameter=${Uri.encodeComponent(name)}');
        return;
      }
    }
    throw const WindowsAppNotRegisteredException();
  }
}

/// Linux: `xdg-mime default`로 `~/.config/mimeapps.list`에 이 앱을 적는다.
/// `install.sh`가 설치한 `.desktop` 파일(이름 = linux/CMakeLists.txt의
/// APPLICATION_ID)이 있어야 데스크톱이 앱을 찾는다.
class LinuxDefaultAppRegistrar implements DefaultAppRegistrar {
  LinuxDefaultAppRegistrar({
    ProcessRunner? run,
    Map<String, String>? environment,
    bool Function(String path)? fileExists,
  }) : _run = run ?? Process.run,
       _environment = environment ?? Platform.environment,
       _fileExists = fileExists ?? ((path) => File(path).existsSync());

  static const desktopId = 'com.ptype.dove_zip.desktop';

  final ProcessRunner _run;
  final Map<String, String> _environment;
  final bool Function(String path) _fileExists;

  @override
  bool get opensSystemSettings => false;

  @override
  Future<void> makeDefault() async {
    if (!_desktopEntryInstalled()) throw const DesktopEntryMissingException(desktopId);
    final ProcessResult result;
    try {
      result = await _run('xdg-mime', ['default', desktopId, ...linuxMimeTypes]);
    } on ProcessException {
      throw const DefaultAppToolMissingException('xdg-mime');
    }
    if (result.exitCode != 0) {
      final stderr = '${result.stderr}'.trim();
      throw DefaultAppFailedException(stderr.isEmpty ? 'xdg-mime exited with ${result.exitCode}' : stderr);
    }
  }

  bool _desktopEntryInstalled() {
    final home = _environment['HOME'] ?? '';
    final dataHome = _environment['XDG_DATA_HOME'] ?? p.posix.join(home, '.local', 'share');
    final dataDirs = (_environment['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share').split(':');
    return [
      dataHome,
      ...dataDirs,
    ].where((dir) => dir.isNotEmpty).any((dir) => _fileExists(p.posix.join(dir, 'applications', desktopId)));
  }
}
