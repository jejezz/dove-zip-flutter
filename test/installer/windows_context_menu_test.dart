import 'dart:io';

import 'package:dove_zip/application/launch_request.dart';
import 'package:dove_zip/domain/repositories/default_app_registrar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Windows 탐색기 우클릭 메뉴 — 설치 프로그램의 등록이 앱 코드·리소스와 맞는지.
void main() {
  final iss = File('installer/windows/app.iss').readAsStringSync();
  final resourceH = File('windows/runner/resource.h').readAsStringSync();
  final rc = File('windows/runner/Runner.rc').readAsStringSync();

  int resourceId(String name) =>
      int.parse(RegExp('#define $name\\s+(\\d+)').firstMatch(resourceH)!.group(1)!);

  test('"여기에 풀기"는 기본 앱 목록과 같은 압축 형식에 붙는다', () {
    final extensions = RegExp(r'SystemFileAssociations\\\.([^\\"]+)\\shell\\DoveZip\.Extract"; ValueType: string; ValueName: "MUIVerb"')
        .allMatches(iss)
        .map((m) => m.group(1))
        .toList();
    expect(extensions, associatedExtensions);
  });

  test('"압축하기"는 그 압축 형식에서는 보이지 않는다', () {
    final appliesTo = RegExp(r'DoveZip\.Compress"; ValueType: string; ValueName: "AppliesTo"; ValueData: "([^"]+)"')
        .firstMatch(iss)!
        .group(1)!;
    final excluded = RegExp(r'NOT System\.FileExtension:=\.(\w+)').allMatches(appliesTo).map((m) => m.group(1)).toList();
    expect(excluded, associatedExtensions);
  });

  test('명령의 플래그는 LaunchRequest가 읽는 것과 같다', () {
    final commands = RegExp(r'\\(DoveZip\.\w+)\\command"; ValueType: string; ValueData: "([^\n]+)"$', multiLine: true)
        .allMatches(iss)
        .map((m) => (m.group(1)!, m.group(2)!))
        .toList();
    expect(commands, isNotEmpty);
    for (final (verb, command) in commands) {
      final flag = verb == 'DoveZip.Compress' ? LaunchRequest.compressHereFlag : LaunchRequest.extractHereFlag;
      expect(command, contains(' $flag ""%1""'), reason: verb);
    }
  });

  test('메뉴 이름 id는 Runner.rc의 영어·한국어 문자열 표에 있다', () {
    final compress = resourceId('IDS_VERB_COMPRESS');
    final extract = resourceId('IDS_VERB_EXTRACT_HERE');
    final ids = RegExp(r'MUIVerb"; ValueData: "@\{app\}\\\{#MyAppExeName\},-(\d+)"')
        .allMatches(iss)
        .map((m) => int.parse(m.group(1)!))
        .toSet();
    expect(ids, {compress, extract});
    expect(RegExp(r'^STRINGTABLE', multiLine: true).allMatches(rc).length, 2);
    expect(RegExp(r'IDS_VERB_COMPRESS\s+"').allMatches(rc).length, 2);
    expect(RegExp(r'IDS_VERB_EXTRACT_HERE\s+"').allMatches(rc).length, 2);
    expect(rc, contains('LANGUAGE LANG_KOREAN, SUBLANG_KOREAN'));
  });

  test('resource.h는 ASCII만 쓴다 (MSVC가 949 코드 페이지에서 경고를 오류로 본다)', () {
    expect(resourceH.codeUnits.every((c) => c < 128), isTrue);
  });
}
