import 'package:path/path.dart' as p;

import '../../data/dart_archive_reader.dart';
import '../../domain/entities/archive_handle.dart';
import '../../domain/repositories/archive_reader.dart';
import 'open_archive.dart' show UnsupportedArchiveFormatException;

/// [entryPath] 하나만 임시 폴더로 꺼내 그 위치를 반환한다 (ARCHITECTURE.md
/// 9장 — 미리보기(F3)가 이 유스케이스로 압축파일 전체를 풀지 않고 항목
/// 하나만 얻는다).
class PreviewArchiveEntry {
  const PreviewArchiveEntry([this._reader = const DartArchiveReader()]);

  final ArchiveReader _reader;

  Future<Uri> call(ArchiveHandle handle, String entryPath, {String? password}) async {
    if (!_reader.supports(handle.format)) {
      throw UnsupportedArchiveFormatException(p.basename(handle.location.toFilePath()));
    }
    return _reader.extractEntryToTemp(handle.location, entryPath, password: password);
  }
}
