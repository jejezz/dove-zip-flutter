import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 탐색기에서 여러 항목을 골라 우클릭 메뉴를 누르면, Windows는 항목마다
/// `dove_zip.exe --compress-here "<항목>"`을 따로 실행한다(클래식 셸 verb의
/// 동작). 이것을 압축파일 하나(또는 창 하나)로 모은다.
///
/// 각 프로세스는 자기 경로를 [directory]에 요청 파일로 남기고 `leader.lock`을
/// 잡아 본다. 잡은 프로세스(리더)는 요청이 더 들어오지 않을 때까지
/// [quietPeriod] 동안 기다렸다가 모두 가져가고, 못 잡은 프로세스는 리더가
/// 자기 요청을 가져가면 창을 띄우지 않고 끝난다. 리더가 다 모은 뒤에 늦게
/// 도착한 요청은 그다음 리더가 따로 처리한다.
class LaunchSpool {
  LaunchSpool(
    this.directory, {
    this.quietPeriod = const Duration(milliseconds: 600),
    this.maxGatherTime = const Duration(seconds: 5),
    this.followerTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(milliseconds: 100),
    this.staleAfter = const Duration(minutes: 2),
  });

  final Directory directory;
  final Duration quietPeriod;
  final Duration maxGatherTime;
  final Duration followerTimeout;
  final Duration pollInterval;

  /// 이보다 오래된 요청 파일은 죽은 프로세스가 남긴 것으로 보고 지운다.
  final Duration staleAfter;

  static const _requestExtension = '.req';

  /// 이 프로세스가 처리할 경로 목록(다른 프로세스 것 포함, 도착 순서). 다른
  /// 프로세스가 대신 처리하면 null — 호출한 쪽은 창을 띄우지 말고 끝낸다.
  Future<List<String>?> gather(List<String> paths) async {
    await directory.create(recursive: true);
    final request = await _writeRequest(paths);
    final lock = await File(p.join(directory.path, 'leader.lock')).open(mode: FileMode.append);
    try {
      final deadline = DateTime.now().add(followerTimeout);
      while (!await _tryLock(lock)) {
        // 다른 프로세스가 리더다. 내 요청을 가져가면 끝, 아니면 리더가 끝난 뒤
        // 내가 리더가 된다.
        if (!await request.exists() || DateTime.now().isAfter(deadline)) return null;
        await Future<void>.delayed(pollInterval);
      }
      if (!await request.exists()) return null; // 직전 리더가 가져갔다.
      try {
        await _waitUntilQuiet();
        return await _takeAll();
      } finally {
        await lock.unlock();
      }
    } finally {
      await lock.close();
    }
  }

  Future<File> _writeRequest(List<String> paths) async {
    // 이름의 앞부분(마이크로초)으로 도착 순서를 정한다.
    final id = '${DateTime.now().microsecondsSinceEpoch.toString().padLeft(20, '0')}_$pid';
    final tmp = File(p.join(directory.path, '$id.tmp'));
    await tmp.writeAsString(paths.join('\n'), flush: true);
    // 이름 바꾸기로 한 번에 나타나게 해 리더가 반쯤 쓴 파일을 읽지 않게 한다.
    return tmp.rename(p.join(directory.path, '$id$_requestExtension'));
  }

  Future<bool> _tryLock(RandomAccessFile lock) async {
    try {
      await lock.lock(FileLock.exclusive);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<List<File>> _requests() async {
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith(_requestExtension)) files.add(entity);
    }
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  Future<void> _waitUntilQuiet() async {
    final start = DateTime.now();
    var count = (await _requests()).length;
    var stableSince = start;
    while (true) {
      final now = DateTime.now();
      if (now.difference(stableSince) >= quietPeriod || now.difference(start) >= maxGatherTime) return;
      await Future<void>.delayed(pollInterval);
      final next = (await _requests()).length;
      if (next != count) {
        count = next;
        stableSince = DateTime.now();
      }
    }
  }

  Future<List<String>> _takeAll() async {
    final oldest = DateTime.now().subtract(staleAfter).microsecondsSinceEpoch;
    final paths = <String>[];
    for (final file in await _requests()) {
      final micros = int.tryParse(p.basename(file.path).split('_').first) ?? 0;
      try {
        if (micros >= oldest) {
          for (final line in await file.readAsLines()) {
            if (line.isNotEmpty && !paths.contains(line)) paths.add(line);
          }
        }
        await file.delete();
      } on FileSystemException {
        // 다른 프로세스가 먼저 지웠다 — 건너뛴다.
      }
    }
    return paths;
  }
}
