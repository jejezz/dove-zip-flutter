import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/extract_progress.dart';
import '../../l10n/app_localizations.dart';

/// 압축 해제 진행 중 띄우는 모달 (UI_UX.md 6장 `OperationBanner` 개념을
/// 이 화면에서는 다이얼로그로 구현). 취소(X) 버튼은 [onCancel]로 넘겨받은
/// `CancelToken.cancel`을 그대로 호출한다.
class ExtractProgressDialog extends StatelessWidget {
  const ExtractProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  final ValueListenable<ExtractProgress?> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.extractingTitle),
        content: SizedBox(
          width: 320,
          child: ValueListenableBuilder<ExtractProgress?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final done = value?.done ?? 0;
              final total = value?.total ?? 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: total > 0 ? done / total : null),
                  const SizedBox(height: 12),
                  Text(
                    value?.currentName ?? l10n.preparing,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.progressCount(done, total), style: Theme.of(context).textTheme.bodyMedium),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
        ],
      ),
    );
  }
}
