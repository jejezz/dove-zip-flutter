import 'package:dove_zip/application/launch_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// 명령줄 인자 — Windows 탐색기 우클릭 메뉴와 파일 연결.
void main() {
  test('경로만 오면(파일 연결) 연다', () {
    final request = LaunchRequest.parse([r'C:\a.zip', r'C:\b.7z']);
    expect(request.action, LaunchAction.openFiles);
    expect(request.paths, [r'C:\a.zip', r'C:\b.7z']);
  });

  test('--compress-here / --extract-here', () {
    expect(LaunchRequest.parse(['--compress-here', r'C:\photos']).action, LaunchAction.compressHere);
    final extract = LaunchRequest.parse(['--extract-here', r'C:\a.zip']);
    expect(extract.action, LaunchAction.extractHere);
    expect(extract.paths, [r'C:\a.zip']);
  });

  test('모르는 플래그와 빈 인자는 경로로 보지 않는다', () {
    expect(LaunchRequest.parse(['--verbose', '', r'C:\a.zip']).paths, [r'C:\a.zip']);
    expect(LaunchRequest.parse(const []).paths, isEmpty);
  });

  test('toArgs를 다시 parse하면 같다', () {
    for (final action in LaunchAction.values) {
      final again = LaunchRequest.parse(LaunchRequest(action, const ['x', 'y']).toArgs());
      expect(again.action, action);
      expect(again.paths, ['x', 'y']);
    }
  });

  test('macOS 채널 메서드 이름', () {
    expect(LaunchAction.fromMethod('compressHere'), LaunchAction.compressHere);
    expect(LaunchAction.fromMethod('extractHere'), LaunchAction.extractHere);
    expect(LaunchAction.fromMethod('openFiles'), LaunchAction.openFiles);
    expect(LaunchAction.fromMethod('nope'), isNull);
  });
}
