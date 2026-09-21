import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/extract_destination_mode.dart';

const _prefsKey = 'last_extract_mode';

/// 마지막으로 고른 압축 해제 모드를 기억한다 (PLAN.md 1.2 P1). 기본값은
/// [ExtractDestinationMode.smart] — daylight의 `themeModeProvider`와 같은
/// 패턴(`shared_preferences`에 enum 이름 문자열로 저장).
class LastExtractModeController extends StateNotifier<ExtractDestinationMode> {
  LastExtractModeController() : super(ExtractDestinationMode.smart) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    state = ExtractDestinationMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ExtractDestinationMode.smart,
    );
  }

  Future<void> remember(ExtractDestinationMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final lastExtractModeProvider =
    StateNotifierProvider<LastExtractModeController, ExtractDestinationMode>(
  (ref) => LastExtractModeController(),
);
