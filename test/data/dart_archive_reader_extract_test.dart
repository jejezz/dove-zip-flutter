import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/entities/extract_progress.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> _writeSampleZip(Directory dir, {String suffix = ''}) async {
  final archive = Archive()
    ..addFile(ArchiveFile.directory('docs/'))
    ..addFile(ArchiveFile.string('docs/a.txt', 'hello'))
    ..addFile(ArchiveFile.string('root.txt', 'world'));
  final zipFile = File('${dir.path}/sample$suffix.zip');
  await zipFile.writeAsBytes(ZipEncoder().encode(archive));
  return zipFile;
}

Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('충돌이 없어야 하는데 onConflict가 호출됨: ${conflict.entryPath}');

void main() {
  late Directory tempDir;
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_extract_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('충돌 없이 전체 해제하면 원본 내용 그대로 파일이 생긴다', () async {
    final zipFile = await _writeSampleZip(tempDir);
    final destDir = Directory('${tempDir.path}/out')..createSync();

    await reader.extractAll(
      zipFile.uri,
      destination: destDir.uri,
      onConflict: _neverCalled,
    );

    expect(await File('${destDir.path}/docs/a.txt').readAsString(), 'hello');
    expect(await File('${destDir.path}/root.txt').readAsString(), 'world');
    expect(await Directory('${destDir.path}/docs').exists(), isTrue);
  });

  test('entryPaths를 주면 그 항목만 해제한다', () async {
    final zipFile = await _writeSampleZip(tempDir);
    final destDir = Directory('${tempDir.path}/out')..createSync();

    await reader.extractAll(
      zipFile.uri,
      destination: destDir.uri,
      entryPaths: const ['root.txt'],
      onConflict: _neverCalled,
    );

    expect(await File('${destDir.path}/root.txt').exists(), isTrue);
    expect(await File('${destDir.path}/docs/a.txt').exists(), isFalse);
  });

  test('진행률 콜백이 파일 개수만큼(디렉터리 제외) 호출된다', () async {
    final zipFile = await _writeSampleZip(tempDir);
    final destDir = Directory('${tempDir.path}/out')..createSync();
    final progresses = <ExtractProgress>[];

    await reader.extractAll(
      zipFile.uri,
      destination: destDir.uri,
      onConflict: _neverCalled,
      onProgress: progresses.add,
    );

    expect(progresses, hasLength(2)); // docs/a.txt, root.txt (디렉터리 제외)
    expect(progresses.last.done, 2);
    expect(progresses.last.total, 2);
  });

  group('충돌 처리', () {
    test('overwrite를 고르면 기존 파일을 덮어쓴다', () async {
      final zipFile = await _writeSampleZip(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();
      await File('${destDir.path}/root.txt').writeAsString('old content');

      await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        entryPaths: const ['root.txt'],
        onConflict: (conflict) async => ConflictAction.overwrite,
      );

      expect(await File('${destDir.path}/root.txt').readAsString(), 'world');
    });

    test('skip을 고르면 기존 파일을 그대로 둔다', () async {
      final zipFile = await _writeSampleZip(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();
      await File('${destDir.path}/root.txt').writeAsString('old content');

      await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        entryPaths: const ['root.txt'],
        onConflict: (conflict) async => ConflictAction.skip,
      );

      expect(await File('${destDir.path}/root.txt').readAsString(), 'old content');
    });

    test('rename을 고르면 새 이름으로 저장하고 기존 파일은 남는다', () async {
      final zipFile = await _writeSampleZip(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();
      await File('${destDir.path}/root.txt').writeAsString('old content');

      await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        entryPaths: const ['root.txt'],
        onConflict: (conflict) async => ConflictAction.rename,
      );

      expect(await File('${destDir.path}/root.txt').readAsString(), 'old content');
      expect(await File('${destDir.path}/root (2).txt').readAsString(), 'world');
    });

    test('cancel을 고르면 예외를 던지고 멈춘다', () async {
      final zipFile = await _writeSampleZip(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();
      await File('${destDir.path}/root.txt').writeAsString('old content');

      expect(
        () => reader.extractAll(
          zipFile.uri,
          destination: destDir.uri,
          entryPaths: const ['root.txt'],
          onConflict: (conflict) async => ConflictAction.cancel,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
    });

    test('overwriteAll을 고르면 이후 충돌도 자동으로 덮어쓴다', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string('a.txt', 'new-a'))
        ..addFile(ArchiveFile.string('b.txt', 'new-b'));
      final zipFile = File('${tempDir.path}/two.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      final destDir = Directory('${tempDir.path}/out')..createSync();
      await File('${destDir.path}/a.txt').writeAsString('old-a');
      await File('${destDir.path}/b.txt').writeAsString('old-b');

      var conflictCalls = 0;
      await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        onConflict: (conflict) async {
          conflictCalls++;
          return ConflictAction.overwriteAll;
        },
      );

      expect(conflictCalls, 1); // 두 번째 충돌부터는 물어보지 않는다.
      expect(await File('${destDir.path}/a.txt').readAsString(), 'new-a');
      expect(await File('${destDir.path}/b.txt').readAsString(), 'new-b');
    });
  });

  test('취소 토큰이 이미 취소돼 있으면 아무것도 쓰지 않는다', () async {
    final zipFile = await _writeSampleZip(tempDir);
    final destDir = Directory('${tempDir.path}/out')..createSync();
    final cancelToken = CancelToken()..cancel();

    await expectLater(
      reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        onConflict: _neverCalled,
        cancelToken: cancelToken,
      ),
      throwsA(isA<OperationCancelledException>()),
    );

    expect(await File('${destDir.path}/root.txt').exists(), isFalse);
  });
}
