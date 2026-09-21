import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/photos.zip'),
    format: ArchiveFormat.zip,
    entries: const [
      ArchiveEntry(pathInArchive: 'report.pdf', isDirectory: false),
      ArchiveEntry(pathInArchive: 'photo.jpg', isDirectory: false),
      ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
    ],
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchiveBrowserScreen(handle: handle),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('검색 버튼을 누르면 입력창이 뜨고 이름으로 필터링된다', (tester) async {
    await pumpScreen(tester);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'photo');
    await tester.pumpAndSettle();

    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('report.pdf'), findsNothing);
    expect(find.text('docs'), findsNothing);
  });

  testWidgets('검색을 닫으면 전체 목록으로 돌아간다', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'photo');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('docs'), findsOneWidget);
  });
}
