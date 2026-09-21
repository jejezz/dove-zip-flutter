import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('충돌이 없어야 하는데 onConflict가 호출됨: ${conflict.entryPath}');

Archive _sampleArchive() => Archive()
  ..addFile(ArchiveFile.directory('docs/'))
  ..addFile(ArchiveFile.string('docs/a.txt', 'hello'))
  ..addFile(ArchiveFile.string('root.txt', 'world'));

void main() {
  late Directory tempDir;
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_tar_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('supports는 tar 계열과 gzip/bzip2/xz를 모두 지원한다', () {
    expect(reader.supports(ArchiveFormat.tar), isTrue);
    expect(reader.supports(ArchiveFormat.tarGz), isTrue);
    expect(reader.supports(ArchiveFormat.tarBz2), isTrue);
    expect(reader.supports(ArchiveFormat.tarXz), isTrue);
    expect(reader.supports(ArchiveFormat.gzip), isTrue);
    expect(reader.supports(ArchiveFormat.bzip2), isTrue);
    expect(reader.supports(ArchiveFormat.xz), isTrue);
    // 여전히 지원하지 않는 것 — zstd는 koni 생태계가 아직 pub.dev에
    // 배포하지 않아 보류(PLAN.md 3장). 7z/RAR는 koni_sevenz/koni_rar로
    // 지원한다 — dart_archive_reader_koni_test.dart 참고.
    expect(reader.supports(ArchiveFormat.zstd), isFalse);
  });

  group('tar 계열 (여러 항목)', () {
    test('.tar 목록을 읽는다', () async {
      final tarBytes = TarEncoder().encode(_sampleArchive());
      final file = File('${tempDir.path}/sample.tar')..writeAsBytesSync(tarBytes);

      final entries = await reader.listEntries(file.uri);

      expect(entries.map((e) => e.pathInArchive).toSet(), {
        'docs/',
        'docs/a.txt',
        'root.txt',
      });
    });

    test('.tar.gz 목록을 읽고 해제한다', () async {
      final tarBytes = TarEncoder().encode(_sampleArchive());
      final gzBytes = GZipEncoder().encodeBytes(tarBytes);
      final file = File('${tempDir.path}/sample.tar.gz')..writeAsBytesSync(gzBytes);

      final entries = await reader.listEntries(file.uri);
      expect(entries.map((e) => e.pathInArchive).toSet(), {
        'docs/',
        'docs/a.txt',
        'root.txt',
      });

      final destDir = Directory('${tempDir.path}/out')..createSync();
      await reader.extractAll(file.uri, destination: destDir.uri, onConflict: _neverCalled);
      expect(await File('${destDir.path}/docs/a.txt').readAsString(), 'hello');
      expect(await File('${destDir.path}/root.txt').readAsString(), 'world');
    });

    test('.tar.bz2 목록을 읽고 해제한다', () async {
      final tarBytes = TarEncoder().encode(_sampleArchive());
      final bz2Bytes = BZip2Encoder().encodeBytes(tarBytes);
      final file = File('${tempDir.path}/sample.tar.bz2')..writeAsBytesSync(bz2Bytes);

      final destDir = Directory('${tempDir.path}/out')..createSync();
      await reader.extractAll(file.uri, destination: destDir.uri, onConflict: _neverCalled);

      expect(await File('${destDir.path}/root.txt').readAsString(), 'world');
    });

    test('.tar.xz 목록을 읽고 해제한다', () async {
      final tarBytes = TarEncoder().encode(_sampleArchive());
      final xzBytes = XZEncoder().encodeBytes(tarBytes);
      final file = File('${tempDir.path}/sample.tar.xz')..writeAsBytesSync(xzBytes);

      final destDir = Directory('${tempDir.path}/out')..createSync();
      await reader.extractAll(file.uri, destination: destDir.uri, onConflict: _neverCalled);

      expect(await File('${destDir.path}/root.txt').readAsString(), 'world');
    });

    test('tar 계열은 항목별 압축 크기를 null로 둔다(파일 단위 개념이 없음)', () async {
      final tarBytes = TarEncoder().encode(_sampleArchive());
      final file = File('${tempDir.path}/sample.tar')..writeAsBytesSync(tarBytes);

      final entries = await reader.listEntries(file.uri);
      final rootFile = entries.firstWhere((e) => e.pathInArchive == 'root.txt');

      expect(rootFile.uncompressedSize, 'world'.length);
      expect(rootFile.compressedSize, isNull);
    });
  });

  group('gzip/bzip2/xz (단일 파일)', () {
    test('.gz는 확장자를 뗀 이름의 항목 하나로 보인다', () async {
      final gzBytes = GZipEncoder().encodeBytes('hello world'.codeUnits);
      final file = File('${tempDir.path}/notes.txt.gz')..writeAsBytesSync(gzBytes);

      final entries = await reader.listEntries(file.uri);

      expect(entries, hasLength(1));
      expect(entries.single.pathInArchive, 'notes.txt');
      expect(entries.single.isDirectory, isFalse);
    });

    test('.gz 항목을 미리보기용으로 꺼내면 원본 내용이 나온다', () async {
      final gzBytes = GZipEncoder().encodeBytes('hello world'.codeUnits);
      final file = File('${tempDir.path}/notes.txt.gz')..writeAsBytesSync(gzBytes);

      final tempUri = await reader.extractEntryToTemp(file.uri, 'notes.txt');

      expect(await File(tempUri.toFilePath()).readAsString(), 'hello world');
    });

    test('.bz2 항목을 해제하면 원본 내용이 나온다', () async {
      final bz2Bytes = BZip2Encoder().encodeBytes('hello world'.codeUnits);
      final file = File('${tempDir.path}/notes.txt.bz2')..writeAsBytesSync(bz2Bytes);
      final destDir = Directory('${tempDir.path}/out')..createSync();

      await reader.extractAll(file.uri, destination: destDir.uri, onConflict: _neverCalled);

      expect(await File('${destDir.path}/notes.txt').readAsString(), 'hello world');
    });

    test('.xz 항목을 해제하면 원본 내용이 나온다', () async {
      final xzBytes = XZEncoder().encodeBytes('hello world'.codeUnits);
      final file = File('${tempDir.path}/notes.txt.xz')..writeAsBytesSync(xzBytes);
      final destDir = Directory('${tempDir.path}/out')..createSync();

      await reader.extractAll(file.uri, destination: destDir.uri, onConflict: _neverCalled);

      expect(await File('${destDir.path}/notes.txt').readAsString(), 'hello world');
    });
  });

  test('알려지지 않은 확장자는 에러를 던진다', () async {
    final file = File('${tempDir.path}/mystery.bin')..writeAsBytesSync([1, 2, 3]);

    expect(() => reader.listEntries(file.uri), throwsArgumentError);
  });
}
