import 'dart:io';

import 'package:flutter/material.dart';

import '../../application/usecases/open_with_default_app.dart';
import '../../l10n/app_localizations.dart';
import 'file_viewer.dart';

const _openWithDefaultApp = OpenWithDefaultApp();

/// 압축파일 안 항목 하나를 미리보기(F3)로 연다.
///
/// [tempFilePath]는 이미 임시 폴더로 꺼내진 파일이다(`PreviewArchiveEntry`).
/// 매칭되는 [FileViewer]가 없으면 "OS 기본 앱으로 열기" 버튼만 보여준다
/// (ARCHITECTURE.md 9장).
class EntryViewerScreen extends StatelessWidget {
  const EntryViewerScreen({super.key, required this.tempFilePath, required this.name});

  final String tempFilePath;
  final String name;

  @override
  Widget build(BuildContext context) {
    final viewer = ViewerRegistry.forFile(name);
    return Scaffold(
      appBar: AppBar(title: Text(name), toolbarHeight: 44),
      body: viewer != null
          ? viewer.build(context, File(tempFilePath))
          : _UnsupportedView(path: tempFilePath),
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.unsupportedFormat),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _openWithDefaultApp(path),
            child: Text(l10n.openWithDefaultAppButton),
          ),
        ],
      ),
    );
  }
}
