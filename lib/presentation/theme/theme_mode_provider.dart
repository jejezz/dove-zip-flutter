import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// 테마 토글 버튼이 순환시키는 순서: 시스템 따라가기 → 라이트 강제 →
/// 다크 강제 → (다시) 시스템 따라가기. daylight-commander-flutter와 동일.
const _cycleOrder = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, state.name);
  }

  Future<void> cycle() async {
    final next = _cycleOrder[(_cycleOrder.indexOf(state) + 1) % _cycleOrder.length];
    state = next;
    await _persist();
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
