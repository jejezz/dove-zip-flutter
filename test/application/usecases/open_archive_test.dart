import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/application/usecases/create_archive.dart';
import 'package:dove_zip/application/usecases/open_archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// zip만 지원하는 실제 [DartArchiveReader]와 달리, 포맷 판정/예외 처리
/// 로직만 골라서 검증하기 위한 가짜 리더 — 어떤 포맷을 넘겨도 성공한다.
/// `extractAll`은 이 테스트 파일에서 쓰지 않아 호출되면 실패하도록 둔다.
class _FakeReader implements ArchiveReader {
  const _FakeReader(this._entries);

  final List<ArchiveEntry> _entries;

  @override
  bool supports(ArchiveFormat format) => format == ArchiveFormat.zip;

  @override
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password}) async =>
      _entries;

  @override
  Future<void> extractAll(
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
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

void main() {
  group('OpenArchive (가짜 리더로 로직만 검증)', () {
    const entries = [
      ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false),
    ];

    test('확장자로 포맷을 인식해 ArchiveHandle을 만든다', () async {
      final openArchive = OpenArchive(const _FakeReader(entries));
      final location = Uri.file('/tmp/photos.zip');

      final handle = await openArchive(location);

      expect(handle.location, location);
      expect(handle.format, ArchiveFormat.zip);
      expect(handle.entries, entries);
    });

    test('알 수 없는 확장자는 예외를 던진다', () async {
      final openArchive = OpenArchive(const _FakeReader(entries));

      expect(
        () => openArchive(Uri.file('/tmp/readme.txt')),
        throwsA(isA<UnsupportedArchiveFormatException>()),
      );
    });

    test('리더가 지원하지 않는 포맷이면 예외를 던진다', () async {
      // 확장자로는 rar가 정확히 인식되지만, 리더가 zip만 지원하므로 실패해야 한다.
      final openArchive = OpenArchive(const _FakeReader(entries));

      expect(
        () => openArchive(Uri.file('/tmp/backup.rar')),
        throwsA(isA<UnsupportedArchiveFormatException>()),
      );
    });
  });

  group('OpenArchive (실제 DartArchiveReader + 진짜 zip 파일)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dove_zip_open_archive_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('실제 zip 파일을 열어 엔트리를 읽는다', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'hello'))
        ..addFile(ArchiveFile.string('b.txt', 'world'));
      final zipFile = File('${tempDir.path}/photos.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));

      const openArchive = OpenArchive();
      final handle = await openArchive(zipFile.uri);

      expect(handle.format, ArchiveFormat.zip);
      expect(handle.entries.map((e) => e.pathInArchive).toSet(), {'a.txt', 'b.txt'});
    });

    test('실제 tar.gz 파일도 문제없이 연다 (TAR/XZ 계열 확장 확인)', () async {
      final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
      final tarBytes = TarEncoder().encode(archive);
      final tarGzFile = File('${tempDir.path}/photos.tar.gz')
        ..writeAsBytesSync(GZipEncoder().encodeBytes(tarBytes));

      const openArchive = OpenArchive();
      final handle = await openArchive(tarGzFile.uri);

      expect(handle.format, ArchiveFormat.tarGz);
      expect(handle.entries.map((e) => e.pathInArchive).toSet(), {'a.txt'});
    });

    test('실제 7z 파일도 문제없이 연다 (koni_sevenz 백엔드 확인)', () async {
      final sourceFile = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
      final sevenZipFile = File('${tempDir.path}/photos.7z');
      await const CreateArchive()(
        sources: [sourceFile.uri],
        destination: sevenZipFile.uri,
        options: const CompressionOptions(format: ArchiveFormat.sevenZip),
      );

      const openArchive = OpenArchive();
      final handle = await openArchive(sevenZipFile.uri);

      expect(handle.format, ArchiveFormat.sevenZip);
      expect(handle.entries.map((e) => e.pathInArchive).toSet(), {'a.txt'});
    });
  });
}
