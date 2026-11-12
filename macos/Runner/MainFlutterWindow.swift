import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ServicesBridge.shared.attach(to: flutterViewController)
    DefaultAppBridge.attach(to: flutterViewController)

    super.awakeFromNib()
  }
}

/// 설정의 "기본 앱으로 설정" — Dart의 `MacDefaultAppRegistrar`가 확장자 목록을
/// 넘기면, 확장자마다 이 앱을 Finder 기본 앱으로 정하고 실패한 확장자 목록을
/// 돌려준다(전부 됐으면 빈 목록). 이 앱이 열 수 있다는 선언은 Info.plist의
/// `CFBundleDocumentTypes`에 이미 있다.
enum DefaultAppBridge {
  static func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "dove_zip/default_app",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setAsDefault", let extensions = call.arguments as? [String] else {
        result(FlutterMethodNotImplemented)
        return
      }
      setAsDefault(extensions[...], failed: [], app: Bundle.main.bundleURL) { failed in
        result(failed)
      }
    }
  }

  /// 하나씩 차례로 바꾼다 — 동시에 부르면 macOS가 확인 창을 여러 개 띄울 수 있다.
  private static func setAsDefault(
    _ remaining: ArraySlice<String>,
    failed: [String],
    app: URL,
    done: @escaping ([String]) -> Void
  ) {
    guard let ext = remaining.first else {
      done(failed)
      return
    }
    let rest = remaining.dropFirst()
    guard let type = UTType(filenameExtension: ext) else {
      setAsDefault(rest, failed: failed + [ext], app: app, done: done)
      return
    }
    // Swift 이름은 `setDefaultApplication(at:toOpen:completionHandler:)`
    // (Objective-C의 `…toOpenContentType:completionHandler:`).
    NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type, completionHandler: { error in
      DispatchQueue.main.async {
        setAsDefault(rest, failed: error == nil ? failed : failed + [ext], app: app, done: done)
      }
    })
  }
}
