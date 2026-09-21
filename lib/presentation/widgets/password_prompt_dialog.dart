import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 비밀번호로 보호된 압축파일을 열거나 풀 때 띄운다 (PLAN.md 1.2 P1).
/// 취소하면 null을 반환한다.
Future<String?> showPasswordPromptDialog(
  BuildContext context, {
  bool wrongPasswordHint = false,
}) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.passwordRequiredTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wrongPasswordHint)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.passwordWrongHint,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(hintText: l10n.passwordHint),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
}
