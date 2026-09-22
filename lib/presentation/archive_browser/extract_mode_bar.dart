import 'package:flutter/material.dart';

import '../../domain/entities/extract_destination_mode.dart';
import '../../l10n/app_localizations.dart';

String _label(
  AppLocalizations l10n,
  ExtractDestinationMode mode,
  bool hasSelection,
) {
  if (hasSelection) {
    return switch (mode) {
      ExtractDestinationMode.here => l10n.extractHereSelectedButton,
      ExtractDestinationMode.smart => l10n.extractSmartSelectedButton,
      ExtractDestinationMode.chooseFolder =>
        l10n.extractChooseFolderSelectedButton,
    };
  }
  return switch (mode) {
    ExtractDestinationMode.here => l10n.extractHereButton,
    ExtractDestinationMode.smart => l10n.extractSmartButton,
    ExtractDestinationMode.chooseFolder => l10n.extractChooseFolderButton,
  };
}

/// 압축 해제 위치 3가지 모드 버튼 (UI_UX.md 7장) — 이 앱의 핵심 편의 기능.
///
/// 셋 다 동급으로 항상 노출하되, [highlightedMode](기본값
/// [ExtractDestinationMode.smart], PLAN.md 1.2 P1 — 마지막으로 고른 모드를
/// 기억해 다음에도 강조)만 Filled(Primary)로 시각적 강조를 준다. 버튼을
/// 누르면 클릭 즉시 실행되고(추가 확인 다이얼로그 없음), "원하는 곳에"만
/// 폴더 선택 다이얼로그가 먼저 뜬다 — 그 처리는 이 위젯이 아니라 호출하는
/// 화면(`onSelectMode`)의 몫이다.
///
/// [hasSelection]이 true면(PLAN.md 1.2 "선택 항목만 해제") 라벨이 "선택
/// 항목 ..."으로 바뀌어 전체 해제와 구분된다 — 실제로 선택된 항목만
/// 골라내는 로직은 호출하는 화면(`ArchiveBrowserScreen`)의 몫이다.
class ExtractModeBar extends StatelessWidget {
  const ExtractModeBar({
    super.key,
    required this.onSelectMode,
    this.enabled = true,
    this.highlightedMode = ExtractDestinationMode.smart,
    this.hasSelection = false,
  });

  final ValueChanged<ExtractDestinationMode> onSelectMode;
  final bool enabled;
  final ExtractDestinationMode highlightedMode;
  final bool hasSelection;

  Widget _button(BuildContext context, ExtractDestinationMode mode) {
    final onPressed = enabled ? () => onSelectMode(mode) : null;
    final label = Text(
      _label(AppLocalizations.of(context), mode, hasSelection),
      overflow: TextOverflow.ellipsis,
    );
    // 셋 다 항상 같은 너비로 "동급"으로 노출한다(UI_UX.md 7장) — 강조는
    // Filled(Primary)/Outlined 스타일 차이만으로 표현한다. 예전엔 강조된
    // 버튼에 flex: 2를 줘서 더 넓게 그렸는데, 마지막 선택 모드가 바뀔
    // 때마다(`highlightedMode`, PLAN.md 1.2 P1) 버튼 폭이 눈에 띄게
    // 들썩여서 없앴다.
    return Expanded(
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
