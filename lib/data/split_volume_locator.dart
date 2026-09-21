import 'dart:io';

import 'package:path/path.dart' as p;

import 'format_registry.dart';

/// [location]과 같은 폴더에서, 같은 논리 압축파일 이름을 공유하는 분할
/// 볼륨 조각을 전부 찾아 번호(1부터) 오름차순으로 정렬해 반환한다.
/// [location] 자신이 실제 존재하는 조각일 필요는 없다 — 압축을 막 끝낸
/// 논리적 목적지 경로("photo.zip", 실제로는 만들어지지 않음)를 넘겨도
/// 디스크의 "photo.zip.001", "photo.zip.002", ... 를 그대로 찾아낸다
/// ([DartArchiveWriter]와 [DartArchiveReader] 양쪽, 그리고 압축 완료 후
/// 결과를 요약하는 `CompressDialog`가 이 하나의 함수를 공유한다).
///
/// 조각을 하나도 못 찾으면 빈 리스트를 반환한다(예외를 던지지 않음 —
/// "애초에 분할이 아니었다"와 "분할인데 다 지워졌다"를 호출부가 구분해
/// 처리할 수 있게).
Future<List<File>> findSplitVolumeParts(Uri location) async {
  final path = location.toFilePath();
  final dir = Directory(p.dirname(path));
  if (!await dir.exists()) return const [];

  final logicalName = FormatRegistry.stripSplitVolumeSuffix(p.basename(path));
  final parts = <int, File>{};

  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    final index = FormatRegistry.splitVolumeIndexOf(name);
    if (index == null) continue;
    if (FormatRegistry.stripSplitVolumeSuffix(name) != logicalName) continue;
    parts[index] = entity;
  }

  final sortedKeys = parts.keys.toList()..sort();
  return [for (final key in sortedKeys) parts[key]!];
}

/// [parts](번호 오름차순으로 이미 정렬돼 있다고 가정)의 번호가 1부터
/// 빠짐없이 연속인지 확인한다. 중간 조각이 빠지면 이어붙인 바이트가
/// 조용히 깨지므로, 디코딩을 시도하기 전에 여기서 바로 알아채는 게 낫다.
void assertContiguousSplitVolumes(String fileName, List<File> parts) {
  for (var i = 0; i < parts.length; i++) {
    final index = FormatRegistry.splitVolumeIndexOf(p.basename(parts[i].path))!;
    if (index != i + 1) {
      throw ArgumentError(
        '분할 압축 조각이 빠졌습니다 (조각 ${i + 1}번을 찾을 수 없음): $fileName',
      );
    }
  }
}
