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

  group('이름을 정해 압축하기·풀기', () {
    test('처음 이름: 항목 하나면 그 이름, 여럿이면 든 폴더 이름', () {
      expect(quickCompressBaseName([path('photos')]), 'photos');
      expect(quickCompressBaseName([path('a.jpg'), path('b.jpg')]), 'Trip');
    });

    test('압축파일은 입력한 이름으로, 고른 항목과 같은 폴더에 만든다', () {
      expect(quickCompressDestinationNamed([path('photos')], '  My Photos ', ArchiveFormat.zip).toFilePath(), path('My Photos.zip'));
    });

    test('풀 폴더의 처음 이름: 압축파일 하나면 그 이름(압축 확장자를 뺀), 여럿이면 든 폴더 이름', () {
      expect(quickExtractFolderName([path('data.tar.gz')]), 'data');
      expect(quickExtractFolderName([path('a.zip'), path('b.7z')]), 'Trip');
    });

    test('압축파일이 하나면 그 폴더에 바로 푼다', () {
      final targets = quickExtractTargets([path('a.zip')], 'Out');
      expect(targets.single.destination.toFilePath(), path('Out'));
    });

    test('압축파일이 여럿이면 폴더 아래 압축파일 이름의 하위 폴더로 나눠 푼다', () {
      final targets = quickExtractTargets([path('a.zip'), path('b.tar.gz')], 'Out');
      expect(targets.map((t) => t.destination.toFilePath()), [p.join(path('Out'), 'a'), p.join(path('Out'), 'b')]);
      expect(targets.map((t) => t.archive), [path('a.zip'), path('b.tar.gz')]);
    });

    test('Windows에서 쓸 수 없는 이름을 가려낸다', () {
      expect(quickNameProblem('Photos 2024'), isNull);
      expect(quickNameProblem('v1.2'), isNull);
      expect(quickNameProblem('   '), QuickNameProblem.empty);
      for (final bad in ['a/b', r'a\b', 'a:b', 'a*', 'a?', 'a"b', 'a<b', 'a>b', 'a|b', 'dot.']) {
        expect(quickNameProblem(bad), QuickNameProblem.invalidCharacters, reason: bad);
      }
      expect(quickNameProblem('con'), QuickNameProblem.reserved);
      expect(quickNameProblem('NUL.txt'), QuickNameProblem.reserved);
      expect(quickNameProblem('COM1'), QuickNameProblem.reserved);
      expect(quickNameProblem('console'), isNull);
    });
  });

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
