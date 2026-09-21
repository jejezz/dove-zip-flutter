/// 압축 해제 진행 상황 한 시점의 스냅샷 (ARCHITECTURE.md 7장).
class ExtractProgress {
  const ExtractProgress({
    required this.done,
    required this.total,
    required this.currentName,
  });

  final int done;
  final int total;
  final String currentName;
}
