import 'archive_entry.dart';

/// 열려 있는 압축파일 하나 (ARCHITECTURE.md 3장).
///
/// [entries]는 플랫 리스트다 — 실제 폴더 엔트리가 압축파일에 없어도(일부
/// tar/zip은 디렉터리 엔트리를 생략) [ArchiveEntry.pathInArchive]의 `/`로
/// 가상 폴더 트리를 구성하는 건 이 엔티티가 아니라 압축파일 탐색(브라우저)
/// 쪽의 몫이다(ARCHITECTURE.md 8장).
class ArchiveHandle {
  const ArchiveHandle({
    required this.location,
    required this.format,
    required this.entries,
  });

  /// 압축파일 자체의 경로, 예: `file:///Users/me/photos.zip`.
  final Uri location;
  final ArchiveFormat format;
  final List<ArchiveEntry> entries;

  @override
  String toString() =>
      'ArchiveHandle($location, format: $format, ${entries.length} entries)';
}
