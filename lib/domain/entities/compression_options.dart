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
    this.excludedExtensions = const {},
    this.followSymlinks = false,
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

  /// 폴더를 압축할 때 이 확장자(점 없이, 소문자, 예: `{"tmp", "log"}`)를
  /// 가진 파일은 건너뛴다 — 대소문자와 앞의 점 유무는 비교 시점에
  /// 정규화하므로 호출자가 어떤 형태로 넘겨도 된다(PLAN.md 1.3 "압축 시
  /// 파일 필터"). 폴더 자체나 확장자가 없는 파일에는 적용되지 않는다.
  /// 소스로 직접 고른 파일 하나짜리 압축(gzip/bzip2/xz)에는 적용하지
  /// 않는다 — 사용자가 명시적으로 고른 파일 하나를 필터로 걸러 아무것도
  /// 안 만드는 혼란스러운 상황을 피하기 위해서다.
  final Set<String> excludedExtensions;

  /// true면 심볼릭 링크를 따라가 그 대상의 실제 내용을 담는다. false(기본값)면
  /// 심볼릭 링크를 완전히 건너뛴다 — 순환 링크로 인한 무한 루프나 예상 밖의
  /// 거대한 대상을 조용히 압축에 끌어들이는 것을 막는 보수적인 기본값이다.
  final bool followSymlinks;
}
