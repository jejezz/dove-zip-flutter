import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/quick_compress.dart';
import '../../data/format_registry.dart';
import '../../l10n/app_localizations.dart';
import 'quick_compress_format_provider.dart';

/// 설정의 "압축하기" 구역 — 탐색기·Finder 우클릭 메뉴의 "압축하기"가 창 없이
/// 바로 만들 형식을 고른다 (settings-screen.md §3의 앱 고유 구역).
class QuickCompressSection extends ConsumerWidget {
  const QuickCompressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = ref.watch(quickCompressFormatProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSectionQuickCompress, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(l10n.quickCompressDescription, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        DropdownMenu(
          initialSelection: format,
          // initialSelection은 처음 한 번만 읽힌다 — 저장된 값을 늦게 읽어 오면 다시 그린다.
          key: ValueKey(format),
          label: Text(l10n.formatLabel),
          onSelected: (value) {
            if (value != null) ref.read(quickCompressFormatProvider.notifier).select(value);
          },
          dropdownMenuEntries: [
            for (final f in quickCompressFormats)
              DropdownMenuEntry(value: f, label: FormatRegistry.of(f).displayName),
          ],
        ),
      ],
    );
  }
}
