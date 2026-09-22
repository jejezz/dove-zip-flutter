import 'package:path/path.dart' as p;

import '../../core/cancel_token.dart';
import '../../data/dart_archive_reader.dart';
import '../../domain/entities/archive_handle.dart';
import '../../domain/entities/extract_destination_mode.dart';
import '../../domain/entities/extract_failure.dart';
import '../../domain/repositories/archive_reader.dart';
import 'open_archive.dart' show UnsupportedArchiveFormatException;
import '../resolve_extract_destination.dart';

/// [ExtractEntries.call]의 결과 — 어디에 풀렸는지와, 손상돼 건너뛴 항목이
/// 있다면 그 목록(PLAN.md 1.2 "손상된 압축파일 복구/부분 해제 시도").
/// [failures]가 비어 있으면 전부 성공한 것이다.
class ExtractResult {
  const ExtractResult({required this.destination, required this.failures});

  final Uri destination;
  final List<ExtractFailure> failures;
}

/// [handle]을 3가지 해제 모드 중 하나로 디스크에 푼다 (ARCHITECTURE.md 1장
/// 유스케이스 목록의 `ExtractEntries` — PLAN.md 1.2 "가장 중요한 편의 기능").
///
/// 목적지 계산은 [resolveExtractDestination](이미 구현된 순수 함수)에
/// 위임하고, 이 유스케이스는 그 결과를 실제 [ArchiveReader.extractAll]
/// 호출로 이어붙이기만 한다.
class ExtractEntries {
  const ExtractEntries([this._reader = const DartArchiveReader()]);

  final ArchiveReader _reader;

  Future<ExtractResult> call({
    required ArchiveHandle handle,
    required ExtractDestinationMode mode,
    List<String>? entryPaths,
    String? password,
    Uri? userChosenFolder,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!_reader.supports(handle.format)) {
      final fileName = p.basename(handle.location.toFilePath());
      throw UnsupportedArchiveFormatException(fileName);
    }

    final destination = resolveExtractDestination(
      archiveLocation: handle.location,
      mode: mode,
      entries: handle.entries,
      userChosenFolder: userChosenFolder,
    );

    final failures = await _reader.extractAll(
      handle.location,
      destination: destination,
      entryPaths: entryPaths,
      password: password,
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    return ExtractResult(destination: destination, failures: failures);
  }
}
