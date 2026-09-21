// daylight-commander-flutter의 lib/core/bytes_format.dart를 그대로 이식.
const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

String formatBytes(int? bytes) {
  if (bytes == null) return '--';
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < _units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final decimals = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${_units[unitIndex]}';
}
