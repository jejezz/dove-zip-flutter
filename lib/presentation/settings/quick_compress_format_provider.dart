import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/quick_compress.dart';
import '../../domain/entities/archive_entry.dart';

const quickCompressFormatKey = 'quick_compress_format';

/// 우클릭 메뉴 "압축하기"의 형식(설정의 "압축하기" 구역). enum 이름 문자열로
/// 저장한다 — `last_extract_mode_provider.dart`와 같은 방식.
class QuickCompressFormatController extends StateNotifier<ArchiveFormat> {
  QuickCompressFormatController() : super(defaultQuickCompressFormat) {
    _load();
  }

  /// 저장된 형식. 우클릭 메뉴로 막 실행된 프로세스는 provider가 비동기로
  /// 읽기를 마칠 때까지 기다릴 수 없어 이것을 직접 부른다.
  static Future<ArchiveFormat> read() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(quickCompressFormatKey);
    return quickCompressFormats.firstWhere((f) => f.name == saved, orElse: () => defaultQuickCompressFormat);
  }

  Future<void> _load() async {
    final format = await read();
    if (mounted) state = format;
  }

  Future<void> select(ArchiveFormat format) async {
    if (!quickCompressFormats.contains(format)) {
      throw ArgumentError.value(format, 'format', 'not a quick-compress format');
    }
    state = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(quickCompressFormatKey, format.name);
  }
}

final quickCompressFormatProvider = StateNotifierProvider<QuickCompressFormatController, ArchiveFormat>(
  (ref) => QuickCompressFormatController(),
);
