import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 이름 하나를 묻는 작은 창 — 탐색기 메뉴의 "압축 파일 이름을 정해 압축하기"와
/// "폴더 이름을 정해 풀기"가 쓴다. 취소하면 null, 확인하면 앞뒤 공백을 뺀 이름.
///
/// [validate]가 문구를 돌려주면 입력 칸 아래에 오류로 보이고 확인을 누를 수
/// 없다. [suffix]는 입력 칸 뒤에 붙여 보이는 고정 문구(확장자 `.zip` 등).
Future<String?> showNamePromptDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialName,
  required String? Function(String name) validate,
  String? suffix,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NamePromptDialog(
      title: title,
      label: label,
      initialName: initialName,
      validate: validate,
      suffix: suffix,
    ),
  );
}

class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.label,
    required this.initialName,
    required this.validate,
    this.suffix,
  });

  final String title;
  final String label;
  final String initialName;
  final String? Function(String name) validate;
  final String? suffix;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String? error) {
    if (error != null) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = widget.validate(_controller.text);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixText: widget.suffix,
            // 처음 열었을 때는 기본 이름이라 오류가 있어도(이미 있는 이름 등) 바로 보인다.
            errorText: error,
          ),
          onSubmitted: (_) => _submit(error),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: error == null ? () => _submit(error) : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
