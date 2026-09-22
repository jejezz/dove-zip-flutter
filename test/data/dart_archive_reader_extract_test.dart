import 'dart:io';
import 'dart:math';

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

/// 진짜로 손상된 zip을 만든다: 첫 번째 항목("bad.txt")의 압축 스트림 바이트
/// 일부만 뒤집어서 그 항목의 로컬 헤더/파일명(따라서 중앙 디렉터리의 항목
/// 목록 자체)은 그대로 두고 압축 데이터만 깨뜨린다. 압축률이 높은 반복
/// 텍스트를 쓰면 압축 결과가 너무 작아져 손상 범위가 다음 항목까지 번질
/// 수 있어, 반복이 적은(비압축 친화적인) 내용을 넉넉한 길이로 준비해
/// 압축 결과가 충분히 커지게 한다 — 그래야 로컬 헤더(30바이트 고정 +
/// 파일명 길이) 바로 뒤 몇 바이트만 뒤집어도 다음 항목을 건드리지 않는다.
/// (자세한 근거는 이 커밋의 스크래치 조사 참고 — archive 패키지는
/// 저장(STORE) 모드에서는 CRC를 검증하지 않아 조용히 잘못된 바이트를
/// 돌려주므로, 실제로 예외가 나는 deflate 스트림 손상 쪽을 쓴다.)
String _lowRepetitionText(int length, int seed) {
  final random = Random(seed);
  return List.generate(length, (_) => String.fromCharCode(65 + random.nextInt(26))).join();
}

Future<File> _writeZipWithOneCorruptedEntry(Directory dir) async {
  final badContent = _lowRepetitionText(400, 1);
  const badName = 'bad.txt';
  final archive = Archive()
    ..addFile(ArchiveFile.string(badName, badContent))
    ..addFile(ArchiveFile.string('good.txt', 'this stays fine ' * 20));
  final bytes = ZipEncoder().encode(archive);

  // 로컬 파일 헤더 30바이트(고정) + 파일명("bad.txt" = 7바이트) + extra
  // field(0바이트) = 37바이트 뒤부터가 bad.txt의 압축 데이터 시작 지점.
  const payloadStart = 30 + badName.length;
  final corrupted = List<int>.from(bytes);
  for (var i = payloadStart + 15; i < payloadStart + 25; i++) {
    corrupted[i] ^= 0xFF;
  }

  final zipFile = File('${dir.path}/corrupted.zip');
  await zipFile.writeAsBytes(corrupted);
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

  group('손상된 항목 부분 해제(PLAN.md 1.2)', () {
    test('한 항목이 손상돼도 전체를 멈추지 않고 나머지는 정상 해제한다', () async {
      final zipFile = await _writeZipWithOneCorruptedEntry(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();

      final failures = await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        onConflict: _neverCalled,
      );

      expect(failures, hasLength(1));
      expect(failures.single.entryPath, 'bad.txt');
      expect(await File('${destDir.path}/bad.txt').exists(), isFalse);
      expect(await File('${destDir.path}/good.txt').readAsString(), 'this stays fine ' * 20);
    });

    test('손상된 항목도 진행률에는 처리됨으로 반영된다', () async {
      final zipFile = await _writeZipWithOneCorruptedEntry(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();
      final progresses = <ExtractProgress>[];

      await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        onConflict: _neverCalled,
        onProgress: progresses.add,
      );

      expect(progresses, hasLength(2));
      expect(progresses.last.done, 2);
      expect(progresses.last.total, 2);
    });

    test('전부 정상이면 빈 목록을 반환한다', () async {
      final zipFile = await _writeSampleZip(tempDir);
      final destDir = Directory('${tempDir.path}/out')..createSync();

      final failures = await reader.extractAll(
        zipFile.uri,
        destination: destDir.uri,
        onConflict: _neverCalled,
      );

      expect(failures, isEmpty);
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
