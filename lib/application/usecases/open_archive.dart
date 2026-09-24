import 'package:path/path.dart' as p;

import '../../data/dart_archive_reader.dart';
import '../../data/format_registry.dart';
import '../../domain/entities/archive_handle.dart';
import '../../domain/repositories/archive_reader.dart';

/// 압축파일을 열어 [ArchiveHandle]을 만든다 (ARCHITECTURE.md 1장 유스케이스
/// 목록의 `OpenArchive`).
///
/// 압축파일 전체를 풀지 않고 엔트리 목록만 읽는다(ARCHITECTURE.md 8장 —
/// daylight-commander-flutter의 `ArchiveViewerScreen` 원칙 계승).
class OpenArchive {
  const OpenArchive([this._reader = const DartArchiveReader()]);

  final ArchiveReader _reader;

  Future<ArchiveHandle> call(Uri archiveLocation, {String? password}) async {
    final fileName = p.basename(archiveLocation.toFilePath());
    final format = FormatRegistry.detectFromFileName(fileName);
    if (format == null || !_reader.supports(format)) {
      throw UnsupportedArchiveFormatException(fileName);
    }

    final entries = await _reader.listEntries(archiveLocation, password: password);
    return ArchiveHandle(location: archiveLocation, format: format, entries: entries);
  }
}

/// 확장자로 압축 형식을 알 수 없거나, 알려진 형식이지만 현재 리더가
/// 지원하지 않을 때 던진다 (예: 스캐폴딩 단계의 `DartArchiveReader`에 rar를
/// 넘긴 경우).
class UnsupportedArchiveFormatException implements Exception {
  const UnsupportedArchiveFormatException(this.fileName);

  final String fileName;

  @override
  String toString() => 'Unknown or unsupported archive format: $fileName';
}
