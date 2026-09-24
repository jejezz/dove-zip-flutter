import 'package:path/path.dart' as p;

import '../../application/drag_out_staging.dart';
import '../../application/usecases/open_archive.dart';
import '../../core/bytes_format.dart';
import '../../core/cancel_token.dart';
import '../../domain/entities/extract_failure.dart';
import '../../domain/repositories/archive_reader.dart';
import '../../domain/repositories/archive_writer.dart';
import '../../l10n/app_localizations.dart';

/// 예외를 사용자에게 보여 줄 문구로 바꾼다.
///
/// 사용자가 만날 수 있는 상황은 데이터를 담은 전용 예외로 던지고(파일 이름,
/// 조각 번호 등), 문구는 여기서 현재 언어로 고른다 — data/domain 레이어는
/// BuildContext도 언어도 모른다 (conventions-v1 localization.md). 전용
/// 예외가 아니면(외부 라이브러리 오류, 내부 버그) 예외 텍스트를 그대로 쓴다.
String describeError(AppLocalizations l10n, Object error) => switch (error) {
      OperationCancelledException() => l10n.errorCancelled,
      UnsupportedArchiveFormatException(:final fileName) => l10n.errorUnsupportedFormat(fileName),
      ArchivePasswordRequiredException(:final entryPath) => l10n.errorPasswordRequired(entryPath),
      MissingSplitVolumeException(:final fileName, missingIndex: final index?) =>
        l10n.errorSplitVolumeMissing(index, fileName),
      MissingSplitVolumeException(:final fileName) => l10n.errorSplitVolumesNotFound(fileName),
      SingleFileFormatException(:final formatName, isDirectory: true) =>
        l10n.errorSingleFileFormatFolder(formatName),
      SingleFileFormatException(:final formatName) => l10n.errorSingleFileFormatMultiple(formatName),
      DragOutTargetExistsException(:final path?) => l10n.errorTargetExists(p.basename(path)),
      DragOutTooLargeException() => l10n.dragOutTooLarge(formatBytes(DragOutStaging.maxBytes)),
      DragOutExtractFailedException(:final failures) =>
        failures.map((f) => describeFailure(l10n, f)).join('\n'),
      _ => '$error',
    };

/// 손상 항목 목록의 한 줄 — `경로: 이유`.
String describeFailure(AppLocalizations l10n, ExtractFailure failure) =>
    '${failure.entryPath}: ${failure.error == null ? failure.message : describeError(l10n, failure.error!)}';
