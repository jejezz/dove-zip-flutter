import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/cancel_token.dart';
import '../domain/entities/archive_entry.dart';
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

/// 압축 목록의 항목을 창 밖(Finder/탐색기)으로 끌어낼 때 디스크 쪽 일을
/// 맡는다(PLAN.md 1.2 "끌어내서 해제"). 방식이 둘이다.
///
/// - **파일 프로미스**(macOS, `FlutterDragOut.supportsPromises`): 드롭된
///   뒤 Finder가 알려 준 위치에 [extractItemTo]로 곧바로 푼다. 미리 풀 것도
///   크기 제한도 없다.
/// - **미리 풀어 두기**(그 밖의 플랫폼): 플러그인이 이미 디스크에 있는
///   경로만 넘길 수 있어, 드래그를 시작할 때 [prepare]로 임시 폴더에 풀기
///   시작해서 포인터가 창을 벗어날 즈음 끝나 있기를 기대한다. 그래서 너무
///   큰 선택은 [maxBytes]에서 거절한다.
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
    final topLevel = topLevelOf(selectedPaths);
    final entryPaths = expandSelectionToEntryPaths(handle.entries, topLevel);
    final selectedEntries = handle.entries
        .where((e) => entryPaths.contains(e.pathInArchive))
        .toList();

    final totalBytes = selectedEntries.fold<int>(
      0,
      (sum, e) => sum + (e.uncompressedSize ?? 0),
    );
    if (totalBytes > maxBytes) throw DragOutTooLargeException(totalBytes);

    _checkPassword(selectedEntries, password);

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

  /// 가상 경로 [selectedPath](파일 또는 폴더) 하나를 정확히 [targetPath]에
  /// 푼다 — 파일 프로미스의 `write`가 쓴다. [targetPath]의 이름은 압축 안
  /// 이름과 다를 수 있다(Finder가 겹치지 않게 `이름 2.txt`로 바꿔 줌).
  ///
  /// 해제 백엔드는 압축 안 경로를 그대로 살려 풀기 때문에, 같은 볼륨인
  /// [targetPath] 옆의 숨김 임시 폴더에 푼 뒤 그 항목만 [targetPath]로
  /// 옮긴다(이름 바꾸기라 복사가 없다). 이미 [targetPath]에 무언가 있으면
  /// 덮어쓰지 않고 실패한다.
  Future<void> extractItemTo({
    required ArchiveHandle handle,
    required String selectedPath,
    required String targetPath,
    String? password,
    CancelToken? cancelToken,
  }) async {
    final entryPaths = expandSelectionToEntryPaths(handle.entries, {
      selectedPath,
    });
    _checkPassword(
      handle.entries.where((e) => entryPaths.contains(e.pathInArchive)),
      password,
    );
    if (FileSystemEntity.typeSync(targetPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('이미 같은 이름의 항목이 있습니다', targetPath);
    }

    final temp = await Directory(p.dirname(targetPath))
        .createTemp('.dove_zip_drag_out_');
    try {
      final result = await extractEntries(
        handle: handle,
        mode: ExtractDestinationMode.chooseFolder,
        userChosenFolder: Uri.directory(temp.path),
        entryPaths: entryPaths.toList(),
        password: password,
        // 새로 만든 임시 폴더라 충돌할 일이 없다.
        onConflict: (_) async => ConflictAction.overwriteAll,
        cancelToken: cancelToken,
      );
      if (result.failures.isNotEmpty) {
        throw DragOutExtractFailedException(result.failures);
      }

      final extracted = p.joinAll([temp.path, ...selectedPath.split('/')]);
      switch (FileSystemEntity.typeSync(extracted, followLinks: false)) {
        case FileSystemEntityType.directory:
          await Directory(extracted).rename(targetPath);
        case FileSystemEntityType.notFound:
          throw StateError('풀린 항목을 찾지 못했습니다: $selectedPath');
        default:
          await File(extracted).rename(targetPath);
      }
    } finally {
      try {
        await temp.delete(recursive: true);
      } on FileSystemException {
        // 숨김 폴더라 남아도 보이지 않는다 — 다음에 사용자가 지울 수 있다.
      }
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

  /// 드래그 도중에는 비밀번호를 물을 수 없으므로, 암호화된 항목이 있는데
  /// [password]가 없으면 풀기 전에 비밀번호 예외를 던진다.
  static void _checkPassword(Iterable<ArchiveEntry> entries, String? password) {
    if (password != null) return;
    for (final entry in entries) {
      if (entry.isEncrypted) {
        throw ArchivePasswordRequiredException(entry.pathInArchive);
      }
    }
  }

  /// [selectedPaths] 가운데 비밀번호 없이는 풀 수 없는 항목이 있는지.
  static bool needsPassword(
    ArchiveHandle handle,
    Set<String> selectedPaths,
    String? password,
  ) {
    if (password != null) return false;
    final entryPaths = expandSelectionToEntryPaths(
      handle.entries,
      selectedPaths,
    );
    return handle.entries.any(
      (e) => e.isEncrypted && entryPaths.contains(e.pathInArchive),
    );
  }

  /// 가상 경로 [path]가 폴더인지 — 디렉터리 엔트리가 있거나, 그 아래에
  /// 항목이 있으면(디렉터리 엔트리 없이 경로로만 존재하는 가상 폴더) 폴더다.
  static bool isDirectoryIn(List<ArchiveEntry> entries, String path) =>
      entries.any(
        (e) =>
            e.pathInArchive.startsWith('$path/') ||
            (e.isDirectory && e.pathInArchive == path),
      );

  /// 폴더와 그 안의 항목이 함께 선택돼 있으면 폴더만 남긴다 — 안쪽 항목을
  /// 따로 한 번 더 넘기면 대상에 같은 파일이 두 번 생긴다.
  static Set<String> topLevelOf(Set<String> selectedPaths) => {
    for (final path in selectedPaths)
      if (!selectedPaths.any(
        (other) => other != path && path.startsWith('$other/'),
      ))
        path,
  };
}
