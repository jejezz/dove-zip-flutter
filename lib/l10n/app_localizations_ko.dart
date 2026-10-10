// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Dove Zip';

  @override
  String get themeMenuTooltip => '테마';

  @override
  String get themeSystem => '시스템 설정 따르기';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get languageMenuTooltip => '언어';

  @override
  String get languageSystem => '시스템 설정 따르기 / System';

  @override
  String get languageSystemShort => '시스템';

  @override
  String get homeDropHint => '압축파일을 여기로 드래그하거나\n클릭해서 열기';

  @override
  String get openButton => '열기';

  @override
  String get createArchiveButton => '새 압축 만들기';

  @override
  String get pickFilesMenuItem => '파일 선택...';

  @override
  String get pickFolderMenuItem => '폴더 선택...';

  @override
  String openArchiveFailed(String error) {
    return '압축파일을 열지 못했습니다: $error';
  }

  @override
  String get recentArchivesTitle => '최근 연 압축파일';

  @override
  String get removeFromRecentTooltip => '목록에서 지우기';

  @override
  String get archiveFileTypeGroupLabel => '압축파일';

  @override
  String get anyFileTypeGroupLabel => '모든 파일 (분할 압축 조각 선택용)';

  @override
  String get parentFolderTooltip => '상위 폴더';

  @override
  String get closeTooltip => '닫기';

  @override
  String get filenameEncodingTooltip => '파일명 인코딩';

  @override
  String get filenameEncodingAuto => '자동 감지';

  @override
  String get filenameEncodingUtf8 => 'UTF-8';

  @override
  String get filenameEncodingCp949 => '한글 (CP949)';

  @override
  String get searchTooltip => '검색';

  @override
  String get closeSearchTooltip => '검색 닫기';

  @override
  String get searchHint => '이 폴더에서 검색';

  @override
  String get emptyFolder => '빈 폴더입니다';

  @override
  String previewFailed(String error) {
    return '미리보기를 열지 못했습니다: $error';
  }

  @override
  String extractCompleted(String path) {
    return '압축 해제 완료: $path';
  }

  @override
  String extractCompletedWithFailures(String path, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 항목은 손상되어 건너뜀',
    );
    return '압축 해제 완료: $path\n($_temp0)';
  }

  @override
  String get extractCancelled => '압축 해제를 취소했습니다.';

  @override
  String extractFailed(String error) {
    return '압축 해제 실패: $error';
  }

  @override
  String dragOutItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 항목',
    );
    return '$_temp0';
  }

  @override
  String get dragOutStillPreparing =>
      '아직 압축을 푸는 중이라 창 밖으로 넘기지 못했습니다. 잠시 뒤 다시 끌어 보세요.';

  @override
  String get dragOutPasswordRequired =>
      '비밀번호가 필요한 항목입니다. 미리보기나 해제로 비밀번호를 한 번 입력한 뒤 끌어내 주세요.';

  @override
  String dragOutTooLarge(String limit) {
    return '창 밖으로 끌어내기는 $limit 이하만 지원합니다. 아래 해제 버튼을 사용하세요.';
  }

  @override
  String dragOutFailed(String error) {
    return '끌어내기를 준비하지 못했습니다: $error';
  }

  @override
  String get columnName => '이름';

  @override
  String get columnSize => '크기';

  @override
  String get columnCompressedSize => '압축크기';

  @override
  String get columnModified => '수정일';

  @override
  String get formatWritableTooltip => '이 형식은 압축 생성도 지원합니다';

  @override
  String get formatReadOnlyTooltip => '이 형식은 해제만 가능합니다(생성 불가)';

  @override
  String statusBarItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 항목',
    );
    return '$_temp0';
  }

  @override
  String get extractHereButton => '여기에 압축 해제';

  @override
  String get extractSmartButton => '알아서 압축 해제';

  @override
  String get extractChooseFolderButton => '원하는 곳에...';

  @override
  String get extractHereSelectedButton => '선택 항목 여기에 해제';

  @override
  String get extractSmartSelectedButton => '선택 항목 알아서 해제';

  @override
  String get extractChooseFolderSelectedButton => '선택 항목 원하는 곳에...';

  @override
  String statusBarSelectedCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 선택됨 ($size)',
    );
    return '$_temp0';
  }

  @override
  String get clearSelectionTooltip => '선택 해제';

  @override
  String get conflictTitle => '이미 같은 이름의 파일이 있습니다';

  @override
  String conflictSourceLabel(String size) {
    return '압축파일 안: $size';
  }

  @override
  String conflictDestinationLabel(String size) {
    return '기존 파일: $size';
  }

  @override
  String get cancel => '취소';

  @override
  String get copyButton => '복사';

  @override
  String get errorMessageCopied => '오류 메시지를 복사했습니다';

  @override
  String get skipAll => '모두 건너뛰기';

  @override
  String get skip => '건너뛰기';

  @override
  String get renameAndExtract => '이름 바꿔서 풀기';

  @override
  String get overwriteAll => '모두 덮어쓰기';

  @override
  String get overwrite => '덮어쓰기';

  @override
  String get extractingTitle => '압축 해제 중...';

  @override
  String get compressingTitle => '압축 생성 중...';

  @override
  String get preparing => '준비 중...';

  @override
  String progressCount(int done, int total) {
    return '$done / $total';
  }

  @override
  String get passwordRequiredTitle => '비밀번호가 필요합니다';

  @override
  String get passwordWrongHint => '비밀번호가 틀렸습니다. 다시 시도해 주세요.';

  @override
  String get passwordHint => '비밀번호';

  @override
  String get confirm => '확인';

  @override
  String get newArchiveTitle => '새 압축 만들기';

  @override
  String compressTargetLabel(String summary) {
    return '대상: $summary';
  }

  @override
  String sourcesSummaryMore(int count) {
    return '외 $count개';
  }

  @override
  String sourcesSummaryTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count개)',
    );
    return '$_temp0';
  }

  @override
  String originalSizeLabel(String size) {
    return '원본 크기: $size';
  }

  @override
  String get formatLabel => '포맷';

  @override
  String get compressionLevelLabel => '압축 레벨';

  @override
  String get compressionLevelStore => '저장';

  @override
  String get compressionLevelFast => '빠름';

  @override
  String get compressionLevelNormal => '보통';

  @override
  String get compressionLevelMax => '최대';

  @override
  String get passwordProtectSupportedFormats => '비밀번호로 보호 (ZIP/7Z만 지원)';

  @override
  String get splitArchiveLabel => '분할 압축';

  @override
  String get splitVolumeSizeHint => '볼륨 크기';

  @override
  String get splitVolumeSizeInvalid =>
      '분할 볼륨 크기를 올바르게 입력해 주세요 (1 이상의 정수, MB 단위).';

  @override
  String splitVolumesCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' ($count개 조각으로 분할됨)',
    );
    return '$_temp0';
  }

  @override
  String get excludedExtensionsLabel => '제외할 확장자';

  @override
  String get excludedExtensionsHint => '쉼표로 구분 (예: tmp, log)';

  @override
  String get followSymlinksLabel => '심볼릭 링크 따라가기';

  @override
  String saveLocationLabel(String path) {
    return '저장 위치: $path';
  }

  @override
  String get changeButton => '변경';

  @override
  String get startCompressButton => '압축 시작';

  @override
  String compressCompleted(String path) {
    return '압축 생성 완료: $path';
  }

  @override
  String compressionRatioLabel(
    String original,
    String compressed,
    int percent,
  ) {
    return ' ($original → $compressed, $percent% 감소)';
  }

  @override
  String compressFailed(String error) {
    return '압축 생성 실패: $error';
  }

  @override
  String get unsupportedFormat => '이 형식은 아직 미리보기를 지원하지 않습니다';

  @override
  String get openWithDefaultAppButton => 'OS 기본 앱으로 열기';

  @override
  String imageLoadError(String error) {
    return '이미지를 열지 못했습니다: $error';
  }

  @override
  String get windowMenuTooltip => '창 배치';

  @override
  String get menuSnapRight => '화면 오른쪽에 붙이기';

  @override
  String get menuSnapLeft => '화면 왼쪽에 붙이기';

  @override
  String get alwaysOnTopOnTooltip => '항상 위에 표시';

  @override
  String get alwaysOnTopOffTooltip => '항상 위에 표시 끄기';

  @override
  String get aboutTooltip => '정보';

  @override
  String aboutMenuItem(String appName) {
    return '$appName 정보';
  }

  @override
  String get aboutTagline => '광고 없는 올인원 압축/해제 유틸리티';

  @override
  String aboutVersion(String version, String build) {
    return '버전 $version (빌드 $build)';
  }

  @override
  String get aboutDescription =>
      'Windows·macOS·Linux를 모두 지원하며, 광고·팝업·인앱결제 유도 없이 압축파일을 풀지 않고 바로 탐색하고 원하는 방식으로 풀고 만들 수 있는 가벼운 압축 유틸리티를 목표로 만들었습니다.';

  @override
  String get aboutFeatureBrowse => '압축파일을 풀지 않고 탐색·미리보기, 중첩 압축 드릴다운';

  @override
  String get aboutFeatureExtract =>
      '3가지 해제 모드(여기에·알아서·원하는 곳에), 선택 항목만 해제, 손상된 압축파일 부분 해제';

  @override
  String get aboutFeatureCompress =>
      '압축 레벨·파일 필터 선택, AES-256 비밀번호(ZIP·7Z), 분할 압축';

  @override
  String get aboutFeatureFormats => 'ZIP·TAR·GZIP·BZIP2·XZ·7Z 압축/해제, RAR 해제';

  @override
  String get aboutFeatureDragDrop => '드래그앤드롭으로 열기·압축하기, Finder/탐색기로 끌어내서 해제';

  @override
  String get aboutFeatureLocaleTheme => '한국어·영어 다국어 지원, 라이트·다크 테마';

  @override
  String get aboutOpenSourceLicenses => '오픈소스 라이선스';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => '닫기';

  @override
  String get errorCancelled => '작업이 취소되었습니다.';

  @override
  String errorUnsupportedFormat(String fileName) {
    return '$fileName의 압축 형식을 알 수 없거나 아직 지원하지 않습니다.';
  }

  @override
  String errorPasswordRequired(String entryPath) {
    return '\"$entryPath\" 항목에 비밀번호가 필요하거나 비밀번호가 틀렸습니다.';
  }

  @override
  String errorSplitVolumeMissing(int index, String fileName) {
    return '분할 압축 조각이 빠졌습니다 (조각 $index번을 찾을 수 없음): $fileName';
  }

  @override
  String errorSplitVolumesNotFound(String fileName) {
    return '분할 압축 조각을 찾을 수 없습니다: $fileName';
  }

  @override
  String errorSingleFileFormatMultiple(String format) {
    return '$format 형식은 파일 하나만 압축할 수 있습니다 — 폴더나 여러 항목은 tar.gz 등으로 먼저 묶어야 합니다.';
  }

  @override
  String errorSingleFileFormatFolder(String format) {
    return '$format 형식은 폴더를 압축할 수 없습니다 — tar.gz 등을 사용하세요.';
  }

  @override
  String errorTargetExists(String name) {
    return '이미 같은 이름의 항목이 있습니다: $name';
  }

  @override
  String get updateCheckMenuItem => '업데이트 확인';

  @override
  String get updateChecking => '업데이트를 확인하는 중…';

  @override
  String get updateAvailableTitle => '새 버전이 있습니다';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest 버전이 나왔습니다. (현재 $current)';
  }

  @override
  String get updateReleaseNotes => '변경 내용';

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updateLater => '나중에';

  @override
  String get updateSkipVersion => '이 버전 건너뛰기';

  @override
  String get updateDownloading => '내려받는 중…';

  @override
  String get updateVerifying => '파일을 확인하는 중…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => '취소';

  @override
  String get updateFailedTitle => '업데이트하지 못했습니다';

  @override
  String get updateCheckFailedTitle => '업데이트를 확인하지 못했습니다';

  @override
  String get updateErrorNetwork =>
      '업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';

  @override
  String get updateErrorChecksum =>
      '내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateErrorInstall => '설치를 시작하지 못했습니다.';

  @override
  String get updateErrorGeneric =>
      '업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.';

  @override
  String get updateUpToDateTitle => '최신 버전입니다';

  @override
  String updateUpToDateBody(String version) {
    return '$version 버전을 사용 중입니다.';
  }

  @override
  String get updateUnavailableTitle => '직접 설치해 주세요';

  @override
  String updateUnavailableBody(String latest) {
    return '$latest 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.';
  }

  @override
  String get updateOpenReleasePage => '릴리스 페이지 열기';

  @override
  String get updateMacosOpenedTitle => '설치 창이 열렸습니다';

  @override
  String updateMacosOpenedBody(String appName) {
    return '열린 창에서 $appName 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.';
  }

  @override
  String get updateWindowsInstallTitle => '설치 프로그램을 열었습니다';

  @override
  String updateWindowsInstallBody(String appName) {
    return '설치하려면 $appName 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.';
  }

  @override
  String updateQuitApp(String appName) {
    return '$appName 종료';
  }

  @override
  String get updateLinuxInstallTitle => '설치를 준비했습니다';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.';
  }

  @override
  String get updateQuitAndInstall => '종료하고 설치';
}
