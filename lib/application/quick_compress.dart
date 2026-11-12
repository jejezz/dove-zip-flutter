import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/format_registry.dart';
import '../domain/entities/archive_entry.dart';

/// 탐색기·Finder 우클릭 메뉴의 "압축하기"가 창 없이 바로 만드는 형식 중에서
/// 설정으로 고를 수 있는 것. 파일 하나만 담는 gzip/bzip2/xz는 폴더나 여러
/// 항목을 고르면 실패하므로 뺀다.
const quickCompressFormats = [
  ArchiveFormat.zip,
  ArchiveFormat.sevenZip,
  ArchiveFormat.tar,
  ArchiveFormat.tarGz,
  ArchiveFormat.tarBz2,
  ArchiveFormat.tarXz,
];

const defaultQuickCompressFormat = ArchiveFormat.zip;

/// "압축하기"가 만들 압축파일 위치. 고른 항목과 같은 폴더에 둔다.
///
/// - 항목 하나: 그 이름(파일이면 확장자를 뺀 이름) — `photos/` → `photos.zip`
/// - 여러 개: 그 항목들이 든 폴더 이름 — `Trip/a.jpg`, `Trip/b.jpg` → `Trip.zip`
///   (드라이브 루트처럼 폴더 이름이 없으면 첫 항목 이름)
/// - 이름이 이미 있으면 `이름 (2).zip`, `이름 (3).zip` …
Uri quickCompressDestination(
  List<String> paths,
  ArchiveFormat format, {
  bool Function(String path)? exists,
}) {
  if (paths.isEmpty) {
    throw ArgumentError.value(paths, 'paths', 'must not be empty');
  }
  final taken = exists ?? (path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
  final first = _trimSeparator(paths.first);
  final dir = p.dirname(first);
  var base = paths.length == 1 ? p.basenameWithoutExtension(first) : p.basename(_trimSeparator(dir));
  if (base.isEmpty || base.contains(RegExp(r'[\\/:]'))) {
    base = p.basenameWithoutExtension(first);
  }
  final ext = FormatRegistry.of(format).extensions.first;

  var candidate = p.join(dir, '$base.$ext');
  for (var n = 2; taken(candidate); n++) {
    candidate = p.join(dir, '$base ($n).$ext');
  }
  return Uri.file(candidate);
}

String _trimSeparator(String path) {
  if (path.length <= 1) return path;
  // `C:\`는 그대로 둔다 — 잘라 내면 "현재 드라이브의 현재 폴더"가 된다.
  if (RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(path)) return path;
  return path.endsWith('/') || path.endsWith(r'\') ? path.substring(0, path.length - 1) : path;
}
