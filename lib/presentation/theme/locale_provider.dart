import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'locale';

/// 언어 토글 버튼이 순환시키는 순서: 시스템 따라가기 → 한국어 → 영어 →
/// (다시) 시스템 따라가기. `null`은 "시스템 설정을 따름"을 뜻한다 —
/// daylight-commander-flutter의 `LocaleController`와 동일한 패턴
/// (`theme_mode_provider.dart`가 이미 본뜬 것과 같은 구조).
const _cycleOrder = <Locale?>[null, Locale('ko'), Locale('en')];

class LocaleController extends StateNotifier<Locale?> {
  LocaleController() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    state = _cycleOrder.firstWhere(
      (locale) => locale?.languageCode == saved,
      orElse: () => null,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final code = state?.languageCode;
    if (code == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, code);
    }
  }

  Future<void> cycle() async {
    final currentIndex = _cycleOrder.indexWhere(
      (locale) => locale?.languageCode == state?.languageCode,
    );
    state = _cycleOrder[(currentIndex + 1) % _cycleOrder.length];
    await _persist();
  }
}

final localeProvider = StateNotifierProvider<LocaleController, Locale?>(
  (ref) => LocaleController(),
);
