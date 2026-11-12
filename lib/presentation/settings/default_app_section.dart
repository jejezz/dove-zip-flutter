import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/system_default_app_registrar.dart';
import '../../domain/repositories/default_app_registrar.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/error_message.dart';

/// 이 플랫폼의 기본 앱 등록기. 테스트는 이 provider를 바꿔 끼운다.
final defaultAppRegistrarProvider = Provider<DefaultAppRegistrar?>((ref) => platformDefaultAppRegistrar());

/// 설정의 "기본 앱" 구역 — "외형" 다음의 앱 고유 구역 (settings-screen.md §3).
/// 단추 하나로 압축파일의 기본 앱을 Dove Zip으로 정한다. Windows는 OS가 막아
/// 설정 앱의 Dove Zip 페이지를 연다.
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
