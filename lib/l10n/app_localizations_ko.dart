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
  String themeToggleTooltip(String mode) {
    return '테마 전환 ($mode)';
  }

  @override
  String get themeModeSystem => '시스템';

  @override
  String get themeModeLight => '라이트';

  @override
  String get themeModeDark => '다크';

  @override
  String languageToggleTooltip(String mode) {
    return '언어 전환 ($mode)';
  }

  @override
  String get languageModeSystem => '시스템';

  @override
  String get languageModeKorean => '한국어';

  @override
  String get languageModeEnglish => '영어';

  @override
  String get homeDropHint => '압축파일을 여기로 드래그하거나\n클릭해서 열기';

  @override
  String get openButton => '열기';

  @override
  String get createArchiveButton => '새 압축 만들기';

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
  String get extractCancelled => '압축 해제를 취소했습니다.';

  @override
  String extractFailed(String error) {
    return '압축 해제 실패: $error';
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
}
