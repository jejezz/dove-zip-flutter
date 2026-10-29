import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'settings_menus.dart';

/// 설정 대화상자: 데스크톱 전용 앱이라 모달로 띄운다 (settings-screen.md §1).
Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.settingsTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.settingsSectionAppearance, style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              Text(l10n.settingsMode, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              const ModeSegmentedButton(),
              const SizedBox(height: 16),
              Text(l10n.settingsPalette, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              const AccentPaletteChips(),
              const SizedBox(height: 16),
              Text(l10n.languageMenuTooltip, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              const LanguageSegmentedButton(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
      ],
    );
  }
}
