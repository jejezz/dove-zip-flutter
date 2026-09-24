import '../domain/entities/archive_entry.dart';

/// 어느 네이티브 백엔드가 이 포맷을 처리하는지 (ARCHITECTURE.md 6장).
///
/// `domain`은 이 enum을 모른다 — FFI인지 Rust인지는 순수한 구현 세부사항이라
/// `data`/`native` 레이어 안에서만 쓰인다 (ARCHITECTURE.md 1장 의존 방향).
enum BackendKind { libarchive, rustNative }

/// 포맷 하나의 지원 범위. [PLAN.md]의 3장 포맷 매트릭스를 코드로 고정한 것.
class FormatCapability {
  const FormatCapability({
    required this.format,
    required this.displayName,
    required this.canRead,
    required this.canWrite,
    required this.readBackend,
    this.writeBackend,
    required this.extensions,
  }) : assert(
          (canWrite && writeBackend != null) || (!canWrite && writeBackend == null),
          'canWrite and writeBackend must be set together',
        );

  final ArchiveFormat format;

  /// 포맷 선택 드롭다운 등 UI에 표시할 사람이 읽는 이름 (예: "TAR.GZ", "7Z").
  final String displayName;

  final bool canRead;
  final bool canWrite;
  final BackendKind readBackend;

  /// null이면 해제 전용 포맷(RAR 등 — PLAN.md 3장 "RAR 정책" 참고).
  final BackendKind? writeBackend;

  /// 점 없이, 소문자, 파일명 끝에 오는 순서 그대로. 이중 확장자
  /// (`"tar.gz"`)가 있는 포맷은 반드시 이중 확장자 형태를 포함해야
  /// [FormatRegistry.detectFromFileName]이 `photos.tar.gz`를 gzip이 아닌
  /// tarGz로 정확히 판별할 수 있다.
  final List<String> extensions;
}

/// PLAN.md 3장 포맷 매트릭스 + ARCHITECTURE.md 4/6장의 백엔드 라우팅 정책을
/// 코드로 고정한 정적 레지스트리. `application`/`presentation` 양쪽이 이
/// 하나의 소스만 참조한다 (ARCHITECTURE.md 4장).
class FormatRegistry {
  const FormatRegistry._();

  static const Map<ArchiveFormat, FormatCapability> _byFormat = {
    // --- 생성+해제 (libarchive로 읽고, Rust로 쓴다) ---
    ArchiveFormat.zip: FormatCapability(
      format: ArchiveFormat.zip,
      displayName: 'ZIP',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['zip'],
    ),
    ArchiveFormat.tar: FormatCapability(
      format: ArchiveFormat.tar,
      displayName: 'TAR',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['tar'],
    ),
    ArchiveFormat.tarGz: FormatCapability(
      format: ArchiveFormat.tarGz,
      displayName: 'TAR.GZ',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['tar.gz', 'tgz'],
    ),
    ArchiveFormat.tarBz2: FormatCapability(
      format: ArchiveFormat.tarBz2,
      displayName: 'TAR.BZ2',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['tar.bz2', 'tbz2', 'tbz'],
    ),
    ArchiveFormat.gzip: FormatCapability(
      format: ArchiveFormat.gzip,
      displayName: 'GZIP',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['gz'],
    ),
    ArchiveFormat.bzip2: FormatCapability(
      format: ArchiveFormat.bzip2,
      displayName: 'BZIP2',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['bz2'],
    ),
    ArchiveFormat.tarXz: FormatCapability(
      format: ArchiveFormat.tarXz,
      displayName: 'TAR.XZ',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['tar.xz', 'txz'],
    ),
    ArchiveFormat.xz: FormatCapability(
      format: ArchiveFormat.xz,
      displayName: 'XZ',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['xz'],
    ),
    ArchiveFormat.tarZst: FormatCapability(
      format: ArchiveFormat.tarZst,
      displayName: 'TAR.ZST',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['tar.zst', 'tzst'],
    ),
    ArchiveFormat.zstd: FormatCapability(
      format: ArchiveFormat.zstd,
      displayName: 'ZSTD',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.libarchive,
      writeBackend: BackendKind.rustNative,
      extensions: ['zst'],
    ),

    // --- 생성+해제, 단 libarchive가 읽기를 커버하지 않아 Rust가 양쪽 다 담당 ---
    ArchiveFormat.sevenZip: FormatCapability(
      format: ArchiveFormat.sevenZip,
      displayName: '7Z',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.rustNative,
      writeBackend: BackendKind.rustNative,
      extensions: ['7z'],
    ),
    ArchiveFormat.lz4: FormatCapability(
      format: ArchiveFormat.lz4,
      displayName: 'LZ4',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.rustNative,
      writeBackend: BackendKind.rustNative,
      extensions: ['lz4'],
    ),
    ArchiveFormat.brotli: FormatCapability(
      format: ArchiveFormat.brotli,
      displayName: 'Brotli',
      canRead: true,
      canWrite: true,
      readBackend: BackendKind.rustNative,
      writeBackend: BackendKind.rustNative,
      extensions: ['br'],
    ),

    // --- 해제 전용 (PLAN.md 3장 "RAR 정책" — RAR 생성은 라이선스상 불가능) ---
    ArchiveFormat.rar: FormatCapability(
      format: ArchiveFormat.rar,
      displayName: 'RAR',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['rar'],
    ),

    // --- 해제 전용, 레거시/니치 (libarchive 커버리지 그대로 활용) ---
    ArchiveFormat.iso9660: FormatCapability(
      format: ArchiveFormat.iso9660,
      displayName: 'ISO9660',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['iso'],
    ),
    ArchiveFormat.cab: FormatCapability(
      format: ArchiveFormat.cab,
      displayName: 'CAB',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['cab'],
    ),
    ArchiveFormat.arj: FormatCapability(
      format: ArchiveFormat.arj,
      displayName: 'ARJ',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['arj'],
    ),
    ArchiveFormat.lha: FormatCapability(
      format: ArchiveFormat.lha,
      displayName: 'LHA',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['lha', 'lzh'],
    ),
    ArchiveFormat.cpio: FormatCapability(
      format: ArchiveFormat.cpio,
      displayName: 'CPIO',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['cpio'],
    ),
    ArchiveFormat.ar: FormatCapability(
      format: ArchiveFormat.ar,
      displayName: 'AR',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['ar'],
    ),
    ArchiveFormat.xar: FormatCapability(
      format: ArchiveFormat.xar,
      displayName: 'XAR',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['xar'],
    ),
    ArchiveFormat.warc: FormatCapability(
      format: ArchiveFormat.warc,
      displayName: 'WARC',
      canRead: true,
      canWrite: false,
      readBackend: BackendKind.libarchive,
      extensions: ['warc'],
    ),
  };

  /// 분할 볼륨 조각 파일 이름 끝에 붙는 번호(`.001`, `.002`, ...) 패턴 —
  /// PLAN.md 1.3 "분할 압축". 최소 3자리로 고정하지는 않는다(조각이 1000개를
  /// 넘으면 [DartArchiveWriter]가 자릿수를 늘려 붙이므로) — 대신 숫자만
  /// 3자리 이상이면 분할 조각으로 인식한다. 압축 확장자 자체는 숫자로
  /// 끝나지 않으므로 오탐 위험은 낮다.
  static final RegExp _splitVolumeSuffix = RegExp(r'\.(\d{3,})$');

  static FormatCapability of(ArchiveFormat format) => _byFormat[format]!;

  static bool canRead(ArchiveFormat format) => of(format).canRead;

  static bool canWrite(ArchiveFormat format) => of(format).canWrite;

  /// 압축 생성 시 포맷 드롭다운에 노출할 목록 (UI_UX.md `CompressDialog`).
  static List<ArchiveFormat> get writableFormats =>
      _byFormat.values.where((c) => c.canWrite).map((c) => c.format).toList();

  /// 모든 포맷의 확장자를 평탄화한 목록(점 없이, 소문자). 순서는 임의라
  /// 호출하는 쪽에서 길이 등으로 다시 정렬해 써야 한다 — 예:
  /// `resolveExtractDestination`의 `basenameWithoutArchiveExtensions`가
  /// 이중 확장자(`tar.gz`)를 먼저 매칭시키기 위해 길이 내림차순으로 정렬해 씀
  /// (ARCHITECTURE.md 5장).
  static List<String> get allExtensions => [
        for (final capability in _byFormat.values) ...capability.extensions,
      ];

  /// 파일명의 확장자로 포맷을 추정한다. 이중 확장자(`.tar.gz` 등)를 가진
  /// 포맷을 먼저 검사해 `photos.tar.gz`가 gzip으로 잘못 판별되지 않게 한다
  /// (긴 확장자부터 매칭 — ARCHITECTURE.md 5장 `basenameWithoutArchiveExtensions`가
  /// 이 목록을 그대로 재사용할 예정).
  static ArchiveFormat? detectFromFileName(String fileName) {
    final lower = stripSplitVolumeSuffix(fileName).toLowerCase();
    final candidates = <(String ext, ArchiveFormat format)>[
      for (final capability in _byFormat.values)
        for (final ext in capability.extensions) (ext, capability.format),
    ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

    for (final (ext, format) in candidates) {
      if (lower.endsWith('.$ext')) return format;
    }
    return null;
  }

  /// [fileName]에서 알려진 압축 확장자를 제거한다. `.tar.gz`처럼 이중
  /// 확장자를 가진 포맷도 한 번에 제거한다(`path` 패키지의
  /// `basenameWithoutExtension`은 마지막 확장자 하나만 제거해서
  /// `photos.tar.gz` → `photos.tar`로 남는 문제가 있다). 확장자를 길이
  /// 내림차순으로 검사해 `tar.gz`가 `gz`보다 먼저 매칭되게 한다 —
  /// `resolveExtractDestination`(ARCHITECTURE.md 5장)과 단일 파일 압축
  /// 포맷(gzip/bzip2/xz)의 내부 항목 이름 추정(ARCHITECTURE.md 6.1) 양쪽이
  /// 이 하나의 구현을 공유한다.
  static String stripKnownExtension(String fileName) {
    final withoutSplitSuffix = stripSplitVolumeSuffix(fileName);
    final lower = withoutSplitSuffix.toLowerCase();
    final extensionsByLengthDesc = allExtensions.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final ext in extensionsByLengthDesc) {
      if (lower.endsWith('.$ext')) {
        return withoutSplitSuffix.substring(0, withoutSplitSuffix.length - ext.length - 1);
      }
    }
    return withoutSplitSuffix;
  }

  /// [fileName]이 분할 압축 조각(`archive.zip.007` 등)이면 true.
  ///
  /// DoveZip의 분할 압축은 7z/RAR의 진짜 멀티볼륨 스펙이 아니라 — 그건
  /// libarchive/네이티브 백엔드가 있어야 다른 도구가 만든 조각까지 읽을 수
  /// 있다(PLAN.md 1.3, 아직 보류) — 완성된 단일 압축파일을 고정 크기로
  /// 나눠 붙인 것뿐이다. 그래서 DoveZip이 만든 조각을 DoveZip 스스로
  /// 다시 이어붙일 때만 정확히 원본과 같아진다(다른 압축 프로그램과의
  /// 호환은 보장하지 않음 — ARCHITECTURE.md 4장 참고).
  static bool isSplitVolumePart(String fileName) => _splitVolumeSuffix.hasMatch(fileName);

  /// 분할 조각 이름의 번호(`archive.zip.007` → `7`)를 반환한다. 조각이
  /// 아니면 null.
  static int? splitVolumeIndexOf(String fileName) {
    final match = _splitVolumeSuffix.firstMatch(fileName);
    return match == null ? null : int.parse(match.group(1)!);
  }

  /// 분할 조각 이름에서 번호 접미사를 떼 원래 압축파일 이름으로 되돌린다
  /// (`archive.zip.007` → `archive.zip`). 조각이 아니면 그대로 반환한다.
  static String stripSplitVolumeSuffix(String fileName) =>
      fileName.replaceFirst(_splitVolumeSuffix, '');
}
