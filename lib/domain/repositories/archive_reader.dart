import '../../core/cancel_token.dart';
import '../entities/archive_entry.dart';
import '../entities/extract_conflict.dart';
import '../entities/extract_failure.dart';
import '../entities/extract_progress.dart';

/// 압축 해제 중 대상 위치에 동일 이름 파일이 있으면 호출돼 처리 방법을
/// 묻는다. daylight-commander-flutter의 `ConflictResolver`와 동일한 콜백
/// 패턴 — Isolate/포트 기반이 아니라 단순 `Future` 콜백으로 충분하다
/// (ARCHITECTURE.md 7장 "구현 후 수정" 참고).
typedef ConflictResolver = Future<ConflictAction> Function(ExtractConflict conflict);

typedef ExtractProgressCallback = void Function(ExtractProgress progress);

/// 압축 해제할 항목이 비밀번호로 보호돼 있는데 비밀번호가 없거나 틀렸을 때
/// 구현체가 던진다 (PLAN.md 1.2 P1). `listEntries`는 이 예외를 던지지
/// 않는다 — zip 목록은 항목을 실제로 복호화하지 않아도 읽을 수 있고,
/// 비밀번호는 내용을 꺼낼 때(`extractAll`/`extractEntryToTemp`)만 필요하다.
class ArchivePasswordRequiredException implements Exception {
  const ArchivePasswordRequiredException(this.entryPath);

  final String entryPath;

  @override
  String toString() => 'Password required or wrong for "$entryPath"';
}

/// 분할 압축(`name.zip.001`, `.002`, …)의 조각이 빠졌을 때. [missingIndex]가
/// 있으면 그 번호의 조각이 없는 것이고, 없으면 조각을 하나도 찾지 못한 것이다.
/// 이어붙인 바이트가 조용히 깨지는 대신 디코딩 전에 알린다.
class MissingSplitVolumeException implements Exception {
  const MissingSplitVolumeException(this.fileName, {this.missingIndex});

  final String fileName;
  final int? missingIndex;

  @override
  String toString() => missingIndex == null
      ? 'No split volumes found: $fileName'
      : 'Split volume #$missingIndex is missing: $fileName';
}

/// 압축파일을 읽어 엔트리 목록을 얻고, 필요하면 디스크에 해제하는 백엔드의
/// 공통 인터페이스 (ARCHITECTURE.md 4장).
///
/// `domain`은 이 인터페이스만 알고, 실제 구현(`DartArchiveReader`, 이후
/// `LibarchiveReader`)은 `data`/`native` 레이어에 있다 — 백엔드를 교체해도
/// 이 인터페이스에 의존하는 유스케이스(`OpenArchive`, `ExtractEntries`)는
/// 바뀌지 않는다.
abstract class ArchiveReader {
  /// 이 리더가 [format]을 처리할 수 있는지. `FormatRegistry.canRead`(포맷
  /// 자체의 이론적 지원 여부)와는 별개로, "지금 이 구현체가 실제로
  /// 처리 가능한지"를 뜻한다 — 예: 스캐폴딩 단계의 `DartArchiveReader`는
  /// zip만 true를 반환한다.
  bool supports(ArchiveFormat format);

  /// 압축파일 전체를 풀지 않고 엔트리 목록만 읽는다.
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password});

  /// [destination] 아래에 압축을 해제한다. [entryPaths]가 null이면 전체
  /// 해제, 아니면 그 경로들(과 디렉터리라면 그 하위 전부)만 해제한다.
  ///
  /// 충돌·취소·진행률 처리 방식은 daylight의 `FileOperationService`와
  /// 동일한 패턴이다: 파일 단위 경계에서 [cancelToken]을 확인하고, 대상에
  /// 이미 파일이 있으면 [onConflict]로 물어본다.
  ///
  /// 항목 하나가 손상돼 읽지 못해도 전체 작업을 멈추지 않는다 — 그 항목만
  /// 건너뛰고 나머지를 계속 해제한 뒤, 건너뛴 항목들을 반환값으로 알려준다
  /// (PLAN.md 1.2 "손상된 압축파일 복구/부분 해제 시도"). 비어 있는 리스트는
  /// 전부 성공했다는 뜻이다. 비밀번호 문제나 사용자 취소는 이 목록에 담기지
  /// 않고 그대로 예외로 던져진다 — 둘 다 "건너뛰고 계속"이 아니라 각자의
  /// 흐름(재시도, 취소)으로 이어져야 하기 때문이다.
  Future<List<ExtractFailure>> extractAll(
    Uri archiveLocation, {
    required Uri destination,
    List<String>? entryPaths,
    String? password,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  });

  /// [entryPath] 하나만 임시 폴더로 꺼내 그 위치를 반환한다 — 미리보기(F3)
  /// 전용. 압축파일 전체를 풀지 않고, 대상 폴더 충돌도 없다(매번 새
  /// 임시 폴더를 쓰므로) — `extractAll`과 달리 [ConflictResolver]가
  /// 필요 없는 이유다 (ARCHITECTURE.md 9장).
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password});
}
