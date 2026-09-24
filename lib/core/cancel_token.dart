// daylight-commander-flutter의 lib/application/cancel_token.dart를 그대로
// 이식 (ARCHITECTURE.md 1장 — 이 앱에서는 core/ 레이어로 배치).

/// 진행 중인 압축/해제 작업을 취소하기 위한 토큰 (ARCHITECTURE.md 7장).
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const OperationCancelledException();
  }
}

class OperationCancelledException implements Exception {
  const OperationCancelledException();

  @override
  String toString() => 'Operation cancelled.';
}
