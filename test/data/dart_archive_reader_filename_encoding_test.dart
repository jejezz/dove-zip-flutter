import 'dart:io';

import 'package:dove_zip/core/encoding/filename_encoding.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 한국어 Windows 탐색기가 만든 것과 같은 — UTF-8 플래그 없이 CP949 바이트로
/// 이름이 들어간 zip (한글/, 한글/파일.txt, 안녕.txt).
final _fixture = Uri.file(
  '${Directory.current.path}/test/fixtures/zip/cp949_names.zip',
);

void main() {
  const reader = DartArchiveReader();

  test('자동 감지: CP949 한글 파일명을 고쳐 읽는다', () async {
    final entries = await reader.listEntries(_fixture);
    expect(entries.map((e) => e.pathInArchive).toSet(), {
      '한글/',
      '한글/파일.txt',
      '안녕.txt',
    });
  });

  test('UTF-8로 지정하면 고치지 않는다(깨진 이름 그대로)', () async {
    final entries = await reader.listEntries(
      _fixture,
      filenameEncoding: FilenameEncoding.utf8,
    );
    expect(entries.map((e) => e.pathInArchive), isNot(contains('안녕.txt')));
  });

  test('CP949로 지정해도 같은 결과', () async {
    final entries = await reader.listEntries(
      _fixture,
      filenameEncoding: FilenameEncoding.cp949,
    );
    expect(entries.map((e) => e.pathInArchive), contains('안녕.txt'));
  });

  test('해제하면 고쳐진 이름으로 파일이 만들어진다', () async {
    final temp = await Directory.systemTemp.createTemp('dove_zip_cp949_');
    addTearDown(() => temp.delete(recursive: true));
    await reader.extractAll(
      _fixture,
      destination: temp.uri,
      onConflict: (_) async => throw StateError('no conflict expected'),
    );
    expect(File('${temp.path}/한글/파일.txt').readAsStringSync(), 'hi');
    expect(File('${temp.path}/안녕.txt').readAsStringSync(), 'hello');
  });

  test('미리보기 임시 추출도 고쳐진 경로로 찾는다', () async {
    final uri = await reader.extractEntryToTemp(_fixture, '안녕.txt');
    expect(File.fromUri(uri).readAsStringSync(), 'hello');
  });
}
