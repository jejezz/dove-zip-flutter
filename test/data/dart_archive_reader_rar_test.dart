import 'dart:io';

import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// `test/fixtures/rar/*.rar`는 koni_archive 프로젝트(MIT, PLAN.md 3장)의
/// 실제 RAR 7.23 도구로 만든 테스트 픽스처를 그대로 가져왔다(출처:
/// `koni_rar/test/fixtures/rar/`) — 우리가 손으로 만들 수 없는 진짜 RAR5
/// 바이트를 검증하기 위해서다. 정확한 멤버/내용은 koni_archive의
/// `tool/generate_fixtures.dart`(`RarFixtureSet`)를 참고해 그대로 옮겼다.
Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('충돌이 없어야 하는데 onConflict가 호출됨: ${conflict.entryPath}');

Uri _fixture(String name) => File('test/fixtures/rar/$name').absolute.uri;

List<int> _nestedDeepDataBinBytes() =>
    List.generate(100000, (i) => ((i * 7) ^ (i >> 3)) & 0xFF);

void main() {
  late Directory tempDir;
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_rar_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('supports는 rar를 지원한다', () {
    expect(reader.supports(ArchiveFormat.rar), isTrue);
  });

  test('normal.rar(RAR5, -m3)의 목록을 정확히 읽는다', () async {
    final entries = await reader.listEntries(_fixture('normal.rar'));
    final byPath = {for (final e in entries) e.pathInArchive: e};

    expect(byPath.keys, containsAll(['hello.txt', 'empty.txt', '日本語/ページ001.txt']));
    expect(byPath['hello.txt']!.isDirectory, isFalse);
    expect(byPath['hello.txt']!.uncompressedSize, 'hello, rar!\n'.length);
    expect(byPath['empty.txt']!.uncompressedSize, 0);
    expect(byPath['日本語/ページ001.txt']!.uncompressedSize, 'unicode page\n'.length);
    // nested/deep/data.bin가 있으므로 nested, nested/deep 디렉터리 엔트리도
    // (파일 경로로 유추되든, 실제 엔트리로 있든) 최종적으로 확인 가능해야
    // 한다 — 여기서는 파일 자체만 확인한다.
    expect(byPath['nested/deep/data.bin']!.uncompressedSize, 100000);
  });

  test('normal.rar를 해제하면 실제 RAR 도구로 담은 내용과 바이트가 정확히 같다', () async {
    final destDir = Directory('${tempDir.path}/out')..createSync();

    await reader.extractAll(
      _fixture('normal.rar'),
      destination: destDir.uri,
      onConflict: _neverCalled,
    );

    expect(await File('${destDir.path}/hello.txt').readAsString(), 'hello, rar!\n');
    expect(await File('${destDir.path}/empty.txt').readAsBytes(), isEmpty);
    expect(
      await File('${destDir.path}/日本語/ページ001.txt').readAsString(),
      'unicode page\n',
    );
    expect(
      await File('${destDir.path}/nested/deep/data.bin').readAsBytes(),
      _nestedDeepDataBinBytes(),
    );
  });

  test('extractEntryToTemp로 항목 하나만 꺼낼 수 있다', () async {
    final tempUri = await reader.extractEntryToTemp(_fixture('normal.rar'), 'hello.txt');
    expect(await File.fromUri(tempUri).readAsString(), 'hello, rar!\n');
  });

  test('synthetic_comic.rar(중첩 폴더 하나로 구성된 코믹 아카이브 — 원본 확장자는 .cbr)를 읽는다',
      () async {
    // koni_archive 픽스처 원본 이름은 synthetic_comic.cbr이지만, 이
    // 앱의 FormatRegistry는 아직 cbr 확장자를 rar로 인식하지 않는다(별도
    // 스코프) — 내용 검증이 목적이라 .rar로 바꿔서 가져왔다.
    final entries = await reader.listEntries(_fixture('synthetic_comic.rar'));
    final paths = entries.map((e) => e.pathInArchive).toSet();

    expect(
      paths,
      containsAll(['comic/ComicInfo.xml', 'comic/page001.png', 'comic/page002.png', 'comic/page003.png']),
    );

    final destDir = Directory('${tempDir.path}/comic_out')..createSync();
    await reader.extractAll(
      _fixture('synthetic_comic.rar'),
      destination: destDir.uri,
      onConflict: _neverCalled,
    );
    expect(
      await File('${destDir.path}/comic/ComicInfo.xml').readAsString(),
      '<ComicInfo><Series>Synthetic</Series></ComicInfo>\n',
    );
  });

  group('비밀번호로 보호된 RAR5', () {
    test('비밀번호 없이 열면 비밀번호 필요 예외를 던진다', () async {
      await expectLater(
        reader.extractEntryToTemp(_fixture('encrypted.rar'), 'hello.txt'),
        throwsA(isA<ArchivePasswordRequiredException>()),
      );
    });

    test('올바른 비밀번호로 열면 원본 내용 그대로 해제된다', () async {
      final tempUri = await reader.extractEntryToTemp(
        _fixture('encrypted.rar'),
        'hello.txt',
        password: 'secret',
      );
      expect(await File.fromUri(tempUri).readAsString(), 'hello, rar!\n');
    });

    test('틀린 비밀번호로 열면 비밀번호 필요 예외를 던진다', () async {
      await expectLater(
        reader.extractEntryToTemp(_fixture('encrypted.rar'), 'hello.txt', password: 'wrong'),
        throwsA(isA<ArchivePasswordRequiredException>()),
      );
    });

    test('헤더까지 암호화된(-hp) RAR도 비밀번호를 주면 목록을 읽을 수 있다', () async {
      final entries = await reader.listEntries(
        _fixture('encrypted_headers.rar'),
        password: 'secret',
      );
      expect(entries.single.pathInArchive, 'hello.txt');
    });

    test('헤더까지 암호화된(-hp) RAR는 비밀번호 없이는 목록조차 읽을 수 없다', () async {
      await expectLater(
        reader.listEntries(_fixture('encrypted_headers.rar')),
        throwsA(isA<ArchivePasswordRequiredException>()),
      );
    });
  });
}
