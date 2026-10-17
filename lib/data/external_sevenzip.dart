import 'dart:io';

import 'package:path/path.dart' as p;

/// 시스템에 설치된 7-Zip 명령줄(`7zz`/`7z`/`7za`)로 항목 하나를 푸는 폴백.
///
/// 순수 Dart 백엔드(koni_sevenz)는 solid 블록 하나를 통째로 메모리에 풀고
/// 1GiB를 넘으면 거부한다. 그런 블록은 스트리밍으로 푸는 외부 7-Zip에 맡긴다.
class ExternalSevenZip {
  const ExternalSevenZip(this.executable);

  final String executable;

  /// 설치된 7-Zip 실행 파일을 찾는다. 없으면 null.
  static Future<ExternalSevenZip?> locate() async {
    final names = Platform.isWindows ? ['7z.exe', '7za.exe'] : ['7zz', '7z', '7za'];
    final candidates = <String>[];

    final pathVar = Platform.environment['PATH'] ?? '';
    for (final dir in pathVar.split(Platform.isWindows ? ';' : ':')) {
      if (dir.isEmpty) continue;
      for (final name in names) {
        candidates.add(p.join(dir, name));
      }
    }
    if (Platform.isWindows) {
      for (final root in [
        Platform.environment['ProgramFiles'],
        Platform.environment['ProgramFiles(x86)'],
        Platform.environment['ProgramW6432'],
      ]) {
        if (root != null) candidates.add(p.join(root, '7-Zip', '7z.exe'));
      }
    } else {
      candidates.addAll([
        '/opt/homebrew/bin/7zz',
        '/usr/local/bin/7zz',
        '/opt/homebrew/bin/7z',
        '/usr/local/bin/7z',
        '/usr/bin/7zz',
        '/usr/bin/7z',
      ]);
    }

    for (final path in candidates) {
      if (await File(path).exists()) return ExternalSevenZip(path);
    }
    return null;
  }

  /// [entryPath] 항목의 내용을 [destPath] 파일로 스트리밍한다.
  /// 실패하면 [ExternalSevenZipException]을 던지고 불완전한 파일은 지운다.
  Future<void> extractEntryTo(
    String archivePath,
    String entryPath,
    String destPath, {
    String? password,
  }) async {
    final process = await Process.start(executable, [
      'x',
      archivePath,
      '-so',
      '-y',
      '-spd', // 항목 이름의 * ? 를 와일드카드로 해석하지 않는다
      if (password != null) '-p$password',
      '--',
      entryPath,
    ]);

    final sink = File(destPath).openWrite();
    final stderrText = process.stderr.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    try {
      await sink.addStream(process.stdout);
    } finally {
      await sink.close();
    }
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      try {
        await File(destPath).delete();
      } on FileSystemException {
        // 이미 없으면 그대로 둔다.
      }
      throw ExternalSevenZipException(exitCode, String.fromCharCodes(await stderrText).trim());
    }
  }
}

class ExternalSevenZipException implements Exception {
  const ExternalSevenZipException(this.exitCode, this.output);

  final int exitCode;
  final String output;

  @override
  String toString() => '7-Zip exited with code $exitCode: $output';
}
