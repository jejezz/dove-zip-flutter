/// [ArchiveReader.extractAll]이 특정 항목 하나를 해제하지 못했을 때(손상된
/// 데이터, 깨진 압축 스트림 등) 그 항목만 건너뛰고 계속 진행하면서 남기는
/// 기록 (PLAN.md 1.2 "손상된 압축파일 복구/부분 해제 시도"). 비밀번호
/// 문제([ArchivePasswordRequiredException])나 사용자 취소는 여기 포함되지
/// 않는다 — 그 둘은 전체 작업을 멈추고 각자의 흐름(재시도 다이얼로그,
/// 취소 스낵바)으로 이어져야 하는 별개의 상황이기 때문이다.
class ExtractFailure {
  const ExtractFailure({required this.entryPath, required this.message, this.error});

  final String entryPath;
  final String message;

  /// [message]를 만든 예외 원본. 화면은 이것으로 번역된 문구를 고른다
  /// (presentation/widgets/error_message.dart) — 없으면 [message]를 쓴다.
  final Object? error;

  @override
  String toString() => '$entryPath: $message';
}
