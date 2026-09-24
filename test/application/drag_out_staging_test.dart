import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dove_zip/application/drag_out_staging.dart';
import 'package:dove_zip/application/usecases/extract_entries.dart';
import 'package:dove_zip/application/usecases/open_archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/archive_handle.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 넘어온 [entryPaths]를 기록하고, 실제 리더처럼 [destination] 아래에 압축
/// 안 경로 그대로 빈 파일/폴더를 만든다. 해제 자체의 정확성은
/// dart_archive_reader_extract_test.dart가 맡는다.
class _WritingReader implements ArchiveReader {
  List<String>? lastEntryPaths;
  String? lastPassword;
  List<ExtractFailure> failures = const [];
  int calls = 0;

  @override
  bool supports(ArchiveFormat format) => true;

  @override
  Future<List<ArchiveEntry>> listEntries(Uri archiveLocation, {String? password}) async => [];

  @override
  Future<List<ExtractFailure>> extractAll(
    Uri archiveLocation, {
    required Uri destination,
    List<String>? entryPaths,
    String? password,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    calls++;
    lastEntryPaths = entryPaths;
    lastPassword = password;
    for (final path in entryPaths ?? const <String>[]) {
      cancelToken?.throwIfCancelled();
      final target = p.joinAll([destination.toFilePath(), ...path.split('/').where((s) => s.isNotEmpty)]);
      if (path.endsWith('/')) {
        await Directory(target).create(recursive: true);
      } else {
        await File(target).create(recursive: true);
      }
    }
    return failures;
  }

  @override
  Future<Uri> extractEntryToTemp(Uri archiveLocation, String entryPath, {String? password}) =>
      throw UnimplementedError('이 테스트에서는 쓰지 않음');
}

void main() {
  late Directory root;
  late _WritingReader reader;
  late DragOutStaging staging;

  final handle = ArchiveHandle(
    location: Uri.file('/tmp/photos.zip'),
    format: ArchiveFormat.zip,
    entries: const [
      ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false, uncompressedSize: 10),
      ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
      ArchiveEntry(pathInArchive: 'docs/c.txt', isDirectory: false, uncompressedSize: 20),
      ArchiveEntry(pathInArchive: 'docs/sub/d.txt', isDirectory: false, uncompressedSize: 30),
      ArchiveEntry(pathInArchive: 'secret.txt', isDirectory: false, isEncrypted: true),
      ArchiveEntry(pathInArchive: 'huge.bin', isDirectory: false, uncompressedSize: DragOutStaging.maxBytes + 1),
    ],
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dove_zip_drag_out_test_');
    reader = _WritingReader();
    staging = DragOutStaging(extractEntries: ExtractEntries(reader), rootPath: root.path);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  List<Directory> sessionDirs() => root.listSync().whereType<Directory>().toList();

  test('풀린 파일 하나의 경로를 돌려준다', () async {
    final stage = await staging.prepare(handle: handle, selectedPaths: {'a.txt'});

    expect(reader.lastEntryPaths, ['a.txt']);
    expect(stage.paths, [p.join(stage.directory.path, 'a.txt')]);
    expect(File(stage.paths.single).existsSync(), isTrue);
    expect(p.isWithin(root.path, stage.directory.path), isTrue);
  });

  test('하위 폴더의 항목은 압축 안 경로 그대로 풀고 그 항목만 넘긴다', () async {
    final stage = await staging.prepare(handle: handle, selectedPaths: {'docs/c.txt'});

    expect(stage.paths, [p.join(stage.directory.path, 'docs', 'c.txt')]);
    expect(File(stage.paths.single).existsSync(), isTrue);
  });

  test('폴더는 하위 전부를 풀고, 함께 고른 안쪽 항목은 따로 넘기지 않는다', () async {
    final stage = await staging.prepare(handle: handle, selectedPaths: {'docs', 'docs/c.txt', 'a.txt'});

    expect(reader.lastEntryPaths, unorderedEquals(['a.txt', 'docs/', 'docs/c.txt', 'docs/sub/d.txt']));
    expect(
      stage.paths,
      unorderedEquals([p.join(stage.directory.path, 'docs'), p.join(stage.directory.path, 'a.txt')]),
    );
    expect(File(p.join(stage.directory.path, 'docs', 'sub', 'd.txt')).existsSync(), isTrue);
  });

  test('너무 크면 풀기 전에 거절한다', () async {
    await expectLater(
      staging.prepare(handle: handle, selectedPaths: {'huge.bin'}),
      throwsA(isA<DragOutTooLargeException>()),
    );
    expect(reader.calls, 0);
  });

  test('암호화된 항목인데 비밀번호가 없으면 풀기 전에 비밀번호 예외를 던진다', () async {
    await expectLater(
      staging.prepare(handle: handle, selectedPaths: {'secret.txt'}),
      throwsA(isA<ArchivePasswordRequiredException>()),
    );
    expect(reader.calls, 0);
  });

  test('비밀번호가 있으면 그대로 넘겨 푼다', () async {
    await staging.prepare(handle: handle, selectedPaths: {'secret.txt'}, password: 'pw');

    expect(reader.lastPassword, 'pw');
  });

  test('손상된 항목이 있으면 실패하고 세션 폴더를 지운다', () async {
    reader.failures = const [ExtractFailure(entryPath: 'a.txt', message: '깨짐')];

    await expectLater(
      staging.prepare(handle: handle, selectedPaths: {'a.txt'}),
      throwsA(isA<DragOutExtractFailedException>()),
    );
    expect(sessionDirs(), isEmpty);
  });

  test('취소되면 취소 예외를 그대로 던지고 세션 폴더를 지운다', () async {
    final token = CancelToken()..cancel();

    await expectLater(
      staging.prepare(handle: handle, selectedPaths: {'a.txt'}, cancelToken: token),
      throwsA(isA<OperationCancelledException>()),
    );
    expect(sessionDirs(), isEmpty);
  });

  test('discard는 세션 폴더를 지운다', () async {
    final stage = await staging.prepare(handle: handle, selectedPaths: {'a.txt'});
    await stage.discard();

    expect(stage.directory.existsSync(), isFalse);
  });

  test('cleanupStale은 오래된 세션 폴더만 지운다', () async {
    await staging.prepare(handle: handle, selectedPaths: {'a.txt'});

    await staging.cleanupStale();
    expect(sessionDirs(), hasLength(1));

    await staging.cleanupStale(now: DateTime.now().add(DragOutStaging.staleAfter * 2));
    expect(sessionDirs(), isEmpty);
  });

  test('실제 zip에서 폴더와 파일을 끌어낼 경로에 내용 그대로 푼다', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.directory('docs/'))
      ..addFile(ArchiveFile.string('docs/a.txt', 'hello'))
      ..addFile(ArchiveFile.string('root.txt', 'world'));
    final zipFile = File(p.join(root.path, 'sample.zip'));
    await zipFile.writeAsBytes(ZipEncoder().encode(archive));
    final realHandle = await const OpenArchive().call(zipFile.uri);
    final realStaging = DragOutStaging(rootPath: p.join(root.path, 'staging'));

    final stage = await realStaging.prepare(handle: realHandle, selectedPaths: {'docs', 'root.txt'});

    expect(
      stage.paths,
      unorderedEquals([p.join(stage.directory.path, 'docs'), p.join(stage.directory.path, 'root.txt')]),
    );
    expect(File(p.join(stage.directory.path, 'docs', 'a.txt')).readAsStringSync(), 'hello');
    expect(File(p.join(stage.directory.path, 'root.txt')).readAsStringSync(), 'world');
  });
}
