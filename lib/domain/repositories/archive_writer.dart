import '../../core/cancel_token.dart';
import '../entities/archive_entry.dart';
import '../entities/compress_progress.dart';
import '../entities/compression_options.dart';

typedef CompressProgressCallback = void Function(CompressProgress progress);

/// 파일/폴더 목록을 압축파일로 만드는 백엔드의 공통 인터페이스
/// (ARCHITECTURE.md 4장) — [ArchiveReader]의 쓰기 쪽 대응.
///
/// `domain`은 이 인터페이스만 알고, 실제 구현(`DartArchiveWriter`, 이후
/// `RustArchiveWriter`)은 `data`/`native` 레이어에 있다.
abstract class ArchiveWriter {
  /// 이 라이터가 [format]으로 압축파일을 만들 수 있는지. `FormatRegistry.canWrite`
  /// (포맷 자체의 이론적 지원 여부)와는 별개로 "지금 이 구현체가 실제로
  /// 만들 수 있는지"를 뜻한다 — 스캐폴딩 단계의 `DartArchiveWriter`는
  /// zip만 true를 반환한다.
  bool supports(ArchiveFormat format);

  /// [sources](파일 또는 폴더 경로)를 [destination]에 압축파일로 만든다.
  /// 폴더는 재귀적으로 전부 포함하고, 폴더 자신의 이름이 압축파일 안의
  /// 최상위 폴더 이름이 된다(Finder/탐색기에서 폴더를 압축할 때와 동일한
  /// 관례).
  Future<void> compress({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  });
}
