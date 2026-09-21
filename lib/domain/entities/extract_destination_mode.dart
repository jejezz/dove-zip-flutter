/// 압축 해제 위치 3가지 모드 (PLAN.md 1.2 — 이 앱의 핵심 편의 기능).
///
/// 기본값은 [smart]. 실제 목적지 계산은 `application/resolve_extract_destination.dart`의
/// `resolveExtractDestination`이 담당한다(ARCHITECTURE.md 5장).
enum ExtractDestinationMode {
  /// 압축파일이 있는 폴더에 내용물을 바로 풀어놓는다.
  here,

  /// 압축파일 이름과 동일한 새 폴더를 만들고 그 안에 해제한다. 압축파일
  /// 내부가 이미 그 이름의 폴더 하나로만 구성돼 있으면 중복 폴더를
  /// 만들지 않는다.
  smart,

  /// 사용자가 폴더 선택 다이얼로그로 직접 지정한 위치에 해제한다.
  chooseFolder,
}
