import 'package:dove_zip/application/usecases/create_archive.dart';
import 'package:dove_zip/application/usecases/open_archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/compression_options.dart';
import 'package:dove_zip/domain/repositories/archive_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 디스크에 쓰지 않고 `CreateArchive`가 넘기는 인자만 기록하는 가짜
/// 라이터. 실제 압축 결과 검증은 dart_archive_writer_test.dart가 맡는다.
class _RecordingWriter implements ArchiveWriter {
  _RecordingWriter({this.supportedFormat = ArchiveFormat.zip});

  final ArchiveFormat supportedFormat;
  List<Uri>? lastSources;
  Uri? lastDestination;

  @override
  bool supports(ArchiveFormat format) => format == supportedFormat;

  @override
  Future<void> compress({
    required List<Uri> sources,
    required Uri destination,
    required CompressionOptions options,
    CompressProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    lastSources = sources;
    lastDestination = destination;
  }
}

void main() {
  final sources = [Uri.file('/tmp/a.txt'), Uri.file('/tmp/b.txt')];
  final destination = Uri.file('/tmp/out.zip');

  test('지원하는 포맷이면 그대로 라이터에 위임한다', () async {
    final writer = _RecordingWriter();
    final createArchive = CreateArchive(writer);

    await createArchive(
      sources: sources,
      destination: destination,
      options: const CompressionOptions(format: ArchiveFormat.zip),
    );

    expect(writer.lastSources, sources);
    expect(writer.lastDestination, destination);
  });

  test('FormatRegistry가 해제 전용으로 아는 포맷(RAR)은 라이터를 부르기 전에 막는다', () async {
    // 어떤 포맷이든 지원한다고 우기는 라이터를 줘도, RAR은 canWrite가
    // false라 CreateArchive 단계에서 먼저 걸려야 한다.
    final writer = _RecordingWriter(supportedFormat: ArchiveFormat.rar);
    final createArchive = CreateArchive(writer);

    expect(
      () => createArchive(
        sources: sources,
        destination: destination,
        options: const CompressionOptions(format: ArchiveFormat.rar),
      ),
      throwsA(isA<UnsupportedArchiveFormatException>()),
    );
    expect(writer.lastDestination, isNull);
  });

  test('라이터가 그 포맷을 지원하지 않으면 예외를 던진다', () async {
    final writer = _RecordingWriter(supportedFormat: ArchiveFormat.tar);
    final createArchive = CreateArchive(writer);

    expect(
      () => createArchive(
        sources: sources,
        destination: destination,
        options: const CompressionOptions(format: ArchiveFormat.zip),
      ),
      throwsA(isA<UnsupportedArchiveFormatException>()),
    );
  });
}
