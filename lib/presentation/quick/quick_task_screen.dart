import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../application/background_jobs.dart';
import '../../application/launch_request.dart';
import '../../application/quick_compress.dart';
import '../../application/usecases/extract_entries.dart';
import '../../domain/repositories/archive_writer.dart';
import '../../core/cancel_token.dart';
import '../../data/format_registry.dart';
import '../../domain/entities/archive_entry.dart';
import '../../domain/entities/archive_handle.dart';
import '../../domain/entities/compression_options.dart';
import '../../domain/entities/extract_destination_mode.dart';
import '../../domain/repositories/archive_reader.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/conflict_dialog.dart';
import '../widgets/error_message.dart';
import '../widgets/password_prompt_dialog.dart';

/// 탐색기 우클릭 메뉴("압축하기"/"알아서 풀기")를 창 없이 처리한다 —
/// Windows 기본 압축처럼 사용자가 거의 눈치채지 못하게 (PLAN.md 1.4).
///
/// 창은 처음에 숨겨 둔다. [revealAfter] 안에 끝나면 끝내 보이지 않고 앱이
/// 끝난다. 더 걸리면 진행률과 취소만 있는 작은 창을 띄운다. 비밀번호나 이름
/// 충돌을 물어야 할 때, 오류·손상 항목을 알려야 할 때도 그때 창을 띄운다.
class QuickTaskScreen extends StatefulWidget {
  const QuickTaskScreen({
    super.key,
    required this.request,
    required this.showWindow,
    required this.exitApp,
    this.closeRequests,
    this.revealAfter = const Duration(seconds: 1),
    this.readFormat,
    this.createArchive = compressInBackground,
    this.openArchive = openArchiveInBackground,
    this.extractEntries = extractInBackground,
  });

  final LaunchRequest request;

  /// 숨겨 둔 창을 보인다. 여러 번 불려도 된다. [prompt]면 무엇을 물을 수
  /// 있게 창을 키운다.
  final Future<void> Function({bool prompt}) showWindow;

  /// 앱을 끝낸다.
  final VoidCallback exitApp;

  /// 사용자가 창의 X를 눌렀다 — 작업 중이면 취소하고, 아니면 끝낸다.
  final Stream<void>? closeRequests;

  final Duration revealAfter;

  /// "압축하기" 형식. null이면 기본값(ZIP).
  final Future<ArchiveFormat> Function()? readFormat;

  /// 기본은 백그라운드 isolate([compressInBackground] 등) — 큰 파일을
  /// 처리하는 동안에도 작은 창이 뜨고 반응한다. 테스트는 유스케이스의
  /// `call`을 그대로 넘긴다.
  final CompressJob createArchive;
  final OpenJob openArchive;
  final ExtractJob extractEntries;

  @override
  State<QuickTaskScreen> createState() => _QuickTaskScreenState();
}

typedef CompressJob = Future<void> Function({
  required List<Uri> sources,
  required Uri destination,
  required CompressionOptions options,
  CompressProgressCallback? onProgress,
  CancelToken? cancelToken,
});

typedef OpenJob = Future<ArchiveHandle> Function(Uri location);

typedef ExtractJob = Future<ExtractResult> Function({
  required ArchiveHandle handle,
  required ExtractDestinationMode mode,
  List<String>? entryPaths,
  String? password,
  Uri? userChosenFolder,
  required ConflictResolver onConflict,
  ExtractProgressCallback? onProgress,
  CancelToken? cancelToken,
});

typedef _Progress = ({int done, int total, String currentName});

class _QuickTaskScreenState extends State<QuickTaskScreen> {
  final _cancelToken = CancelToken();
  final _progress = ValueNotifier<_Progress?>(null);
  StreamSubscription<void>? _closeSub;
  Timer? _revealTimer;
  bool _shown = false;
  bool _running = true;

  /// 끝났는데 알려야 할 것 — 오류, 손상 항목. null이면 조용히 끝낸다.
  String? _message;

  @override
  void initState() {
    super.initState();
    _revealTimer = Timer(widget.revealAfter, _reveal);
    _closeSub = widget.closeRequests?.listen((_) {
      if (_running) {
        _cancelToken.cancel();
      } else {
        widget.exitApp();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _closeSub?.cancel();
    super.dispose();
  }

  Future<void> _reveal({bool prompt = false}) async {
    if (!mounted || (_shown && !prompt)) return;
    _shown = true;
    await widget.showWindow(prompt: prompt);
  }

  Future<void> _run() async {
    String? message;
    try {
      message = switch (widget.request.action) {
        LaunchAction.compressHere => await _compress(),
        LaunchAction.extractHere => await _extract(),
        LaunchAction.openFiles => null,
      };
    } on OperationCancelledException {
      message = null;
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      message = widget.request.action == LaunchAction.compressHere
          ? l10n.compressFailed(describeError(l10n, e))
          : l10n.extractFailed(describeError(l10n, e));
    }
    _revealTimer?.cancel();
    if (!mounted) return;
    if (message == null) {
      widget.exitApp();
      return;
    }
    setState(() {
      _running = false;
      _message = message;
    });
    await _reveal();
  }

  Future<String?> _compress() async {
    final paths = widget.request.paths;
    final format = await (widget.readFormat?.call() ?? Future.value(defaultQuickCompressFormat));
    await widget.createArchive(
      sources: paths.map(Uri.file).toList(),
      destination: quickCompressDestination(paths, format),
      options: CompressionOptions(format: format),
      onProgress: (v) => _progress.value = (done: v.done, total: v.total, currentName: v.currentName),
      cancelToken: _cancelToken,
    );
    return null;
  }

  /// 고른 압축파일을 차례로 "알아서" 푼다 — 압축파일 이름의 새 폴더에. 손상 항목이 있었으면 그 요약.
  Future<String?> _extract() async {
    final l10n = AppLocalizations.of(context);
    final summaries = <String>[];
    String? password;
    for (final path in widget.request.paths) {
      if (FormatRegistry.detectFromFileName(p.basename(path)) == null) continue;
      _cancelToken.throwIfCancelled();
      final handle = await widget.openArchive(Uri.file(path));
      final (result, used) = await _withPassword(password, (pw) => _extractOne(handle, pw));
      password = used; // 같은 비밀번호로 묶은 여러 압축파일을 한 번만 묻는다.
      if (result.failures.isNotEmpty && mounted) {
        final detail = result.failures.map((f) => '- ${describeFailure(l10n, f)}').join('\n');
        summaries.add(
          '${l10n.extractCompletedWithFailures(result.destination.toFilePath(), result.failures.length)}\n$detail',
        );
      }
    }
    return summaries.isEmpty ? null : summaries.join('\n\n');
  }

  Future<ExtractResult> _extractOne(ArchiveHandle handle, String? password) => widget.extractEntries(
        handle: handle,
        mode: ExtractDestinationMode.smart,
        password: password,
        onConflict: (conflict) async {
          await _reveal(prompt: true);
          if (!mounted) throw const OperationCancelledException();
          return showConflictDialog(context, conflict);
        },
        onProgress: (v) => _progress.value = (done: v.done, total: v.total, currentName: v.currentName),
        cancelToken: _cancelToken,
      );

  /// 비밀번호가 필요하면 창을 띄워 묻고 다시 해 본다(틀리면 다시 묻는다).
  Future<(T, String?)> _withPassword<T>(String? password, Future<T> Function(String? password) action) async {
    var wrong = false;
    while (true) {
      try {
        return (await action(password), password);
      } on ArchivePasswordRequiredException {
        await _reveal(prompt: true);
        if (!mounted) throw const OperationCancelledException();
        final entered = await showPasswordPromptDialog(context, wrongPasswordHint: wrong);
        if (entered == null || entered.isEmpty) throw const OperationCancelledException();
        password = entered;
        wrong = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final message = _message;
    final title = widget.request.action == LaunchAction.compressHere ? l10n.compressingTitle : l10n.extractingTitle;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: message != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SingleChildScrollView(child: SelectableText(message))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Clipboard.setData(ClipboardData(text: message)),
                        child: Text(l10n.copyButton),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: widget.exitApp, child: Text(l10n.commonClose)),
                    ],
                  ),
                ],
              )
            : ValueListenableBuilder<_Progress?>(
                valueListenable: _progress,
                builder: (context, value, _) {
                  final done = value?.done ?? 0;
                  final total = value?.total ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: total > 0 ? done / total : null),
                      const SizedBox(height: 12),
                      Text(value?.currentName ?? l10n.preparing, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(l10n.progressCount(done, total), style: theme.textTheme.bodySmall),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _cancelToken.cancel, child: Text(l10n.cancel)),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
