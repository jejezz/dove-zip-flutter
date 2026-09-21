import 'package:dove_zip/data/format_registry.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모든 ArchiveFormat이 레지스트리에 등록돼 있다', () {
    for (final format in ArchiveFormat.values) {
      expect(() => FormatRegistry.of(format), returnsNormally,
          reason: '$format 항목 누락');
    }
  });

  group('생성+해제 포맷', () {
    for (final format in [
      ArchiveFormat.zip,
      ArchiveFormat.tar,
      ArchiveFormat.tarGz,
      ArchiveFormat.tarBz2,
      ArchiveFormat.gzip,
      ArchiveFormat.bzip2,
      ArchiveFormat.tarXz,
      ArchiveFormat.xz,
      ArchiveFormat.tarZst,
      ArchiveFormat.zstd,
      ArchiveFormat.sevenZip,
      ArchiveFormat.lz4,
      ArchiveFormat.brotli,
    ]) {
      test('$format은 읽기/쓰기 모두 가능하다', () {
        expect(FormatRegistry.canRead(format), isTrue);
        expect(FormatRegistry.canWrite(format), isTrue);
        expect(FormatRegistry.of(format).writeBackend, isNotNull);
      });
    }
  });

  group('해제 전용 포맷 (PLAN.md 3장 RAR 정책 포함)', () {
    for (final format in [
      ArchiveFormat.rar,
      ArchiveFormat.iso9660,
      ArchiveFormat.cab,
      ArchiveFormat.arj,
      ArchiveFormat.lha,
      ArchiveFormat.cpio,
      ArchiveFormat.ar,
      ArchiveFormat.xar,
      ArchiveFormat.warc,
    ]) {
      test('$format은 해제만 가능하고 생성은 불가능하다', () {
        expect(FormatRegistry.canRead(format), isTrue);
        expect(FormatRegistry.canWrite(format), isFalse);
        expect(FormatRegistry.of(format).writeBackend, isNull);
      });
    }
  });

  test('writableFormats에는 RAR 등 해제 전용 포맷이 없다', () {
    final writable = FormatRegistry.writableFormats;
    expect(writable, isNot(contains(ArchiveFormat.rar)));
    expect(writable, contains(ArchiveFormat.zip));
    expect(writable, contains(ArchiveFormat.sevenZip));
    expect(writable.length, 13);
  });

  group('detectFromFileName', () {
    test('이중 확장자를 gzip/bzip2로 오판하지 않는다', () {
      expect(
        FormatRegistry.detectFromFileName('photos.tar.gz'),
        ArchiveFormat.tarGz,
      );
      expect(
        FormatRegistry.detectFromFileName('photos.tar.bz2'),
        ArchiveFormat.tarBz2,
      );
      expect(
        FormatRegistry.detectFromFileName('photos.tar.xz'),
        ArchiveFormat.tarXz,
      );
      expect(
        FormatRegistry.detectFromFileName('photos.tar.zst'),
        ArchiveFormat.tarZst,
      );
    });

    test('단일 확장자를 정확히 판별한다', () {
      expect(FormatRegistry.detectFromFileName('archive.zip'), ArchiveFormat.zip);
      expect(FormatRegistry.detectFromFileName('data.7z'), ArchiveFormat.sevenZip);
      expect(FormatRegistry.detectFromFileName('backup.rar'), ArchiveFormat.rar);
      expect(FormatRegistry.detectFromFileName('note.gz'), ArchiveFormat.gzip);
    });

    test('대소문자를 구분하지 않는다', () {
      expect(FormatRegistry.detectFromFileName('PHOTOS.TAR.GZ'), ArchiveFormat.tarGz);
      expect(FormatRegistry.detectFromFileName('ARCHIVE.ZIP'), ArchiveFormat.zip);
    });

    test('축약 확장자(tgz 등)도 인식한다', () {
      expect(FormatRegistry.detectFromFileName('photos.tgz'), ArchiveFormat.tarGz);
      expect(FormatRegistry.detectFromFileName('photos.tbz2'), ArchiveFormat.tarBz2);
      expect(FormatRegistry.detectFromFileName('photos.txz'), ArchiveFormat.tarXz);
    });

    test('알 수 없는 확장자는 null을 반환한다', () {
      expect(FormatRegistry.detectFromFileName('readme.txt'), isNull);
      expect(FormatRegistry.detectFromFileName('no_extension'), isNull);
    });
  });

  group('stripKnownExtension', () {
    test('이중 확장자를 한 번에 제거한다', () {
      expect(FormatRegistry.stripKnownExtension('photos.tar.gz'), 'photos');
      expect(FormatRegistry.stripKnownExtension('photos.tar.bz2'), 'photos');
    });

    test('단일 확장자를 제거한다', () {
      expect(FormatRegistry.stripKnownExtension('notes.txt.gz'), 'notes.txt');
      expect(FormatRegistry.stripKnownExtension('archive.zip'), 'archive');
    });

    test('알려진 확장자가 아니면 그대로 반환한다', () {
      expect(FormatRegistry.stripKnownExtension('readme.txt'), 'readme.txt');
    });

    test('분할 볼륨 접미사가 있으면 먼저 뗀 뒤 압축 확장자를 제거한다', () {
      expect(FormatRegistry.stripKnownExtension('archive.zip.001'), 'archive');
      expect(FormatRegistry.stripKnownExtension('photos.tar.gz.002'), 'photos');
    });
  });

  group('분할 볼륨(PLAN.md 1.3 "분할 압축")', () {
    test('isSplitVolumePart는 3자리 이상 숫자 접미사만 조각으로 인식한다', () {
      expect(FormatRegistry.isSplitVolumePart('archive.zip.001'), isTrue);
      expect(FormatRegistry.isSplitVolumePart('archive.zip.1234'), isTrue);
      expect(FormatRegistry.isSplitVolumePart('archive.zip'), isFalse);
      // 2자리 이하는 조각으로 보지 않는다 — 일반 파일명과 헷갈릴 여지를 줄임.
      expect(FormatRegistry.isSplitVolumePart('archive.zip.01'), isFalse);
    });

    test('splitVolumeIndexOf는 번호를 정수로 반환한다', () {
      expect(FormatRegistry.splitVolumeIndexOf('archive.zip.007'), 7);
      expect(FormatRegistry.splitVolumeIndexOf('archive.zip.1000'), 1000);
      expect(FormatRegistry.splitVolumeIndexOf('archive.zip'), isNull);
    });

    test('stripSplitVolumeSuffix는 번호 접미사만 뗀다', () {
      expect(FormatRegistry.stripSplitVolumeSuffix('archive.zip.007'), 'archive.zip');
      expect(FormatRegistry.stripSplitVolumeSuffix('archive.zip'), 'archive.zip');
    });

    test('detectFromFileName은 분할 조각도 원래 포맷으로 판별한다', () {
      expect(FormatRegistry.detectFromFileName('archive.zip.001'), ArchiveFormat.zip);
      expect(FormatRegistry.detectFromFileName('photos.tar.gz.003'), ArchiveFormat.tarGz);
    });
  });
}
