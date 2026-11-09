#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <iterator>

#include "flutter_window.h"
#include "utils.h"

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
  if (!window.Create(L"Dove Zip", origin, size)) {
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
