import 'dart:io';

// daylight-commander-flutter의 lib/application/usecases/open_with_default_app.dart를
// 그대로 이식.

/// 파일을 OS가 확장자에 연결해 둔 기본 앱으로 연다 (Finder/Explorer의
/// 더블클릭과 동일한 동작) — ARCHITECTURE.md 9장, 미리보기를 지원하지
/// 않는 형식의 폴백.
class OpenWithDefaultApp {
  const OpenWithDefaultApp();

  Future<void> call(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }
}
