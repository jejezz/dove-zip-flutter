import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/data/dart_archive_writer.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/compress_progress.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  const writer = DartArchiveWriter();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_writer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('supports는 zip/tar 계열/gzip/bzip2/xz/7z를 지원하고 그 외는 아니다', () {
    expect(writer.supports(ArchiveFormat.zip), isTrue);
    expect(writer.supports(ArchiveFormat.tar), isTrue);
    expect(writer.supports(ArchiveFormat.tarGz), isTrue);
    expect(writer.supports(ArchiveFormat.tarBz2), isTrue);
    expect(writer.supports(ArchiveFormat.tarXz), isTrue);
    expect(writer.supports(ArchiveFormat.gzip), isTrue);
    expect(writer.supports(ArchiveFormat.bzip2), isTrue);
    expect(writer.supports(ArchiveFormat.xz), isTrue);
    expect(writer.supports(ArchiveFormat.sevenZip), isTrue);
    // RAR 쓰기는 라이선스상 불가능(PLAN.md 3장 RAR 정책), zstd는 koni
    // 생태계가 아직 pub.dev에 배포하지 않아 보류.
    expect(writer.supports(ArchiveFormat.zstd), isFalse);
    expect(writer.supports(ArchiveFormat.rar), isFalse);
  });

  test('파일 여러 개를 압축하면 압축파일 최상위에 그대로 들어간다', () async {
    final fileA = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
    final fileB = File('${tempDir.path}/b.txt')..writeAsStringSync('world');
    final destination = File('${tempDir.path}/out.zip');

    await writer.compress(
      sources: [fileA.uri, fileB.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.zip),
    );

    final archive = ZipDecoder().decodeBytes(await destination.readAsBytes());
    expect(archive.map((f) => f.name).toSet(), {'a.txt', 'b.txt'});
    expect(archive.findFile('a.txt')!.content, 'hello'.codeUnits);
  });

  test('폴더를 압축하면 그 폴더 이름이 압축파일 안 최상위 폴더가 된다', () async {
    final docsDir = Directory('${tempDir.path}/docs')..createSync();
    File('${docsDir.path}/a.txt').writeAsStringSync('hello');
    Directory('${docsDir.path}/sub').createSync();
    File('${docsDir.path}/sub/b.txt').writeAsStringSync('world');
    final destination = File('${tempDir.path}/out.zip');

    await writer.compress(
      sources: [docsDir.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.zip),
    );

    final archive = ZipDecoder().decodeBytes(await destination.readAsBytes());
    final names = archive.map((f) => f.name).toSet();
    expect(names, containsAll(['docs/', 'docs/a.txt', 'docs/sub/', 'docs/sub/b.txt']));
  });

  test('저장(store) 레벨은 압축하지 않고 그대로 담는다', () async {
    final file = File('${tempDir.path}/a.txt')..writeAsStringSync('hello' * 100);
    final destination = File('${tempDir.path}/out.zip');

    await writer.compress(
      sources: [file.uri],
      destination: destination.uri,
      options: const CompressionOptions(
        format: ArchiveFormat.zip,
        level: CompressionLevel.store,
      ),
    );

    final archive = ZipDecoder().decodeBytes(await destination.readAsBytes());
    final entry = archive.findFile('a.txt')!;
    expect(entry.content.length, 'hello'.length * 100);
    expect(entry.rawContent!.length, entry.size); // 압축 안 됐으니 원본 크기와 같음
  });

  test('진행률 콜백이 파일 개수만큼(디렉터리 제외) 호출된다', () async {
    final docsDir = Directory('${tempDir.path}/docs')..createSync();
    File('${docsDir.path}/a.txt').writeAsStringSync('hello');
    File('${docsDir.path}/b.txt').writeAsStringSync('world');
    final destination = File('${tempDir.path}/out.zip');
    final progresses = <CompressProgress>[];

    await writer.compress(
      sources: [docsDir.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.zip),
      onProgress: progresses.add,
    );

    expect(progresses, hasLength(2));
    expect(progresses.last.done, 2);
    expect(progresses.last.total, 2);
  });

  test('비밀번호를 주면 AES로 암호화된 zip을 만든다 (올바른 비밀번호로만 해제된다)', () async {
    final file = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
    final destination = File('${tempDir.path}/out.zip');

    await writer.compress(
      sources: [file.uri],
      destination: destination.uri,
      options: const CompressionOptions(format: ArchiveFormat.zip, password: 'secret'),
    );

    final bytes = await destination.readAsBytes();
    expect(
      () => ZipDecoder().decodeBytes(bytes).findFile('a.txt')!.content,
      throwsA(anything), // 비밀번호 없이는 복호화 실패
    );
    final decrypted =
        ZipDecoder().decodeBytes(bytes, password: 'secret').findFile('a.txt')!;
    expect(decrypted.content, 'hello'.codeUnits);
  });

  group('분할 압축 (PLAN.md 1.3, DoveZip 자체 스킴)', () {
    test('splitVolumeBytes를 주면 지정 크기로 조각 파일을 만들고 원래 이름의 파일은 안 만든다', () async {
      final file = File('${tempDir.path}/a.txt')..writeAsStringSync('x' * 1000);
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [file.uri],
        destination: destination.uri,
        options: const CompressionOptions(
          format: ArchiveFormat.zip,
          level: CompressionLevel.store,
          splitVolumeBytes: 300,
        ),
      );

      expect(await destination.exists(), isFalse);

      final part1 = File('${destination.path}.001');
      final part2 = File('${destination.path}.002');
      final part3 = File('${destination.path}.003');
      final part4 = File('${destination.path}.004');
      for (final part in [part1, part2, part3, part4]) {
        expect(await part.exists(), isTrue, reason: '${part.path} 없음');
      }
      expect(await File('${destination.path}.005').exists(), isFalse);

      // 마지막 조각을 빼고는 전부 지정 크기와 정확히 같아야 한다.
      expect(await part1.length(), 300);
      expect(await part2.length(), 300);
      expect(await part3.length(), 300);
      expect(await part4.length(), lessThanOrEqualTo(300));

      // 조각을 번호 순서대로 이어붙이면 분할 전과 똑같은 zip 바이트가 된다.
      final concatenated = BytesBuilder();
      for (final part in [part1, part2, part3, part4]) {
        concatenated.add(await part.readAsBytes());
      }
      final rebuilt = ZipDecoder().decodeBytes(concatenated.takeBytes());
      expect(rebuilt.findFile('a.txt')!.content, ('x' * 1000).codeUnits);
    });

    test('조각 수가 999개 이하면 조각 번호는 3자리로 0을 채운다', () async {
      final file = File('${tempDir.path}/a.txt')..writeAsStringSync('ab');
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [file.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.zip, splitVolumeBytes: 1000000),
      );

      expect(await File('${destination.path}.001').exists(), isTrue);
      expect(await File('${destination.path}.01').exists(), isFalse);
      expect(await File('${destination.path}.1').exists(), isFalse);
    });

    test('gzip처럼 파일 하나만 감싸는 포맷도 분할할 수 있다', () async {
      // gzip은 반복되는 내용을 잘 압축해 버려 조각 수를 미리 계산하기
      // 어렵다 — 무작위 바이트를 써서 거의 압축되지 않게 만든다.
      final random = Random(1);
      final randomBytes = List<int>.generate(2000, (_) => random.nextInt(256));
      final file = File('${tempDir.path}/a.bin')..writeAsBytesSync(randomBytes);
      final destination = File('${tempDir.path}/out.gz');

      await writer.compress(
        sources: [file.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.gzip, splitVolumeBytes: 500),
      );

      expect(await destination.exists(), isFalse);
      expect(await File('${destination.path}.001').exists(), isTrue);
      expect(await File('${destination.path}.002').exists(), isTrue);

      final concatenated = BytesBuilder();
      var index = 1;
      while (true) {
        final part = File('${destination.path}.${index.toString().padLeft(3, '0')}');
        if (!await part.exists()) break;
        concatenated.add(await part.readAsBytes());
        index++;
      }
      expect(GZipDecoder().decodeBytes(concatenated.takeBytes()), randomBytes);
    });

    test('분할 볼륨 크기가 0 이하면 에러를 던진다', () async {
      final file = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
      final destination = File('${tempDir.path}/out.zip');

      await expectLater(
        writer.compress(
          sources: [file.uri],
          destination: destination.uri,
          options: const CompressionOptions(format: ArchiveFormat.zip, splitVolumeBytes: 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('파일 필터 (PLAN.md 1.3 "압축 시 파일 필터")', () {
    test('excludedExtensions에 있는 확장자는 폴더 압축에서 제외된다', () async {
      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      File('${docsDir.path}/a.txt').writeAsStringSync('hello');
      File('${docsDir.path}/b.tmp').writeAsStringSync('temp');
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(
          format: ArchiveFormat.zip,
          excludedExtensions: {'tmp'},
        ),
      );

      final names =
          ZipDecoder().decodeBytes(await destination.readAsBytes()).map((f) => f.name).toSet();
      expect(names, contains('docs/a.txt'));
      expect(names, isNot(contains('docs/b.tmp')));
    });

    test('제외 확장자는 앞의 점과 대소문자를 무시하고 비교한다', () async {
      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      File('${docsDir.path}/a.LOG').writeAsStringSync('log');
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(
          format: ArchiveFormat.zip,
          excludedExtensions: {'.log'}, // 점을 붙여 넘겨도 동작해야 한다
        ),
      );

      final names =
          ZipDecoder().decodeBytes(await destination.readAsBytes()).map((f) => f.name).toSet();
      expect(names, isNot(contains('docs/a.LOG')));
    });

    test('확장자가 없는 파일은 필터에 걸리지 않는다', () async {
      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      File('${docsDir.path}/Makefile').writeAsStringSync('all:');
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(
          format: ArchiveFormat.zip,
          excludedExtensions: {'tmp'},
        ),
      );

      final names =
          ZipDecoder().decodeBytes(await destination.readAsBytes()).map((f) => f.name).toSet();
      expect(names, contains('docs/Makefile'));
    });

    test('followSymlinks 기본값(false)이면 폴더 안 심볼릭 링크를 건너뛴다', () async {
      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      final realFile = File('${docsDir.path}/real.txt')..writeAsStringSync('real content');
      Link('${docsDir.path}/link.txt').createSync(realFile.path);
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.zip),
      );

      final names =
          ZipDecoder().decodeBytes(await destination.readAsBytes()).map((f) => f.name).toSet();
      expect(names, contains('docs/real.txt'));
      expect(names, isNot(contains('docs/link.txt')));
    });

    test('followSymlinks: true면 폴더 안 심볼릭 링크가 가리키는 실제 내용을 담는다', () async {
      final docsDir = Directory('${tempDir.path}/docs')..createSync();
      final realFile = File('${docsDir.path}/real.txt')..writeAsStringSync('real content');
      Link('${docsDir.path}/link.txt').createSync(realFile.path);
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [docsDir.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.zip, followSymlinks: true),
      );

      final archive = ZipDecoder().decodeBytes(await destination.readAsBytes());
      final names = archive.map((f) => f.name).toSet();
      expect(names, contains('docs/real.txt'));
      expect(names, contains('docs/link.txt'));
      expect(archive.findFile('docs/link.txt')!.content, 'real content'.codeUnits);
    });

    test('최상위 소스 자체가 심볼릭 링크면 followSymlinks: true일 때만 포함된다', () async {
      final realFile = File('${tempDir.path}/real.txt')..writeAsStringSync('real content');
      final linkFile = Link('${tempDir.path}/link.txt')..createSync(realFile.path);
      final destination = File('${tempDir.path}/out.zip');

      await writer.compress(
        sources: [Uri.file(linkFile.path)],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.zip, followSymlinks: true),
      );

      final archive = ZipDecoder().decodeBytes(await destination.readAsBytes());
      expect(archive.findFile('link.txt')!.content, 'real content'.codeUnits);
    });
  });

  test('취소 토큰이 이미 취소돼 있으면 결과 파일을 만들지 않는다', () async {
    final file = File('${tempDir.path}/a.txt')..writeAsStringSync('hello');
    final destination = File('${tempDir.path}/out.zip');
    final cancelToken = CancelToken()..cancel();

    await expectLater(
      writer.compress(
        sources: [file.uri],
        destination: destination.uri,
        options: const CompressionOptions(format: ArchiveFormat.zip),
        cancelToken: cancelToken,
      ),
      throwsA(isA<OperationCancelledException>()),
    );

    expect(await destination.exists(), isFalse);
  });
}
