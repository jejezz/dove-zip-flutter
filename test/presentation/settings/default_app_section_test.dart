import 'package:dove_zip/domain/repositories/default_app_registrar.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/settings/default_app_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRegistrar implements DefaultAppRegistrar {
  _FakeRegistrar({this.opensSystemSettings = false, this.error});

  @override
  final bool opensSystemSettings;

  final Object? error;
  int calls = 0;

  @override
  Future<void> makeDefault() async {
    calls++;
    if (error != null) throw error!;
  }
}

Widget _app(DefaultAppRegistrar? registrar) => ProviderScope(
  overrides: [defaultAppRegistrarProvider.overrideWithValue(registrar)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: DefaultAppSection()),
  ),
);

/// 설정의 "기본 앱" 구역 — 단추 하나로 바꾸고, 결과를 단추 아래에 알린다.
void main() {
  testWidgets('macOS·Linux: 바꾸고 나면 완료 문구를 보인다', (tester) async {
    final registrar = _FakeRegistrar();
    await tester.pumpWidget(_app(registrar));

    expect(find.text('Default app'), findsOneWidget);
    await tester.tap(find.text('Set as default app'));
    await tester.pumpAndSettle();

    expect(registrar.calls, 1);
    expect(find.text('Archives now open in Dove Zip.'), findsOneWidget);
  });

  testWidgets('Windows: 설정 앱을 여는 단추이고, 연 뒤에는 완료라고 하지 않는다', (tester) async {
    final registrar = _FakeRegistrar(opensSystemSettings: true);
    await tester.pumpWidget(_app(registrar));

    expect(find.textContaining('click "Set default"'), findsOneWidget);
    await tester.tap(find.text('Open Windows Settings'));
    await tester.pumpAndSettle();

    expect(registrar.calls, 1);
    expect(find.text('Archives now open in Dove Zip.'), findsNothing);
  });

  testWidgets('실패하면 전용 예외의 문구를 보인다', (tester) async {
    await tester.pumpWidget(_app(_FakeRegistrar(error: const DesktopEntryMissingException('x.desktop'))));

    await tester.tap(find.text('Set as default app'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Run install.sh'), findsOneWidget);
  });

  testWidgets('데스크톱이 아니면(등록기 없음) 구역을 보이지 않는다', (tester) async {
    await tester.pumpWidget(_app(null));
    expect(find.text('Default app'), findsNothing);
  });
}
