import 'package:dove_zip/core/encoding/filename_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

/// archive 패키지가 UTF-8 실패 시 돌려주는 형태(바이트 = 문자 코드)로 만든다.
String _raw(List<int> bytes) => String.fromCharCodes(bytes);

void main() {
  final hangul = _raw(_cp949HangulTxt);

  test('auto: CP949 이름을 복원한다', () {
    expect(fixFilenameEncoding(hangul, FilenameEncoding.auto), '한글.txt');
  });

  test('auto: ASCII와 정상 UTF-8 이름은 그대로 둔다', () {
    expect(fixFilenameEncoding('a/b.txt', FilenameEncoding.auto), 'a/b.txt');
    expect(fixFilenameEncoding('한글.txt', FilenameEncoding.auto), '한글.txt');
    expect(fixFilenameEncoding('café.txt', FilenameEncoding.auto), 'café.txt');
  });

  test('utf8: 손대지 않는다', () {
    expect(fixFilenameEncoding(hangul, FilenameEncoding.utf8), hangul);
  });

  test('cp949: 강제로 CP949로 읽는다', () {
    expect(fixFilenameEncoding(hangul, FilenameEncoding.cp949), '한글.txt');
  });

  test('decodeCp949 strict는 잘못된 바이트에 null', () {
    expect(decodeCp949([0xC7], strict: true), isNull);
    expect(decodeCp949([0xC7], strict: false), '�');
  });
}

// "한글.txt"의 CP949 바이트.
const _cp949HangulTxt = [0xC7, 0xD1, 0xB1, 0xDB, 0x2E, 0x74, 0x78, 0x74];
