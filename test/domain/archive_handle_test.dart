import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location/format/entries를 그대로 보관한다', () {
    final entries = [
      const ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
      const ArchiveEntry(
        pathInArchive: 'docs/report.pdf',
        isDirectory: false,
        uncompressedSize: 2048,
        compressedSize: 1024,
      ),
    ];
    final handle = ArchiveHandle(
      location: Uri.file('/Users/me/photos.zip'),
      format: ArchiveFormat.zip,
      entries: entries,
    );

    expect(handle.location, Uri.file('/Users/me/photos.zip'));
    expect(handle.format, ArchiveFormat.zip);
    expect(handle.entries, entries);
  });

  test('빈 압축파일도 표현할 수 있다', () {
    final handle = ArchiveHandle(
      location: Uri.file('/tmp/empty.tar'),
      format: ArchiveFormat.tar,
      entries: const [],
    );
    expect(handle.entries, isEmpty);
  });
}
