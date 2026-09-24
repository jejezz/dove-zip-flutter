import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'about_dialog.dart';

/// Dove Zip의 정보 창 — 공통 정보 창(about_dialog.dart)에 이 앱의 소개·기능
/// 문구만 넘긴다. 공통 파일은 템플릿과 같게 두고 앱 고유 내용은 여기에 둔다
/// (conventions/about-dialog.md §3).
Future<void> showDoveZipAbout(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAppAboutDialog(
    context,
    tagline: l10n.aboutTagline,
    description: l10n.aboutDescription,
    features: [
      l10n.aboutFeatureBrowse,
      l10n.aboutFeatureExtract,
      l10n.aboutFeatureCompress,
      l10n.aboutFeatureFormats,
      l10n.aboutFeatureDragDrop,
      l10n.aboutFeatureLocaleTheme,
    ],
  );
}
