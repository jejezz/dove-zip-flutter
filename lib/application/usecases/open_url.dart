import 'dart:io';

// daylight-commander-flutter의 lib/application/usecases/open_url.dart를
// 그대로 이식.

/// URL을 OS 기본 브라우저로 연다 (정보(About) 다이얼로그의 GitHub 링크 등).
/// `url_launcher` 패키지 없이, [OpenWithDefaultApp]과 같은 플랫폼별
/// 프로세스 실행 방식을 그대로 재사용한다.
class OpenUrl {
  const OpenUrl();

  Future<void> call(String url) async {
    if (Platform.isMacOS) {
      await Process.start('open', [url]);
      return;
    }
    if (Platform.isWindows) {
      await Process.start('cmd.exe', ['/c', 'start', '', url]);
      return;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [url]);
    }
  }
}
