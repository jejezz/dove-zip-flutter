import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../widgets/error_message.dart';

/// 미리보기(F3) 확장 포인트 (ARCHITECTURE.md 9장).
///
/// daylight-commander-flutter의 `ViewerScreen`과 같은 확장자 화이트리스트
/// 방식 — 매칭되는 뷰어가 없으면 [ViewerRegistry.forFile]이 null을
/// 반환하고, 화면은 "OS 기본 앱으로 열기"로 폴백한다.
abstract class FileViewer {
  const FileViewer();

  bool canHandle(String extension);

  Widget build(BuildContext context, File file);
}

/// 등록된 뷰어 중 파일에 맞는 것을 찾는다. Hex 덤프(P1)/PDF·미디어(P2)는
/// 아직 없다 — daylight의 우선순위 그대로 텍스트/이미지부터.
class ViewerRegistry {
  const ViewerRegistry._();

  static const List<FileViewer> _viewers = [TextFileViewer(), ImageFileViewer()];

  static FileViewer? forFile(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    for (final viewer in _viewers) {
      if (viewer.canHandle(extension)) return viewer;
    }
    return null;
  }
}

const _textExtensions = {
  'txt', 'md', 'json', 'xml', 'html', 'htm', 'css', 'java', 'dart', 'py', 'js', //
  'ts', 'yaml', 'yml', 'sql', 'sh', 'log', 'ini', 'csv', 'c', 'cpp', 'h', 'kt',
  'swift', 'gradle',
};

class TextFileViewer extends FileViewer {
  const TextFileViewer();

  @override
  bool canHandle(String extension) => _textExtensions.contains(extension);

  @override
  Widget build(BuildContext context, File file) => _TextView(file: file);
}

class _TextView extends StatefulWidget {
  const _TextView({required this.file});

  final File file;

  @override
  State<_TextView> createState() => _TextViewState();
}

class _TextViewState extends State<_TextView> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.file.readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        // 인코딩 자동 감지는 아직 없음(P2) — UTF-8 실패 시 Latin-1로 폴백
        // (daylight-commander-flutter의 ViewerScreen과 동일 정책).
        text = latin1.decode(bytes);
      }
      if (mounted) setState(() => _content = text);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(AppLocalizations.of(context), e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (_content == null) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content!,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

class ImageFileViewer extends FileViewer {
  const ImageFileViewer();

  @override
  bool canHandle(String extension) => _imageExtensions.contains(extension);

  @override
  Widget build(BuildContext context, File file) => InteractiveViewer(
        minScale: 0.1,
        maxScale: 8,
        child: Center(
          child: Image.file(
            file,
            errorBuilder: (context, error, stack) =>
                Text(AppLocalizations.of(context).imageLoadError('$error')),
          ),
        ),
      );
}
