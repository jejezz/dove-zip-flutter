import 'package:dove_zip/application/resolve_extract_destination.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:dove_zip/domain/entities/extract_destination_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('basenameWithoutArchiveExtensions', () {
    test('이중 확장자를 한 번에 제거한다', () {
      expect(
        basenameWithoutArchiveExtensions(Uri.file('/tmp/photos.tar.gz')),
        'photos',
      );
      expect(
        basenameWithoutArchiveExtensions(Uri.file('/tmp/photos.tar.bz2')),
        'photos',
      );
      expect(
        basenameWithoutArchiveExtensions(Uri.file('/tmp/photos.tar.zst')),
        'photos',
      );
    });

    test('단일 확장자를 제거한다', () {
      expect(basenameWithoutArchiveExtensions(Uri.file('/tmp/photos.zip')),
          'photos');
      expect(basenameWithoutArchiveExtensions(Uri.file('/tmp/data.7z')), 'data');
      expect(basenameWithoutArchiveExtensions(Uri.file('/tmp/backup.rar')),
          'backup');
    });

    test('이름 자체에 점이 여러 개 있어도 확장자만 제거한다', () {
      expect(
        basenameWithoutArchiveExtensions(Uri.file('/tmp/my.report.v2.zip')),
        'my.report.v2',
      );
    });

    test('대소문자를 구분하지 않고 확장자를 인식한다', () {
      expect(basenameWithoutArchiveExtensions(Uri.file('/tmp/PHOTOS.TAR.GZ')),
          'PHOTOS');
    });

    test('알려진 압축 확장자가 아니면 그대로 반환한다', () {
      expect(basenameWithoutArchiveExtensions(Uri.file('/tmp/readme.txt')),
          'readme.txt');
    });

    test('분할 압축 조각이어도 일반 압축파일과 같은 폴더 이름을 계산한다', () {
      expect(
        basenameWithoutArchiveExtensions(Uri.file('/tmp/photos.zip.001')),
        'photos',
      );
      expect(
        basenameWithoutArchiveExtensions(Uri.file('/tmp/photos.tar.gz.002')),
        'photos',
      );
    });
  });

  group('hasSingleTopLevelFolderNamed', () {
    test('빈 엔트리 목록은 항상 false다', () {
      expect(hasSingleTopLevelFolderNamed(const [], 'photos'), isFalse);
    });

    test('모든 엔트리가 같은 최상위 폴더 하나뿐이면 true다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'photos/', isDirectory: true),
        ArchiveEntry(pathInArchive: 'photos/a.jpg', isDirectory: false),
        ArchiveEntry(pathInArchive: 'photos/sub/b.jpg', isDirectory: false),
      ];
      expect(hasSingleTopLevelFolderNamed(entries, 'photos'), isTrue);
    });

    test('최상위 폴더 이름이 압축파일명과 다르면 false다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'other/a.jpg', isDirectory: false),
      ];
      expect(hasSingleTopLevelFolderNamed(entries, 'photos'), isFalse);
    });

    test('대소문자가 다르면 다른 이름으로 취급한다(엄격 매칭)', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'Photos/a.jpg', isDirectory: false),
      ];
      expect(hasSingleTopLevelFolderNamed(entries, 'photos'), isFalse);
    });

    test('최상위에 루트 레벨 파일이 섞여 있으면 false다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'photos/a.jpg', isDirectory: false),
        ArchiveEntry(pathInArchive: 'readme.txt', isDirectory: false),
      ];
      expect(hasSingleTopLevelFolderNamed(entries, 'photos'), isFalse);
    });
  });

  group('resolveExtractDestination', () {
    final archiveLocation = Uri.file('/tmp/downloads/photos.tar.gz');
    const nestedEntries = [
      ArchiveEntry(pathInArchive: 'a.jpg', isDirectory: false),
      ArchiveEntry(pathInArchive: 'b.jpg', isDirectory: false),
    ];
    const singleFolderEntries = [
      ArchiveEntry(pathInArchive: 'photos/', isDirectory: true),
      ArchiveEntry(pathInArchive: 'photos/a.jpg', isDirectory: false),
    ];

    test('here 모드는 항상 압축파일이 있는 폴더를 반환한다', () {
      final destination = resolveExtractDestination(
        archiveLocation: archiveLocation,
        mode: ExtractDestinationMode.here,
        entries: nestedEntries,
      );
      expect(destination, Uri.file('/tmp/downloads'));
    });

    test('smart 모드는 단일 최상위 폴더가 없으면 압축파일명 폴더를 새로 만든다', () {
      final destination = resolveExtractDestination(
        archiveLocation: archiveLocation,
        mode: ExtractDestinationMode.smart,
        entries: nestedEntries,
      );
      expect(destination, Uri.file('/tmp/downloads/photos'));
    });

    test('smart 모드는 내부에 이미 동일 이름 폴더 하나뿐이면 이중 중첩하지 않는다', () {
      final destination = resolveExtractDestination(
        archiveLocation: archiveLocation,
        mode: ExtractDestinationMode.smart,
        entries: singleFolderEntries,
      );
      expect(destination, Uri.file('/tmp/downloads'));
    });

    test('chooseFolder 모드는 사용자가 고른 폴더를 그대로 반환한다', () {
      final chosen = Uri.file('/Volumes/External/backup');
      final destination = resolveExtractDestination(
        archiveLocation: archiveLocation,
        mode: ExtractDestinationMode.chooseFolder,
        entries: nestedEntries,
        userChosenFolder: chosen,
      );
      expect(destination, chosen);
    });

    test('chooseFolder 모드에서 폴더를 안 넘기면 에러를 던진다', () {
      expect(
        () => resolveExtractDestination(
          archiveLocation: archiveLocation,
          mode: ExtractDestinationMode.chooseFolder,
          entries: nestedEntries,
        ),
        throwsArgumentError,
      );
    });
  });
}
