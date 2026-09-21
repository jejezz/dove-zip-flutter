import 'package:flutter/material.dart';

import '../../domain/entities/extract_destination_mode.dart';
import '../../l10n/app_localizations.dart';

String _label(AppLocalizations l10n, ExtractDestinationMode mode) => switch (mode) {
      ExtractDestinationMode.here => l10n.extractHereButton,
      ExtractDestinationMode.smart => l10n.extractSmartButton,
      ExtractDestinationMode.chooseFolder => l10n.extractChooseFolderButton,
    };

/// 압축 해제 위치 3가지 모드 버튼 (UI_UX.md 7장) — 이 앱의 핵심 편의 기능.
///
/// 셋 다 동급으로 항상 노출하되, [highlightedMode](기본값
/// [ExtractDestinationMode.smart], PLAN.md 1.2 P1 — 마지막으로 고른 모드를
/// 기억해 다음에도 강조)만 Filled(Primary)로 시각적 강조를 준다. 버튼을
/// 누르면 클릭 즉시 실행되고(추가 확인 다이얼로그 없음), "원하는 곳에"만
/// 폴더 선택 다이얼로그가 먼저 뜬다 — 그 처리는 이 위젯이 아니라 호출하는
/// 화면(`onSelectMode`)의 몫이다.
class ExtractModeBar extends StatelessWidget {
  const ExtractModeBar({
    super.key,
    required this.onSelectMode,
    this.enabled = true,
    this.highlightedMode = ExtractDestinationMode.smart,
  });

  final ValueChanged<ExtractDestinationMode> onSelectMode;
  final bool enabled;
  final ExtractDestinationMode highlightedMode;

  Widget _button(BuildContext context, ExtractDestinationMode mode) {
    final onPressed = enabled ? () => onSelectMode(mode) : null;
    final label = Text(_label(AppLocalizations.of(context), mode));
    return Expanded(
      flex: mode == highlightedMode ? 2 : 1,
      child: mode == highlightedMode
          ? FilledButton(onPressed: onPressed, child: label)
          : OutlinedButton(onPressed: onPressed, child: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _button(context, ExtractDestinationMode.here),
            const SizedBox(width: 8),
            _button(context, ExtractDestinationMode.smart),
            const SizedBox(width: 8),
            _button(context, ExtractDestinationMode.chooseFolder),
          ],
        ),
      ),
    );
  }
}
