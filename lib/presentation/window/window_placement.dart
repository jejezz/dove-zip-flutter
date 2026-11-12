import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_identity.dart';

const windowDefaultSize = Size(1200, 720);
const windowMinimumSize = Size(380, 560);
/// 창 크기·위치 — macOS·Linux는 window_manager의 논리 좌표로 저장한다.
const _boundsKey = 'window_bounds';

/// Windows는 물리 픽셀로 저장한다. window_manager는 창이 *지금* 있는 화면의
/// 배율로 좌표를 바꾸므로, 배율이 다른 두 번째 화면에서 닫으면 다음 실행 때
/// 주 화면 배율로 되살아나 창이 엉뚱한 곳(화면 밖)에 놓인다.
/// 물리 픽셀은 runner(windows/runner/flutter_window.cpp)가 읽고 쓴다.
const _physicalBoundsKey = 'window_bounds_px';
const _frameChannel = MethodChannel('dove_zip/window_frame');

/// 창을 준비한다: 저장해 둔 크기·위치가 있으면 되살리고, 없거나 어느 화면에도
/// 걸치지 않으면 화면 가운데에 기본 크기로 연다. 화면이 기본 높이보다 낮으면
/// 작업 영역 높이에 맞춘다. 돌려주는 함수를 불러야 실제로 창이 보인다 —
/// 첫 프레임이 그려진 뒤에 불러야 깜빡이지 않는다 (window-placement.md §5).
Future<Future<void> Function()> prepareWindow() async {
  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  const options = WindowOptions(
    size: windowDefaultSize,
    minimumSize: windowMinimumSize,
    title: AppIdentity.displayName,
  );
  final placed = Completer<void>();
  await windowManager.waitUntilReadyToShow(options, () async {
    if (!await _restoreBounds(prefs)) await _centerWindow();
    placed.complete();
  });
  return () async {
    await placed.future;
    await _nextFrame();
    await windowManager.show();
    await windowManager.focus();
    windowManager.addListener(_BoundsSaver(prefs));
  };
}

/// 다음 프레임이 그려질 때까지 기다린다.
Future<void> _nextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
  WidgetsBinding.instance.scheduleFrame();
  return completer.future;
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
  if (saved == null || saved.width < windowMinimumSize.width || saved.height < windowMinimumSize.height) {
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
Future<void> _centerWindow() async {
  final area = await _workArea();
  final height = area.height < windowDefaultSize.height ? area.height : windowDefaultSize.height;
  await windowManager.setBounds(
    Rect.fromCenter(center: area.center, width: windowDefaultSize.width, height: height),
  );
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

/// 우클릭 메뉴용 작은 창(진행률·취소, 오류)의 크기.
const quickWindowSize = Size(480, 240);

/// 이름 충돌·비밀번호를 물을 때의 크기 — 충돌 대화상자의 단추 여섯 개가 들어간다.
const quickPromptWindowSize = Size(620, 520);

/// 우클릭 메뉴로 실행됐을 때의 창 — 숨긴 채로 준비만 하고, 크기·위치를
/// 저장하지 않는다. 돌려주는 `show`를 불러야 보인다. 창의 X는 바로 닫지
/// 않고 `closeRequests`로 알린다(작업 중이면 취소부터 하도록). `show(prompt:
/// true)`는 무엇을 묻기 전에 부른다 — 창을 [quickPromptWindowSize]로 키운다.
Future<({Future<void> Function({bool prompt}) show, Stream<void> closeRequests})> prepareQuickWindow() async {
  await windowManager.ensureInitialized();
  final closes = StreamController<void>.broadcast();
  const options = WindowOptions(size: quickWindowSize, minimumSize: quickWindowSize, title: AppIdentity.displayName);
  final placed = Completer<void>();
  await windowManager.waitUntilReadyToShow(options, () async {
    final area = await _workArea();
    await windowManager.setBounds(
      Rect.fromCenter(center: area.center, width: quickWindowSize.width, height: quickWindowSize.height),
    );
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setPreventClose(true);
    windowManager.addListener(_CloseForwarder(closes));
    placed.complete();
  });
  var shown = false;
  var large = false;
  return (
    show: ({bool prompt = false}) async {
      await placed.future;
      if (prompt && !large) {
        large = true;
        final center = (await windowManager.getBounds()).center;
        await windowManager.setMinimumSize(quickPromptWindowSize);
        await windowManager.setBounds(
          Rect.fromCenter(center: center, width: quickPromptWindowSize.width, height: quickPromptWindowSize.height),
        );
      }
      if (shown) return;
      shown = true;
      await _nextFrame();
      await windowManager.show();
      await windowManager.focus();
    },
    closeRequests: closes.stream,
  );
}

class _CloseForwarder with WindowListener {
  _CloseForwarder(this.closes);

  final StreamController<void> closes;

  @override
  void onWindowClose() => closes.add(null);
}
