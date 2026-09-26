import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/main.dart';
import 'package:dove_zip/presentation/archive_browser/archive_browser_screen.dart';
import 'package:dove_zip/presentation/compress/compress_dialog.dart';
import 'package:dove_zip/presentation/window/dock_window.dart';
import 'package:dove_zip/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 세로 창(UI_UX.md 9장): 최소 크기 380×560과 기본 폭 440에서 화면이 넘치지
/// 않고, 폭에 따라 열과 해제 버튼 배치가 바뀐다. 넘치면 flutter test가
/// RenderFlex overflow 예외로 실패한다.
void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/a-rather-long-archive-name-for-a-narrow-window.tar.gz'),
    format: ArchiveFormat.tarGz,
    entries: [
      const ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
      ArchiveEntry(
        pathInArchive: 'quarterly-report-final-version-2.pdf',
        isDirectory: false,
        uncompressedSize: 2100000,
        compressedSize: 1900000,
        modifiedAt: DateTime(2026, 1, 3),
      ),
    ],
  );

  Future<void> setWindow(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpBrowser(WidgetTester tester, String locale) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchiveBrowserScreen(handle: handle),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in ['ko', 'en']) {
    testWidgets('[$locale] 최소 크기에서 빈 상태 화면이 넘치지 않는다', (tester) async {
      await setWindow(tester, dockMinimumSize);
      SharedPreferences.setMockInitialValues({
        AppSettings.localeKey: locale,
        'recent_archives': ['/tmp/some-archive-with-a-long-name.zip'],
      });
      final settings = await AppSettings.load();

      await tester.pumpWidget(ProviderScope(child: DoveZipApp(settings: settings)));
      await tester.pumpAndSettle();

      expect(find.byType(DockMenuButton), findsOneWidget);
      expect(find.byType(AlwaysOnTopButton), findsOneWidget);
    });

    testWidgets('[$locale] 최소 크기에서 압축 목록이 넘치지 않고 해제 버튼을 쌓는다', (tester) async {
      await setWindow(tester, dockMinimumSize);
      await pumpBrowser(tester, locale);

      final buttons = [
        ...tester.widgetList(find.byType(OutlinedButton)),
        ...tester.widgetList(find.byType(FilledButton)),
      ];
      expect(buttons, hasLength(3));
      final xs = {
        for (final b in buttons) tester.getTopLeft(find.byWidget(b)).dx,
      };
      expect(xs, hasLength(1), reason: '세 버튼이 한 줄에 하나씩');
    });

    testWidgets('[$locale] 최소 크기에서 새 압축 다이얼로그가 넘치지 않는다', (tester) async {
      await setWindow(tester, dockMinimumSize);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CompressDialog(sources: [Uri.file('/tmp/photo.jpg')]),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 비밀번호·분할 입력까지 펼친다.
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('기본 폭 440에서는 이름·크기 열만 보인다', (tester) async {
    await setWindow(tester, dockDefaultSize);
    await pumpBrowser(tester, 'ko');

    expect(find.text('크기'), findsOneWidget);
    expect(find.text('수정일'), findsNothing);
    expect(find.text('압축크기'), findsNothing);
  });

  testWidgets('창을 넓히면 수정일, 더 넓히면 압축 크기와 가로 해제 버튼이 보인다', (tester) async {
    await setWindow(tester, const Size(560, 800));
    await pumpBrowser(tester, 'ko');
    expect(find.text('수정일'), findsOneWidget);
    expect(find.text('압축크기'), findsNothing);

    await setWindow(tester, const Size(800, 800));
    await pumpBrowser(tester, 'ko');
    expect(find.text('압축크기'), findsOneWidget);
    final ys = {
      for (final b in [
        ...tester.widgetList(find.byType(OutlinedButton)),
        ...tester.widgetList(find.byType(FilledButton)),
      ])
        tester.getTopLeft(find.byWidget(b)).dy,
    };
    expect(ys, hasLength(1), reason: '세 버튼이 한 줄에');
  });

  testWidgets('핀 버튼을 누르면 창을 항상 위에 두고, 다시 누르면 끈다', (tester) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        if (call.method == 'setAlwaysOnTop') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null));

    await setWindow(tester, dockDefaultSize);
    await pumpBrowser(tester, 'ko');

    await tester.tap(find.byTooltip('항상 위에 표시'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.byTooltip('항상 위에 표시 끄기'), findsOneWidget);

    await tester.tap(find.byTooltip('항상 위에 표시 끄기'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(calls, [
      {'isAlwaysOnTop': true},
      {'isAlwaysOnTop': false},
    ]);
  });
}
