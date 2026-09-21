import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArchiveEntry.name', () {
    test('중첩 경로에서 마지막 세그먼트만 반환한다', () {
      const entry = ArchiveEntry(
        pathInArchive: 'docs/sub/report.pdf',
        isDirectory: false,
      );
      expect(entry.name, 'report.pdf');
    });

    test('최상위 파일은 경로 전체가 이름이다', () {
      const entry = ArchiveEntry(pathInArchive: 'readme.txt', isDirectory: false);
      expect(entry.name, 'readme.txt');
    });

    test('끝에 슬래시가 붙은 디렉터리 엔트리도 올바르게 잘라낸다', () {
      const entry = ArchiveEntry(pathInArchive: 'docs/sub/', isDirectory: true);
      expect(entry.name, 'sub');
    });

    test('슬래시 없는 최상위 디렉터리도 동일하게 동작한다', () {
      const entry = ArchiveEntry(pathInArchive: 'docs', isDirectory: true);
      expect(entry.name, 'docs');
    });
  });

  test('선택적 필드는 기본값을 갖는다', () {
    const entry = ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false);
    expect(entry.uncompressedSize, isNull);
    expect(entry.compressedSize, isNull);
    expect(entry.modifiedAt, isNull);
    expect(entry.isEncrypted, isFalse);
  });
}
