import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/system_default_app_registrar.dart';
import '../../domain/repositories/default_app_registrar.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/error_message.dart';

/// 이 플랫폼의 기본 앱 등록기. 테스트는 이 provider를 바꿔 끼운다.
final defaultAppRegistrarProvider = Provider<DefaultAppRegistrar?>((ref) => platformDefaultAppRegistrar());

/// 설정의 "기본 앱" 구역 — "외형" 다음의 앱 고유 구역 (settings-screen.md §3).
/// 단추 하나로 압축파일의 기본 앱을 Dove Zip으로 정한다. Windows는 OS가 막아
/// 설정 앱의 Dove Zip 페이지를 열고, 사용자가 따라 할 단계와 눌러서 복사하는
/// 파일 형식 목록을 함께 보여 준다.
class DefaultAppSection extends ConsumerStatefulWidget {
  const DefaultAppSection({super.key});

  @override
  ConsumerState<DefaultAppSection> createState() => _DefaultAppSectionState();
}

class _DefaultAppSectionState extends ConsumerState<DefaultAppSection> {
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;

  Future<void> _makeDefault(DefaultAppRegistrar registrar) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _status = null;
    });
    String? status;
    var isError = false;
    try {
      await registrar.makeDefault();
      if (!registrar.opensSystemSettings) status = l10n.defaultAppDone;
    } catch (error) {
      status = describeError(l10n, error);
      isError = true;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status;
      _statusIsError = isError;
    });
  }

  Future<void> _copyFileType(String fileType) async {
    final message = AppLocalizations.of(context).defaultAppCopied(fileType);
    await Clipboard.setData(ClipboardData(text: fileType));
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusIsError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registrar = ref.watch(defaultAppRegistrarProvider);
    if (registrar == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = _status;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSectionDefaultApp, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          registrar.opensSystemSettings ? l10n.defaultAppDescriptionWindows : l10n.defaultAppDescription,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _makeDefault(registrar),
          icon: Icon(registrar.opensSystemSettings ? Icons.open_in_new_rounded : Icons.check_circle_outline_rounded),
          label: Text(registrar.opensSystemSettings ? l10n.defaultAppOpenSettingsButton : l10n.defaultAppSetButton),
        ),
        if (registrar.opensSystemSettings) ...[const SizedBox(height: 16), _WindowsGuide(onCopy: _copyFileType)],
        if (status != null) ...[
          const SizedBox(height: 8),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _statusIsError ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Windows에서 사용자가 설정 앱에서 할 일. 설치 프로그램이 Dove Zip을 후보로
/// 등록해 두었으므로(installer/windows/app.iss), 최신 Windows 11은 Dove Zip
/// 페이지의 "기본값 설정" 한 번으로 끝나고, 그 단추가 없는 Windows는 형식마다
/// 검색해서 고른다. 형식은 칩을 눌러 복사한다.
class _WindowsGuide extends StatelessWidget {
  const _WindowsGuide({required this.onCopy});

  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = [
      l10n.defaultAppWindowsStep1,
      l10n.defaultAppWindowsStep2,
      l10n.defaultAppWindowsStep3,
      l10n.defaultAppWindowsStep4,
      l10n.defaultAppWindowsStep5,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20, child: Text('${index + 1}.', style: theme.textTheme.bodySmall)),
                Expanded(child: Text(step, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(l10n.defaultAppFileTypesLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final ext in associatedExtensions)
              ActionChip(
                avatar: const Icon(Icons.content_copy_rounded, size: 14),
                label: Text('.$ext'),
                tooltip: l10n.defaultAppCopyTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: () => onCopy('.$ext'),
              ),
          ],
        ),
      ],
    );
  }
}
