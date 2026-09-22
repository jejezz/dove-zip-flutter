import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:koni_archive_core/koni_archive_core.dart' as koni;
import 'package:koni_sevenz/koni_sevenz.dart' as koni_sevenz;
import 'package:path/path.dart' as p;

import '../core/cancel_token.dart';
import '../domain/entities/archive_entry.dart';
import '../domain/entities/compress_progress.dart';
import '../domain/entities/compression_options.dart';
import '../domain/repositories/archive_writer.dart';

/// 스캐폴딩 단계의 임시 [ArchiveWriter]. zip/tar 계열은 `archive` 패키지가
/// 이미 갖고 있는 코덱으로, 7z는 [koni_sevenz](순수 Dart, MIT — PLAN.md
/// 3장)로 만든다. `DartArchiveReader`와 마찬가지로 ARCHITECTURE.md 4장의
/// 네이티브 백엔드가 준비되면 교체할 예정.
///
/// tar 계열은 zip과 같은 [Archive]/[ArchiveFile] 모델을 그대로 쓰므로,
/// 파일/폴더를 모으는 로직([_collectEntries])은 포맷과 무관하게 공유하고
/// 실제로 바이트로 인코딩하는 [_encodeArchive]만 포맷별로 갈라진다.
/// gzip/bzip2/xz는 애초에 파일 하나만 감싸는 포맷이라([_compressSingleFile])
/// 별도 경로를 탄다. 7z는 그 어느 쪽 모델에도 맞지 않아(koni의 스트림
/// 기반 라이터 API) [_compressSevenZip]이라는 완전히 다른 경로를 타지만,
/// 파일/폴더 수집([_collectEntries])과 분할 압축 후처리([_writeOutput])는
/// 그대로 재사용한다.
///
/// 모든 소스 파일을 메모리에 올려 한 번에 인코딩한다(대용량 스트리밍은
/// ARCHITECTURE.md 6.4의 향후 최적화 항목).
class DartArchiveWriter implements ArchiveWriter {
  const DartArchiveWriter();

  static const _multiFileFormats = {
    ArchiveFormat.zip,
    ArchiveFormat.tar,
    ArchiveFormat.tarGz,
    ArchiveFormat.tarBz2,
    ArchiveFormat.tarXz,
  };

  static const _singleFileFormats = {
    ArchiveFormat.gzip,
    ArchiveFormat.bzip2,
    ArchiveFormat.xz,
  };

  /// zip과 마찬가지로 AES-256 비밀번호 보호를 지원하는 포맷 — PLAN.md 1.3
  /// P1. koni_sevenz가 7z AES-256을 이미 구현하고 있어 zip 외에도 이제
  /// 하나 더 있다.
  static const _passwordCapableFormats = {ArchiveFormat.zip, ArchiveFormat.sevenZip};

  @override
  bool supports(ArchiveFormat format) =>
      _multiFileFormats.contains(format) ||
      _singleFileFormats.contains(format) ||
      format == ArchiveFormat.sevenZip;

  @override
  Future<void> compress({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (options.splitVolumeBytes != null && options.splitVolumeBytes! <= 0) {
      throw ArgumentError('분할 볼륨 크기는 0보다 커야 합니다: ${options.splitVolumeBytes}');
    }
    if (options.password != null && !_passwordCapableFormats.contains(options.format)) {
      throw UnsupportedError(
        'DartArchiveWriter는 zip/7z 외의 형식에서는 비밀번호 보호를 지원하지 않습니다.',
      );
    }

    if (options.format == ArchiveFormat.sevenZip) {
      return _compressSevenZip(
        sources: sources,
        destination: destination,
        options: options,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    if (_singleFileFormats.contains(options.format)) {
      await _compressSingleFile(
        sources: sources,
        destination: destination,
        options: options,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    return _compressMultiFile(
      sources: sources,
      destination: destination,
      options: options,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// 7z 전용 경로 — [Archive]/[ArchiveFile] 모델에 맞지 않는 koni_sevenz의
  /// 스트림 기반 라이터 API를 직접 쓴다. 파일/폴더 수집은 zip/tar 경로와
  /// 동일한 [_collectEntries]를 재사용한다.
  Future<void> _compressSevenZip({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final entries = await _collectEntries(
      sources,
      excludedExtensions: options.excludedExtensions,
      followSymlinks: options.followSymlinks,
    );
    final fileEntries = entries.where((e) => !e.isDirectory).toList();
    final total = fileEntries.length;
    var done = 0;

    final sink = koni.BytesBuilderSink();
    final writeOptions = koni.ArchiveWriteOptions(
      password: options.password,
      // 코덱 자체엔 압축 "레벨" 조절이 없다 — store만 명시적으로 고르고
      // (bzip2/xz와 같은 기존 한계), 나머지는 koni_sevenz 기본값(LZMA2)에
      // 맡긴다.
      compression: options.level == CompressionLevel.store ? koni.ArchiveCompression.stored : null,
    );
    final writer = const koni_sevenz.SevenZWriteFormat().openWriter(sink, writeOptions);

    for (final entry in entries) {
      cancelToken?.throwIfCancelled();

      if (entry.isDirectory) {
        await writer.addEntry(koni.ArchiveEntrySpec(
          path: _withoutTrailingSlash(entry.archiveName),
          type: koni.ArchiveEntryType.directory,
        ));
        continue;
      }

      final bytes = await entry.file!.readAsBytes();
      final modified = (await entry.file!.lastModified()).toUtc();
      await writer.addBytes(
        koni.ArchiveEntrySpec(path: entry.archiveName, modified: modified),
        Uint8List.fromList(bytes),
      );

      done++;
      onProgress?.call(
          CompressProgress(done: done, total: total, currentName: entry.archiveName));
    }

    await writer.close();
    // ArchiveWriter.close()는 ByteSink는 닫지 않는다("호출자가 소유") —
    // BytesBuilderSink.takeBytes()는 close() 이후에만 호출할 수 있어
    // 따로 닫아야 한다.
    await sink.close();
    await _writeOutput(sink.takeBytes(), destination, options.splitVolumeBytes, cancelToken);
  }

  String _withoutTrailingSlash(String path) =>
      path.endsWith('/') ? path.substring(0, path.length - 1) : path;

  Future<void> _compressMultiFile({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {

    final entries = await _collectEntries(
      sources,
      excludedExtensions: options.excludedExtensions,
      followSymlinks: options.followSymlinks,
    );
    final fileEntries = entries.where((e) => !e.isDirectory).toList();
    final total = fileEntries.length;
    var done = 0;

    final archive = Archive();
    for (final entry in entries) {
      cancelToken?.throwIfCancelled();

      if (entry.isDirectory) {
        archive.addFile(ArchiveFile.directory(entry.archiveName));
        continue;
      }

      final bytes = await entry.file!.readAsBytes();
      final archiveFile = ArchiveFile.bytes(entry.archiveName, bytes)
        ..lastModTime = (await entry.file!.lastModified()).millisecondsSinceEpoch ~/ 1000;
      if (options.level == CompressionLevel.store) {
        archiveFile.compression = CompressionType.none;
      }
      archive.addFile(archiveFile);

      done++;
      onProgress?.call(
          CompressProgress(done: done, total: total, currentName: entry.archiveName));
    }

    final bytes = _encodeArchive(archive, options);
    await _writeOutput(bytes, destination, options.splitVolumeBytes, cancelToken);
  }

  /// [Archive]를 [options.format]에 맞는 바이트로 인코딩한다. 실제로
  /// 포맷마다 갈라지는 부분은 이 메서드 하나뿐 — 그 위(파일/폴더 수집,
  /// 진행률 계산)는 전부 공통이다.
  List<int> _encodeArchive(Archive archive, CompressionOptions options) {
    final level = _deflateLevelOf(options.level);
    return switch (options.format) {
      ArchiveFormat.zip =>
        // password가 있으면 ZipEncoder가 모든 항목을 AES-256으로
        // 암호화한다 (PLAN.md 1.3 P1 — zip AES-256).
        ZipEncoder(password: options.password).encode(archive, level: level),
      ArchiveFormat.tar => TarEncoder().encode(archive),
      ArchiveFormat.tarGz =>
        GZipEncoder().encodeBytes(TarEncoder().encode(archive), level: level),
      // BZip2Encoder/XZEncoder는 압축 레벨 파라미터가 없다 — 그 알고리즘
      // 자체가 이 패키지에서 레벨을 조절할 수 있게 구현돼 있지 않다.
      ArchiveFormat.tarBz2 => BZip2Encoder().encodeBytes(TarEncoder().encode(archive)),
      ArchiveFormat.tarXz => XZEncoder().encodeBytes(TarEncoder().encode(archive)),
      _ => throw UnsupportedError(
          'DartArchiveWriter가 지원하지 않는 압축 형식입니다: ${options.format}',
        ),
    };
  }

  /// gzip/bzip2/xz는 파일 하나만 감쌀 수 있다 — 폴더나 여러 항목을 담고
  /// 싶으면 먼저 tar로 묶어야 한다(tar.gz 등, 위 [_multiFileFormats] 경로).
  Future<void> _compressSingleFile({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (sources.length != 1) {
      throw ArgumentError(
        '${options.format.name} 형식은 파일 하나만 압축할 수 있습니다 — '
        '폴더나 여러 항목은 tar.gz 등으로 먼저 묶어야 합니다.',
      );
    }

    final sourcePath = sources.single.toFilePath();
    final type = await FileSystemEntity.type(sourcePath);
    if (type != FileSystemEntityType.file) {
      throw ArgumentError('${options.format.name} 형식은 폴더를 압축할 수 없습니다.');
    }

    cancelToken?.throwIfCancelled();
    final bytes = await File(sourcePath).readAsBytes();
    final level = _deflateLevelOf(options.level);
    final encoded = switch (options.format) {
      ArchiveFormat.gzip => GZipEncoder().encodeBytes(bytes, level: level),
      ArchiveFormat.bzip2 => BZip2Encoder().encodeBytes(bytes),
      ArchiveFormat.xz => XZEncoder().encodeBytes(bytes),
      _ => throw UnsupportedError(
          'DartArchiveWriter가 지원하지 않는 압축 형식입니다: ${options.format}',
        ),
    };

    await _writeOutput(encoded, destination, options.splitVolumeBytes, cancelToken);
    onProgress?.call(
        CompressProgress(done: 1, total: 1, currentName: p.basename(sourcePath)));
  }

  /// 완성된 압축파일 바이트를 디스크에 쓴다. `splitVolumeBytes`가 null이면
  /// [destination]에 그대로 한 번에 쓰고, 값이 있으면 그 크기로 잘라
  /// `<destination>.001`, `<destination>.002`, ... 로 나눠 쓴다(PLAN.md 1.3
  /// "분할 압축" — [FormatRegistry.isSplitVolumePart] 문서 참고, DoveZip
  /// 자신만 다시 이어붙일 수 있는 실용적 절충이다).
  ///
  /// 조각 번호는 최소 3자리, 조각 수가 999개를 넘으면 그만큼 자릿수를
  /// 늘린다 — 모든 조각이 같은 자릿수를 쓰므로 사전순 정렬이 곧 번호순
  /// 정렬이 된다.
  Future<void> _writeOutput(
    List<int> bytes,
    Uri destination,
    int? splitVolumeBytes,
    CancelToken? cancelToken,
  ) async {
    if (splitVolumeBytes == null) {
      await File(destination.toFilePath()).writeAsBytes(bytes);
      return;
    }

    final destinationPath = destination.toFilePath();
    final totalParts = math.max(1, (bytes.length / splitVolumeBytes).ceil());
    final digits = math.max(3, totalParts.toString().length);

    for (var index = 0; index < totalParts; index++) {
      cancelToken?.throwIfCancelled();
      final start = index * splitVolumeBytes;
      final end = math.min(start + splitVolumeBytes, bytes.length);
      final partNumber = (index + 1).toString().padLeft(digits, '0');
      await File('$destinationPath.$partNumber').writeAsBytes(bytes.sublist(start, end));
    }
  }

  int _deflateLevelOf(CompressionLevel level) => switch (level) {
        CompressionLevel.store => DeflateLevel.none,
        CompressionLevel.fast => DeflateLevel.bestSpeed,
        CompressionLevel.normal => DeflateLevel.defaultCompression,
        CompressionLevel.max => DeflateLevel.bestCompression,
      };

  /// [sources] 각각을 파일이면 그대로, 폴더면 재귀적으로 펼쳐서 압축파일
  /// 안에서 쓰일 posix 스타일 이름과 함께 담는다. 폴더 자신의 이름이
  /// 압축파일 최상위 폴더 이름이 된다 — 예: `/Users/me/docs`를 압축하면
  /// 안에 `docs/a.txt`가 생긴다(Finder/탐색기 관례).
  ///
  /// [excludedExtensions]에 걸리는 파일과(디렉터리는 대상이 아니다),
  /// [followSymlinks]가 false일 때 만나는 심볼릭 링크는 건너뛴다(PLAN.md
  /// 1.3 "압축 시 파일 필터"). `followLinks: false`로 순회하면 심볼릭
  /// 링크가 [Link] 타입으로 나와 아래 `if (entity is Directory) ... else if
  /// (entity is File)`에 걸리지 않고 자연히 빠진다 — 최상위 소스 자체가
  /// 심볼릭 링크인 경우도 [FileSystemEntity.type]에 같은 `followLinks`를
  /// 넘겨 동일하게 처리한다.
  Future<List<_PendingEntry>> _collectEntries(
    List<Uri> sources, {
    required Set<String> excludedExtensions,
    required bool followSymlinks,
  }) async {
    final entries = <_PendingEntry>[];
    final normalizedExclusions = {
      for (final ext in excludedExtensions)
        (ext.startsWith('.') ? ext.substring(1) : ext).toLowerCase(),
    };

    for (final source in sources) {
      final rawPath = source.toFilePath();
      final sourcePath =
          rawPath.length > 1 && rawPath.endsWith(Platform.pathSeparator)
              ? rawPath.substring(0, rawPath.length - 1)
              : rawPath;
      final baseName = p.basename(sourcePath);
      final type = await FileSystemEntity.type(sourcePath, followLinks: followSymlinks);

      if (type == FileSystemEntityType.file) {
        if (_isExcluded(sourcePath, normalizedExclusions)) continue;
        entries.add(_PendingEntry(archiveName: baseName, file: File(sourcePath)));
      } else if (type == FileSystemEntityType.directory) {
        entries.add(_PendingEntry(archiveName: '$baseName/', isDirectory: true));
        final dir = Directory(sourcePath);
        await for (final entity in dir.list(recursive: true, followLinks: followSymlinks)) {
          final relative = p.split(p.relative(entity.path, from: sourcePath));
          final archiveName = [baseName, ...relative].join('/');
          if (entity is Directory) {
            entries.add(_PendingEntry(archiveName: '$archiveName/', isDirectory: true));
          } else if (entity is File) {
            if (_isExcluded(entity.path, normalizedExclusions)) continue;
            entries.add(_PendingEntry(archiveName: archiveName, file: entity));
          }
        }
      }
      // 심볼릭 링크(followSymlinks가 false일 때)나 이미 사라진 경로는
      // 조용히 건너뛴다 — 드롭 직후 파일이 옮겨지는 등 경합 상황에서 전체
      // 압축이 실패하지 않도록.
    }

    return entries;
  }

  /// [path]의 확장자가 [normalizedExclusions](이미 점 없이 소문자로 정규화된
  /// 집합)에 있는지. 확장자가 없는 파일(`Makefile` 등)은 절대 걸리지 않는다.
  bool _isExcluded(String path, Set<String> normalizedExclusions) {
    if (normalizedExclusions.isEmpty) return false;
    final ext = p.extension(path);
    if (ext.isEmpty) return false;
    return normalizedExclusions.contains(ext.substring(1).toLowerCase());
  }
}

class _PendingEntry {
  _PendingEntry({required this.archiveName, this.file, this.isDirectory = false});

  final String archiveName;
  final File? file;
  final bool isDirectory;
}
