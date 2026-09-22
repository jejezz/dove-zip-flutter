import 'package:dove_zip/application/archive_browser_entries.dart';
import 'package:dove_zip/domain/entities/archive_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('childrenOf', () {
    test('루트의 파일만 있으면 그대로 보여준다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'b.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'a.txt', isDirectory: false),
      ];
      final children = childrenOf(entries, '');
      expect(children.map((e) => e.name).toList(), ['a.txt', 'b.txt']);
      expect(children.every((e) => !e.isDirectory), isTrue);
    });

    test('디렉터리 엔트리가 없어도 파일 경로에서 가상 폴더를 유추한다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'docs/sub/b.txt', isDirectory: false),
      ];
      final rootChildren = childrenOf(entries, '');
      expect(rootChildren, hasLength(1));
      expect(rootChildren.single.name, 'docs');
      expect(rootChildren.single.isDirectory, isTrue);
      expect(rootChildren.single.sourceEntry, isNull); // 가상 폴더
    });

    test('실제 디렉터리 엔트리가 있으면 그것을 sourceEntry로 담는다(중복 없음)', () {
      const dirEntry = ArchiveEntry(pathInArchive: 'docs/', isDirectory: true);
      const entries = [
        dirEntry,
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
      ];
      final rootChildren = childrenOf(entries, '');
      expect(rootChildren, hasLength(1));
      expect(rootChildren.single.name, 'docs');
      expect(rootChildren.single.sourceEntry, dirEntry);
    });

    test('디렉터리 엔트리가 나중에 나와도 가상 폴더를 실제 엔트리로 대체한다', () {
      const dirEntry = ArchiveEntry(pathInArchive: 'docs/', isDirectory: true);
      const entries = [
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false), // 먼저 등장
        dirEntry, // 나중에 등장
      ];
      final rootChildren = childrenOf(entries, '');
      expect(rootChildren, hasLength(1));
      expect(rootChildren.single.sourceEntry, dirEntry);
    });

    test('한 단계 더 들어가면 그 폴더 안의 항목만 보여준다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'docs/sub/b.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'readme.txt', isDirectory: false),
      ];
      final docsChildren = childrenOf(entries, 'docs');
      expect(docsChildren.map((e) => e.name).toSet(), {'a.txt', 'sub'});

      final subChildren = childrenOf(entries, 'docs/sub');
      expect(subChildren.map((e) => e.name).toList(), ['b.txt']);
    });

    test('현재 폴더 자신의 디렉터리 엔트리는 자기 목록에 나타나지 않는다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
      ];
      final docsChildren = childrenOf(entries, 'docs');
      expect(docsChildren.map((e) => e.name).toList(), ['a.txt']);
    });

    test('폴더가 파일보다 먼저, 그 다음은 대소문자 무시 이름순이다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'b.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'A.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'zzz/x.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'aaa/x.txt', isDirectory: false),
      ];
      final children = childrenOf(entries, '');
      expect(children.map((e) => e.name).toList(), ['aaa', 'zzz', 'A.txt', 'b.txt']);
    });

    test('다른 폴더 아래 항목은 섞이지 않는다', () {
      const entries = [
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'documents/b.txt', isDirectory: false),
      ];
      final docsChildren = childrenOf(entries, 'docs');
      expect(docsChildren.map((e) => e.name).toList(), ['a.txt']);
    });
  });

  group('expandSelectionToEntryPaths (PLAN.md 1.2 "선택 항목만 해제")', () {
    const entries = [
      ArchiveEntry(pathInArchive: 'root.txt', isDirectory: false),
      ArchiveEntry(pathInArchive: 'docs/', isDirectory: true),
      ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
      ArchiveEntry(pathInArchive: 'docs/sub/', isDirectory: true),
      ArchiveEntry(pathInArchive: 'docs/sub/b.txt', isDirectory: false),
      ArchiveEntry(pathInArchive: 'documents/c.txt', isDirectory: false),
    ];

    test('파일 하나를 선택하면 그 파일 하나만 포함한다', () {
      final result = expandSelectionToEntryPaths(entries, {'root.txt'});
      expect(result, {'root.txt'});
    });

    test('폴더를 선택하면 그 안의 모든 하위 엔트리(몇 단계든)를 포함한다', () {
      final result = expandSelectionToEntryPaths(entries, {'docs'});
      expect(result, {
        'docs/',
        'docs/a.txt',
        'docs/sub/',
        'docs/sub/b.txt',
      });
    });

    test('가상 폴더(디렉터리 엔트리 없음)를 선택해도 하위 파일들을 포함한다', () {
      const virtualOnly = [
        ArchiveEntry(pathInArchive: 'photos/a.jpg', isDirectory: false),
        ArchiveEntry(pathInArchive: 'photos/b.jpg', isDirectory: false),
        ArchiveEntry(pathInArchive: 'other.txt', isDirectory: false),
      ];
      final result = expandSelectionToEntryPaths(virtualOnly, {'photos'});
      expect(result, {'photos/a.jpg', 'photos/b.jpg'});
    });

    test('비슷한 이름의 다른 폴더까지 잘못 포함하지 않는다(prefix 오탐 방지)', () {
      const similar = [
        ArchiveEntry(pathInArchive: 'docs/a.txt', isDirectory: false),
        ArchiveEntry(pathInArchive: 'docs2/b.txt', isDirectory: false),
      ];
      final result = expandSelectionToEntryPaths(similar, {'docs'});
      expect(result, {'docs/a.txt'});
    });

    test('여러 개를 동시에 선택하면 합쳐서 반환한다', () {
      final result = expandSelectionToEntryPaths(entries, {
        'root.txt',
        'docs/sub',
      });
      expect(result, {'root.txt', 'docs/sub/', 'docs/sub/b.txt'});
    });

    test('빈 선택은 빈 결과를 반환한다', () {
      expect(expandSelectionToEntryPaths(entries, {}), isEmpty);
    });
  });
}
