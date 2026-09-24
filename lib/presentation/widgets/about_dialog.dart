import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../application/usecases/open_url.dart';
import '../../l10n/app_localizations.dart';

// daylight-commander-flutter의 lib/presentation/widgets/about_dialog.dart를
// 이식 — 제목 아이콘만 Material 아이콘 대신 실제 앱 아이콘을 쓴다.

const _openUrl = OpenUrl();
const _githubUrl = 'https://github.com/jejezz/dove-zip-flutter';

/// 앱 정보(About) 다이얼로그. 버전은 [PackageInfo]로 실제 빌드에서 읽어와
/// pubspec.yaml과 어긋날 일이 없게 한다.
Future<void> showAboutInfoDialog(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);

  final features = [
    l10n.aboutFeatureBrowse,
    l10n.aboutFeatureExtract,
    l10n.aboutFeatureCompress,
    l10n.aboutFeatureFormats,
    l10n.aboutFeatureDragDrop,
    l10n.aboutFeatureLocaleTheme,
  ];

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Image.asset('assets/images/app_icon.png', width: 32, height: 32),
          const SizedBox(width: 10),
          Flexible(child: Text(l10n.aboutDialogTitle)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.aboutTagline, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                l10n.aboutVersionLabel('${packageInfo.version}+${packageInfo.buildNumber}'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Text(l10n.aboutDescription),
              const SizedBox(height: 16),
              Text(l10n.aboutFeaturesTitle, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final feature in features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(l10n.aboutTechStackLabel, style: Theme.of(context).textTheme.bodySmall),
              Text(l10n.aboutLicenseLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _openUrl(_githubUrl),
          child: Text(l10n.aboutGithubButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}
