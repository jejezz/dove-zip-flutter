import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// 창 크기·위치 — macOS·Linux는 window_manager의 논리 좌표로 저장한다.
const _boundsKey = 'window_bounds';

/// Windows는 물리 픽셀로 저장한다. window_manager는 창이 *지금* 있는 화면의
/// 배율로 좌표를 바꾸므로, 배율이 다른 두 번째 화면에서 닫으면 다음 실행 때
/// 주 화면 배율로 되살아나 창이 엉뚱한 곳(화면 밖)에 놓인다.
/// 물리 픽셀은 runner(windows/runner/flutter_window.cpp)가 읽고 쓴다.
const _physicalBoundsKey = 'window_bounds_px';
const _frameChannel = MethodChannel('dove_zip/window_frame');

/// 창을 띄운다: 저장해 둔 크기·위치가 있으면 되살리고, 없거나 어느 화면에도
/// 걸치지 않으면 화면 가운데에 기본 크기로 연다. 화면이 기본 높이보다 낮으면
/// 작업 영역 높이에 맞춘다.
Future<void> showDockWindow() async {
  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  const options = WindowOptions(
    size: dockDefaultSize,
    minimumSize: dockMinimumSize,
    title: AppIdentity.displayName,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    if (!await _restoreBounds(prefs)) await _centerDockWindow();
    await windowManager.show();
    await windowManager.focus();
  });
  windowManager.addListener(_BoundsSaver(prefs));
}

/// 저장해 둔 크기·위치로 창을 옮긴다. 저장한 적이 없거나 어느 화면에도
/// 걸치지 않으면(그 화면을 뗀 경우 등) false.
Future<bool> _restoreBounds(SharedPreferences prefs) async {
  if (Platform.isWindows) {
    final saved = _readBounds(prefs, _physicalBoundsKey);
    if (saved == null) return false;
    final frame = [saved.left, saved.top, saved.width, saved.height].map((d) => d.round()).toList();
    return await _frameChannel.invokeMethod<bool>('setFrame', frame) ?? false;
  }
  final saved = _readBounds(prefs, _boundsKey);
  if (saved == null || saved.width < dockMinimumSize.width || saved.height < dockMinimumSize.height) {
    return false;
  }
  await windowManager.setBounds(saved);
  return await _areaUnderWindow() != null;
}

Future<void> _saveBounds(SharedPreferences prefs) async {
  final String key;
  final List<num> frame;
  if (Platform.isWindows) {
    final f = await _frameChannel.invokeListMethod<int>('getFrame');
    if (f == null) return;
    (key, frame) = (_physicalBoundsKey, f);
  } else {
    final r = await windowManager.getBounds();
    (key, frame) = (_boundsKey, [r.left, r.top, r.width, r.height]);
  }
  await prefs.setStringList(key, frame.map((d) => d.toStringAsFixed(0)).toList());
}

/// 창이 있는 화면의 작업 영역 가운데에 기본 크기로 둔다.
///
/// windowManager.center()는 쓰지 않는다 — Windows에서 커서가 있는 화면의
/// 좌표(그 화면 배율 기준)를 창이 있는 화면의 배율로 되돌려, 노트북 LCD와
/// 외부 모니터처럼 배율이 다른 화면이 섞이면 창이 화면 밖으로 밀려난다.
/// 창이 있는 화면은 좌표 배율이 창과 같아서 안전하다.
Future<void> _centerDockWindow() async {
  final area = await _workArea();
  final height = area.height < dockDefaultSize.height ? area.height : dockDefaultSize.height;
  await windowManager.setBounds(
    Rect.fromCenter(center: area.center, width: dockDefaultSize.width, height: height),
  );
}

/// 창이 있는 화면의 오른쪽·왼쪽 가장자리에 붙인다 — 작업 영역 높이 전체, 폭 440.
Future<void> snapDockWindow({required bool right}) async {
  final area = await _workArea();
  await windowManager.setBounds(
    Rect.fromLTWH(right ? area.right - _dockWidth : area.left, area.top, _dockWidth, area.height),
  );
  // window_manager는 사용자가 끌어서 옮길 때만 이동 이벤트를 보낸다.
  await _saveBounds(await SharedPreferences.getInstance());
}

/// 창 가운데가 걸친 화면의 작업 영역(메뉴 막대·Dock·작업 표시줄 제외).
/// 어느 화면에도 걸치지 않으면 주 화면의 작업 영역.
Future<Rect> _workArea() async =>
    await _areaUnderWindow() ?? _areaOf(await screenRetriever.getPrimaryDisplay());

/// 창 가운데가 걸친 화면의 작업 영역, 없으면 null.
Future<Rect?> _areaUnderWindow() async {
  final center = (await windowManager.getBounds()).center;
  for (final d in await screenRetriever.getAllDisplays()) {
    if (_areaOf(d).contains(center)) return _areaOf(d);
  }
  return null;
}

Rect _areaOf(Display d) => (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);

Rect? _readBounds(SharedPreferences prefs, String key) {
  final v = prefs.getStringList(key);
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
    _timer = Timer(const Duration(milliseconds: 500), () => _saveBounds(prefs));
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
