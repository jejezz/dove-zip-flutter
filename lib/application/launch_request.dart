/// OS가 앱 밖에서 넘겨 준 요청 — macOS Finder 서비스 메뉴(`dove_zip/services`
/// 채널)와 Windows 탐색기 우클릭 메뉴(명령줄 인자)가 같은 모양으로 들어온다
/// (PLAN.md 1.4 "OS 컨텍스트 메뉴").
enum LaunchAction {
  /// 압축파일을 연다 — 파일 연결(더블클릭), "연결 프로그램".
  openFiles,

  /// 고른 파일·폴더로 "새 압축 만들기" 창을 연다.
  compressHere,

  /// 압축파일을 열고 곧바로 같은 폴더에 푼다.
  extractHere;

  /// macOS 채널의 메서드 이름에서 고른다. 모르는 이름이면 null.
  static LaunchAction? fromMethod(String method) {
    for (final action in values) {
      if (action.name == method) return action;
    }
    return null;
  }
}

/// 명령줄 인자를 읽은 결과.
class LaunchRequest {
  const LaunchRequest(this.action, this.paths);

  /// Windows 설치 프로그램(`installer/windows/app.iss`)이 탐색기 메뉴에
  /// 등록하는 명령의 첫 인자.
  static const compressHereFlag = '--compress-here';
  static const extractHereFlag = '--extract-here';

  final LaunchAction action;
  final List<String> paths;

  /// `dove_zip.exe --compress-here "C:\a"`처럼 첫 인자가 플래그면 그 동작,
  /// 아니면(파일 연결로 경로만 넘어온 경우) [LaunchAction.openFiles]다.
  /// 그 밖의 `--`로 시작하는 인자는 경로가 아니므로 버린다.
  factory LaunchRequest.parse(List<String> args) {
    final action = switch (args.firstOrNull) {
      compressHereFlag => LaunchAction.compressHere,
      extractHereFlag => LaunchAction.extractHere,
      _ => LaunchAction.openFiles,
    };
    final paths = args.where((a) => !a.startsWith('--') && a.isNotEmpty).toList();
    return LaunchRequest(action, paths);
  }

  /// [parse]가 다시 읽을 수 있는 명령줄 인자.
  List<String> toArgs() => [
        if (action == LaunchAction.compressHere) compressHereFlag,
        if (action == LaunchAction.extractHere) extractHereFlag,
        ...paths,
      ];
}
