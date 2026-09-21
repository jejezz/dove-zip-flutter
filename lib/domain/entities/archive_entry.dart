import 'package:path/path.dart' as p;

/// 이 앱이 다루는 압축 포맷. 생성(쓰기) 가능 여부는 포맷마다 다르다 —
/// PLAN.md 3장 매트릭스 참고. RAR/ISO9660/CAB 등은 항상 해제 전용이며,
/// 이 enum 자체는 그 구분을 담지 않는다(구분은 이후 FormatRegistry가 맡음).
enum ArchiveFormat {
  zip,
  tar,
  tarGz,
  tarBz2,
  tarXz,
  tarZst,
  gzip,
  bzip2,
  xz,
  zstd,
  sevenZip,
  lz4,
  brotli,
  rar,
  iso9660,
  cab,
  arj,
  lha,
  cpio,
  ar,
  xar,
  warc,
}

/// 압축파일 **내부**의 항목 하나 (ARCHITECTURE.md 3장).
///
/// daylight-commander-flutter의 `FileEntry`와 달리 실제 파일시스템 [Uri]를
/// 갖지 않는다 — `ArchiveHandle.location` + [pathInArchive] 조합으로만
/// 식별된다.
class ArchiveEntry {
  const ArchiveEntry({
    required this.pathInArchive,
    required this.isDirectory,
    this.uncompressedSize,
    this.compressedSize,
    this.modifiedAt,
    this.isEncrypted = false,
  });

  /// posix 스타일 경로, 예: `"dir/sub/file.txt"`. 디렉터리 엔트리는 관례상
  /// 끝에 `/`가 붙기도 하지만(포맷마다 다름), [name]은 양쪽 경우 모두
  /// 올바르게 마지막 세그먼트만 뽑아낸다.
  final String pathInArchive;
  final bool isDirectory;
  final int? uncompressedSize;
  final int? compressedSize;
  final DateTime? modifiedAt;

  /// 항목 단위 암호화 표시(zip은 항목별, 7z는 전체 헤더 암호화라 모든
  /// 항목이 동일하게 true일 수 있음).
  final bool isEncrypted;

  /// [pathInArchive]의 마지막 세그먼트. 디렉터리 엔트리에 끝에 `/`가
  /// 붙어 있어도(`"docs/"`) 정상적으로 `"docs"`를 반환한다.
  String get name {
    final trimmed = pathInArchive.endsWith('/')
        ? pathInArchive.substring(0, pathInArchive.length - 1)
        : pathInArchive;
    return p.posix.basename(trimmed);
  }

  @override
  String toString() =>
      'ArchiveEntry($pathInArchive, isDirectory: $isDirectory)';
}
