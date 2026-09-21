import 'package:flutter/material.dart';

import '../../core/bytes_format.dart';
import '../../domain/entities/extract_conflict.dart';
import '../../l10n/app_localizations.dart';

/// 압축 해제 대상 위치에 동일 이름 파일이 있을 때 띄운다
/// (daylight-commander-flutter의 `showConflictDialog`와 동일한 6버튼 구성 —
/// 취소/모두건너뛰기/건너뛰기/이름변경/모두덮어쓰기/덮어쓰기).
///
/// 대화상자를 닫아버리는 등 값 없이 pop되면 [ConflictAction.cancel]로
/// 취급한다.
Future<ConflictAction> showConflictDialog(
  BuildContext context,
  ExtractConflict conflict,
) async {
  final l10n = AppLocalizations.of(context);
  final action = await showDialog<ConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l10n.conflictTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(conflict.destinationPath, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Text(l10n.conflictSourceLabel(formatBytes(conflict.sourceSizeBytes))),
          Text(l10n.conflictDestinationLabel(formatBytes(conflict.destinationSizeBytes))),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.cancel),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.skipAll),
          child: Text(l10n.skipAll),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.skip),
          child: Text(l10n.skip),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.rename),
          child: Text(l10n.renameAndExtract),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.overwriteAll),
          child: Text(l10n.overwriteAll),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ConflictAction.overwrite),
          child: Text(l10n.overwrite),
        ),
      ],
    ),
  );
  return action ?? ConflictAction.cancel;
}
