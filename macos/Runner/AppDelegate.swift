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

  // 파일 연결(Info.plist의 CFBundleDocumentTypes, PLAN.md 1.4 "OS 파일
  // 연결")로 등록해 둔 zip/tar/7z 등을 더블클릭했을 때(또는 Dock 아이콘에
  // 드래그했을 때) macOS가 호출한다. FlutterAppDelegate 자체 구현은
  // FlutterAppLifecycleDelegate 등록자에게만 넘기고 아무것도 하지 않아,
  // super 호출 전에 먼저 ServicesBridge로 넘긴다.
  override func application(_ application: NSApplication, open urls: [URL]) {
    ServicesBridge.shared.openFiles(urls.map { $0.path })
    super.application(application, open: urls)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
