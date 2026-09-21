import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('충돌이 없어야 하는데 onConflict가 호출됨');

void main() {
  late Directory tempDir;
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_password_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('비밀번호 없이 보호된 zip을 풀면 비밀번호 필요 예외를 던진다', () async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/protected.zip')
      ..writeAsBytesSync(ZipEncoder(password: 'hunter2').encode(archive));
    final destDir = Directory('${tempDir.path}/out')..createSync();

    expect(
      () => reader.extractAll(zipFile.uri, destination: destDir.uri, onConflict: _neverCalled),
      throwsA(isA<ArchivePasswordRequiredException>()),
    );
  });

  test('틀린 비밀번호로 풀면 비밀번호 필요 예외를 던진다', () async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/protected.zip')
      ..writeAsBytesSync(ZipEncoder(password: 'hunter2').encode(archive));
    final destDir = Directory('${tempDir.path}/out')..createSync();

    expect(
      () => reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        password: 'wrong-password',
        onConflict: _neverCalled,
      ),
      throwsA(isA<ArchivePasswordRequiredException>()),
    );
  });

  test('올바른 비밀번호로 풀면 원본 내용 그대로 해제된다', () async {
    final archive = Archive()..addFile(ArchiveFile.string('a.txt', 'hello'));
    final zipFile = File('${tempDir.path}/protected.zip')
      ..writeAsBytesSync(ZipEncoder(password: 'hunter2').encode(archive));
    final destDir = Directory('${tempDir.path}/out')..createSync();

    await reader.extractAll(
      zipFile.uri,
      destination: destDir.uri,
      password: 'hunter2',
      onConflict: _neverCalled,
    );

    expect(await File('${destDir.path}/a.txt').readAsString(), 'hello');
  });
}
