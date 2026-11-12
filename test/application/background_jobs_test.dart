import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/application/background_jobs.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/compress_progress.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:dove_zip/domain/entities/extract_conflict.dart';
import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 압축·해제를 백그라운드 isolate에서 — 진행률, 충돌 묻기, 오류, 취소가 오간다.
void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('dove_zip_bg_test_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows에서 죽인 isolate가 아직 파일을 쥐고 있으면 남겨 둔다.
    }
  });

  test('압축하고 진행률을 받는다', () async {
    final a = File(p.join(dir.path, 'a.txt'))..writeAsStringSync('hello');
    final dest = Uri.file(p.join(dir.path, 'a.zip'));
    final progress = <CompressProgress>[];

    await compressInBackground(
      sources: [a.uri],
      destination: dest,
      options: const CompressionOptions(format: ArchiveFormat.zip),
      onProgress: progress.add,
    );

    final archive = ZipDecoder().decodeBytes(File(dest.toFilePath()).readAsBytesSync());
    expect(archive.files.map((f) => f.name), ['a.txt']);
    expect(progress.last.done, progress.last.total);
  });

  test('isolate 안의 예외가 그대로 넘어온다', () async {
    await expectLater(
      compressInBackground(
        sources: [(File(p.join(dir.path, 'a.txt'))..writeAsStringSync('a')).uri],
        destination: Uri.file(p.join(dir.path, 'no', 'such', 'folder', 'x.zip')),
        options: const CompressionOptions(format: ArchiveFormat.zip),
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('이미 취소돼 있으면 취소로 끝나고 만들던 파일을 남기지 않는다', () async {
    final a = File(p.join(dir.path, 'a.txt'))..writeAsStringSync('hello');
    final dest = File(p.join(dir.path, 'a.zip'));
    final token = CancelToken()..cancel();

    await expectLater(
      compressInBackground(
        sources: [a.uri],
        destination: dest.uri,
        options: const CompressionOptions(format: ArchiveFormat.zip),
        cancelToken: token,
      ),
      throwsA(isA<OperationCancelledException>()),
    );
    expect(dest.existsSync(), isFalse);
  });

  test('열고 풀다가 이름이 겹치면 UI 쪽에 묻고 그 답대로 한다', () async {
    final zip = File(p.join(dir.path, 'pack.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(Archive()..addFile(ArchiveFile.string('a.txt', 'new'))));
    File(p.join(dir.path, 'a.txt')).writeAsStringSync('old');
    final asked = <ExtractConflict>[];

    final handle = await openArchiveInBackground(zip.uri);
    final result = await extractInBackground(
      handle: handle,
      mode: ExtractDestinationMode.here,
      onConflict: (c) async {
        asked.add(c);
        return ConflictAction.overwrite;
      },
    );

    expect(result.failures, isEmpty);
    expect(asked.single.entryPath, 'a.txt');
    expect(File(p.join(dir.path, 'a.txt')).readAsStringSync(), 'new');
  });
}
