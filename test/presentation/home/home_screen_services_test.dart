import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// macOS Finder의 "서비스" 메뉴(NSServices, `macos/Runner/Info.plist` +
/// `ServicesBridge.swift`)가 실제로 앱을 실행/활성화하는 부분은 이
/// 테스트로 검증할 수 없다(네이티브 Finder 통합) — 여기서는 그 네이티브
/// 쪽이 채널로 파일 경로를 전달했다고 가정하고, `HomeScreen`이 그
/// MethodChannel 호출을 받아 앱 내부 버튼과 똑같은 경로로 잘 이어붙이는지만
/// 검증한다(PLAN.md 1.4 "OS 컨텍스트 메뉴").
const _servicesChannel = MethodChannel('dove_zip/services');

/// 채널 호출을 "던지기만" 한다 — `compressHere`/`extractHere` 핸들러는
/// 내부적으로 `showDialog`/`Navigator.push`를 그대로 기다리는데, 그
/// Future는 사용자가 다이얼로그를 닫거나 화면에서 뒤로 가야 끝난다(실제
/// 앱에서는 문제없다 — Swift `ServicesBridge`는 이 완료를 기다리지
/// 않는다). 그래서 이 호출을 `await`하면 테스트가 절대 끝나지 않는 UI를
/// 기다리며 멈춘다 — 대신 메시지만 보내고 그 결과(다이얼로그/화면이 뜨는
/// 것)만 따로 확인한다.
void _sendServiceCall(String method, List<String> paths) {
  final data = _servicesChannel.codec.encodeMethodCall(MethodCall(method, paths));
  unawaited(
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage('dove_zip/services', data, (ByteData? reply) {}),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('dove_zip_services_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('compressHere가 오면 선택된 경로로 압축 다이얼로그가 뜬다', (tester) async {
    final file = File('${tempDir.path}/photo.jpg')..writeAsStringSync('fake image bytes');

    await pumpHome(tester);
    _sendServiceCall('compressHere', [file.path]);
    await tester.pumpAndSettle();

    // "새 압축 만들기"는 홈 화면 버튼 라벨과도 겹쳐, 다이얼로그
    // 안에서만 찾아야 한다.
    expect(find.widgetWithText(AlertDialog, '새 압축 만들기'), findsOneWidget);
    expect(find.textContaining('photo.jpg'), findsOneWidget);
  });

  testWidgets('extractHere가 오면 압축파일을 열고 탐색 화면으로 넘어간다', (tester) async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/sample.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    await pumpHome(tester);

    // `_openArchiveForAutoExtract`의 `Navigator.push`는 이 화면을 나가야
    // 끝나는 Future라(이 테스트는 절대 그렇게 하지 않는다) 그 Future 자체를
    // 기다릴 수 없다 — 실제 파일 읽기(OpenArchive)가 완료되기에 충분한
    // 시간만 runAsync 안에서 흘려보내고, 위젯 트리 반영은 그 바깥에서
    // pump로 확인한다(테스트 프레임워크의 pump 가드와 "영원히 안 끝나는"
    // 플랫폼 채널 호출을 같은 runAsync 안에서 반복 섞으면 멈춘다 — 자동
    // 해제 자체(두 번째 파일 쓰기)는 여기서 검증하지 않고
    // archive_browser_screen_extract_test.dart의 autoExtractMode 테스트가
    // 전담한다).
    await tester.runAsync(() async {
      _sendServiceCall('extractHere', [zipFile.path]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.widgetWithText(AppBar, 'sample.zip'), findsOneWidget);
  });

  testWidgets('extractHere에 압축파일이 아닌 항목이 섞여 있으면 조용히 건너뛴다', (tester) async {
    File('${tempDir.path}/notes.txt').writeAsStringSync('not an archive');

    await pumpHome(tester);
    _sendServiceCall('extractHere', ['${tempDir.path}/notes.txt']);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
