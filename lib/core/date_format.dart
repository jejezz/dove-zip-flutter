// daylight-commander-flutter의 lib/core/date_format.dart를 그대로 이식.
String formatModified(DateTime? dt) {
  if (dt == null) return '--';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}
