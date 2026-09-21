import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'recent_archives';
const _maxEntries = 10;

/// 최근 연 압축파일 경로 목록, 최신순 (PLAN.md 1.4 P1).
class RecentArchivesController extends StateNotifier<List<String>> {
  RecentArchivesController() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? const [];
  }

  Future<void> addRecent(String path) async {
    final updated = [path, ...state.where((p) => p != path)];
    state = updated.length > _maxEntries ? updated.sublist(0, _maxEntries) : updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }

  Future<void> remove(String path) async {
    state = state.where((p) => p != path).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }
}

final recentArchivesProvider =
    StateNotifierProvider<RecentArchivesController, List<String>>(
  (ref) => RecentArchivesController(),
);
