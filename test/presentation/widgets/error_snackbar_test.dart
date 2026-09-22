import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/widgets/error_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _message = '문제가 생겼습니다: boom';

Future<void> _pumpTriggerButton(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showErrorSnackBar(context, _message),
          child: const Text('trigger'),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('메시지와 복사 액션이 함께 뜬다', (tester) async {
    await _pumpTriggerButton(tester);

    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text(_message), findsOneWidget);
    expect(find.text('복사'), findsOneWidget);
  });

  testWidgets('복사 버튼을 누르면 메시지가 클립보드에 복사되고 확인 스낵바가 뜬다', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await _pumpTriggerButton(tester);

    await tester.tap(find.text('trigger'));
    // 스낵바 등장 애니메이션이 끝날 때까지 기다린다 — 한 프레임만
    // pump하면 화면 아래에서 올라오는 도중이라 액션 버튼의 실제 위치가
    // 아직 화면 밖이라 탭이 씹힌다.
    await tester.pumpAndSettle();

    await tester.tap(find.text('복사'));
    // Clipboard.setData가 끝나고 확인 스낵바가 등장 애니메이션까지
    // 마칠 시간을 준다.
    await tester.pumpAndSettle();

    expect(copiedText, _message);
    expect(find.text('오류 메시지를 복사했습니다'), findsOneWidget);
  });
}
