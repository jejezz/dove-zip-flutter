import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_identity.dart';
import '../../l10n/app_localizations.dart';

/// 화면 왼쪽·오른쪽에 세워 두는 세로 창 (UI_UX.md 9장) — Branch Dock과 같은
/// 창 규칙이라 Finder·탐색기·편집기 옆에 나란히 두고 파일을 주고받는다.
/// flutter test와 모바일에는 창이 없다 — 창 메뉴는 데스크톱에서만 보인다.
final bool hasDockWindow = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

const dockDefaultSize = Size(440, 960);
const dockMinimumSize = Size(380, 560);
const _dockWidth = 440.0;
const _boundsKey = 'window_bounds';

/// 창을 띄운다: 저장해 둔 크기·위치가 있으면 되살리고, 없으면 화면 가운데에
/// 기본 크기로 연다. 화면이 기본 높이보다 낮으면 작업 영역 높이에 맞춘다.
Future<void> showDockWindow() async {
  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = _readBounds(prefs);
  const options = WindowOptions(
    size: dockDefaultSize,
    minimumSize: dockMinimumSize,
    title: AppIdentity.displayName,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    if (saved != null && saved.width >= dockMinimumSize.width && saved.height >= dockMinimumSize.height) {
      await windowManager.setBounds(saved);
    } else {
      final area = await _workArea();
      if (area.height < dockDefaultSize.height) {
        await windowManager.setSize(Size(dockDefaultSize.width, area.height));
      }
      await windowManager.center();
    }
    await windowManager.show();
    await windowManager.focus();
  });
  windowManager.addListener(_BoundsSaver(prefs));
}

/// 창이 있는 화면의 오른쪽·왼쪽 가장자리에 붙인다 — 작업 영역 높이 전체, 폭 440.
Future<void> snapDockWindow({required bool right}) async {
  final area = await _workArea();
  await windowManager.setBounds(
    Rect.fromLTWH(right ? area.right - _dockWidth : area.left, area.top, _dockWidth, area.height),
  );
}

/// 창 가운데가 걸친 화면의 작업 영역(메뉴 막대·Dock·작업 표시줄 제외).
Future<Rect> _workArea() async {
  final center = (await windowManager.getBounds()).center;
  final displays = await screenRetriever.getAllDisplays();
  Rect areaOf(Display d) => (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
  for (final d in displays) {
    if (areaOf(d).contains(center)) return areaOf(d);
  }
  return areaOf(await screenRetriever.getPrimaryDisplay());
}

Rect? _readBounds(SharedPreferences prefs) {
  final v = prefs.getStringList(_boundsKey);
  if (v == null || v.length != 4) return null;
  final n = v.map(double.tryParse).toList();
  if (n.contains(null)) return null;
  return Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!);
}

/// 창을 옮기거나 크기를 바꾸면 잠시 뒤 저장한다.
class _BoundsSaver with WindowListener {
  _BoundsSaver(this.prefs);

  final SharedPreferences prefs;
  Timer? _timer;

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () async {
      final r = await windowManager.getBounds();
      await prefs.setStringList(
        _boundsKey,
        [r.left, r.top, r.width, r.height].map((d) => d.toStringAsFixed(0)).toList(),
      );
    });
  }

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMoved() => _schedule();
}

enum _DockAction { snapRight, snapLeft }

/// 앱 바의 창 메뉴: 오른쪽·왼쪽에 붙이기.
class DockMenuButton extends StatelessWidget {
  const DockMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_DockAction>(
      tooltip: l10n.windowMenuTooltip,
      icon: const Icon(Icons.view_sidebar_outlined),
      position: PopupMenuPosition.under,
      onSelected: (action) => snapDockWindow(right: action == _DockAction.snapRight),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _DockAction.snapRight,
          child: Text(l10n.menuSnapRight),
        ),
        PopupMenuItem(
          value: _DockAction.snapLeft,
          child: Text(l10n.menuSnapLeft),
        ),
      ],
    );
  }
}

/// 창 하나를 여러 화면(홈, 압축 목록)이 공유하므로 항상 위 상태도 하나만 둔다.
final _alwaysOnTop = ValueNotifier(false);

/// 앱 바의 항상 위에 표시 토글 — 켜면 핀이 채워진다 (Branch Dock과 같은 모양).
class AlwaysOnTopButton extends StatelessWidget {
  const AlwaysOnTopButton({super.key});

  Future<void> _toggle() async {
    final pinned = !_alwaysOnTop.value;
    await windowManager.setAlwaysOnTop(pinned);
    _alwaysOnTop.value = pinned;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: _alwaysOnTop,
      builder: (context, pinned, _) => IconButton(
        tooltip: pinned ? l10n.alwaysOnTopOffTooltip : l10n.alwaysOnTopOnTooltip,
        isSelected: pinned,
        icon: const Icon(Icons.push_pin_outlined),
        selectedIcon: const Icon(Icons.push_pin),
        onPressed: _toggle,
      ),
    );
  }
}
