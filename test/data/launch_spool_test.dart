import 'dart:io';

import 'package:dove_zip/data/launch_spool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 탐색기가 항목마다 띄운 프로세스를 하나로 모으기.
void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('dove_zip_spool_test_'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  LaunchSpool spool() => LaunchSpool(
        dir,
        quietPeriod: const Duration(milliseconds: 150),
        pollInterval: const Duration(milliseconds: 20),
        followerTimeout: const Duration(seconds: 3),
      );

  /// 다른 프로세스가 남긴 요청 파일.
  void otherRequest(DateTime at, List<String> paths) {
    final micros = at.microsecondsSinceEpoch.toString().padLeft(20, '0');
    File(p.join(dir.path, '${micros}_999.req')).writeAsStringSync(paths.join('\n'));
  }

  test('리더는 먼저 온 요청부터 모두 가져가고 요청 파일을 지운다', () async {
    final now = DateTime.now();
    otherRequest(now.subtract(const Duration(seconds: 2)), ['a']);
    otherRequest(now.subtract(const Duration(seconds: 1)), ['b']);

    expect(await spool().gather(['c']), ['a', 'b', 'c']);
    expect(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.req')), isEmpty);
  });

  test('기다리는 동안 들어온 요청도 모은다', () async {
    final pending = spool().gather(['a']);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    otherRequest(DateTime.now(), ['b']);
    expect(await pending, ['a', 'b']);
  });

  test('같은 경로는 한 번만, 오래된 요청은 버린다', () async {
    otherRequest(DateTime.now().subtract(const Duration(minutes: 10)), ['stale']);
    otherRequest(DateTime.now().subtract(const Duration(seconds: 1)), ['a']);
    expect(await spool().gather(['a', 'b']), ['a', 'b']);
  });

  test(
    '다른 프로세스가 리더면, 내 요청을 가져갈 때 null로 끝난다',
    () async {
      // Windows의 파일 잠금은 핸들마다라, 같은 프로세스 안에서도 다른 리더를 흉내 낼 수 있다.
      final leader = await File(p.join(dir.path, 'leader.lock')).open(mode: FileMode.append);
      await leader.lock(FileLock.exclusive);
      final follower = spool().gather(['mine']);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.req'))) {
        f.deleteSync(); // 리더가 가져갔다.
      }
      expect(await follower, isNull);
      await leader.unlock();
      await leader.close();
    },
    skip: Platform.isWindows ? false : 'POSIX 잠금은 프로세스마다라 같은 프로세스에서 흉내 낼 수 없다',
  );
}
