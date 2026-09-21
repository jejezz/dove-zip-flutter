import 'package:path/path.dart' as p;

import '../data/format_registry.dart';
import '../domain/entities/archive_entry.dart';
import '../domain/entities/extract_destination_mode.dart';

/// 압축파일 경로와 모드로부터 실제 해제 대상 폴더를 계산한다
/// (ARCHITECTURE.md 5장 — PLAN.md 1.2 "가장 중요한 편의 기능").
///
/// 파일시스템에 접근하지 않는 순수 함수라 유닛 테스트가 쉽다. 앱 내부 UI
/// 버튼과 (P2로 예정된) OS 컨텍스트 메뉴 확장 양쪽에서 이 함수 하나만
/// 호출하면 되므로 "편의성" 로직이 한 곳에만 존재한다.
Uri resolveExtractDestination({
  required Uri archiveLocation,
  required ExtractDestinationMode mode,
  required List<ArchiveEntry> entries,
  Uri? userChosenFolder,
}) {
  switch (mode) {
    case ExtractDestinationMode.here:
      return _archiveDirectory(archiveLocation);

    case ExtractDestinationMode.smart:
      final baseName = basenameWithoutArchiveExtensions(archiveLocation);
      if (hasSingleTopLevelFolderNamed(entries, baseName)) {
        // 압축파일 내부가 이미 "photos/" 폴더 하나로만 구성돼 있으면
        // 그대로 사용 — WinRAR/Keka와 같은 이중 중첩 방지 관례.
        return _archiveDirectory(archiveLocation);
      }
      final archiveDirPath = _archiveDirectory(archiveLocation).toFilePath();
      return Uri.file(p.join(archiveDirPath, baseName));

    case ExtractDestinationMode.chooseFolder:
      if (userChosenFolder == null) {
        throw ArgumentError.notNull('userChosenFolder');
      }
      return userChosenFolder;
  }
}

Uri _archiveDirectory(Uri archiveLocation) =>
    Uri.file(p.dirname(archiveLocation.toFilePath()));

/// 압축파일 이름에서 알려진 압축 확장자를 제거한다. `.tar.gz`처럼 이중
/// 확장자를 가진 포맷도 한 번에 제거한다 — 실제 구현은
/// [FormatRegistry.stripKnownExtension]에 있고(단일 파일 압축 포맷의 내부
/// 항목 이름 추정과 공유), 이 함수는 [Uri]에서 파일명을 뽑아 넘기는
/// 얇은 래퍼다.
String basenameWithoutArchiveExtensions(Uri archiveLocation) =>
    FormatRegistry.stripKnownExtension(p.basename(archiveLocation.toFilePath()));

/// 엔트리 목록의 최상위(`pathInArchive`의 `/` 기준 첫 세그먼트)가 전부
/// 동일한 [name] 하나뿐인지 확인한다. 이름이 다르면(대소문자 차이 포함)
/// 항상 false를 반환하는 엄격 매칭 — 새 폴더를 만드는 쪽이 안전하다.
bool hasSingleTopLevelFolderNamed(List<ArchiveEntry> entries, String name) {
  if (entries.isEmpty) return false;
  return entries.every((entry) => _topLevelSegment(entry.pathInArchive) == name);
}

String _topLevelSegment(String pathInArchive) {
  final slashIndex = pathInArchive.indexOf('/');
  return slashIndex == -1 ? pathInArchive : pathInArchive.substring(0, slashIndex);
}
