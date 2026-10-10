// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dove Zip';

  @override
  String get themeMenuTooltip => 'Theme';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystem => 'System / 시스템 설정 따르기';

  @override
  String get languageSystemShort => 'System';

  @override
  String get homeDropHint => 'Drag an archive here\nor click to open';

  @override
  String get openButton => 'Open';

  @override
  String get createArchiveButton => 'New Archive';

  @override
  String get pickFilesMenuItem => 'Pick Files...';

  @override
  String get pickFolderMenuItem => 'Pick Folder...';

  @override
  String openArchiveFailed(String error) {
    return 'Couldn\'t open the archive: $error';
  }

  @override
  String get recentArchivesTitle => 'Recent Archives';

  @override
  String get removeFromRecentTooltip => 'Remove from list';

  @override
  String get archiveFileTypeGroupLabel => 'Archives';

  @override
  String get anyFileTypeGroupLabel =>
      'All Files (for picking a split volume part)';

  @override
  String get parentFolderTooltip => 'Parent folder';

  @override
  String get closeTooltip => 'Close';

  @override
  String get filenameEncodingTooltip => 'Filename encoding';

  @override
  String get filenameEncodingAuto => 'Auto-detect';

  @override
  String get filenameEncodingUtf8 => 'UTF-8';

  @override
  String get filenameEncodingCp949 => 'Korean (CP949)';

  @override
  String get searchTooltip => 'Search';

  @override
  String get closeSearchTooltip => 'Close search';

  @override
  String get searchHint => 'Search in this folder';

  @override
  String get emptyFolder => 'This folder is empty';

  @override
  String previewFailed(String error) {
    return 'Couldn\'t open the preview: $error';
  }

  @override
  String extractCompleted(String path) {
    return 'Extraction complete: $path';
  }

  @override
  String extractCompletedWithFailures(String path, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items were skipped as damaged',
      one: '$count item was skipped as damaged',
    );
    return 'Extraction complete: $path\n($_temp0)';
  }

  @override
  String get extractCancelled => 'Extraction cancelled.';

  @override
  String extractFailed(String error) {
    return 'Extraction failed: $error';
  }

  @override
  String dragOutItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get dragOutStillPreparing =>
      'Still extracting, so the items couldn\'t leave the window yet. Try dragging again in a moment.';

  @override
  String get dragOutPasswordRequired =>
      'These items need a password. Enter it once by previewing or extracting, then drag them out.';

  @override
  String dragOutTooLarge(String limit) {
    return 'Dragging out of the window supports up to $limit. Use the extract buttons below instead.';
  }

  @override
  String dragOutFailed(String error) {
    return 'Couldn\'t prepare the drag: $error';
  }

  @override
  String get columnName => 'Name';

  @override
  String get columnSize => 'Size';

  @override
  String get columnCompressedSize => 'Compressed';

  @override
  String get columnModified => 'Modified';

  @override
  String get formatWritableTooltip =>
      'This format also supports creating archives';

  @override
  String get formatReadOnlyTooltip =>
      'This format can only be extracted (not created)';

  @override
  String statusBarItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get extractHereButton => 'Extract Here';

  @override
  String get extractSmartButton => 'Smart Extract';

  @override
  String get extractChooseFolderButton => 'Choose Location...';

  @override
  String get extractHereSelectedButton => 'Extract Selected Here';

  @override
  String get extractSmartSelectedButton => 'Extract Selected (Smart)';

  @override
  String get extractChooseFolderSelectedButton => 'Extract Selected To...';

  @override
  String statusBarSelectedCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected ($size)',
      one: '$count selected ($size)',
    );
    return '$_temp0';
  }

  @override
  String get clearSelectionTooltip => 'Clear selection';

  @override
  String get conflictTitle => 'A file with the same name already exists';

  @override
  String conflictSourceLabel(String size) {
    return 'In archive: $size';
  }

  @override
  String conflictDestinationLabel(String size) {
    return 'Existing file: $size';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get copyButton => 'Copy';

  @override
  String get errorMessageCopied => 'Copied the error message';

  @override
  String get skipAll => 'Skip All';

  @override
  String get skip => 'Skip';

  @override
  String get renameAndExtract => 'Rename and Extract';

  @override
  String get overwriteAll => 'Overwrite All';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get extractingTitle => 'Extracting...';

  @override
  String get compressingTitle => 'Compressing...';

  @override
  String get preparing => 'Preparing...';

  @override
  String progressCount(int done, int total) {
    return '$done / $total';
  }

  @override
  String get passwordRequiredTitle => 'Password Required';

  @override
  String get passwordWrongHint => 'Incorrect password. Please try again.';

  @override
  String get passwordHint => 'Password';

  @override
  String get confirm => 'OK';

  @override
  String get newArchiveTitle => 'New Archive';

  @override
  String compressTargetLabel(String summary) {
    return 'Target: $summary';
  }

  @override
  String sourcesSummaryMore(int count) {
    return 'and $count more';
  }

  @override
  String sourcesSummaryTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count items)',
      one: '($count item)',
    );
    return '$_temp0';
  }

  @override
  String originalSizeLabel(String size) {
    return 'Original size: $size';
  }

  @override
  String get formatLabel => 'Format';

  @override
  String get compressionLevelLabel => 'Compression Level';

  @override
  String get compressionLevelStore => 'Store';

  @override
  String get compressionLevelFast => 'Fast';

  @override
  String get compressionLevelNormal => 'Normal';

  @override
  String get compressionLevelMax => 'Maximum';

  @override
  String get passwordProtectSupportedFormats =>
      'Password protect (ZIP/7Z only)';

  @override
  String get splitArchiveLabel => 'Split into volumes';

  @override
  String get splitVolumeSizeHint => 'Volume size';

  @override
  String get splitVolumeSizeInvalid =>
      'Enter a valid volume size (a positive whole number, in MB).';

  @override
  String splitVolumesCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' (split into $count parts)',
      one: ' (split into 1 part)',
    );
    return '$_temp0';
  }

  @override
  String get excludedExtensionsLabel => 'Exclude extensions';

  @override
  String get excludedExtensionsHint => 'Comma-separated (e.g. tmp, log)';

  @override
  String get followSymlinksLabel => 'Follow symbolic links';

  @override
  String saveLocationLabel(String path) {
    return 'Save to: $path';
  }

  @override
  String get changeButton => 'Change';

  @override
  String get startCompressButton => 'Start';

  @override
  String compressCompleted(String path) {
    return 'Archive created: $path';
  }

  @override
  String compressionRatioLabel(
    String original,
    String compressed,
    int percent,
  ) {
    return ' ($original → $compressed, $percent% smaller)';
  }

  @override
  String compressFailed(String error) {
    return 'Failed to create archive: $error';
  }

  @override
  String get unsupportedFormat =>
      'Preview isn\'t supported for this format yet';

  @override
  String get openWithDefaultAppButton => 'Open with Default App';

  @override
  String imageLoadError(String error) {
    return 'Couldn\'t load the image: $error';
  }

  @override
  String get windowMenuTooltip => 'Window placement';

  @override
  String get menuSnapRight => 'Snap to right edge';

  @override
  String get menuSnapLeft => 'Snap to left edge';

  @override
  String get alwaysOnTopOnTooltip => 'Keep on top';

  @override
  String get alwaysOnTopOffTooltip => 'Stop keeping on top';

  @override
  String get aboutTooltip => 'About';

  @override
  String aboutMenuItem(String appName) {
    return 'About $appName';
  }

  @override
  String get aboutTagline => 'An ad-free, all-in-one archive utility';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutDescription =>
      'Built for Windows, macOS, and Linux, it aims to be a lightweight archive utility with no ads, pop-ups, or in-app purchase nags — browse archives without extracting them, then extract or create them exactly the way you want.';

  @override
  String get aboutFeatureBrowse =>
      'Browse and preview archives without extracting, drill into nested archives';

  @override
  String get aboutFeatureExtract =>
      'Three extract modes (here, smart, choose location), extract selected items only, partial extraction of damaged archives';

  @override
  String get aboutFeatureCompress =>
      'Compression levels and file filters, AES-256 passwords (ZIP, 7Z), split archives';

  @override
  String get aboutFeatureFormats =>
      'Create and extract ZIP, TAR, GZIP, BZIP2, XZ, and 7Z; extract RAR';

  @override
  String get aboutFeatureDragDrop =>
      'Drag and drop to open or compress, drag items out to Finder/Explorer to extract';

  @override
  String get aboutFeatureLocaleTheme =>
      'Korean and English localization, light and dark themes';

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => 'Close';

  @override
  String get errorCancelled => 'The operation was cancelled.';

  @override
  String errorUnsupportedFormat(String fileName) {
    return 'Unknown or not yet supported archive format: $fileName';
  }

  @override
  String errorPasswordRequired(String entryPath) {
    return '\"$entryPath\" needs a password, or the password is wrong.';
  }

  @override
  String errorSplitVolumeMissing(int index, String fileName) {
    return 'A split volume is missing (part $index not found): $fileName';
  }

  @override
  String errorSplitVolumesNotFound(String fileName) {
    return 'Couldn\'t find the split volumes: $fileName';
  }

  @override
  String errorSingleFileFormatMultiple(String format) {
    return '$format can compress only a single file — bundle folders or multiple items into tar.gz or similar first.';
  }

  @override
  String errorSingleFileFormatFolder(String format) {
    return '$format can\'t compress a folder — use tar.gz or similar.';
  }

  @override
  String errorTargetExists(String name) {
    return 'An item with the same name already exists: $name';
  }

  @override
  String get updateCheckMenuItem => 'Check for Updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest is available. You have $current.';
  }

  @override
  String get updateReleaseNotes => 'What\'s new';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Verifying the file…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateFailedTitle => 'Couldn\'t update';

  @override
  String get updateCheckFailedTitle => 'Couldn\'t check for updates';

  @override
  String get updateErrorNetwork =>
      'Couldn\'t reach the update server. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The downloaded file didn\'t pass verification, so it was not installed. Please try again later.';

  @override
  String get updateErrorInstall => 'Couldn\'t start the installation.';

  @override
  String get updateErrorGeneric =>
      'The update server sent an unexpected response. Please try again later.';

  @override
  String get updateUpToDateTitle => 'You\'re up to date';

  @override
  String updateUpToDateBody(String version) {
    return 'You\'re using version $version.';
  }

  @override
  String get updateUnavailableTitle => 'Install it manually';

  @override
  String updateUnavailableBody(String latest) {
    return 'Version $latest is available, but the app can\'t install it automatically. Please download it from the release page.';
  }

  @override
  String get updateOpenReleasePage => 'Open release page';

  @override
  String get updateMacosOpenedTitle => 'The installer window is open';

  @override
  String updateMacosOpenedBody(String appName) {
    return 'In the window that opened, drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateWindowsInstallTitle => 'The installer is open';

  @override
  String updateWindowsInstallBody(String appName) {
    return '$appName must quit before it can be updated. Follow the installer\'s instructions.';
  }

  @override
  String updateQuitApp(String appName) {
    return 'Quit $appName';
  }

  @override
  String get updateLinuxInstallTitle => 'Ready to install';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName will quit and install the update, then start again automatically.';
  }

  @override
  String get updateQuitAndInstall => 'Quit and install';
}
