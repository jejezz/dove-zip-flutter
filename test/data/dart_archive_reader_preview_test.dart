import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_preview_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('엔트리 하나만 임시 파일로 꺼내고 원본 이름을 유지한다', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('docs/a.txt', 'hello'))
      ..addFile(ArchiveFile.string('root.txt', 'world'));
    final zipFile = File('${tempDir.path}/sample.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final tempUri = await reader.extractEntryToTemp(zipFile.uri, 'docs/a.txt');
    final tempFile = File(tempUri.toFilePath());

    expect(await tempFile.exists(), isTrue);
    expect(p.basename(tempFile.path), 'a.txt');
    expect(await tempFile.readAsString(), 'hello');
  });

  test('여러 번 호출하면 매번 다른 임시 폴더를 써서 충돌하지 않는다', () async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/sample.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    final first = await reader.extractEntryToTemp(zipFile.uri, 'a.txt');
    final second = await reader.extractEntryToTemp(zipFile.uri, 'a.txt');

    expect(first, isNot(second));
    expect(await File(first.toFilePath()).exists(), isTrue);
    expect(await File(second.toFilePath()).exists(), isTrue);
  });

  test('없는 항목을 요청하면 에러를 던진다', () async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/sample.zip')
      ..writeAsBytesSync(ZipEncoder().encode(archive));

    expect(
      () => reader.extractEntryToTemp(zipFile.uri, 'missing.txt'),
      throwsArgumentError,
    );
  });

  test('비밀번호로 보호된 항목은 올바른 비밀번호로만 미리보기를 꺼낼 수 있다', () async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/sample.zip')
      ..writeAsBytesSync(ZipEncoder(password: 'hunter2').encode(archive));

    expect(
      () => reader.extractEntryToTemp(zipFile.uri, 'a.txt'),
      throwsA(isA<ArchivePasswordRequiredException>()),
    );

    final tempUri =
        await reader.extractEntryToTemp(zipFile.uri, 'a.txt', password: 'hunter2');
    expect(await File(tempUri.toFilePath()).readAsString(), 'hello');
  });
}
