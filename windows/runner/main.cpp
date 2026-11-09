#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <shlobj.h>

#include <cstdlib>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

#pragma comment(lib, "version.lib")

namespace {

struct Translation {
  WORD language;
  WORD code_page;
};

// A string from this executable's version resource (Runner.rc).
std::wstring VersionString(const wchar_t* name) {
  wchar_t exe[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return L"";
  DWORD size = ::GetFileVersionInfoSizeW(exe, nullptr);
  if (size == 0) return L"";
  std::vector<char> data(size);
  if (!::GetFileVersionInfoW(exe, 0, size, data.data())) return L"";
  Translation* translation = nullptr;
  UINT translation_size = 0;
  if (!::VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation",
                        reinterpret_cast<void**>(&translation),
                        &translation_size) ||
      translation_size < sizeof(Translation)) {
    return L"";
  }
  wchar_t key[96];
  swprintf_s(key, L"\\StringFileInfo\\%04x%04x\\%s", translation->language,
             translation->code_page, name);
  wchar_t* value = nullptr;
  UINT value_size = 0;
  if (!::VerQueryValueW(data.data(), key, reinterpret_cast<void**>(&value),
                        &value_size) ||
      value == nullptr) {
    return L"";
  }
  return value;
}

// The folder name path_provider uses: characters Windows forbids become '_'.
std::wstring FolderName(std::wstring name) {
  for (wchar_t& c : name) {
    if (wcschr(L"<>:\"/\\|?*", c) != nullptr) c = L'_';
  }
  while (!name.empty() && (name.back() == L'.' || name.back() == L' ')) {
    name.pop_back();
  }
  return name;
}

// The window frame in physical pixels that dock_window.dart saved under
// 'window_bounds_px' in shared_preferences.json, or false when there is none
// or it does not touch any monitor (then the default frame is used and
// dock_window.dart centers the window as before).
bool ReadSavedFrame(RECT* frame) {
  PWSTR app_data = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr,
                                    &app_data))) {
    return false;
  }
  std::wstring path = app_data;
  ::CoTaskMemFree(app_data);
  path += L"\\" + FolderName(VersionString(L"CompanyName")) + L"\\" +
          FolderName(VersionString(L"ProductName")) +
          L"\\shared_preferences.json";

  std::ifstream file(path, std::ios::binary);
  if (!file) return false;
  std::string json((std::istreambuf_iterator<char>(file)),
                   std::istreambuf_iterator<char>());
  const std::string key = "\"flutter.window_bounds_px\"";
  size_t at = json.find(key);
  if (at == std::string::npos) return false;
  size_t open = json.find('[', at + key.size());
  size_t close = json.find(']', at);
  if (open == std::string::npos || close == std::string::npos || open > close) {
    return false;
  }
  // ["left","top","width","height"]
  long v[4];
  at = open;
  for (long& number : v) {
    size_t begin = json.find('"', at);
    size_t end = begin == std::string::npos ? begin : json.find('"', begin + 1);
    if (end == std::string::npos || end > close) return false;
    const std::string text = json.substr(begin + 1, end - begin - 1);
    char* parsed = nullptr;
    number = std::strtol(text.c_str(), &parsed, 10);
    if (parsed == text.c_str() || *parsed != '\0') return false;
    at = end + 1;
  }
  if (v[2] <= 0 || v[3] <= 0 || v[2] > 20000 || v[3] > 20000) return false;
  POINT middle = {v[0] + v[2] / 2, v[1] + v[3] / 2};
  if (::MonitorFromPoint(middle, MONITOR_DEFAULTTONULL) == nullptr) {
    return false;
  }
  *frame = {v[0], v[1], v[0] + v[2], v[1] + v[3]};
  return true;
}

}  // namespace

// True when DAYLIGHT_IMPELLER is 1, true, on or yes (case-insensitive).
static bool ImpellerRequested() {
  wchar_t value[16];
  DWORD length = ::GetEnvironmentVariableW(L"DAYLIGHT_IMPELLER", value,
                                           static_cast<DWORD>(std::size(value)));
  if (length == 0 || length >= std::size(value)) {
    return false;
  }
  return ::_wcsicmp(value, L"1") == 0 || ::_wcsicmp(value, L"true") == 0 ||
         ::_wcsicmp(value, L"on") == 0 || ::_wcsicmp(value, L"yes") == 0;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Impeller is off unless DAYLIGHT_IMPELLER asks for it (1/true/on/yes).
  // The same variable name is used by every Daylight app. Release engines
  // ignore FLUTTER_ENGINE_SWITCHES, so this is set through the project.
  project.set_impeller_switch(ImpellerRequested()
                                  ? flutter::ImpellerSwitch::Enabled
                                  : flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  // Open where the window was last (see ReadSavedFrame) so it need not move
  // across monitors after the Flutter view exists; dock_window.dart still
  // validates and applies the same frame, which is then a no-op.
  RECT saved_frame;
  const bool created = ReadSavedFrame(&saved_frame)
                           ? window.Create(L"Dove Zip", saved_frame)
                           : window.Create(L"Dove Zip", origin, size);
  if (!created) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
