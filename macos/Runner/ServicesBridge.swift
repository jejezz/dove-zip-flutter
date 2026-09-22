import Cocoa
import FlutterMacOS

/// macOS 쪽에서 Flutter로 파일 경로를 넘겨야 하는 두 가지 네이티브 이벤트를
/// 한 곳에서 다리 놓는다:
/// 1. Finder의 "서비스" 메뉴(`Info.plist`의 `NSServices`, PLAN.md 1.4 "OS
///    컨텍스트 메뉴")로 들어오는 "여기에 압축"/"여기에 풀기" 요청.
/// 2. `Info.plist`의 `CFBundleDocumentTypes`로 등록해 둔 확장자(zip/tar/7z
///    등, PLAN.md 1.4 "OS 파일 연결")를 더블클릭했을 때 AppDelegate가 받는
///    `application(_:open:)` 이벤트, 또는 앱 아이콘에 파일을 드래그한 경우.
///
/// 실제 압축/해제/열기 로직은 전혀 없다 — 이 클래스는 경로를 꺼내 전달하는
/// 얇은 다리일 뿐이고, 나머지는 Dart 쪽 기존 `CreateArchive`/`ExtractEntries`/
/// `OpenArchive` 유스케이스가 앱 내부 버튼과 100% 동일하게 처리한다
/// (ARCHITECTURE.md 5장).
///
/// Finder 서비스는 앱이 아직 실행 중이 아니어도 실행시키며 곧바로 메시지를
/// 보낼 수 있어, `FlutterViewController`/엔진이 준비되기 전에 이 메서드가
/// 먼저 불릴 수 있다 — 그래서 채널이 아직 없으면 [pendingCalls]에 쌓아두고
/// [attach]가 호출되는 순간 그대로 흘려보낸다.
final class ServicesBridge: NSObject {
  static let shared = ServicesBridge()

  private var channel: FlutterMethodChannel?
  private var pendingCalls: [(method: String, paths: [String])] = []

  private override init() {}

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "dove_zip/services",
      binaryMessenger: controller.engine.binaryMessenger
    )
    self.channel = channel
    let queued = pendingCalls
    pendingCalls.removeAll()
    for call in queued {
      channel.invokeMethod(call.method, arguments: call.paths)
    }
  }

  @objc func compressHere(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString>
  ) {
    send("compressHere", paths: Self.filePaths(from: pasteboard))
  }

  @objc func extractHere(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString>
  ) {
    send("extractHere", paths: Self.filePaths(from: pasteboard))
  }

  /// 파일 연결(더블클릭)이나 Dock 아이콘 드래그로 열린 파일들 — `AppDelegate`가
  /// `application(_:open:)`에서 호출한다.
  func openFiles(_ paths: [String]) {
    send("openFiles", paths: paths)
  }

  private func send(_ method: String, paths: [String]) {
    guard !paths.isEmpty else { return }
    NSApp.activate(ignoringOtherApps: true)
    if let channel = channel {
      channel.invokeMethod(method, arguments: paths)
    } else {
      pendingCalls.append((method, paths))
    }
  }

  /// `NSSendTypes`에 신형(`public.file-url`)과 구형(`NSFilenamesPboardType`)
  /// 둘 다 등록해 뒀다 — Finder가 어떤 선택(파일/폴더/여러 개)에 어느 쪽을
  /// 실제로 채워주는지가 macOS 버전마다 조금씩 달라, 신형을 먼저 시도하고
  /// 없으면 구형으로 내려간다.
  private static func filePaths(from pasteboard: NSPasteboard) -> [String] {
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
      !urls.isEmpty
    {
      return urls.map { $0.path }
    }
    let legacyType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    if let legacyPaths = pasteboard.propertyList(forType: legacyType) as? [String] {
      return legacyPaths
    }
    return []
  }
}
