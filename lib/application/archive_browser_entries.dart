import '../domain/entities/archive_entry.dart';

/// 압축파일 탐색 화면에서 한 폴더 깊이만큼 보여줄 항목 (ARCHITECTURE.md 8장).
///
/// 실제 [ArchiveEntry]가 있으면 [sourceEntry]에 그대로 담는다(파일, 또는
/// 압축파일에 디렉터리 엔트리가 실제로 존재하는 폴더). 압축파일에
/// 디렉터리 엔트리가 없어 파일 경로로만 존재를 유추한 가상 폴더는
/// [sourceEntry]가 null이다.
class ArchiveBrowserEntry {
  const ArchiveBrowserEntry({
    required this.name,
    required this.isDirectory,
    this.sourceEntry,
  });

  final String name;
  final bool isDirectory;
  final ArchiveEntry? sourceEntry;

  @override
  String toString() => 'ArchiveBrowserEntry($name, isDirectory: $isDirectory)';
}

/// [entries](압축파일 전체의 플랫 리스트)에서 [virtualPath] 바로 아래
/// 한 단계 깊이의 항목만 뽑아낸다.
///
/// 압축파일을 다시 읽지 않는 순수 함수라 폴더를 드나들 때마다 백엔드를
/// 다시 호출할 필요가 없다 (ARCHITECTURE.md 8장 — "폴더 진입은 인메모리
/// 필터링, entries를 다시 읽지 않음"). [virtualPath]는 루트일 때 빈
/// 문자열, 그 외에는 앞뒤에 슬래시 없이 `"docs"`, `"docs/sub"`처럼 넘긴다.
///
/// 폴더가 파일보다 먼저 오고, 그 안에서는 이름 오름차순(대소문자
/// 무시)으로 정렬한다 — daylight-commander-flutter의 "폴더 우선 정렬"
/// 관례 계승.
List<ArchiveBrowserEntry> childrenOf(
  List<ArchiveEntry> entries,
  String virtualPath,
) {
  final prefix = virtualPath.isEmpty ? '' : '$virtualPath/';
  final children = <String, ArchiveBrowserEntry>{};

  for (final entry in entries) {
    if (!entry.pathInArchive.startsWith(prefix)) continue;

    final remainder = entry.pathInArchive.substring(prefix.length);
    if (remainder.isEmpty) continue; // 현재 폴더 자신의 디렉터리 엔트리

    // 디렉터리 엔트리는 관례상 끝에 '/'가 붙기도 한다(포맷마다 다름) — 그
    // 트레일링 슬래시는 "몇 단계 더 들어가야 하는지" 판단에서 제외해야
    // "docs/"(이 깊이의 폴더 자신) 항목이 "docs/뭔가"(더 깊은 중간 폴더)로
    // 잘못 분류되지 않는다.
    final hasTrailingSlash = remainder.endsWith('/');
    final withoutTrailingSlash = hasTrailingSlash
        ? remainder.substring(0, remainder.length - 1)
        : remainder;
    final slashIndex = withoutTrailingSlash.indexOf('/');

    if (slashIndex == -1) {
      // 이 깊이의 파일, 또는 이 깊이의 디렉터리 엔트리 자신.
      final name = withoutTrailingSlash;
      children[name] = ArchiveBrowserEntry(
        name: name,
        isDirectory: entry.isDirectory || hasTrailingSlash,
        sourceEntry: entry,
      );
    } else {
      // 더 깊은 항목이 지나가는 중간 폴더 — 실제 디렉터리 엔트리가 따로
      // 있으면 위 분기에서 나중에(또는 먼저) 덮어써지므로 순서에 안전하다.
      final folderName = withoutTrailingSlash.substring(0, slashIndex);
      children.putIfAbsent(
        folderName,
        () => ArchiveBrowserEntry(name: folderName, isDirectory: true),
      );
    }
  }

  return children.values.toList()..sort((a, b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

/// [selectedPaths](화면에서 고른 항목들의 전체 가상 경로 — 실제 엔트리가
/// 있든 파일 경로로만 유추된 가상 폴더든 상관없다)를 압축파일 전체
/// [entries] 기준으로 펼친다. 파일은 그대로 한 항목, 폴더는 그 안의 모든
/// 하위 엔트리(파일 + 디렉터리, 몇 단계든)까지 전부 포함한다 — 반환값은
/// 실제 [ArchiveEntry.pathInArchive] 값들의 집합이라 `ExtractEntries`의
/// `entryPaths`로 그대로 넘길 수 있다(PLAN.md 1.2 "선택 항목만 해제").
///
/// 폴더 자신의 디렉터리 엔트리가 없어도(가상 폴더) 동작한다 — 그 아래
/// 파일들의 경로가 이미 `$selected/`로 시작하므로 prefix 매칭만으로
/// 충분하고, 해제 시 빈 디렉터리 생성은 [DartArchiveReader]가 파일을 쓰기
/// 전 상위 폴더를 자동으로 만들어주는 기존 로직에 맡긴다.
Set<String> expandSelectionToEntryPaths(
  List<ArchiveEntry> entries,
  Set<String> selectedPaths,
) {
  final result = <String>{};
  for (final entry in entries) {
    final normalized = entry.pathInArchive.endsWith('/')
        ? entry.pathInArchive.substring(0, entry.pathInArchive.length - 1)
        : entry.pathInArchive;
    final matches = selectedPaths.any(
      (selected) =>
          normalized == selected || normalized.startsWith('$selected/'),
    );
    if (matches) result.add(entry.pathInArchive);
  }
  return result;
}
