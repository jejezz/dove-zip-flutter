/// 압축 생성 진행 상황 한 시점의 스냅샷 (ARCHITECTURE.md 7장의
/// `ExtractProgress`와 대응되는 압축 생성 버전).
class CompressProgress {
  const CompressProgress({
    required this.done,
    required this.total,
    required this.currentName,
  });

  final int done;
  final int total;
  final String currentName;
}
