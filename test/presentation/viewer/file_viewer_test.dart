import 'dart:convert';
import 'dart:io';

import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/viewer/file_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1x1 투명 PNG (base64) — 이미지 뷰어가 실제로 디코딩할 수 있는 최소
/// 유효 이미지가 필요해서 사용한다.
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  group('ViewerRegistry.forFile', () {
    test('텍스트 확장자는 TextFileViewer를 고른다', () {
      expect(ViewerRegistry.forFile('readme.txt'), isA<TextFileViewer>());
      expect(ViewerRegistry.forFile('data.JSON'), isA<TextFileViewer>()); // 대소문자 무관
    });

    test('이미지 확장자는 ImageFileViewer를 고른다', () {
      expect(ViewerRegistry.forFile('photo.jpg'), isA<ImageFileViewer>());
      expect(ViewerRegistry.forFile('photo.png'), isA<ImageFileViewer>());
    });

    test('매칭되는 뷰어가 없으면 null이다', () {
      expect(ViewerRegistry.forFile('app.exe'), isNull);
      expect(ViewerRegistry.forFile('노확장자'), isNull);
    });
  });

  group('TextFileViewer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dove_zip_text_viewer_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<void> pumpTextViewer(WidgetTester tester, File file) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (context) => const TextFileViewer().build(context, file)),
        ),
      ));
    }

    testWidgets('UTF-8 텍스트를 그대로 보여준다', (tester) async {
      final file = File('${tempDir.path}/a.txt')..writeAsStringSync('안녕하세요');

      await tester.runAsync(() async {
        await pumpTextViewer(tester, file);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      });

      expect(find.text('안녕하세요'), findsOneWidget);
    });

    testWidgets('UTF-8로 디코딩 안 되면 Latin-1로 폴백해서 깨지지 않는다', (tester) async {
      // 0xFF 0xFE는 유효한 UTF-8 시퀀스가 아니다.
      final file = File('${tempDir.path}/b.txt')
        ..writeAsBytesSync([0xFF, 0xFE, 0x41, 0x42]);

      await tester.runAsync(() async {
        await pumpTextViewer(tester, file);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      });

      // 에러 화면이 아니라 정상적으로 SelectableText가 떴는지만 확인한다
      // (Latin-1 결과 자체의 정확한 글자 비교는 의미가 적다).
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  group('ImageFileViewer', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dove_zip_image_viewer_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets('유효한 이미지 파일을 Image 위젯으로 렌더링한다', (tester) async {
      final file = File('${tempDir.path}/a.png')
        ..writeAsBytesSync(base64Decode(_tinyPngBase64));

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (context) => const ImageFileViewer().build(context, file)),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });
  });
}
