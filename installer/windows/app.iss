; Inno Setup script template for a Flutter Windows desktop app
; (jejezz/application-release-templates desktop/ @ conventions-v1).
;
; Run by .github/workflows/release.yml's `build-windows` job on every
; `vX.Y.Z` tag push, which passes MyAppName / MyFileName / MyAppVersion /
; MyAppNumericVersion / MyAppExeName via `ISCC /D...` (read from the tag,
; AppInfo.xcconfig and windows/CMakeLists.txt). The fallbacks below are only
; for a local, manual compile — MyAppVersion 0.0.0 marks such a build.
;
; Edit by hand, once per app:
;   1. AppId — a fresh GUID (PowerShell: `[guid]::NewGuid()`). Never reuse
;      another app's GUID, and never change it after the first release, or
;      Windows treats the next version as a different application (breaking
;      upgrade/uninstall). conventions/identity.md §5.
;   2. MyAppURL — this app's GitHub repository (conventions/identity.md §1).
;
; Dove Zip: AppId is the GUID v0.1.0/v0.1.1 shipped with — never change it.

#ifndef MyAppName
  #define MyAppName "Dove Zip"
#endif
#ifndef MyFileName
  #define MyFileName "DoveZip"
#endif
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppNumericVersion
  #define MyAppNumericVersion "0.0.0"
#endif
#ifndef MyAppExeName
  #define MyAppExeName "dove_zip.exe"
#endif
#define MyAppPublisher "Jongyun Ahn"
#define MyAppURL "https://github.com/jejezz/dove-zip-flutter"
; The app's first release year — edit it for apps started after 2026.
#define MyFirstReleaseYear "2026"
#define SourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{1C29D018-6668-4C23-9E9D-FE93E1229ABC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
AppCopyright=Copyright (C) {#MyFirstReleaseYear} {#MyAppPublisher}
VersionInfoVersion={#MyAppNumericVersion}
VersionInfoProductName={#MyAppName}
VersionInfoCompany={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename={#MyFileName}-{#MyAppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; The [Registry] file associations below — tell Explorer to refresh its icons.
ChangesAssociations=yes
; No license page: MIT apps have nothing to agree to (conventions/licensing.md §4).

[Languages]
; Installer text comes from Inno Setup's own translations — don't hardcode
; Korean (or English) strings below (conventions/packaging.md §3).
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[InstallDelete]
; v0.1.0–v0.1.1 installers put the Start-menu shortcut in a "Dove Zip" folder
; ({group}); this template puts it directly under Programs. Remove the old one
; on upgrade so users don't see two entries (conventions/packaging.md §3).
Type: files; Name: "{group}\{#MyAppName}.lnk"
Type: dirifempty; Name: "{group}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; File associations (PLAN.md 1.4 "OS 파일 연결"). Windows doesn't let an app
; make itself the default, so this only *registers* Dove Zip as a candidate:
; it shows up in "Open with", and Settings > Default apps gets a "Dove Zip"
; page (RegisteredApplications) whose "Set default" button the app's
; "Set as default app" setting opens. Existing defaults are left alone.
; The extension list matches CFBundleDocumentTypes in macos/Runner/Info.plist
; and lib/domain/repositories/default_app_registrar.dart (a test checks).
Root: HKA; Subkey: "Software\Classes\DoveZip.Archive"; ValueType: string; ValueData: "{#MyAppName} Archive"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\DoveZip.Archive\DefaultIcon"; ValueType: string; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\DoveZip.Archive\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\shell\open\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
Root: HKA; Subkey: "Software\DoveZip"; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\DoveZip\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "{#MyAppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\DoveZip\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "{#MyAppName}"
Root: HKA; Subkey: "Software\DoveZip\Capabilities"; ValueType: string; ValueName: "ApplicationIcon"; ValueData: "{app}\{#MyAppExeName},0"
; The value name must stay "{#MyAppName}" — the app opens
; ms-settings:defaultapps?registeredApp…={#MyAppName} to reach this page.
Root: HKA; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: "Software\DoveZip\Capabilities"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.zip\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.tar\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.gz\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.tgz\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.bz2\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.tbz2\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.tbz\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.xz\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.txz\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.7z\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\.rar\OpenWithProgids"; ValueType: string; ValueName: "DoveZip.Archive"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".zip"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".tar"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".gz"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".tgz"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".bz2"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".tbz2"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".tbz"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".xz"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".txz"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".7z"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".rar"; ValueData: ""
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".zip"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".tar"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".gz"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".tgz"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".bz2"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".tbz2"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".tbz"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".xz"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".txz"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".7z"; ValueData: "DoveZip.Archive"
Root: HKA; Subkey: "Software\DoveZip\Capabilities\FileAssociations"; ValueType: string; ValueName: ".rar"; ValueData: "DoveZip.Archive"

; Explorer right-click menu (PLAN.md 1.4 "OS 컨텍스트 메뉴") — classic shell
; verbs, no COM DLL; on Windows 11 they sit under "Show more options".
; Archives get "Extract Here", everything else (files, folders) "Compress";
; both run at once, without a dialog. Labels are indirect strings
; (MUIVerb "@exe,-id") from the STRINGTABLE in windows/runner/Runner.rc, so
; Explorer shows them in the Windows display language. Explorer starts one
; process per selected item; lib/data/launch_spool.dart gathers them into one.
; The flags match lib/application/launch_request.dart (a test checks).
; MultiSelectModel "Player" keeps the verb for selections over 15 items.
Root: HKA; Subkey: "Software\Classes\*\shell\DoveZip.Compress"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1001"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\*\shell\DoveZip.Compress"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\*\shell\DoveZip.Compress"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\*\shell\DoveZip.Compress"; ValueType: string; ValueName: "AppliesTo"; ValueData: "NOT System.FileExtension:=.zip AND NOT System.FileExtension:=.tar AND NOT System.FileExtension:=.gz AND NOT System.FileExtension:=.tgz AND NOT System.FileExtension:=.bz2 AND NOT System.FileExtension:=.tbz2 AND NOT System.FileExtension:=.tbz AND NOT System.FileExtension:=.xz AND NOT System.FileExtension:=.txz AND NOT System.FileExtension:=.7z AND NOT System.FileExtension:=.rar"
Root: HKA; Subkey: "Software\Classes\*\shell\DoveZip.Compress\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --compress-here ""%1"""
Root: HKA; Subkey: "Software\Classes\Directory\shell\DoveZip.Compress"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1001"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Directory\shell\DoveZip.Compress"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\Directory\shell\DoveZip.Compress"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\Directory\shell\DoveZip.Compress\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --compress-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.zip\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.zip\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.zip\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.zip\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tar\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tar\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tar\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tar\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gz\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.gz\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tgz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tgz\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tgz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tgz\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.bz2\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.bz2\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.bz2\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.bz2\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz2\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz2\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz2\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz2\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.tbz\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.xz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.xz\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.xz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.xz\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.txz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.txz\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.txz\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.txz\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.7z\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.7z\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.7z\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.7z\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.rar\shell\DoveZip.Extract"; ValueType: string; ValueName: "MUIVerb"; ValueData: "@{app}\{#MyAppExeName},-1002"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.rar\shell\DoveZip.Extract"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.rar\shell\DoveZip.Extract"; ValueType: string; ValueName: "MultiSelectModel"; ValueData: "Player"
Root: HKA; Subkey: "Software\Classes\SystemFileAssociations\.rar\shell\DoveZip.Extract\command"; ValueType: string; ValueData: """{app}\{#MyAppExeName}"" --extract-here ""%1"""

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
