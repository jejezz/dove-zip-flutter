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
  final taken = exists ?? quickPathTaken;
  final dir = p.dirname(_trimSeparator(paths.first));
  final base = quickCompressBaseName(paths);
  final ext = FormatRegistry.of(format).extensions.first;

  var candidate = p.join(dir, '$base.$ext');
  for (var n = 2; taken(candidate); n++) {
    candidate = p.join(dir, '$base ($n).$ext');
  }
  return Uri.file(candidate);
}

/// [quickCompressDestination]이 쓰는 확장자 없는 기본 이름 — 항목 하나면 그
/// 이름, 여럿이면 그 항목들이 든 폴더 이름. "이름을 정해 압축하기"가 입력
/// 칸의 처음 값으로도 쓴다.
String quickCompressBaseName(List<String> paths) {
  if (paths.isEmpty) {
    throw ArgumentError.value(paths, 'paths', 'must not be empty');
  }
  final first = _trimSeparator(paths.first);
  final dir = p.dirname(first);
  final base = paths.length == 1 ? p.basenameWithoutExtension(first) : p.basename(_trimSeparator(dir));
  if (base.isEmpty || base.contains(RegExp(r'[\\/:]'))) {
    return p.basenameWithoutExtension(first);
  }
  return base;
}

/// "이름을 정해 압축하기"가 만들 압축파일 위치 — 고른 항목과 같은 폴더의
/// `이름.확장자`. 이미 있는 이름은 호출하는 쪽이 먼저 막는다([quickPathTaken]).
Uri quickCompressDestinationNamed(List<String> paths, String name, ArchiveFormat format) {
  final dir = p.dirname(_trimSeparator(paths.first));
  final ext = FormatRegistry.of(format).extensions.first;
  return Uri.file(p.join(dir, '${name.trim()}.$ext'));
}

/// "폴더 이름을 정해 풀기"의 처음 이름 — 압축파일 하나면 그 이름(압축 확장자를
/// 뺀), 여럿이면 그것들이 든 폴더 이름.
String quickExtractFolderName(List<String> archivePaths) {
  final first = archivePaths.first;
  if (archivePaths.length == 1) return FormatRegistry.stripKnownExtension(p.basename(first));
  final name = p.basename(_trimSeparator(p.dirname(_trimSeparator(first))));
  return name.isEmpty ? FormatRegistry.stripKnownExtension(p.basename(first)) : name;
}

/// 압축파일 하나당 풀 폴더. 폴더는 첫 압축파일과 같은 위치에 [folderName]으로
/// 만든다. 압축파일이 하나면 그 폴더 바로 아래에(압축파일 이름 하위 폴더 없이),
/// 여럿이면 `폴더/압축파일이름`으로 나눈다.
List<({String archive, Uri destination})> quickExtractTargets(List<String> archivePaths, String folderName) {
  final root = p.join(p.dirname(_trimSeparator(archivePaths.first)), folderName.trim());
  return [
    for (final archive in archivePaths)
      (
        archive: archive,
        destination: Uri.file(
          archivePaths.length == 1 ? root : p.join(root, FormatRegistry.stripKnownExtension(p.basename(archive))),
        ),
      ),
  ];
}

enum QuickNameProblem { empty, invalidCharacters, reserved }

/// 사용자가 입력한 [name]을 Windows에서 파일·폴더 이름으로 쓸 수 없으면 그
/// 이유, 괜찮으면 null.
QuickNameProblem? quickNameProblem(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return QuickNameProblem.empty;
  if (trimmed.contains(RegExp(r'[\\/:*?"<>|\x00-\x1f]')) || trimmed.endsWith('.')) {
    return QuickNameProblem.invalidCharacters;
  }
  final stem = trimmed.split('.').first.trim().toUpperCase();
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(stem)) return QuickNameProblem.reserved;
  return null;
}

/// [path]에 이미 파일이나 폴더가 있는지.
bool quickPathTaken(String path) => FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;

String _trimSeparator(String path) {
  if (path.length <= 1) return path;
  // `C:\`는 그대로 둔다 — 잘라 내면 "현재 드라이브의 현재 폴더"가 된다.
  if (RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(path)) return path;
  return path.endsWith('/') || path.endsWith(r'\') ? path.substring(0, path.length - 1) : path;
}
