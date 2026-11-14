import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_drag_out/flutter_drag_out.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/launch_request.dart';
import '../../application/quick_compress.dart';
import '../../application/usecases/create_archive.dart';
import '../../application/usecases/open_archive.dart';
import '../../core/cancel_token.dart';
import '../../domain/entities/compress_progress.dart';
import '../../domain/entities/compression_options.dart';
import '../settings/quick_compress_format_provider.dart';
import '../widgets/compress_progress_dialog.dart';
import '../../data/format_registry.dart';
import '../../domain/entities/extract_destination_mode.dart';
import '../../l10n/app_localizations.dart';
import '../archive_browser/archive_browser_screen.dart';
import '../compress/compress_dialog.dart';
import '../../about/dove_zip_about.dart';
import '../../settings/settings_dialog.dart';
import '../widgets/error_snackbar.dart';
import 'recent_archives_provider.dart';
import '../widgets/error_message.dart';
import '../../window/focus_tint.dart';

/// macOS 쪽 두 가지 네이티브 이벤트를 받는 채널(`ServicesBridge.swift`가
/// 이 채널로 전달) — 보내는 쪽은 macOS뿐이다. Windows 탐색기 메뉴는
/// 명령줄 인자로 같은 요청을 넘긴다([LaunchRequest]).
/// - Finder의 "서비스" 메뉴(NSServices, `macos/Runner/Info.plist`)로
///   들어오는 "압축하기"/"알아서 풀기" 요청(PLAN.md 1.4 "OS 컨텍스트
///   메뉴", ARCHITECTURE.md 5장).
/// - 파일 연결(`CFBundleDocumentTypes`)로 등록해 둔 확장자를 더블클릭했을
///   때, 또는 Dock 아이콘에 파일을 드래그했을 때(PLAN.md 1.4 "OS 파일 연결").
const _servicesChannel = MethodChannel('dove_zip/services');

/// 빈 상태(압축파일 없음) 화면 — UI_UX.md 6.1 목업 구현.
///
/// "열기"/드래그로 고른 압축파일은 [OpenArchive]로 열어 곧바로
/// [ArchiveBrowserScreen](UI_UX.md 6.2)으로 넘어간다. "새 압축 만들기"나
/// 압축파일이 아닌 것을 드롭하면 [CompressDialog](UI_UX.md 6.3)로 라우팅한다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.launchPaths = const []});

  /// 명령줄 인자(Windows/Linux의 파일 연결, Windows 탐색기 우클릭 메뉴).
  /// [LaunchRequest.parse]가 읽는다.
  final List<String> launchPaths;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _dragHovering = false;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    // macOS만 이 채널로 보내지만, 다른 플랫폼에 등록해 둬도 해가 없고 테스트가 어디서나 돈다.
    _servicesChannel.setMethodCallHandler(_handleServiceCall);
    if (widget.launchPaths.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLaunchPaths());
    }
  }

  /// Windows 탐색기 우클릭 메뉴(`--compress-here`/`--extract-here`)와 파일
  /// 연결(경로만)은 명령줄로 들어온다 — macOS 서비스 메뉴와 같은 길로 보낸다.
  Future<void> _openLaunchPaths() async {
    final request = LaunchRequest.parse(widget.launchPaths);
    await _handleLaunch(request.action, request.paths);
  }

  @override
  void dispose() {
    _servicesChannel.setMethodCallHandler(null);
    super.dispose();
  }

  /// [ServicesBridge.swift]가 Finder 서비스 메뉴/파일 연결(더블클릭)에서
  /// 넘겨준 파일/폴더 경로를 받아, 앱 내부 버튼을 눌렀을 때와 완전히 같은
  /// 경로로 이어붙인다(PLAN.md 1.4 — 로직 100% 공유가 목표).
  Future<void> _handleServiceCall(MethodCall call) async {
    final action = LaunchAction.fromMethod(call.method);
    if (action == null) return;
    await _handleLaunch(action, (call.arguments as List).cast<String>());
  }

  /// OS 메뉴·파일 연결로 들어온 요청을 앱 안의 단추와 같은 코드로 처리한다.
  Future<void> _handleLaunch(LaunchAction action, List<String> paths) async {
    if (paths.isEmpty || !mounted) return;

    switch (action) {
      case LaunchAction.compressHere || LaunchAction.compressAs: // 이름 묻기는 Windows 빠른 작업 전용
        await _quickCompress(paths);
      case LaunchAction.extractHere || LaunchAction.extractTo:
        for (final path in paths) {
          if (!mounted) return;
          if (FormatRegistry.detectFromFileName(p.basename(path)) == null) {
            continue; // 압축파일이 아닌 항목이 섞여 있으면 조용히 건너뛴다.
          }
          await _openArchiveForAutoExtract(path);
        }
      case LaunchAction.openFiles:
        for (final path in paths) {
          if (!mounted) return;
          if (FormatRegistry.detectFromFileName(p.basename(path)) == null) {
            continue;
          }
          await _openArchivePath(path);
        }
    }
  }

  /// 우클릭 메뉴의 "압축하기" — 압축 창 없이 설정의 형식으로 같은 폴더에 바로
  /// 만든다([quickCompressDestination]). 진행률·취소·완료/실패 알림은 압축
  /// 창과 같은 것을 쓴다.
  Future<void> _quickCompress(List<String> paths) async {
    final format = await QuickCompressFormatController.read();
    if (!mounted) return;
    final destination = quickCompressDestination(paths, format);
    final cancelToken = CancelToken();
    final progress = ValueNotifier<CompressProgress?>(null);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CompressProgressDialog(progress: progress, onCancel: cancelToken.cancel),
      ),
    );
    try {
      await const CreateArchive()(
        sources: paths.map(Uri.file).toList(),
        destination: destination,
        options: CompressionOptions(format: format),
        onProgress: (value) => progress.value = value,
        cancelToken: cancelToken,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // 진행률 다이얼로그
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).compressCompleted(destination.toFilePath()))),
      );
    } on OperationCancelledException {
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final l10n = AppLocalizations.of(context);
      showErrorSnackBar(context, l10n.compressFailed(describeError(l10n, e)));
    }
    // progress는 dispose하지 않는다 — 닫히는 다이얼로그가 애니메이션 동안 아직 듣고 있다.
  }

  /// 평소 "열기"([_openArchivePath])와 달리, 화면이 뜨자마자 곧바로 "알아서"
  /// 해제(압축파일 이름의 새 폴더)까지 자동 실행한다 — Finder 서비스 메뉴 전용.
  Future<void> _openArchiveForAutoExtract(String path) async {
    try {
      final handle = await const OpenArchive()(Uri.file(path));
      unawaited(ref.read(recentArchivesProvider.notifier).addRecent(path));
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ArchiveBrowserScreen(
            handle: handle,
            autoExtractMode: ExtractDestinationMode.smart,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showErrorSnackBar(context, l10n.openArchiveFailed(describeError(l10n, e)));
    }
  }

  Future<void> _pickAndOpenArchive() async {
    final l10n = AppLocalizations.of(context);
    final typeGroup = XTypeGroup(
      label: l10n.archiveFileTypeGroupLabel,
      extensions: const ['zip', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'zst', '7z', 'rar'],
    );
    // 분할 압축 조각(`archive.zip.001` 등)은 숫자로 끝나 위 확장자 목록에
    // 없다 — file_selector는 확장자 없는 XTypeGroup을 "모든 파일"로
    // 취급하므로, 두 번째 그룹으로 추가해 파일 선택 창의 형식 드롭다운에서
    // 전환할 수 있게 한다(PLAN.md 1.3 "분할 압축").
    final anyFileTypeGroup = XTypeGroup(label: l10n.anyFileTypeGroupLabel);
    final file = await openFile(acceptedTypeGroups: [typeGroup, anyFileTypeGroup]);
    if (file != null) {
      await _openArchivePath(file.path);
    }
  }

  Future<void> _onFilesDropped(List<XFile> files) async {
    if (files.isEmpty) return;

    // 압축파일 하나만 드롭했으면 "연다", 그 외(파일 여러 개, 폴더, 압축파일이
    // 아닌 파일 하나)는 전부 "새 압축 만들기"로 라우팅한다 — 폴더는 애초에
    // 확장자가 없어 detectFromFileName이 null을 반환하므로 자연스럽게 이
    // 분기를 탄다.
    if (files.length == 1 &&
        FormatRegistry.detectFromFileName(p.basename(files.single.path)) != null) {
      await _openArchivePath(files.single.path);
      return;
    }

    await _openCompressDialog(files.map((f) => Uri.file(f.path)).toList());
  }

  Future<void> _pickFilesAndCompress() async {
    final files = await openFiles();
    if (files.isEmpty) return;
    await _openCompressDialog(files.map((f) => Uri.file(f.path)).toList());
  }

  /// `file_selector`의 `openFiles()`는 macOS에서 `canChooseDirectories`를
  /// 항상 false로 고정해 둬(플러그인 자체 제약 — 네이티브 NSOpenPanel은
  /// 파일+폴더 동시 선택을 지원하지만 이 패키지가 그 조합을 노출하지
  /// 않는다) 폴더를 통째로 고를 수 없다. 그래서 폴더 선택은 별도
  /// `getDirectoryPaths()`로 분리한다 — 드래그앤드롭은 이미 폴더를
  /// 지원하므로(파일시스템 경로일 뿐이라 구분이 없다), 이건 파일 피커
  /// 쪽에서만 겪는 제약이다.
  Future<void> _pickFolderAndCompress() async {
    final folders = await getDirectoryPaths();
    if (folders.isEmpty) return;
    await _openCompressDialog(
      folders.whereType<String>().map(Uri.directory).toList(),
    );
  }

  Future<void> _openCompressDialog(List<Uri> sources) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CompressDialog(sources: sources),
    );
  }

  Future<void> _openArchivePath(String path) async {
    setState(() => _isOpening = true);
    try {
      final handle = await const OpenArchive()(Uri.file(path));
      unawaited(ref.read(recentArchivesProvider.notifier).addRecent(path));
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ArchiveBrowserScreen(handle: handle)),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showErrorSnackBar(context, l10n.openArchiveFailed(describeError(l10n, e)));
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final recentArchives = ref.watch(recentArchivesProvider);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.appTitle),
        // conventions: 오른쪽 끝 순서는 테마 | 언어 | 정보, 전환은 체크 메뉴.
        actions: [
          IconButton(
            tooltip: l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showSettingsDialog(context),
          ),
          IconButton(
            tooltip: l10n.aboutTooltip,
            onPressed: () => showDoveZipAbout(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragHovering = true),
        onDragExited: (_) => setState(() => _dragHovering = false),
        onDragDone: (details) {
          setState(() => _dragHovering = false);
          // 압축 목록에서 끌어낸 임시 파일이 창으로 되돌아온 것이면 외부
          // 드롭이 아니다(flutter_drag_out README "Ignoring your own files").
          if (FlutterDragOut.inProgress) return;
          unawaited(_onFilesDropped(details.files));
        },
        // 끌어 온 파일이 창 위에 있으면 드롭 영역이 강조된다 (테두리 + 배경색).
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _dragHovering
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              width: 2,
              color: _dragHovering ? theme.colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_zip_outlined,
                      size: 48,
                      color: _dragHovering
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _dragHovering ? l10n.homeDropRelease : l10n.homeDropHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _dragHovering ? theme.colorScheme.primary : null,
                        fontWeight: _dragHovering ? FontWeight.w600 : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isOpening)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickAndOpenArchive,
                            icon: const Icon(Icons.folder_open_outlined, size: 18),
                            label: Text(l10n.openButton),
                          ),
                          MenuAnchor(
                            menuChildren: [
                              MenuItemButton(
                                onPressed: _pickFilesAndCompress,
                                child: Text(l10n.pickFilesMenuItem),
                              ),
                              MenuItemButton(
                                onPressed: _pickFolderAndCompress,
                                child: Text(l10n.pickFolderMenuItem),
                              ),
                            ],
                            builder: (context, controller, child) {
                              return FilledButton.icon(
                                onPressed: () => controller.isOpen
                                    ? controller.close()
                                    : controller.open(),
                                icon: const Icon(Icons.add_box_outlined, size: 18),
                                label: Text(l10n.createArchiveButton),
                              );
                            },
                          ),
                        ],
                      ),
                    if (recentArchives.isNotEmpty && !_isOpening) ...[
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(l10n.recentArchivesTitle, style: theme.textTheme.labelLarge),
                      ),
                      const SizedBox(height: 4),
                      for (final path in recentArchives)
                        _RecentArchiveTile(
                          path: path,
                          onTap: () => _openArchivePath(path),
                          onRemove: () =>
                              ref.read(recentArchivesProvider.notifier).remove(path),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentArchiveTile extends StatelessWidget {
  const _RecentArchiveTile({required this.path, required this.onTap, required this.onRemove});

  final String path;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // 색 구성(주색)을 따라 바뀐다.
            Icon(Icons.folder_zip_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // 분할 압축의 특정 조각(.001 등)을 열었어도 목록엔 논리
                // 압축파일 이름만 보여준다 — PLAN.md 1.3 "분할 압축".
                FormatRegistry.stripSplitVolumeSuffix(p.basename(path)),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: AppLocalizations.of(context).removeFromRecentTooltip,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
