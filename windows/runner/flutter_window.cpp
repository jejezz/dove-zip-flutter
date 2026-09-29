#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

// window_manager converts bounds with the DPI scale of the monitor the window
// is on *now*, so a frame saved on one monitor lands elsewhere when restored
// from a monitor with another scale. Physical pixels mean the same on every
// monitor, so the frame is saved and restored in them.
void FlutterWindow::RegisterFrameChannel() {
  frame_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dove_zip/window_frame",
          &flutter::StandardMethodCodec::GetInstance());
  frame_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HWND hwnd = GetHandle();
    if (call.method_name() == "getFrame") {
      RECT r;
      if (!GetWindowRect(hwnd, &r)) {
        result->Success();
        return;
      }
      result->Success(flutter::EncodableValue(flutter::EncodableList{
          flutter::EncodableValue(static_cast<int32_t>(r.left)),
          flutter::EncodableValue(static_cast<int32_t>(r.top)),
          flutter::EncodableValue(static_cast<int32_t>(r.right - r.left)),
          flutter::EncodableValue(static_cast<int32_t>(r.bottom - r.top)),
      }));
    } else if (call.method_name() == "setFrame") {
      const auto* args = std::get_if<flutter::EncodableList>(call.arguments());
      if (args == nullptr || args->size() != 4) {
        result->Error("bad-args", "setFrame expects [left, top, width, height]");
        return;
      }
      int v[4];
      for (size_t i = 0; i < 4; i++) {
        v[i] = static_cast<int>((*args)[i].LongValue());
      }
      // Refuse a frame whose middle is off every monitor (e.g. the monitor
      // it was saved on is disconnected) so the caller can center instead.
      POINT middle = {v[0] + v[2] / 2, v[1] + v[3] / 2};
      if (v[2] <= 0 || v[3] <= 0 ||
          MonitorFromPoint(middle, MONITOR_DEFAULTTONULL) == nullptr) {
        result->Success(flutter::EncodableValue(false));
        return;
      }
      // Moving onto a monitor with another DPI sends WM_DPICHANGED, which
      // rescales the window; the second call restores the saved size there.
      for (int i = 0; i < 2; i++) {
        SetWindowPos(hwnd, nullptr, v[0], v[1], v[2], v[3],
                     SWP_NOZORDER | SWP_NOACTIVATE);
      }
      result->Success(flutter::EncodableValue(true));
    } else {
      result->NotImplemented();
    }
  });
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterFrameChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
