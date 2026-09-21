import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/data/dart_archive_writer.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  const writer = DartArchiveWriter();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_writer_tar_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('tar 계열 (여러 항목)', () {
    test('.tar을 만들면 TarDecoder로 그대로 읽힌다', () async {
      final fileA = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
      final destination = File('${tempDir.path}/out.tar');

      await writer.compress(
        sources: [fileA.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.tar),
      );

      final archive = TarDecoder().decodeBytes(await destination.readAsBytes());
      expect(archive.findFile('a.txt')!.content, 'hello'.codeUnits);
    });

    test('.tar.gz를 만들면 gunzip 후 TarDecoder로 읽힌다', () async {
      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      File('${docsDir.path}/a.txt').writeAsStringSync('hello');
      final destination = File('${tempDir.path}/out.tar.gz');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.tarGz),
      );

      final tarBytes = GZipDecoder().decodeBytes(await destination.readAsBytes());
      final archive = TarDecoder().decodeBytes(tarBytes);
      expect(archive.findFile('docs/a.txt')!.content, 'hello'.codeUnits);
    });

    test('.tar.bz2를 만들면 bunzip2 후 TarDecoder로 읽힌다', () async {
      final fileA = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
      final destination = File('${tempDir.path}/out.tar.bz2');

      await writer.compress(
        sources: [fileA.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.tarBz2),
      );

      final tarBytes = BZip2Decoder().decodeBytes(await destination.readAsBytes());
      final archive = TarDecoder().decodeBytes(tarBytes);
      expect(archive.findFile('a.txt')!.content, 'hello'.codeUnits);
    });

    test('.tar.xz를 만들면 unxz 후 TarDecoder로 읽힌다', () async {
      final fileA = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
      final destination = File('${tempDir.path}/out.tar.xz');

      await writer.compress(
        sources: [fileA.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.tarXz),
      );

      final tarBytes = XZDecoder().decodeBytes(await destination.readAsBytes());
      final archive = TarDecoder().decodeBytes(tarBytes);
      expect(archive.findFile('a.txt')!.content, 'hello'.codeUnits);
    });
  });

  group('gzip/bzip2/xz (단일 파일)', () {
    test('.gz는 파일 하나를 그대로 압축한다', () async {
      final fileA = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello world');
      final destination = File('${tempDir.path}/notes.txt.gz');

      await writer.compress(
        sources: [fileA.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.gzip),
      );

      final decoded = GZipDecoder().decodeBytes(await destination.readAsBytes());
      expect(String.fromCharCodes(decoded), 'hello world');
    });

    test('.bz2는 파일 하나를 그대로 압축한다', () async {
      final fileA = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello world');
      final destination = File('${tempDir.path}/notes.txt.bz2');

      await writer.compress(
        sources: [fileA.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.bzip2),
      );

      final decoded = BZip2Decoder().decodeBytes(await destination.readAsBytes());
      expect(String.fromCharCodes(decoded), 'hello world');
    });

    test('.xz는 파일 하나를 그대로 압축한다', () async {
      final fileA = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello world');
      final destination = File('${tempDir.path}/notes.txt.xz');

      await writer.compress(
        sources: [fileA.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.xz),
      );

      final decoded = XZDecoder().decodeBytes(await destination.readAsBytes());
      expect(String.fromCharCodes(decoded), 'hello world');
    });

    test('파일 두 개를 gzip으로 압축하려 하면 에러를 던진다', () async {
      final fileA = File('${tempDir.path}/a.txt')..writeAsStringSync('a');
      final fileB = File('${tempDir.path}/b.txt')..writeAsStringSync('b');

      expect(
        () => writer.compress(
          sources: [fileA.uri, fileB.uri],
          destination: File('${tempDir.path}/out.gz').uri,
          options: const CompressionOptions(format: ArchiveFormat.gzip),
        ),
        throwsArgumentError,
      );
    });

    test('폴더를 gzip으로 압축하려 하면 에러를 던진다', () async {
      final dir = Directory('${tempDir.path}/docs')..createSync();

      expect(
        () => writer.compress(
          sources: [dir.uri],
          destination: File('${tempDir.path}/out.gz').uri,
          options: const CompressionOptions(format: ArchiveFormat.gzip),
        ),
        throwsArgumentError,
      );
    });
  });

  test('zip이 아닌 형식에 비밀번호를 주면 에러를 던진다', () async {
    final fileA = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');

    expect(
      () => writer.compress(
        sources: [fileA.uri],
        destination: File('${tempDir.path}/out.tar').uri,
        options: const CompressionOptions(format: ArchiveFormat.tar, password: 'secret'),
      ),
      throwsUnsupportedError,
    );
  });
}
