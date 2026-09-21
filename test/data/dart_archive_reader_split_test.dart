import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/data/dart_archive_reader.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

/// PLAN.md 1.3 "분할 압축"의 읽기 쪽 — `DartArchiveWriter`가 실제로 만드는
/// 조각 파일 형식(`sample.zip.001`, `sample.zip.002`, ...)을 여기서는 직접
/// 만들어 리더만 독립적으로 검증한다(쓰기 쪽은 dart_archive_writer_test.dart).
Future<List<File>> _writeSplitZip(
  Directory dir, {
  required Map<String, String> entries,
  required int volumeBytes,
  String baseName = 'sample.zip',
}) async {
  final archive = Archive();
  for (final MapEntry(:key, :value) in entries.entries) {
    archive.addFile(ArchiveFile.string(key, value));
  }
  final bytes = ZipEncoder().encode(archive);

  final totalParts = (bytes.length / volumeBytes).ceil();
  final parts = <File>[];
  for (var index = 0; index < totalParts; index++) {
    final start = index * volumeBytes;
    final end = (start + volumeBytes).clamp(0, bytes.length);
    final partNumber = (index + 1).toString().padLeft(3, '0');
    final part = File('${dir.path}/$baseName.$partNumber');
    await part.writeAsBytes(bytes.sublist(start, end));
    parts.add(part);
  }
  return parts;
}

Future<ConflictAction> _neverCalled(ExtractConflict conflict) =>
    throw StateError('충돌이 없어야 하는데 onConflict가 호출됨: ${conflict.entryPath}');

void main() {
  late Directory tempDir;
  const reader = DartArchiveReader();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dove_zip_split_read_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('listEntries는 어떤 조각을 골라도 전체 조각을 이어붙여 읽는다', () async {
    final parts = await _writeSplitZip(
      tempDir,
      entries: {'a.txt': 'hello', 'b.txt': 'world'},
      volumeBytes: 40,
    );
    expect(parts.length, greaterThan(1), reason: '테스트가 실제로 여러 조각을 만들었는지 확인');

    for (final chosenPart in parts) {
      final entries = await reader.listEntries(chosenPart.uri);
      expect(entries.map((e) => e.pathInArchive).toSet(), {'a.txt', 'b.txt'});
    }
  });

  test('extractAll은 조각을 이어붙여 원본 내용 그대로 해제한다', () async {
    final parts = await _writeSplitZip(
      tempDir,
      entries: {'a.txt': 'hello', 'b.txt': 'world'},
      volumeBytes: 40,
    );
    final destDir = Directory('${tempDir.path}/out')..createSync();

    await reader.extractAll(
      parts.first.uri,
      destination: destDir.uri,
      onConflict: _neverCalled,
    );

    expect(await File('${destDir.path}/a.txt').readAsString(), 'hello');
    expect(await File('${destDir.path}/b.txt').readAsString(), 'world');
  });

  test('extractEntryToTemp도 분할 조각을 이어붙여 항목 하나를 꺼낸다', () async {
    final parts = await _writeSplitZip(
      tempDir,
      entries: {'a.txt': 'hello'},
      volumeBytes: 30,
    );

    final tempUri = await reader.extractEntryToTemp(parts.last.uri, 'a.txt');
    expect(await File.fromUri(tempUri).readAsString(), 'hello');
  });

  test('중간 조각이 없으면 명확한 에러를 던진다', () async {
    final parts = await _writeSplitZip(
      tempDir,
      entries: {'a.txt': 'hello', 'b.txt': 'world'},
      volumeBytes: 40,
    );
    expect(parts.length, greaterThan(2));
    await parts[1].delete(); // 가운데 조각(.002)을 지워 구멍을 낸다

    await expectLater(
      reader.listEntries(parts.first.uri),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'message',
          contains('조각'),
        ),
      ),
    );
  });

  test('조각을 전부 지우면 찾을 수 없다는 에러를 던진다', () async {
    final parts = await _writeSplitZip(
      tempDir,
      entries: {'a.txt': 'hello'},
      volumeBytes: 40,
    );
    final chosenUri = parts.first.uri;
    for (final part in parts) {
      await part.delete();
    }

    await expectLater(
      reader.listEntries(chosenUri),
      throwsA(isA<ArgumentError>()),
    );
  });
}
