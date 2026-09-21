import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/application/usecases/open_archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 파일을 건드리지 않고 `ExtractEntries`가 넘기는 인자만 기록하는
/// 가짜 리더 — 목적지 계산(resolveExtractDestination 연동)과 예외 처리
/// 로직만 검증한다. 실제 디스크 I/O는 dart_archive_reader_extract_test.dart가 맡는다.
class _RecordingReader implements ArchiveReader {
  _RecordingReader({this.supportedFormat = ArchiveFormat.zip});

  final ArchiveFormat supportedFormat;
  Uri? lastDestination;
  List<String>? lastEntryPaths;

  @override
  bool supports(ArchiveFormat format) => format == supportedFormat;

  @override
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password}) async => [];

  @override
  Future<void> extractAll(
    Uri archiveLocation, {
    required Uri destination,
    List<String>? entryPaths,
    String? password,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    lastDestination = destination;
    lastEntryPaths = entryPaths;
  }

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('호출되면 안 됨');

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/downloads/photos.tar.gz'),
    format: ArchiveFormat.zip,
    entries: const [
      ArchiveEntry(pathInArchive: 'a.jpg', isDirectory: false),
    ],
  );

  test('here 모드는 압축파일이 있는 폴더로 해제를 넘긴다', () async {
    final reader = _RecordingReader();
    final extractEntries = ExtractEntries(reader);

    final destination = await extractEntries(
      handle: handle,
      mode: ExtractDestinationMode.here,
      onConflict: _neverCalled,
    );

    expect(destination, Uri.file('/tmp/downloads'));
    expect(reader.lastDestination, destination);
  });

  test('smart 모드는 압축파일명 폴더로 해제를 넘긴다', () async {
    final reader = _RecordingReader();
    final extractEntries = ExtractEntries(reader);

    final destination = await extractEntries(
      handle: handle,
      mode: ExtractDestinationMode.smart,
      onConflict: _neverCalled,
    );

    expect(destination, Uri.file('/tmp/downloads/photos'));
  });

  test('chooseFolder 모드는 사용자가 고른 폴더를 그대로 쓴다', () async {
    final reader = _RecordingReader();
    final extractEntries = ExtractEntries(reader);
    final chosen = Uri.file('/Volumes/External');

    final destination = await extractEntries(
      handle: handle,
      mode: ExtractDestinationMode.chooseFolder,
      userChosenFolder: chosen,
      onConflict: _neverCalled,
    );

    expect(destination, chosen);
  });

  test('entryPaths를 그대로 리더에 전달한다', () async {
    final reader = _RecordingReader();
    final extractEntries = ExtractEntries(reader);

    await extractEntries(
      handle: handle,
      mode: ExtractDestinationMode.here,
      entryPaths: const ['a.jpg'],
      onConflict: _neverCalled,
    );

    expect(reader.lastEntryPaths, ['a.jpg']);
  });

  test('리더가 지원하지 않는 포맷이면 리더를 호출하지 않고 예외를 던진다', () async {
    final reader = _RecordingReader(supportedFormat: ArchiveFormat.rar);
    final extractEntries = ExtractEntries(reader);

    expect(
      () => extractEntries(
        handle: handle,
        mode: ExtractDestinationMode.here,
        onConflict: _neverCalled,
      ),
      throwsA(isA<UnsupportedArchiveFormatException>()),
    );
    expect(reader.lastDestination, isNull);
  });
}
