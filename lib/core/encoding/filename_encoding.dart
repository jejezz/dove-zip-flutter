import 'dart:typed_data';

import 'cp949_table.g.dart';

/// 압축파일 안 파일명을 어떤 인코딩으로 읽을지 (zip은 UTF-8 플래그가 없으면
/// 인코딩을 알 수 없어, 한국어 Windows가 만든 파일은 CP949로 들어 있다).
enum FilenameEncoding {
  /// UTF-8로 읽고, 한글 CP949로 보이는 이름만 자동으로 고친다.
  auto,

  /// 파일에 들어 있는 대로(UTF-8) 읽는다.
  utf8,

  /// 전부 CP949(EUC-KR 확장)로 읽는다.
  cp949,
}

/// `archive` 패키지가 돌려준 [decoded] 이름을 [encoding]에 맞게 고친다.
///
/// 이 패키지는 이름을 UTF-8로 읽다가 실패하면 원본 바이트를 그대로 문자
/// 코드(0~255)로 바꾼다 — 그래서 모든 문자가 255 이하인 이름은 바이트로
/// 손실 없이 되돌릴 수 있다. 255를 넘는 문자가 있으면 이미 올바른 UTF-8
/// 이름이므로 그대로 둔다.
String fixFilenameEncoding(String decoded, FilenameEncoding encoding) {
  if (encoding == FilenameEncoding.utf8) return decoded;

  var hasHigh = false;
  for (final unit in decoded.codeUnits) {
    if (unit > 0xFF) return decoded;
    if (unit > 0x7F) hasHigh = true;
  }
  if (!hasHigh) return decoded;

  final bytes = Uint8List.fromList(decoded.codeUnits);
  if (encoding == FilenameEncoding.cp949) {
    return decodeCp949(bytes, strict: false) ?? decoded;
  }
  // auto: 엄격히 디코딩되고 한글 음절이 들어 있을 때만 CP949로 본다 —
  // 그렇지 않으면 é 같은 정상 UTF-8 이름을 잘못 고치게 된다.
  final cp949 = decodeCp949(bytes, strict: true);
  if (cp949 != null && _hasHangul(cp949)) return cp949;
  return decoded;
}

bool _hasHangul(String s) => s.runes.any((r) => r >= 0xAC00 && r <= 0xD7A3);

/// [bytes]를 CP949로 디코딩한다. [strict]면 잘못된 바이트가 하나라도
/// 있을 때 null, 아니면 그 자리를 U+FFFD로 채운다.
String? decodeCp949(List<int> bytes, {required bool strict}) {
  final out = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b < 0x80) {
      out.writeCharCode(b);
      i++;
      continue;
    }
    String ch = '�';
    var width = 1;
    if (b >= cp949LeadMin && b <= cp949LeadMax && i + 1 < bytes.length) {
      final t = bytes[i + 1];
      if (t >= cp949TrailMin && t <= cp949TrailMax) {
        ch = cp949Table[(b - cp949LeadMin) * (cp949TrailMax - cp949TrailMin + 1) + (t - cp949TrailMin)];
        width = 2;
      }
    }
    if (ch == '�' && strict) return null;
    out.write(ch);
    i += width;
  }
  return out.toString();
}
