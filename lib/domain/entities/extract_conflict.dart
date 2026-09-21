/// 압축 해제 중 대상 위치에 동일 이름 파일이 이미 있을 때 사용자에게 묻는다
/// (PLAN.md 1.2 — daylight-commander-flutter의 `FileConflict`/`ConflictAction`과
/// 동일한 개념).
class ExtractConflict {
  const ExtractConflict({
    required this.entryPath,
    required this.destinationPath,
    this.sourceSizeBytes,
    this.destinationSizeBytes,
    this.destinationModifiedAt,
  });

  /// 압축파일 내부 경로 (posix 스타일).
  final String entryPath;

  /// 실제로 파일이 써질 로컬 파일시스템 경로.
  final String destinationPath;

  final int? sourceSizeBytes;
  final int? destinationSizeBytes;
  final DateTime? destinationModifiedAt;
}

enum ConflictAction { overwrite, overwriteAll, skip, skipAll, rename, cancel }
