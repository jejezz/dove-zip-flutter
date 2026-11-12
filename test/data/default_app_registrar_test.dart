import 'dart:io';

import 'package:dove_zip/data/system_default_app_registrar.dart';
import 'package:dove_zip/domain/repositories/default_app_registrar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ProcessResult _result(int exitCode, {String stderr = ''}) => ProcessResult(0, exitCode, '', stderr);

/// 기본 앱 등록 — 플랫폼별 구현과, 확장자·MIME 목록이 패키징 파일과 같은지.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('확장자·MIME 목록이 패키징 파일과 같다', () {
    test('macOS Info.plist의 CFBundleTypeExtensions', () {
      final plist = File('macos/Runner/Info.plist').readAsStringSync();
      final array = RegExp(
        r'<key>CFBundleTypeExtensions</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)!.group(1)!;
      final extensions = RegExp(r'<string>([^<]+)</string>').allMatches(array).map((m) => m.group(1)).toList();
      expect(extensions, associatedExtensions);
    });

    test('Windows 설치 프로그램의 OpenWithProgids·FileAssociations', () {
      final iss = File('installer/windows/app.iss').readAsStringSync();
      final openWith = RegExp(r'Software\\Classes\\\.([^\\"]+)\\OpenWithProgids')
          .allMatches(iss)
          .map((m) => m.group(1))
          .toList();
      final capabilities = RegExp(r'Capabilities\\FileAssociations"; ValueType: string; ValueName: "\.([^"]+)"')
          .allMatches(iss)
          .map((m) => m.group(1))
          .toList();
      expect(openWith, associatedExtensions);
      expect(capabilities, associatedExtensions);
    });

    test('릴리스 워크플로가 만드는 .desktop의 MimeType', () {
      final workflow = File('.github/workflows/release.yml').readAsStringSync();
      final line = RegExp(r'^\s*MimeType=(.*)$', multiLine: true).firstMatch(workflow)!.group(1)!;
      expect(line, '${linuxMimeTypes.join(';')};');
    });
  });

  group('Windows', () {
    test('HKLM에 등록돼 있으면 registeredAppMachine 링크를 연다', () async {
      final opened = <String>[];
      final registrar = WindowsDefaultAppRegistrar(
        run: (exe, args) async => _result(args[1].startsWith('HKLM') ? 0 : 1),
        openUrl: (url) async => opened.add(url),
      );
      await registrar.makeDefault();
      expect(opened, ['ms-settings:defaultapps?registeredAppMachine=Dove%20Zip']);
      expect(registrar.opensSystemSettings, isTrue);
    });

    test('HKCU에만 있으면 registeredAppUser 링크를 연다', () async {
      final opened = <String>[];
      await WindowsDefaultAppRegistrar(
        run: (exe, args) async => _result(args[1].startsWith('HKCU') ? 0 : 1),
        openUrl: (url) async => opened.add(url),
      ).makeDefault();
      expect(opened, ['ms-settings:defaultapps?registeredAppUser=Dove%20Zip']);
    });

    test('설치 프로그램으로 설치하지 않았으면 전용 예외', () async {
      final registrar = WindowsDefaultAppRegistrar(run: (exe, args) async => _result(1), openUrl: (_) async {});
      await expectLater(registrar.makeDefault(), throwsA(isA<WindowsAppNotRegisteredException>()));
    });
  });

  group('Linux', () {
    const env = {'HOME': '/home/u'};
    const installed = '/home/u/.local/share/applications/com.ptype.dove_zip.desktop';

    test('xdg-mime default로 모든 MIME 형식을 이 앱에 정한다', () async {
      final calls = <List<String>>[];
      await LinuxDefaultAppRegistrar(
        run: (exe, args) async {
          calls.add([exe, ...args]);
          return _result(0);
        },
        environment: env,
        fileExists: (path) => path == installed,
      ).makeDefault();
      expect(calls, [
        ['xdg-mime', 'default', 'com.ptype.dove_zip.desktop', ...linuxMimeTypes],
      ]);
    });

    test('XDG_DATA_DIRS의 시스템 위치에 설치돼 있어도 된다', () async {
      await LinuxDefaultAppRegistrar(
        run: (exe, args) async => _result(0),
        environment: const {'HOME': '/home/u', 'XDG_DATA_DIRS': '/opt/share:/usr/share'},
        fileExists: (path) => path == '/opt/share/applications/com.ptype.dove_zip.desktop',
      ).makeDefault();
    });

    test('.desktop 파일이 없으면(install.sh 안 돌림) 전용 예외', () async {
      final registrar = LinuxDefaultAppRegistrar(
        run: (exe, args) async => _result(0),
        environment: env,
        fileExists: (_) => false,
      );
      await expectLater(registrar.makeDefault(), throwsA(isA<DesktopEntryMissingException>()));
    });

    test('xdg-mime이 없으면 전용 예외', () async {
      final registrar = LinuxDefaultAppRegistrar(
        run: (exe, args) async => throw const ProcessException('xdg-mime', []),
        environment: env,
        fileExists: (path) => path == installed,
      );
      await expectLater(
        registrar.makeDefault(),
        throwsA(isA<DefaultAppToolMissingException>().having((e) => e.tool, 'tool', 'xdg-mime')),
      );
    });

    test('xdg-mime이 실패하면 오류 출력을 담는다', () async {
      final registrar = LinuxDefaultAppRegistrar(
        run: (exe, args) async => _result(4, stderr: 'no write access\n'),
        environment: env,
        fileExists: (path) => path == installed,
      );
      await expectLater(
        registrar.makeDefault(),
        throwsA(isA<DefaultAppFailedException>().having((e) => e.detail, 'detail', 'no write access')),
      );
    });
  });

  group('macOS', () {
    const channel = MethodChannel('test/default_app');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('확장자 목록을 넘기고, 전부 되면 그대로 끝난다', () async {
      Object? sent;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'setAsDefault');
        sent = call.arguments;
        return <String>[];
      });
      await MacDefaultAppRegistrar(channel: channel).makeDefault();
      expect(sent, associatedExtensions);
    });

    test('실패한 확장자가 있으면 전용 예외에 담는다', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => <String>['7z', 'rar']);
      await expectLater(
        MacDefaultAppRegistrar(channel: channel).makeDefault(),
        throwsA(isA<DefaultAppFailedException>().having((e) => e.detail, 'detail', '.7z, .rar')),
      );
    });
  });
}
