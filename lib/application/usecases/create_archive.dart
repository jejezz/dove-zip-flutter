import 'package:path/path.dart' as p;

import '../../core/cancel_token.dart';
import '../../data/dart_archive_writer.dart';
import '../../data/format_registry.dart';
import '../../domain/entities/compression_options.dart';
import '../../domain/repositories/archive_writer.dart';
import 'open_archive.dart' show UnsupportedArchiveFormatException;

/// [sources]를 새 압축파일로 만든다 (ARCHITECTURE.md 1장 유스케이스 목록의
/// `CreateArchive` — UI_UX.md 6.3 `CompressDialog`가 이 유스케이스를 호출).
///
/// 포맷이 애초에 생성 불가능한 것(RAR 등)이면 리더를 부르기 전에
/// `FormatRegistry.canWrite`로 먼저 막는다 — UI가 포맷 드롭다운을
/// `writableFormats`로만 채우면 정상적으로는 여기 걸릴 일이 없지만, 방어적으로
/// 한 번 더 확인한다.
class CreateArchive {
  const CreateArchive([this._writer = const DartArchiveWriter()]);

  final ArchiveWriter _writer;

  Future<void> call({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!FormatRegistry.canWrite(options.format) || !_writer.supports(options.format)) {
      throw UnsupportedArchiveFormatException(p.basename(destination.toFilePath()));
    }

    await _writer.compress(
      sources: sources,
      destination: destination,
      options: options,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}
