import 'package:dove_zip/application/quick_compress.dart';
import 'package:dove_zip/data/format_registry.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 우클릭 "압축하기"가 만드는 파일 이름.
void main() {
  final dir = p.join(p.separator == r'\' ? r'C:\' : '/', 'work', 'Trip');
  String path(String name) => p.join(dir, name);
  String dest(List<String> paths, ArchiveFormat format, {Set<String> taken = const {}}) =>
      quickCompressDestination(paths, format, exists: taken.contains).toFilePath();

  test('항목 하나: 그 이름, 파일이면 확장자를 뺀다', () {
    expect(dest([path('photos')], ArchiveFormat.zip), path('photos.zip'));
    expect(dest([path('report.pdf')], ArchiveFormat.zip), path('report.zip'));
    expect(dest([path('photos') + p.separator], ArchiveFormat.zip), path('photos.zip'));
  });

  test('여러 개: 그 항목들이 든 폴더 이름', () {
    expect(dest([path('a.jpg'), path('b.jpg')], ArchiveFormat.zip), path('Trip.zip'));
  });

  test('설정한 형식의 확장자를 쓴다', () {
    expect(dest([path('photos')], ArchiveFormat.tar), path('photos.tar'));
    expect(dest([path('photos')], ArchiveFormat.tarGz), path('photos.${FormatRegistry.of(ArchiveFormat.tarGz).extensions.first}'));
    expect(dest([path('photos')], ArchiveFormat.sevenZip), path('photos.7z'));
  });

  test('이름이 있으면 (2), (3) …', () {
    expect(dest([path('photos')], ArchiveFormat.zip, taken: {path('photos.zip')}), path('photos (2).zip'));
    expect(
      dest([path('photos')], ArchiveFormat.zip, taken: {path('photos.zip'), path('photos (2).zip')}),
      path('photos (3).zip'),
    );
  });

  test('바로 만들 수 있는 형식은 모두 여러 항목을 담고 쓸 수 있다', () {
    for (final format in quickCompressFormats) {
      expect(FormatRegistry.canWrite(format), isTrue, reason: '$format');
    }
    expect(quickCompressFormats, isNot(contains(ArchiveFormat.gzip)));
    expect(quickCompressFormats.first, defaultQuickCompressFormat);
  });
}
