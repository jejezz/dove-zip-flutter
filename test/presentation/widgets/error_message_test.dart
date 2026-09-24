import 'package:dove_zip/application/drag_out_staging.dart';
import 'package:dove_zip/application/usecases/open_archive.dart';
import 'package:dove_zip/core/cancel_token.dart';
import 'package:dove_zip/domain/entities/extract_failure.dart';
import 'package:dove_zip/domain/repositories/archive_reader.dart';
import 'package:dove_zip/domain/repositories/archive_writer.dart';
import 'package:dove_zip/l10n/app_localizations.dart';
import 'package:dove_zip/presentation/widgets/error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 사용자가 만나는 예외는 현재 언어의 문구로, 그 밖의 예외는 텍스트 그대로.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('전용 예외는 언어별 문구로 바뀐다', () {
    expect(describeError(ko, const OperationCancelledException()), '작업이 취소되었습니다.');
    expect(describeError(en, const OperationCancelledException()), 'The operation was cancelled.');
    expect(describeError(ko, const UnsupportedArchiveFormatException('a.lzh')), contains('a.lzh'));
    expect(describeError(en, const UnsupportedArchiveFormatException('a.lzh')),
        'Unknown or not yet supported archive format: a.lzh');
    expect(describeError(ko, const ArchivePasswordRequiredException('secret.txt')),
        '"secret.txt" 항목에 비밀번호가 필요하거나 비밀번호가 틀렸습니다.');
  });

  test('분할 조각 누락은 번호가 있을 때와 없을 때 문구가 다르다', () {
    expect(describeError(ko, const MissingSplitVolumeException('a.zip.001', missingIndex: 2)),
        '분할 압축 조각이 빠졌습니다 (조각 2번을 찾을 수 없음): a.zip.001');
    expect(describeError(en, const MissingSplitVolumeException('a.zip.001')),
        "Couldn't find the split volumes: a.zip.001");
  });

  test('단일 파일 형식은 폴더와 여러 항목을 구분한다', () {
    expect(describeError(ko, const SingleFileFormatException('gzip', isDirectory: true)),
        startsWith('gzip 형식은 폴더를'));
    expect(describeError(en, const SingleFileFormatException('gzip', isDirectory: false)),
        startsWith('gzip can compress only a single file'));
  });

  test('끌어내기 대상 충돌은 파일 이름만 보여 준다', () {
    expect(describeError(en, const DragOutTargetExistsException('/Users/me/Desktop/photo.jpg')),
        'An item with the same name already exists: photo.jpg');
  });

  test('손상 항목 목록은 예외 원본이 있으면 번역하고, 없으면 메시지를 쓴다', () {
    const withError = ExtractFailure(
      entryPath: 'a.txt',
      message: 'ignored',
      error: ArchivePasswordRequiredException('a.txt'),
    );
    expect(describeFailure(en, withError), 'a.txt: "a.txt" needs a password, or the password is wrong.');
    expect(describeFailure(en, const ExtractFailure(entryPath: 'b.bin', message: 'CRC mismatch')),
        'b.bin: CRC mismatch');
  });

  test('전용 예외가 아니면 텍스트 그대로', () {
    expect(describeError(ko, const FormatException('bad header')), 'FormatException: bad header');
  });
}
