import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// 예외 메시지를 담은 스낵바를 "복사" 액션과 함께 보여준다 — 원인이 되는
/// 예외 텍스트(`$e`)를 그대로 클립보드에 복사해 리포트하거나 검색해볼 수
/// 있게 한다. `openArchiveFailed`/`previewFailed`/`extractFailed`/
/// `compressFailed`처럼 예외를 그대로 문자열에 담는 실패 메시지 전용이고,
/// 완료/취소처럼 복사할 예외 정보가 없는 메시지에는 쓰지 않는다.
void showErrorSnackBar(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: l10n.copyButton,
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: message));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorMessageCopied)),
          );
        },
      ),
    ),
  );
}
