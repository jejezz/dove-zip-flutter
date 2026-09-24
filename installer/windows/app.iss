; Inno Setup script template for a Flutter Windows desktop app.
;
; Run automatically by .github/workflows/release.yml's `build-windows` job on
; every `v*.*.*` tag push, which passes MyAppName/MyAppVersion/MyAppExeName
; via `ISCC /D...` (read from pubspec.yaml and windows/CMakeLists.txt, so no
; edits needed here for those). For local, manual compiles the fallback
; defaults below are used instead — edit them to match your app.
;
; Dove Zip: MyAppName is the display name "Dove Zip" (the workflow reads it
; from macos/Runner/Configs/AppInfo.xcconfig, since pubspec.yaml's `name` is
; the Dart package id `dove_zip`), and the installer file name drops its
; space (DoveZipSetup-x.y.z.exe) so GitHub Release doesn't rename it.
;
; The one thing you MUST edit yourself: AppId below. Generate a fresh GUID
; for your app (PowerShell: `[guid]::NewGuid()`) and paste it in — never
; reuse another app's GUID, and never change it again once you've shipped a
; release, or Windows will treat future versions as a different application
; (breaking upgrade/uninstall for existing users).

#ifndef MyAppName
  #define MyAppName "Dove Zip"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "dove_zip.exe"
#endif
#define SourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{1C29D018-6668-4C23-9E9D-FE93E1229ABC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\..\dist
OutputBaseFilename={#StringChange(MyAppName, " ", "")}Setup-{#MyAppVersion}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch after install"; Flags: nowait postinstall skipifsilent
