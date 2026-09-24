import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:koni_archive_core/koni_archive_core.dart' as koni;
import 'package:koni_rar/koni_rar.dart' as koni_rar;
import 'package:koni_sevenz/koni_sevenz.dart' as koni_sevenz;
import 'package:path/path.dart' as p;

import '../core/cancel_token.dart';
import '../domain/entities/archive_entry.dart';
import '../domain/entities/extract_conflict.dart';
import '../domain/entities/extract_failure.dart';
import '../domain/entities/extract_progress.dart';
import '../domain/repositories/archive_reader.dart';
import 'format_registry.dart';
import 'split_volume_locator.dart';

/// 스캐폴딩 단계의 임시 [ArchiveReader]. 두 백엔드를 함께 쓴다 —
/// zip/tar/tar.gz/tar.bz2/tar.xz/gzip/bzip2/xz는 `archive` 패키지의
/// [Archive]/[ArchiveFile] 모델로(ARCHITECTURE.md 4장 "구현 후 수정" 참고),
/// 7z/RAR는 [koni_sevenz]/[koni_rar](순수 Dart, MIT — PLAN.md 3장)로
/// 읽는다. 어느 쪽도 아직 진짜 libarchive/Rust는 아니지만, `ArchiveReader`
/// 인터페이스를 통해 접근하므로 상위 유스케이스는 나중에 실제 네이티브
/// 백엔드로 바뀌어도 영향받지 않는다. ZSTD는 koni 생태계가 아직 pub.dev에
/// 배포하지 않아(2026-09 기준 GitHub 메인 브랜치에만 있음) 이번에는
/// 제외했다 — PLAN.md 3장 참고.
///
/// tar 계열은 zip과 같은 [Archive]/[ArchiveFile] 모델을 그대로 쓰기 때문에,
/// 실제로 포맷마다 갈라지는 부분은 바이트를 [Archive]로 디코딩하는
/// [_decodeArchive] 하나뿐이다. 7z/RAR는 그 모델에 맞지 않아(엔트리 내용을
/// 지연 스트리밍하는 별도 API) [_openKoniReader]로 시작하는 완전히 다른
/// 경로를 탄다 — 대신 해제 루프의 충돌/진행률/취소 처리(둘 다 공통으로
/// 필요한 부분)는 [_extractEntries] 하나로 합쳐서 공유한다.
class DartArchiveReader implements ArchiveReader {
  const DartArchiveReader();

  static const _archivePackageFormats = {
    ArchiveFormat.zip,
    ArchiveFormat.tar,
    ArchiveFormat.tarGz,
    ArchiveFormat.tarBz2,
    ArchiveFormat.tarXz,
    ArchiveFormat.gzip,
    ArchiveFormat.bzip2,
    ArchiveFormat.xz,
  };

  static const _koniFormats = {ArchiveFormat.sevenZip, ArchiveFormat.rar};

  @override
  bool supports(ArchiveFormat format) =>
      _archivePackageFormats.contains(format) || _koniFormats.contains(format);

  @override
  Future<List<ArchiveEntry>> listEntries(
    Uri archiveLocation, {
    String? password,
  }) async {
    final fileName = p.basename(archiveLocation.toFilePath());
    final format = FormatRegistry.detectFromFileName(fileName);

    if (format != null && _koniFormats.contains(format)) {
      final reader = await _openKoniReader(format, archiveLocation, password: password);
      try {
        return [for (final entry in reader.entries) _toDomainEntry(entry)];
      } finally {
        await reader.close();
      }
    }

    // zip 목록은 항목을 복호화하지 않아도 읽을 수 있어 password 없이도
    // 항상 동작한다 — 그래도 넘겨받으면 그대로 전달해 나중에 이 archive
    // 객체를 재사용할 여지를 남긴다.
    final (archive, decodedFormat) = await _decodeArchive(archiveLocation, password: password);

    return [
      for (final file in archive)
        ArchiveEntry(
          pathInArchive: file.name,
          isDirectory: file.isDirectory,
          uncompressedSize: file.isDirectory ? null : file.size,
          // 항목별 압축 크기는 zip에서만 의미가 있다 — tar 계열은 압축이
          // (있다면) 파일 하나하나가 아니라 tar 스트림 전체에 걸리므로
          // 항목 단위 "압축 크기"라는 개념 자체가 없다.
          compressedSize: (decodedFormat == ArchiveFormat.zip && !file.isDirectory)
              ? file.rawContent?.length
              : null,
          modifiedAt: file.lastModDateTime,
          // NOTE: 이 패키지의 공개 API는 zip 항목별 암호화 여부(bit flag)를
          // 노출하지 않아 isEncrypted는 항상 false — 네이티브 백엔드
          // 도입 시 보완 (ARCHITECTURE.md 6.4).
        ),
    ];
  }

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
    final fileName = p.basename(archiveLocation.toFilePath());
    final format = FormatRegistry.detectFromFileName(fileName);
    final wanted = entryPaths?.toSet();

    if (format != null && _koniFormats.contains(format)) {
      final reader = await _openKoniReader(format, archiveLocation, password: password);
      try {
        final targets = [
          for (final koniEntry in reader.entries)
            if (wanted == null || wanted.contains(koniEntry.path))
              (_toDomainEntry(koniEntry), () => _readKoniEntryContent(reader, koniEntry)),
        ];
        return await _extractEntries(
          targets: targets,
          destinationDir: destination.toFilePath(),
          onConflict: onConflict,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } finally {
        await reader.close();
      }
    }

    final (archive, _) = await _decodeArchive(archiveLocation, password: password);
    // NOTE: entryPaths는 지금은 정확히 일치하는 이름만 고른다. 폴더 하나를
    // 선택해서 그 안의 파일들까지 전부 해제하는 것은 아직 이 앱에 다중
    // 선택 UI가 없어 호출하는 곳이 없다 — 그 기능이 생기면 호출부에서
    // 하위 경로까지 미리 펼쳐서 넘기거나, 여기 prefix 매칭을 추가한다.
    final targets = [
      for (final file in archive)
        if (wanted == null || wanted.contains(file.name))
          (
            ArchiveEntry(
              pathInArchive: file.name,
              isDirectory: file.isDirectory,
              uncompressedSize: file.isDirectory ? null : file.size,
            ),
            () async => _readContent(file),
          ),
    ];
    return _extractEntries(
      targets: targets,
      destinationDir: destination.toFilePath(),
      onConflict: onConflict,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// 해제 루프의 공통부 — 어느 백엔드든 충돌 처리·진행률·취소는 이 하나의
  /// 로직을 공유한다. [targets]의 각 항목은 (엔트리, 그 엔트리의 실제
  /// 바이트를 가져오는 콜백) 쌍이다.
  ///
  /// [readContent]가 실패하면(손상된 데이터, 깨진 압축 스트림 등) 그 항목만
  /// [ExtractFailure]로 기록하고 나머지는 계속 해제한다 — 단, 비밀번호
  /// 문제([ArchivePasswordRequiredException])는 예외로, 이 항목 하나가 아니라
  /// 호출부의 재시도 흐름으로 곧장 넘겨야 하므로 그대로 다시 던진다.
  Future<List<ExtractFailure>> _extractEntries({
    required List<(ArchiveEntry entry, Future<List<int>> Function() readContent)> targets,
    required String destinationDir,
    required ConflictResolver onConflict,
    ExtractProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final total = targets.where((t) => !t.$1.isDirectory).length;
    var done = 0;
    ConflictAction? bulkAction;
    final failures = <ExtractFailure>[];

    for (final (entry, readContent) in targets) {
      cancelToken?.throwIfCancelled();

      final destPath = p.joinAll([destinationDir, ..._segmentsOf(entry.pathInArchive)]);

      if (entry.isDirectory) {
        await Directory(destPath).create(recursive: true);
        continue;
      }

      await Directory(p.dirname(destPath)).create(recursive: true);

      var finalDestPath = destPath;
      final destFile = File(destPath);
      if (await destFile.exists()) {
        final action = bulkAction ??
            await onConflict(ExtractConflict(
              entryPath: entry.pathInArchive,
              destinationPath: destPath,
              sourceSizeBytes: entry.uncompressedSize ?? 0,
              destinationSizeBytes: await destFile.length(),
              destinationModifiedAt: (await destFile.stat()).modified,
            ));
        if (action == ConflictAction.overwriteAll) bulkAction = ConflictAction.overwrite;
        if (action == ConflictAction.skipAll) bulkAction = ConflictAction.skip;
        if (action == ConflictAction.cancel) {
          throw const OperationCancelledException();
        }

        final effective = bulkAction ?? action;
        if (effective == ConflictAction.skip) {
          done++;
          onProgress?.call(
              ExtractProgress(done: done, total: total, currentName: entry.pathInArchive));
          continue;
        } else if (effective == ConflictAction.rename) {
          finalDestPath = await _availableName(destPath);
        }
      }

      try {
        await File(finalDestPath).writeAsBytes(await readContent());
      } on ArchivePasswordRequiredException {
        rethrow;
      } catch (e) {
        failures.add(ExtractFailure(entryPath: entry.pathInArchive, message: '$e', error: e));
        done++;
        onProgress?.call(ExtractProgress(done: done, total: total, currentName: entry.pathInArchive));
        continue;
      }
      done++;
      onProgress?.call(ExtractProgress(done: done, total: total, currentName: entry.pathInArchive));
    }

    return failures;
  }

  @override
  Future<Uri> extractEntryToTemp(
    Uri archiveLocation,
    String entryPath, {
    String? password,
  }) async {
    final fileName = p.basename(archiveLocation.toFilePath());
    final format = FormatRegistry.detectFromFileName(fileName);

    if (format != null && _koniFormats.contains(format)) {
      final reader = await _openKoniReader(format, archiveLocation, password: password);
      try {
        final koniEntry = reader.entries.where((e) => e.path == entryPath).firstOrNull;
        if (koniEntry == null) {
          throw ArgumentError('No entry "$entryPath" in the archive');
        }
        final content = await _readKoniEntryContent(reader, koniEntry);
        return await _writeToTempFile(entryPath, content);
      } finally {
        await reader.close();
      }
    }

    final (archive, _) = await _decodeArchive(archiveLocation, password: password);
    final entry = archive.findFile(entryPath);
    if (entry == null) {
      throw ArgumentError('No entry "$entryPath" in the archive');
    }
    return _writeToTempFile(entryPath, _readContent(entry));
  }

  /// 매번 새 임시 폴더를 쓰므로 이름 충돌이 날 수 없다 — [extractAll]과
  /// 달리 [ConflictResolver]가 필요 없는 이유(ARCHITECTURE.md 9장).
  Future<Uri> _writeToTempFile(String entryPath, List<int> content) async {
    final tempDir = await Directory.systemTemp.createTemp('dove_zip_preview_');
    final tempFile = File(p.join(tempDir.path, p.basename(entryPath)));
    await tempFile.writeAsBytes(content);
    return tempFile.uri;
  }

  /// [format]([ArchiveFormat.sevenZip]/[ArchiveFormat.rar])으로 koni 리더를
  /// 연다. 헤더 자체가 암호화돼 있어 비밀번호 없이는 목록조차 못 읽는
  /// 경우 [ArchivePasswordRequiredException]으로 바꿔 던진다(항목 하나를
  /// 열 때만 필요한 경우는 [_readKoniEntryContent]가 담당).
  Future<koni.ArchiveReader> _openKoniReader(
    ArchiveFormat format,
    Uri archiveLocation, {
    String? password,
  }) async {
    final fileName = p.basename(archiveLocation.toFilePath());
    final bytes = await _readArchiveBytes(archiveLocation);
    final source = koni.MemoryByteSource(Uint8List.fromList(bytes), name: fileName);
    final koniFormat = switch (format) {
      ArchiveFormat.sevenZip => const koni_sevenz.SevenZFormat(),
      ArchiveFormat.rar => const koni_rar.RarFormat(),
      _ => throw ArgumentError('Format not handled by the koni backend: $format'),
    };

    try {
      return await koniFormat.openReader(source, koni.ArchiveReadOptions(password: password));
    } on koni.InvalidPasswordException catch (e) {
      throw ArchivePasswordRequiredException(e.entryPath ?? fileName);
    } on koni.EncryptedArchiveException catch (e) {
      throw ArchivePasswordRequiredException(e.entryPath ?? fileName);
    }
  }

  ArchiveEntry _toDomainEntry(koni.ArchiveEntry entry) => ArchiveEntry(
        pathInArchive: entry.path,
        isDirectory: entry.isDirectory,
        // zstd 프레임처럼 크기를 모를 때는 -1을 쓴다는 koni_archive_core의
        // 관례(현재는 7z/RAR 둘 다 항상 안다) — 방어적으로 그대로 처리.
        uncompressedSize:
            entry.isDirectory || entry.uncompressedSize < 0 ? null : entry.uncompressedSize,
        compressedSize: entry.isDirectory ? null : entry.compressedSize,
        modifiedAt: entry.modified,
        isEncrypted: entry.isEncrypted,
      );

  /// [entry]의 실제 바이트를 읽는다. 비밀번호가 없거나 틀리면
  /// [ArchivePasswordRequiredException]으로 바꿔 던진다.
  ///
  /// 7z는 비밀번호 확인용 체크값이 아예 없어(koni_sevenz 문서 참고) 틀린
  /// 비밀번호가 [koni.InvalidPasswordException]이 아니라
  /// [koni.ChecksumMismatchException]으로 나타난다 — 그래서 암호화된
  /// 항목에서 체크섬이 안 맞으면 "틀린 비밀번호"로 취급한다(암호화 안 된
  /// 항목의 순수한 손상은 그대로 다시 던진다).
  Future<List<int>> _readKoniEntryContent(
    koni.ArchiveReader reader,
    koni.ArchiveEntry entry,
  ) async {
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in reader.openRead(entry)) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on koni.InvalidPasswordException {
      throw ArchivePasswordRequiredException(entry.path);
    } on koni.EncryptedArchiveException {
      throw ArchivePasswordRequiredException(entry.path);
    } on koni.ChecksumMismatchException {
      if (entry.isEncrypted) throw ArchivePasswordRequiredException(entry.path);
      rethrow;
    }
  }

  /// 압축파일을 읽어 공통 [Archive] 모델로 디코딩한다. zip/tar 계열과
  /// zstd/tar.zst 전용 경로 — 7z/RAR는 [_openKoniReader]를 따로 쓴다(클래스
  /// 문서 참고). 실제로 포맷마다 갈라지는 부분은 이 메서드 하나뿐이고,
  /// 나머지 로직(엔트리 매핑, 해제, 충돌 처리)은 [Archive]/[ArchiveFile]
  /// 위에서 포맷과 무관하게 동작한다.
  ///
  /// 압축 확장자로 포맷을 다시 판별한다 — `ArchiveReader` 인터페이스가
  /// 포맷을 인자로 받지 않기 때문에(다른 구현체도 같은 시그니처를 써야
  /// 하므로 바꾸지 않았다), 파일명으로부터 재추정하는 쪽을 택했다.
  Future<(Archive, ArchiveFormat)> _decodeArchive(
    Uri archiveLocation, {
    String? password,
  }) async {
    final fileName = p.basename(archiveLocation.toFilePath());
    final format = FormatRegistry.detectFromFileName(fileName);
    if (format == null || !supports(format)) {
      throw ArgumentError('DartArchiveReader does not support: $fileName');
    }

    final bytes = await _readArchiveBytes(archiveLocation);

    final archive = switch (format) {
      ArchiveFormat.zip => ZipDecoder().decodeBytes(bytes, password: password),
      ArchiveFormat.tar => TarDecoder().decodeBytes(bytes),
      ArchiveFormat.tarGz => TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes)),
      ArchiveFormat.tarBz2 => TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes)),
      ArchiveFormat.tarXz => TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes)),
      ArchiveFormat.gzip => _singleFileArchive(fileName, GZipDecoder().decodeBytes(bytes)),
      ArchiveFormat.bzip2 => _singleFileArchive(fileName, BZip2Decoder().decodeBytes(bytes)),
      ArchiveFormat.xz => _singleFileArchive(fileName, XZDecoder().decodeBytes(bytes)),
      _ => throw ArgumentError('DartArchiveReader does not support: $format'),
    };

    return (archive, format);
  }

  /// [archiveLocation]이 분할 압축 조각(`archive.zip.007` 등, PLAN.md 1.3)이면
  /// 같은 폴더의 모든 조각을 번호순으로 찾아 이어붙인 바이트를, 아니면
  /// 그 파일 하나를 그대로 읽는다. 사용자가 어떤 조각을 골랐든 상관없다 —
  /// [findSplitVolumeParts]는 항상 전체 조각 집합을 찾는다.
  Future<List<int>> _readArchiveBytes(Uri archiveLocation) async {
    final fileName = p.basename(archiveLocation.toFilePath());
    if (!FormatRegistry.isSplitVolumePart(fileName)) {
      return File(archiveLocation.toFilePath()).readAsBytes();
    }

    final parts = await findSplitVolumeParts(archiveLocation);
    if (parts.isEmpty) {
      throw MissingSplitVolumeException(fileName);
    }
    assertContiguousSplitVolumes(fileName, parts);

    final builder = BytesBuilder(copy: false);
    for (final part in parts) {
      builder.add(await part.readAsBytes());
    }
    return builder.takeBytes();
  }

  /// gzip/bzip2/xz/zstd처럼 파일 하나만 감싸는 포맷을, 나머지 로직이 그대로
  /// 재사용할 수 있도록 항목 하나짜리 [Archive]로 감싼다. 내부 파일 이름은
  /// 압축 확장자를 뗀 원래 이름으로 추정한다(`photo.txt.gz` → `photo.txt`)
  /// — 이 포맷들은 원본 파일명을 별도로 저장하지 않는다.
  Archive _singleFileArchive(String archiveFileName, List<int> decompressedBytes) {
    final innerName = FormatRegistry.stripKnownExtension(archiveFileName);
    return Archive()..addFile(ArchiveFile.bytes(innerName, decompressedBytes));
  }

  /// [file.content]를 읽되, 비밀번호가 없거나 틀려서 복호화에 실패하면
  /// [ArchivePasswordRequiredException]으로 바꿔 던진다.
  ///
  /// 이 패키지는 별도 예외 타입을 안 두고 상황에 따라 다른 걸 던진다 —
  /// 비밀번호가 틀렸을 때는 `Exception('password error')`/`'macs don't
  /// match'`, **비밀번호를 아예 안 줬을 때**는 AES 헤더의 null 필드를
  /// 그대로 강제 언랩하다 `TypeError: Null check operator used on a null
  /// value`를 던진다 — 그래서 메시지 키워드에 이것도 포함한다. zipCrypto
  /// (구식 암호화)는 이 라이브러리가 검증 없이 조용히 깨진 바이트를 만들
  /// 수 있어 이 판별이 항상 잡아내지는 못한다(알려진 한계, ARCHITECTURE.md 6.4).
  /// zip이 아닌 포맷은 애초에 이 실패 모드 자체가 없다(암호화 개념이 없어서).
  List<int> _readContent(ArchiveFile file) {
    try {
      return file.content as List<int>;
    } catch (e) {
      final message = e.toString().toLowerCase();
      final looksLikePasswordIssue = message.contains('password') ||
          message.contains('mac') ||
          message.contains('null check operator');
      if (looksLikePasswordIssue) {
        throw ArchivePasswordRequiredException(file.name);
      }
      rethrow;
    }
  }

  /// `"docs/a.txt"` → `["docs", "a.txt"]`. 디렉터리 엔트리에 붙은 트레일링
  /// 슬래시(`"docs/"`)는 빈 세그먼트를 만들지 않도록 먼저 제거한다.
  List<String> _segmentsOf(String pathInArchive) {
    final trimmed =
        pathInArchive.endsWith('/') ? pathInArchive.substring(0, pathInArchive.length - 1) : pathInArchive;
    return trimmed.split('/');
  }

  /// `photos.txt` → `photos (2).txt` → `photos (3).txt` ... 이미 존재하지
  /// 않는 이름을 찾을 때까지 증가시킨다 (daylight-commander-flutter의
  /// `FileOperationService._availableName`과 동일 로직).
  Future<String> _availableName(String path) async {
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final base = p.basenameWithoutExtension(path);
    var i = 2;
    String candidate;
    do {
      candidate = p.join(dir, '$base ($i)$ext');
      i++;
    } while (await FileSystemEntity.type(candidate) != FileSystemEntityType.notFound);
    return candidate;
  }
}
