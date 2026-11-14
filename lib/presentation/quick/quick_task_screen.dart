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
import '../widgets/name_prompt_dialog.dart';
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
    this.pathExists = quickPathTaken,
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

  /// "이름을 정해 압축하기"가 이미 있는 이름을 막는 데 쓴다. 테스트가 바꾼다.
  final bool Function(String path) pathExists;

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
        LaunchAction.compressAs => await _compress(askName: true),
        LaunchAction.extractHere => await _extract(),
        LaunchAction.extractTo => await _extract(askName: true),
        LaunchAction.openFiles => null,
      };
    } on OperationCancelledException {
      message = null;
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      message = _isCompress
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

  bool get _isCompress =>
      widget.request.action == LaunchAction.compressHere || widget.request.action == LaunchAction.compressAs;

  /// 이름을 묻는 창을 띄워 받는다. 취소하면 작업 전체를 취소한다.
  Future<String> _askName({
    required String title,
    required String initialName,
    String? suffix,
    String? Function(String name)? validateMore,
  }) async {
    await _reveal(prompt: true);
    if (!mounted) throw const OperationCancelledException();
    final l10n = AppLocalizations.of(context);
    final name = await showNamePromptDialog(
      context,
      title: title,
      label: title,
      initialName: initialName,
      suffix: suffix,
      validate: (name) {
        final problem = switch (quickNameProblem(name)) {
          QuickNameProblem.empty => l10n.nameProblemEmpty,
          QuickNameProblem.invalidCharacters => l10n.nameProblemInvalidCharacters,
          QuickNameProblem.reserved => l10n.nameProblemReserved,
          null => null,
        };
        return problem ?? validateMore?.call(name);
      },
    );
    if (name == null) throw const OperationCancelledException();
    return name;
  }

  /// [askName]이면 압축파일 이름을 물어(처음 값: [quickCompressBaseName]) 그 이름으로 만든다.
  Future<String?> _compress({bool askName = false}) async {
    final paths = widget.request.paths;
    final format = await (widget.readFormat?.call() ?? Future.value(defaultQuickCompressFormat));
    final Uri destination;
    if (askName) {
      if (!mounted) throw const OperationCancelledException();
      final l10n = AppLocalizations.of(context);
      final name = await _askName(
        title: l10n.promptCompressTitle,
        initialName: quickCompressBaseName(paths),
        suffix: '.${FormatRegistry.of(format).extensions.first}',
        validateMore: (name) => widget.pathExists(quickCompressDestinationNamed(paths, name, format).toFilePath())
            ? l10n.nameProblemExists
            : null,
      );
      destination = quickCompressDestinationNamed(paths, name, format);
    } else {
      destination = quickCompressDestination(paths, format);
    }
    await widget.createArchive(
      sources: paths.map(Uri.file).toList(),
      destination: destination,
      options: CompressionOptions(format: format),
      onProgress: (v) => _progress.value = (done: v.done, total: v.total, currentName: v.currentName),
      cancelToken: _cancelToken,
    );
    return null;
  }

  /// 고른 압축파일을 차례로 푼다. 손상 항목이 있었으면 그 요약.
  ///
  /// 기본은 "알아서" — 압축파일 이름의 새 폴더에. [askName]이면 폴더 이름을
  /// 물어, 압축파일이 하나면 그 폴더에 바로, 여럿이면 그 아래 압축파일 이름의
  /// 하위 폴더로 나눠 푼다.
  Future<String?> _extract({bool askName = false}) async {
    final l10n = AppLocalizations.of(context);
    final archives = [
      for (final path in widget.request.paths)
        if (FormatRegistry.detectFromFileName(p.basename(path)) != null) path,
    ];
    if (archives.isEmpty) return null;
    final targets = askName
        ? quickExtractTargets(
            archives,
            await _askName(title: l10n.promptExtractTitle, initialName: quickExtractFolderName(archives)),
          )
        : null;
    final summaries = <String>[];
    String? password;
    for (var i = 0; i < archives.length; i++) {
      _cancelToken.throwIfCancelled();
      final handle = await widget.openArchive(Uri.file(archives[i]));
      final folder = targets?[i].destination;
      final (result, used) = await _withPassword(password, (pw) => _extractOne(handle, pw, folder));
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

  /// [folder]가 null이면 "알아서"(압축파일 이름의 새 폴더), 아니면 그 폴더에 푼다.
  Future<ExtractResult> _extractOne(ArchiveHandle handle, String? password, Uri? folder) => widget.extractEntries(
        handle: handle,
        mode: folder == null ? ExtractDestinationMode.smart : ExtractDestinationMode.chooseFolder,
        userChosenFolder: folder,
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
    final title = _isCompress ? l10n.compressingTitle : l10n.extractingTitle;
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
