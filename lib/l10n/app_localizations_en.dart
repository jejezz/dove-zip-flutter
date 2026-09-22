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
  String themeToggleTooltip(String mode) {
    return 'Switch theme ($mode)';
  }

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String languageToggleTooltip(String mode) {
    return 'Switch language ($mode)';
  }

  @override
  String get languageModeSystem => 'System';

  @override
  String get languageModeKorean => 'Korean';

  @override
  String get languageModeEnglish => 'English';

  @override
  String get homeDropHint => 'Drag an archive here\nor click to open';

  @override
  String get openButton => 'Open';

  @override
  String get createArchiveButton => 'New Archive';

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
  String get extractCancelled => 'Extraction cancelled.';

  @override
  String extractFailed(String error) {
    return 'Extraction failed: $error';
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
}
