import 'dart:io';

import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/data/dart_archive_writer.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/compress_progress.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// koni_sevenz(순수 Dart, PLAN.md 3장)로 만든 7z를, 이 리포에 없는 별도
/// 구현체인 실제 `7z`(p7zip) CLI로 풀어서 진짜로 상호 호환되는지 검증한다
/// — koni_archive 프로젝트 자신이 `unzip`/`bsdtar`/`7zz`를 오라클로 쓰는
/// 것과 같은 취지. `7z`가 PATH에 없으면(CI 등) 이 그룹은 건너뛴다.
Future<bool> _has7z() async {
  try {
    final result = await Process.run('7z', ['i']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('충돌이 없어야 하는데 onConflict가 호출됨: ${conflict.entryPath}');

void main() {
  late Directory tempDir;
  const writer = DartArchiveWriter();
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_sevenzip_writer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('supports는 sevenZip을 지원한다', () {
    expect(writer.supports(ArchiveFormat.sevenZip), isTrue);
  });

  test('파일 여러 개와 폴더를 담은 7z를 만들면 우리 리더로 그대로 읽힌다', () async {
    final docsDir = Directory('${tempDir.path}/docs')..createSync();
    File('${docsDir.path}/a.txt').writeAsStringSync('hello');
    Directory('${docsDir.path}/sub').createSync();
    File('${docsDir.path}/sub/b.txt').writeAsStringSync('world');
    final destination = File('${tempDir.path}/out.7z');

    await writer.compress(
      sources: [docsDir.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.sevenZip),
    );

    expect(await destination.exists(), isTrue);

    final entries = await reader.listEntries(destination.uri);
    final names = entries.map((e) => e.pathInArchive).toSet();
    expect(names, containsAll(['docs', 'docs/a.txt', 'docs/sub', 'docs/sub/b.txt']));

    final outDir = Directory('${tempDir.path}/out')..createSync();
    await reader.extractAll(destination.uri, destination: outDir.uri, onConflict: _neverCalled);
    expect(await File('${outDir.path}/docs/a.txt').readAsString(), 'hello');
    expect(await File('${outDir.path}/docs/sub/b.txt').readAsString(), 'world');
  });

  test('진행률 콜백이 파일 개수만큼(디렉터리 제외) 호출된다', () async {
    final docsDir = Directory('${tempDir.path}/docs')..createSync();
    File('${docsDir.path}/a.txt').writeAsStringSync('hello');
    File('${docsDir.path}/b.txt').writeAsStringSync('world');
    final destination = File('${tempDir.path}/out.7z');
    final progresses = <CompressProgress>[];

    await writer.compress(
      sources: [docsDir.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.sevenZip),
      onProgress: progresses.add,
    );

    expect(progresses, hasLength(2));
    expect(progresses.last.done, 2);
    expect(progresses.last.total, 2);
  });

  test('비밀번호를 주면 AES-256으로 암호화된 7z를 만든다 (올바른 비밀번호로만 해제된다)', () async {
    final file = File('${tempDir.path}/secret.txt')..writeAsStringSync('classified');
    final destination = File('${tempDir.path}/out.7z');

    await writer.compress(
      sources: [file.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.sevenZip, password: 'hunter2'),
    );

    // 비밀번호 없이는 항목 내용을 읽을 수 없다 — 목록(이름/크기)은 헤더
    // 자체를 암호화하지 않는 한(encryptHeader) 그대로 보인다.
    final entries = await reader.listEntries(destination.uri);
    expect(entries.single.pathInArchive, 'secret.txt');
    expect(entries.single.isEncrypted, isTrue);

    await expectLater(
      reader.extractEntryToTemp(destination.uri, 'secret.txt'),
      throwsA(isA<ArchivePasswordRequiredException>()),
    );

    final tempUri = await reader.extractEntryToTemp(
      destination.uri,
      'secret.txt',
      password: 'hunter2',
    );
    expect(await File.fromUri(tempUri).readAsString(), 'classified');
  });

  test('취소 토큰이 이미 취소돼 있으면 결과 파일을 만들지 않는다', () async {
    final file = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
    final destination = File('${tempDir.path}/out.7z');
    final cancelToken = CancelToken()..cancel();

    await expectLater(
      writer.compress(
        sources: [file.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.sevenZip),
        cancelToken: cancelToken,
      ),
      throwsA(isA<OperationCancelledException>()),
    );

    expect(await destination.exists(), isFalse);
  });

  test('분할 압축도 지원한다(다른 포맷과 동일한 후처리)', () async {
    final file = File('${tempDir.path}/a.txt')..writeAsStringSync('y' * 2000);
    final destination = File('${tempDir.path}/out.7z');

    await writer.compress(
      sources: [file.uri],
      destination: destination.uri,
      options: const CompressionOptions(
        format: ArchiveFormat.sevenZip,
        level: CompressionLevel.store,
        splitVolumeBytes: 100,
      ),
    );

    expect(await destination.exists(), isFalse);
    expect(await File('${destination.path}.001').exists(), isTrue);
    expect(await File('${destination.path}.002').exists(), isTrue);

    final entries = await reader.listEntries(File('${destination.path}.001').uri);
    expect(entries.single.pathInArchive, 'a.txt');
  });

  group('실제 7z(p7zip) CLI와의 상호 호환', () {
    late bool has7z;

    setUpAll(() async {
      has7z = await _has7z();
    });

    test('koni_sevenz가 만든 7z를 실제 7z 도구로 풀 수 있다', () async {
      if (!has7z) {
        markTestSkipped('이 환경에 7z(p7zip)가 설치돼 있지 않음');
        return;
      }

      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      File('${docsDir.path}/a.txt').writeAsStringSync('hello, koni!');
      File('${docsDir.path}/data.bin').writeAsBytesSync(
        List.generate(5000, (i) => (i * 31) & 0xFF),
      );
      final destination = File('${tempDir.path}/out.7z');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.sevenZip),
      );

      final extractDir = Directory('${tempDir.path}/extracted')..createSync();
      final result = await Process.run('7z', [
        'x',
        destination.path,
        '-o${extractDir.path}',
        '-y',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      expect(
        await File('${extractDir.path}/docs/a.txt').readAsString(),
        'hello, koni!',
      );
      expect(
        await File('${extractDir.path}/docs/data.bin').readAsBytes(),
        List.generate(5000, (i) => (i * 31) & 0xFF),
      );
    });

    test('실제 7z 도구가 만든 7z를 koni_sevenz 리더로 풀 수 있다', () async {
      if (!has7z) {
        markTestSkipped('이 환경에 7z(p7zip)가 설치돼 있지 않음');
        return;
      }

      final srcDir = Directory('${tempDir.path}/src')..createSync();
      File('${srcDir.path}/note.txt').writeAsStringSync('made by real 7z');
      final archivePath = '${tempDir.path}/made_by_7z.7z';

      // 상대 경로로 실행해 7z가 절대 경로 구조를 통째로 담지 않고
      // "note.txt" 하나만 담게 한다.
      final result = await Process.run(
        '7z',
        ['a', archivePath, 'note.txt'],
        workingDirectory: srcDir.path,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      final entries = await reader.listEntries(File(archivePath).uri);
      expect(entries.single.pathInArchive, 'note.txt');

      final outDir = Directory('${tempDir.path}/out')..createSync();
      await reader.extractAll(
        File(archivePath).uri,
        destination: outDir.uri,
        onConflict: _neverCalled,
      );
      expect(await File('${outDir.path}/note.txt').readAsString(), 'made by real 7z');
    });

    test('실제 7z 도구가 비밀번호로 암호화한 7z를 koni_sevenz 리더로 풀 수 있다', () async {
      if (!has7z) {
        markTestSkipped('이 환경에 7z(p7zip)가 설치돼 있지 않음');
        return;
      }

      final srcDir = Directory('${tempDir.path}/src2')..createSync();
      File('${srcDir.path}/secret.txt').writeAsStringSync('shh');
      final archivePath = '${tempDir.path}/made_by_7z_enc.7z';

      final result = await Process.run(
        '7z',
        ['a', '-psecret', archivePath, 'secret.txt'],
        workingDirectory: srcDir.path,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

      await expectLater(
        reader.extractEntryToTemp(File(archivePath).uri, 'secret.txt'),
        throwsA(isA<ArchivePasswordRequiredException>()),
      );

      final tempUri = await reader.extractEntryToTemp(
        File(archivePath).uri,
        'secret.txt',
        password: 'secret',
      );
      expect(await File.fromUri(tempUri).readAsString(), 'shh');
    });
  });
}
