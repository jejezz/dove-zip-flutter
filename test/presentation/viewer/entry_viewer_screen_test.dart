import 'dart:io';

import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/viewer/entry_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_entry_viewer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  testWidgets('지원하는 확장자는 해당 뷰어로 연결된다', (tester) async {
    final file = File('${tempDir.path}/note.txt')..writeAsStringSync('hello');

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EntryViewerScreen(tempFilePath: file.path, name: 'note.txt'),
      ));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    });

    expect(find.text('note.txt'), findsOneWidget); // AppBar 제목
    expect(find.text('hello'), findsOneWidget); // TextFileViewer가 내용을 보여줌
  });

  testWidgets('지원하지 않는 확장자는 OS 기본 앱으로 열기 폴백을 보여준다', (tester) async {
    final file = File('${tempDir.path}/app.exe')..writeAsBytesSync([0, 1, 2]);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EntryViewerScreen(tempFilePath: file.path, name: 'app.exe'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('이 형식은 아직 미리보기를 지원하지 않습니다'), findsOneWidget);
    expect(find.text('OS 기본 앱으로 열기'), findsOneWidget);
  });
}
