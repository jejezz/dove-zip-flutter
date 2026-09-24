import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/cancel_token.dart';
import '../domain/entities/archive_handle.dart';
import '../domain/entities/extract_conflict.dart';
import '../domain/entities/extract_destination_mode.dart';
import '../domain/entities/extract_failure.dart';
import '../domain/repositories/archive_reader.dart'
    show ArchivePasswordRequiredException;
import 'archive_browser_entries.dart';
import 'usecases/extract_entries.dart';

/// 끌어내려는 항목의 원본 크기 합이 [DragOutStaging.maxBytes]를 넘을 때.
/// 창 밖으로 나가기 전에 다 풀지 못할 가능성이 커서 아예 시작하지 않는다.
class DragOutTooLargeException implements Exception {
  const DragOutTooLargeException(this.totalBytes);

  final int totalBytes;

  @override
  String toString() => '끌어내기에는 너무 큽니다: $totalBytes 바이트';
}

/// 임시 폴더로 푸는 중 손상된 항목이 있었을 때. 일부만 넘기면 사용자가
/// 빠진 파일을 알아채기 어려우므로 끌어내기 자체를 포기한다.
class DragOutExtractFailedException implements Exception {
  const DragOutExtractFailedException(this.failures);

  final List<ExtractFailure> failures;

  @override
  String toString() =>
      failures.map((f) => '${f.entryPath}: ${f.message}').join('\n');
}

/// [DragOutStaging.prepare]가 만든 임시 복사본 하나.
class DragOutStage {
  DragOutStage(this.directory, this.paths);

  /// 이번 끌어내기 전용 세션 폴더.
  final Directory directory;

  /// OS 드래그로 넘길 최상위 파일/폴더의 절대 경로.
  final List<String> paths;

  /// 세션 폴더를 지운다. 대상 앱이 아직 읽고 있을 수 있으니, 드롭이
  /// 받아들여진 세션에는 부르지 않는다([DragOutStaging.cleanupStale]에 맡김).
  Future<void> discard() async {
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // 이미 지워졌거나 접근할 수 없으면 오래된 폴더 정리에서 다시 시도한다.
    }
  }
}

/// 압축 목록의 항목을 창 밖(Finder/탐색기)으로 끌어낼 수 있도록 임시
/// 폴더에 미리 풀어 둔다(PLAN.md 1.2 "끌어내서 해제").
///
/// `flutter_drag_out` 플러그인은 이미 디스크에 있는 경로만 넘길 수 있다.
/// 드롭된 뒤에 파일을 만드는 "파일 프로미스"가 플러그인에 생기기 전까지는,
/// 드래그를 시작할 때 풀기 시작해서 포인터가 창을 벗어날 즈음 끝나 있기를
/// 기대하는 방식이다. 그래서 너무 큰 선택은 [maxBytes]에서 거절한다.
class DragOutStaging {
  const DragOutStaging({
    this.extractEntries = const ExtractEntries(),
    this.rootPath,
  });

  /// 이보다 크면 끌어내기를 시작하지 않는다 — 아래 해제 버튼을 쓰는 편이
  /// 낫다.
  static const maxBytes = 512 * 1024 * 1024;

  /// 드롭이 받아들여진 세션 폴더는 대상 앱이 비동기로 복사할 수 있어 바로
  /// 지우지 않고, 이 시간이 지난 뒤 다음 끌어내기 때 정리한다.
  static const staleAfter = Duration(hours: 1);

  final ExtractEntries extractEntries;

  /// 세션 폴더들을 둘 곳. 기본값은 시스템 임시 폴더 아래 전용 폴더다.
  final String? rootPath;

  Directory get _root => Directory(
    rootPath ?? p.join(Directory.systemTemp.path, 'dove_zip_drag_out'),
  );

  /// [selectedPaths](화면의 전체 가상 경로 — `_selectedPaths`와 같은 형식)를
  /// 새 세션 폴더에 풀고, 끌어낼 최상위 경로들을 돌려준다.
  ///
  /// 드래그 도중에는 비밀번호를 물을 수 없으므로, 암호화된 항목이 있는데
  /// [password]가 없으면 풀기 전에 [ArchivePasswordRequiredException]을
  /// 던진다. 틀린 비밀번호도 같은 예외로 끝난다.
  Future<DragOutStage> prepare({
    required ArchiveHandle handle,
    required Set<String> selectedPaths,
    String? password,
    CancelToken? cancelToken,
  }) async {
    final topLevel = _withoutNested(selectedPaths);
    final entryPaths = expandSelectionToEntryPaths(handle.entries, topLevel);
    final selectedEntries = handle.entries
        .where((e) => entryPaths.contains(e.pathInArchive))
        .toList();

    final totalBytes = selectedEntries.fold<int>(
      0,
      (sum, e) => sum + (e.uncompressedSize ?? 0),
    );
    if (totalBytes > maxBytes) throw DragOutTooLargeException(totalBytes);

    if (password == null) {
      final encrypted = selectedEntries.where((e) => e.isEncrypted);
      if (encrypted.isNotEmpty) {
        throw ArchivePasswordRequiredException(encrypted.first.pathInArchive);
      }
    }

    await cleanupStale();
    await _root.create(recursive: true);
    final directory = await _root.createTemp('s');
    final stage = DragOutStage(directory, const []);
    try {
      final result = await extractEntries(
        handle: handle,
        mode: ExtractDestinationMode.chooseFolder,
        userChosenFolder: Uri.directory(directory.path),
        entryPaths: entryPaths.toList(),
        password: password,
        // 매번 새 세션 폴더라 충돌할 일이 없다.
        onConflict: (_) async => ConflictAction.overwriteAll,
        cancelToken: cancelToken,
      );
      if (result.failures.isNotEmpty) {
        throw DragOutExtractFailedException(result.failures);
      }

      final paths = [
        for (final selected in topLevel)
          p.joinAll([directory.path, ...selected.split('/')]),
      ];
      final missing = paths.where(
        (path) =>
            FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound,
      );
      if (missing.isNotEmpty) {
        throw StateError('풀린 항목을 찾지 못했습니다: ${missing.first}');
      }
      return DragOutStage(directory, paths);
    } catch (_) {
      await stage.discard();
      rethrow;
    }
  }

  /// [staleAfter]보다 오래된 세션 폴더를 지운다. 실패는 무시한다(다음에
  /// 다시 시도).
  Future<void> cleanupStale({DateTime? now}) async {
    final root = _root;
    if (!await root.exists()) return;
    final threshold = (now ?? DateTime.now()).subtract(staleAfter);
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        try {
          final modified = (await entity.stat()).modified;
          if (modified.isBefore(threshold)) {
            await entity.delete(recursive: true);
          }
        } on FileSystemException {
          continue;
        }
      }
    } on FileSystemException {
      return;
    }
  }

  /// 폴더와 그 안의 항목이 함께 선택돼 있으면 폴더만 남긴다 — 안쪽 항목을
  /// 따로 한 번 더 넘기면 대상에 같은 파일이 두 번 생긴다.
  static Set<String> _withoutNested(Set<String> selectedPaths) => {
    for (final path in selectedPaths)
      if (!selectedPaths.any(
        (other) => other != path && path.startsWith('$other/'),
      ))
        path,
  };
}
