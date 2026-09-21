import 'archive_entry.dart';

/// 압축 레벨 (PLAN.md 1.3 — 저장/빠름/보통/최대). 사람이 읽는 이름은
/// 다국어(PLAN.md 1.4 P1) 대상이라 여기 두지 않고, 화면 쪽에서
/// `AppLocalizations`로 직접 번역한다(`compress_dialog.dart`).
enum CompressionLevel { store, fast, normal, max }

/// 압축 생성 옵션 (ARCHITECTURE.md 3장).
class CompressionOptions {
  const CompressionOptions({
    required this.format,
    this.level = CompressionLevel.normal,
    this.password,
    this.splitVolumeBytes,
  });

  /// `FormatRegistry.canWrite(format) == true`인 것만 유효하다.
  final ArchiveFormat format;

  final CompressionLevel level;

  /// zip(AES-256)/7z(AES-256)만 유효 — PLAN.md상 P1, 아직 어떤 백엔드도
  /// 지원하지 않아 값이 있으면 항상 실패한다(현재 UI도 노출하지 않음).
  final String? password;

  /// null이면 분할 압축 안 함. 값이 있으면 완성된 압축파일을 이 크기(바이트)
  /// 단위로 잘라 `이름.001`, `이름.002`, ... 로 나눠 쓴다 — DoveZip 자체
  /// 스킴이라 DoveZip 스스로만 다시 이어붙일 수 있다(PLAN.md 1.3,
  /// `FormatRegistry.isSplitVolumePart` 문서 참고).
  final int? splitVolumeBytes;
}
