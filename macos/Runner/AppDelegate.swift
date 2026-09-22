import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Finder "서비스" 메뉴(NSServices, Info.plist)의 "여기에 압축"/"여기에
    // 풀기"를 받는다(PLAN.md 1.4 "OS 컨텍스트 메뉴"). 실제 처리는
    // ServicesBridge가 Flutter MethodChannel로 그대로 넘긴다.
    NSApp.servicesProvider = ServicesBridge.shared
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
