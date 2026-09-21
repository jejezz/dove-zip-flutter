import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/ (디렉터리), docs/a.txt("hello"), root.txt("world")로 구성된
/// 실제 zip 파일을 임시 폴더에 만든다. daylight-commander-flutter가
/// `Directory.systemTemp`로 실제 파일 연산을 검증하던 방식을 계승.
Future<File> _createSampleZip(Directory tempDir) async {
  final archive = Archive()
    ..addFile(ArchiveFile.directory('docs/'))
    ..addFile(ArchiveFile.string('docs/a.txt', 'hello'))
    ..addFile(ArchiveFile.string('root.txt', 'world'));

  final bytes = ZipEncoder().encode(archive);
  final zipFile = File('${tempDir.path}/sample.zip');
  await zipFile.writeAsBytes(bytes);
  return zipFile;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_reader_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('zip 내부 엔트리를 실제로 풀지 않고 목록만 읽는다', () async {
    final zipFile = await _createSampleZip(tempDir);
    const reader = DartArchiveReader();

    final entries = await reader.listEntries(zipFile.uri);

    expect(entries.map((e) => e.pathInArchive).toSet(), {
      'docs/',
      'docs/a.txt',
      'root.txt',
    });

    final docsDir = entries.firstWhere((e) => e.pathInArchive == 'docs/');
    expect(docsDir.isDirectory, isTrue);
    expect(docsDir.uncompressedSize, isNull);

    final rootFile = entries.firstWhere((e) => e.pathInArchive == 'root.txt');
    expect(rootFile.isDirectory, isFalse);
    expect(rootFile.uncompressedSize, 'world'.length);
    expect(rootFile.name, 'root.txt');
  });

  test('supports는 zip을 지원한다', () {
    const reader = DartArchiveReader();
    expect(reader.supports(ArchiveFormat.zip), isTrue);
  });

  test('비밀번호로 보호된 zip도 목록은 비밀번호 없이 읽을 수 있다', () async {
    // zip 목록은 항목을 복호화하지 않아도 읽을 수 있다 — 실제 내용을
    // 꺼낼 때만 비밀번호가 필요하다(dart_archive_reader_password_test.dart 참고).
    final archive = Archive()..addFile(ArchiveFile.string('secret.txt', 'hello'));
    final zipFile = File('${tempDir.path}/protected.zip')
      ..writeAsBytesSync(ZipEncoder(password: 'hunter2').encode(archive));
    const reader = DartArchiveReader();

    final entries = await reader.listEntries(zipFile.uri);

    expect(entries.map((e) => e.pathInArchive).toSet(), {'secret.txt'});
  });
}
