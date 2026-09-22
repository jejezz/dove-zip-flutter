import 'package:dove_zip/application/usecases/open_archive.dart';
import 'package:dove_zip/application/usecases/preview_archive_entry.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeReader implements ArchiveReader {
  _FakeReader({this.supportedFormat = ArchiveFormat.zip});

  final ArchiveFormat supportedFormat;
  String? lastEntryPath;

  @override
  bool supports(ArchiveFormat format) => format == supportedFormat;

  @override
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password}) async => [];

  @override
  Future<List<ExtractFailure>> extractAll(
    Uri archiveLocation, {
    required Uri destination,
    List<String>? entryPaths,
    String? password,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) async {
    lastEntryPath = entryPath;
    return Uri.file('/tmp/preview/${entryPath.split('/').last}');
  }
}

void main() {
  final handle = ArchiveHandle(
    location: Uri.file('/tmp/photos.zip'),
    format: ArchiveFormat.zip,
    entries: const [ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false)],
  );

  test('지원하는 포맷이면 리더에 그대로 위임한다', () async {
    final reader = _FakeReader();
    final preview = PreviewArchiveEntry(reader);

    final tempUri = await preview(handle, 'docs/a.txt');

    expect(reader.lastEntryPath, 'docs/a.txt');
    expect(tempUri, Uri.file('/tmp/preview/a.txt'));
  });

  test('리더가 지원하지 않는 포맷이면 예외를 던지고 리더를 부르지 않는다', () async {
    final reader = _FakeReader(supportedFormat: ArchiveFormat.rar);
    final preview = PreviewArchiveEntry(reader);

    expect(
      () => preview(handle, 'docs/a.txt'),
      throwsA(isA<UnsupportedArchiveFormatException>()),
    );
    expect(reader.lastEntryPath, isNull);
  });
}
