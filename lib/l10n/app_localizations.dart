import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// 앱 이름 — 번역하지 않는다.
  ///
  /// In ko, this message translates to:
  /// **'Dove Zip'**
  String get appTitle;

  /// No description provided for @themeMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get themeMenuTooltip;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get languageMenuTooltip;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기 / System'**
  String get languageSystem;

  /// No description provided for @languageSystemShort.
  ///
  /// In ko, this message translates to:
  /// **'시스템'**
  String get languageSystemShort;

  /// No description provided for @homeDropHint.
  ///
  /// In ko, this message translates to:
  /// **'압축파일을 여기로 드래그하거나\n클릭해서 열기'**
  String get homeDropHint;

  /// No description provided for @openButton.
  ///
  /// In ko, this message translates to:
  /// **'열기'**
  String get openButton;

  /// No description provided for @createArchiveButton.
  ///
  /// In ko, this message translates to:
  /// **'새 압축 만들기'**
  String get createArchiveButton;

  /// No description provided for @pickFilesMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'파일 선택...'**
  String get pickFilesMenuItem;

  /// No description provided for @pickFolderMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'폴더 선택...'**
  String get pickFolderMenuItem;

  /// No description provided for @openArchiveFailed.
  ///
  /// In ko, this message translates to:
  /// **'압축파일을 열지 못했습니다: {error}'**
  String openArchiveFailed(String error);

  /// No description provided for @recentArchivesTitle.
  ///
  /// In ko, this message translates to:
  /// **'최근 연 압축파일'**
  String get recentArchivesTitle;

  /// No description provided for @removeFromRecentTooltip.
  ///
  /// In ko, this message translates to:
  /// **'목록에서 지우기'**
  String get removeFromRecentTooltip;

  /// No description provided for @archiveFileTypeGroupLabel.
  ///
  /// In ko, this message translates to:
  /// **'압축파일'**
  String get archiveFileTypeGroupLabel;

  /// No description provided for @anyFileTypeGroupLabel.
  ///
  /// In ko, this message translates to:
  /// **'모든 파일 (분할 압축 조각 선택용)'**
  String get anyFileTypeGroupLabel;

  /// No description provided for @parentFolderTooltip.
  ///
  /// In ko, this message translates to:
  /// **'상위 폴더'**
  String get parentFolderTooltip;

  /// No description provided for @closeTooltip.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get closeTooltip;

  /// No description provided for @searchTooltip.
  ///
  /// In ko, this message translates to:
  /// **'검색'**
  String get searchTooltip;

  /// No description provided for @closeSearchTooltip.
  ///
  /// In ko, this message translates to:
  /// **'검색 닫기'**
  String get closeSearchTooltip;

  /// No description provided for @searchHint.
  ///
  /// In ko, this message translates to:
  /// **'이 폴더에서 검색'**
  String get searchHint;

  /// No description provided for @emptyFolder.
  ///
  /// In ko, this message translates to:
  /// **'빈 폴더입니다'**
  String get emptyFolder;

  /// No description provided for @previewFailed.
  ///
  /// In ko, this message translates to:
  /// **'미리보기를 열지 못했습니다: {error}'**
  String previewFailed(String error);

  /// No description provided for @extractCompleted.
  ///
  /// In ko, this message translates to:
  /// **'압축 해제 완료: {path}'**
  String extractCompleted(String path);

  /// No description provided for @extractCompletedWithFailures.
  ///
  /// In ko, this message translates to:
  /// **'압축 해제 완료: {path}\n({count, plural, other{{count}개 항목은 손상되어 건너뜀}})'**
  String extractCompletedWithFailures(String path, int count);

  /// No description provided for @extractCancelled.
  ///
  /// In ko, this message translates to:
  /// **'압축 해제를 취소했습니다.'**
  String get extractCancelled;

  /// No description provided for @extractFailed.
  ///
  /// In ko, this message translates to:
  /// **'압축 해제 실패: {error}'**
  String extractFailed(String error);

  /// 여러 항목을 창 밖으로 끌 때 드래그 미리보기에 보이는 문구.
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개 항목}}'**
  String dragOutItemCount(int count);

  /// No description provided for @dragOutStillPreparing.
  ///
  /// In ko, this message translates to:
  /// **'아직 압축을 푸는 중이라 창 밖으로 넘기지 못했습니다. 잠시 뒤 다시 끌어 보세요.'**
  String get dragOutStillPreparing;

  /// No description provided for @dragOutPasswordRequired.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 필요한 항목입니다. 미리보기나 해제로 비밀번호를 한 번 입력한 뒤 끌어내 주세요.'**
  String get dragOutPasswordRequired;

  /// No description provided for @dragOutTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'창 밖으로 끌어내기는 {limit} 이하만 지원합니다. 아래 해제 버튼을 사용하세요.'**
  String dragOutTooLarge(String limit);

  /// No description provided for @dragOutFailed.
  ///
  /// In ko, this message translates to:
  /// **'끌어내기를 준비하지 못했습니다: {error}'**
  String dragOutFailed(String error);

  /// No description provided for @columnName.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get columnName;

  /// No description provided for @columnSize.
  ///
  /// In ko, this message translates to:
  /// **'크기'**
  String get columnSize;

  /// No description provided for @columnCompressedSize.
  ///
  /// In ko, this message translates to:
  /// **'압축크기'**
  String get columnCompressedSize;

  /// No description provided for @columnModified.
  ///
  /// In ko, this message translates to:
  /// **'수정일'**
  String get columnModified;

  /// No description provided for @formatWritableTooltip.
  ///
  /// In ko, this message translates to:
  /// **'이 형식은 압축 생성도 지원합니다'**
  String get formatWritableTooltip;

  /// No description provided for @formatReadOnlyTooltip.
  ///
  /// In ko, this message translates to:
  /// **'이 형식은 해제만 가능합니다(생성 불가)'**
  String get formatReadOnlyTooltip;

  /// No description provided for @statusBarItemCount.
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개 항목}}'**
  String statusBarItemCount(int count);

  /// No description provided for @extractHereButton.
  ///
  /// In ko, this message translates to:
  /// **'여기에 압축 해제'**
  String get extractHereButton;

  /// No description provided for @extractSmartButton.
  ///
  /// In ko, this message translates to:
  /// **'알아서 압축 해제'**
  String get extractSmartButton;

  /// No description provided for @extractChooseFolderButton.
  ///
  /// In ko, this message translates to:
  /// **'원하는 곳에...'**
  String get extractChooseFolderButton;

  /// No description provided for @extractHereSelectedButton.
  ///
  /// In ko, this message translates to:
  /// **'선택 항목 여기에 해제'**
  String get extractHereSelectedButton;

  /// No description provided for @extractSmartSelectedButton.
  ///
  /// In ko, this message translates to:
  /// **'선택 항목 알아서 해제'**
  String get extractSmartSelectedButton;

  /// No description provided for @extractChooseFolderSelectedButton.
  ///
  /// In ko, this message translates to:
  /// **'선택 항목 원하는 곳에...'**
  String get extractChooseFolderSelectedButton;

  /// No description provided for @statusBarSelectedCount.
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{{count}개 선택됨 ({size})}}'**
  String statusBarSelectedCount(int count, String size);

  /// No description provided for @clearSelectionTooltip.
  ///
  /// In ko, this message translates to:
  /// **'선택 해제'**
  String get clearSelectionTooltip;

  /// No description provided for @conflictTitle.
  ///
  /// In ko, this message translates to:
  /// **'이미 같은 이름의 파일이 있습니다'**
  String get conflictTitle;

  /// No description provided for @conflictSourceLabel.
  ///
  /// In ko, this message translates to:
  /// **'압축파일 안: {size}'**
  String conflictSourceLabel(String size);

  /// No description provided for @conflictDestinationLabel.
  ///
  /// In ko, this message translates to:
  /// **'기존 파일: {size}'**
  String conflictDestinationLabel(String size);

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @copyButton.
  ///
  /// In ko, this message translates to:
  /// **'복사'**
  String get copyButton;

  /// No description provided for @errorMessageCopied.
  ///
  /// In ko, this message translates to:
  /// **'오류 메시지를 복사했습니다'**
  String get errorMessageCopied;

  /// No description provided for @skipAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 건너뛰기'**
  String get skipAll;

  /// No description provided for @skip.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get skip;

  /// No description provided for @renameAndExtract.
  ///
  /// In ko, this message translates to:
  /// **'이름 바꿔서 풀기'**
  String get renameAndExtract;

  /// No description provided for @overwriteAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 덮어쓰기'**
  String get overwriteAll;

  /// No description provided for @overwrite.
  ///
  /// In ko, this message translates to:
  /// **'덮어쓰기'**
  String get overwrite;

  /// No description provided for @extractingTitle.
  ///
  /// In ko, this message translates to:
  /// **'압축 해제 중...'**
  String get extractingTitle;

  /// No description provided for @compressingTitle.
  ///
  /// In ko, this message translates to:
  /// **'압축 생성 중...'**
  String get compressingTitle;

  /// No description provided for @preparing.
  ///
  /// In ko, this message translates to:
  /// **'준비 중...'**
  String get preparing;

  /// No description provided for @progressCount.
  ///
  /// In ko, this message translates to:
  /// **'{done} / {total}'**
  String progressCount(int done, int total);

  /// No description provided for @passwordRequiredTitle.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 필요합니다'**
  String get passwordRequiredTitle;

  /// No description provided for @passwordWrongHint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 틀렸습니다. 다시 시도해 주세요.'**
  String get passwordWrongHint;

  /// No description provided for @passwordHint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get passwordHint;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @newArchiveTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 압축 만들기'**
  String get newArchiveTitle;

  /// No description provided for @compressTargetLabel.
  ///
  /// In ko, this message translates to:
  /// **'대상: {summary}'**
  String compressTargetLabel(String summary);

  /// No description provided for @sourcesSummaryMore.
  ///
  /// In ko, this message translates to:
  /// **'외 {count}개'**
  String sourcesSummaryMore(int count);

  /// No description provided for @sourcesSummaryTotal.
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{({count}개)}}'**
  String sourcesSummaryTotal(int count);

  /// No description provided for @originalSizeLabel.
  ///
  /// In ko, this message translates to:
  /// **'원본 크기: {size}'**
  String originalSizeLabel(String size);

  /// No description provided for @formatLabel.
  ///
  /// In ko, this message translates to:
  /// **'포맷'**
  String get formatLabel;

  /// No description provided for @compressionLevelLabel.
  ///
  /// In ko, this message translates to:
  /// **'압축 레벨'**
  String get compressionLevelLabel;

  /// No description provided for @compressionLevelStore.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get compressionLevelStore;

  /// No description provided for @compressionLevelFast.
  ///
  /// In ko, this message translates to:
  /// **'빠름'**
  String get compressionLevelFast;

  /// No description provided for @compressionLevelNormal.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get compressionLevelNormal;

  /// No description provided for @compressionLevelMax.
  ///
  /// In ko, this message translates to:
  /// **'최대'**
  String get compressionLevelMax;

  /// No description provided for @passwordProtectSupportedFormats.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호로 보호 (ZIP/7Z만 지원)'**
  String get passwordProtectSupportedFormats;

  /// No description provided for @splitArchiveLabel.
  ///
  /// In ko, this message translates to:
  /// **'분할 압축'**
  String get splitArchiveLabel;

  /// No description provided for @splitVolumeSizeHint.
  ///
  /// In ko, this message translates to:
  /// **'볼륨 크기'**
  String get splitVolumeSizeHint;

  /// No description provided for @splitVolumeSizeInvalid.
  ///
  /// In ko, this message translates to:
  /// **'분할 볼륨 크기를 올바르게 입력해 주세요 (1 이상의 정수, MB 단위).'**
  String get splitVolumeSizeInvalid;

  /// No description provided for @splitVolumesCreated.
  ///
  /// In ko, this message translates to:
  /// **'{count, plural, other{ ({count}개 조각으로 분할됨)}}'**
  String splitVolumesCreated(int count);

  /// No description provided for @excludedExtensionsLabel.
  ///
  /// In ko, this message translates to:
  /// **'제외할 확장자'**
  String get excludedExtensionsLabel;

  /// No description provided for @excludedExtensionsHint.
  ///
  /// In ko, this message translates to:
  /// **'쉼표로 구분 (예: tmp, log)'**
  String get excludedExtensionsHint;

  /// No description provided for @followSymlinksLabel.
  ///
  /// In ko, this message translates to:
  /// **'심볼릭 링크 따라가기'**
  String get followSymlinksLabel;

  /// No description provided for @saveLocationLabel.
  ///
  /// In ko, this message translates to:
  /// **'저장 위치: {path}'**
  String saveLocationLabel(String path);

  /// No description provided for @changeButton.
  ///
  /// In ko, this message translates to:
  /// **'변경'**
  String get changeButton;

  /// No description provided for @startCompressButton.
  ///
  /// In ko, this message translates to:
  /// **'압축 시작'**
  String get startCompressButton;

  /// No description provided for @compressCompleted.
  ///
  /// In ko, this message translates to:
  /// **'압축 생성 완료: {path}'**
  String compressCompleted(String path);

  /// No description provided for @compressionRatioLabel.
  ///
  /// In ko, this message translates to:
  /// **' ({original} → {compressed}, {percent}% 감소)'**
  String compressionRatioLabel(String original, String compressed, int percent);

  /// No description provided for @compressFailed.
  ///
  /// In ko, this message translates to:
  /// **'압축 생성 실패: {error}'**
  String compressFailed(String error);

  /// No description provided for @unsupportedFormat.
  ///
  /// In ko, this message translates to:
  /// **'이 형식은 아직 미리보기를 지원하지 않습니다'**
  String get unsupportedFormat;

  /// No description provided for @openWithDefaultAppButton.
  ///
  /// In ko, this message translates to:
  /// **'OS 기본 앱으로 열기'**
  String get openWithDefaultAppButton;

  /// No description provided for @imageLoadError.
  ///
  /// In ko, this message translates to:
  /// **'이미지를 열지 못했습니다: {error}'**
  String imageLoadError(String error);

  /// No description provided for @aboutTooltip.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get aboutTooltip;

  /// No description provided for @aboutMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 정보'**
  String aboutMenuItem(String appName);

  /// No description provided for @aboutTagline.
  ///
  /// In ko, this message translates to:
  /// **'광고 없는 올인원 압축/해제 유틸리티'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In ko, this message translates to:
  /// **'버전 {version} (빌드 {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutDescription.
  ///
  /// In ko, this message translates to:
  /// **'Windows·macOS·Linux를 모두 지원하며, 광고·팝업·인앱결제 유도 없이 압축파일을 풀지 않고 바로 탐색하고 원하는 방식으로 풀고 만들 수 있는 가벼운 압축 유틸리티를 목표로 만들었습니다.'**
  String get aboutDescription;

  /// No description provided for @aboutFeatureBrowse.
  ///
  /// In ko, this message translates to:
  /// **'압축파일을 풀지 않고 탐색·미리보기, 중첩 압축 드릴다운'**
  String get aboutFeatureBrowse;

  /// No description provided for @aboutFeatureExtract.
  ///
  /// In ko, this message translates to:
  /// **'3가지 해제 모드(여기에·알아서·원하는 곳에), 선택 항목만 해제, 손상된 압축파일 부분 해제'**
  String get aboutFeatureExtract;

  /// No description provided for @aboutFeatureCompress.
  ///
  /// In ko, this message translates to:
  /// **'압축 레벨·파일 필터 선택, AES-256 비밀번호(ZIP·7Z), 분할 압축'**
  String get aboutFeatureCompress;

  /// No description provided for @aboutFeatureFormats.
  ///
  /// In ko, this message translates to:
  /// **'ZIP·TAR·GZIP·BZIP2·XZ·7Z 압축/해제, RAR 해제'**
  String get aboutFeatureFormats;

  /// No description provided for @aboutFeatureDragDrop.
  ///
  /// In ko, this message translates to:
  /// **'드래그앤드롭으로 열기·압축하기, Finder/탐색기로 끌어내서 해제'**
  String get aboutFeatureDragDrop;

  /// No description provided for @aboutFeatureLocaleTheme.
  ///
  /// In ko, this message translates to:
  /// **'한국어·영어 다국어 지원, 라이트·다크 테마'**
  String get aboutFeatureLocaleTheme;

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutRepository.
  ///
  /// In ko, this message translates to:
  /// **'GitHub'**
  String get aboutRepository;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
