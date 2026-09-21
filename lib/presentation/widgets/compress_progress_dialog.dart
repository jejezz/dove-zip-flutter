import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/compress_progress.dart';
import '../../l10n/app_localizations.dart';

/// 압축 생성 중 띄우는 모달 — [ExtractProgressDialog]의 압축 생성 버전
/// (구조가 거의 같지만 진행 대상 타입이 달라 그대로 재사용하기보다
/// 나란히 둔다).
class CompressProgressDialog extends StatelessWidget {
  const CompressProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  final ValueListenable<CompressProgress?> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.compressingTitle),
        content: SizedBox(
          width: 320,
          child: ValueListenableBuilder<CompressProgress?>(
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
