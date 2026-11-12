/// 압축파일을 더블클릭하면 Dove Zip이 열리도록 OS 기본 앱으로 정한다
/// (설정의 "기본 앱" 구역, PLAN.md 1.4 "OS 파일 연결").
///
/// macOS·Linux는 앱이 직접 바꿀 수 있지만, Windows는 앱이 기본 앱을 바꾸는
/// 것을 막는다 — 그래서 Windows 구현은 설정 앱의 Dove Zip 페이지를 열고,
/// 사용자가 거기서 "기본값 설정"을 누른다([opensSystemSettings]).
abstract class DefaultAppRegistrar {
  /// true면 [makeDefault]가 직접 바꾸지 않고 OS 설정 화면을 연다.
  bool get opensSystemSettings;

  /// 실패하면 아래의 전용 예외를 던진다.
  Future<void> makeDefault();
}

/// 기본 앱으로 정하는 확장자. `macos/Runner/Info.plist`의
/// `CFBundleDocumentTypes`, `installer/windows/app.iss`의 `[Registry]`와 같아야
/// 한다(test/data/default_app_registrar_test.dart가 비교한다).
/// `DartArchiveReader`가 실제로 열 수 있는 형식만 둔다.
const associatedExtensions = ['zip', 'tar', 'gz', 'tgz', 'bz2', 'tbz2', 'tbz', 'xz', 'txz', '7z', 'rar'];

/// [associatedExtensions]에 해당하는 freedesktop MIME 형식. 배포판마다 쓰는
/// 이름이 조금씩 달라(application/x-rar ↔ application/vnd.rar 등) 별칭까지
/// 둔다. 릴리스 워크플로가 만드는 `.desktop` 파일의 `MimeType=`과 같아야 한다.
const linuxMimeTypes = [
  'application/zip',
  'application/x-tar',
  'application/gzip',
  'application/x-gzip',
  'application/x-compressed-tar',
  'application/x-bzip2',
  'application/x-bzip',
  'application/x-bzip2-compressed-tar',
  'application/x-bzip-compressed-tar',
  'application/x-xz',
  'application/x-xz-compressed-tar',
  'application/x-7z-compressed',
  'application/vnd.rar',
  'application/x-rar',
  'application/x-rar-compressed',
];

/// Linux: `install.sh`를 돌리지 않아 `.desktop` 파일이 없다 — 이 상태로는
/// 기본 앱으로 정해도 데스크톱이 앱을 찾지 못한다.
class DesktopEntryMissingException implements Exception {
  const DesktopEntryMissingException(this.desktopId);

  final String desktopId;

  @override
  String toString() => '$desktopId is not installed in any XDG applications directory';
}

/// Windows: 설치 프로그램으로 설치하지 않아(개발 빌드, 압축만 푼 사본)
/// 설정 앱에 Dove Zip 페이지가 없다.
class WindowsAppNotRegisteredException implements Exception {
  const WindowsAppNotRegisteredException();

  @override
  String toString() => 'Dove Zip is not listed under RegisteredApplications';
}

/// 기본 앱을 바꾸는 OS 도구(Linux의 `xdg-mime`)가 없다.
class DefaultAppToolMissingException implements Exception {
  const DefaultAppToolMissingException(this.tool);

  final String tool;

  @override
  String toString() => '$tool was not found';
}

/// OS가 바꾸기를 거절했다. [detail]은 실패한 확장자(macOS)나 도구가 남긴
/// 오류 출력(Linux).
class DefaultAppFailedException implements Exception {
  const DefaultAppFailedException(this.detail);

  final String detail;

  @override
  String toString() => 'Could not set the default app: $detail';
}
