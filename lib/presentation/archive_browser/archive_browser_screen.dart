import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../../application/archive_browser_entries.dart';
import '../../application/usecases/extract_entries.dart';
import '../../application/usecases/preview_archive_entry.dart';
import '../../core/bytes_format.dart';
import '../../core/cancel_token.dart';
import '../../core/date_format.dart';
import '../../data/format_registry.dart';
import '../../domain/entities/archive_handle.dart';
import '../../domain/entities/extract_destination_mode.dart';
import '../../domain/entities/extract_progress.dart';
import '../../domain/repositories/archive_reader.dart' show ArchivePasswordRequiredException;
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/file_type_style.dart';
import '../viewer/entry_viewer_screen.dart';
import '../widgets/conflict_dialog.dart';
import '../widgets/extract_progress_dialog.dart';
import '../widgets/password_prompt_dialog.dart';
import 'extract_mode_bar.dart';
import 'last_extract_mode_provider.dart';

/// 압축파일 탐색 화면 (UI_UX.md 6.2).
///
/// [handle]은 [OpenArchive]가 이미 한 번에 다 읽어 온 엔트리 전체를 담고
/// 있다 — 폴더를 드나들 때마다 다시 읽지 않고 [childrenOf]로 그때그때
/// 인메모리 필터링만 한다(ARCHITECTURE.md 8장).
class ArchiveBrowserScreen extends ConsumerStatefulWidget {
  const ArchiveBrowserScreen({
    super.key,
    required this.handle,
    this.extractEntries = const ExtractEntries(),
    this.previewArchiveEntry = const PreviewArchiveEntry(),
  });

  final ArchiveHandle handle;

  /// 테스트에서 실제 디스크 I/O 없이 가짜 리더를 주입할 수 있도록 기본값과
  /// 함께 노출한다 — 실제 앱 실행에서는 항상 기본값(`DartArchiveReader`)을
  /// 그대로 쓴다.
  final ExtractEntries extractEntries;
  final PreviewArchiveEntry previewArchiveEntry;

  @override
  ConsumerState<ArchiveBrowserScreen> createState() => _ArchiveBrowserScreenState();
}

class _ArchiveBrowserScreenState extends ConsumerState<ArchiveBrowserScreen> {
  String _currentPath = '';
  bool _isExtracting = false;

  /// 미리보기를 위해 지금 임시 폴더로 꺼내는 중인 항목의 `pathInArchive`.
  /// 그 행에 스피너를 보여주고, 겹쳐 누르는 것도 막는다.
  String? _previewingPath;

  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  /// 한 번 입력하면 이 화면(같은 압축파일)이 열려 있는 동안은 기억한다
  /// (UI_UX.md 7장 `PasswordPromptDialog` — "이번 세션 동안 기억").
  String? _sessionPassword;

  /// [action]을 비밀번호 없이 먼저 시도하고, [ArchivePasswordRequiredException]이
  /// 나면 다이얼로그로 물어본 뒤 그 비밀번호로 다시 시도한다. 사용자가
  /// 다이얼로그를 취소하면 [OperationCancelledException]을 던져 호출부의
  /// 취소 처리 분기를 그대로 재사용한다.
  Future<T> _withPasswordRetry<T>(Future<T> Function(String? password) action) async {
    var password = _sessionPassword;
    var showWrongHint = false;
    while (true) {
      try {
        final result = await action(password);
        if (password != null) _sessionPassword = password;
        return result;
      } on ArchivePasswordRequiredException {
        if (!mounted) throw const OperationCancelledException();
        final entered =
            await showPasswordPromptDialog(context, wrongPasswordHint: showWrongHint);
        if (entered == null || entered.isEmpty) {
          throw const OperationCancelledException();
        }
        password = entered;
        showWrongHint = true;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 현재 폴더 안에서만 필터링한다(daylight의 퀵서치와 동일 범위 — 하위
  /// 폴더까지 재귀 검색하지는 않는다, PLAN.md 1.1).
  List<ArchiveBrowserEntry> get _visibleEntries {
    final children = childrenOf(widget.handle.entries, _currentPath);
    if (_searchQuery.isEmpty) return children;
    final query = _searchQuery.toLowerCase();
    return children.where((e) => e.name.toLowerCase().contains(query)).toList();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _enterFolder(String name) {
    setState(() {
      _currentPath = _currentPath.isEmpty ? name : '$_currentPath/$name';
    });
  }

  void _goUp() {
    if (_currentPath.isEmpty) return;
    final slashIndex = _currentPath.lastIndexOf('/');
    setState(() {
      _currentPath = slashIndex == -1 ? '' : _currentPath.substring(0, slashIndex);
    });
  }

  Future<void> _openFile(ArchiveBrowserEntry entry) async {
    final entryPath = entry.sourceEntry!.pathInArchive;
    setState(() => _previewingPath = entryPath);
    try {
      final tempUri = await _withPasswordRetry(
        (password) =>
            widget.previewArchiveEntry(widget.handle, entryPath, password: password),
      );
      if (!mounted) return;
      // 로딩 스피너는 임시 파일을 꺼내는 동안만 보여준다 — 뷰어 화면을
      // 닫을 때까지 기다리면(push의 Future는 pop돼야 완료됨) 이 화면이
      // 뒤에서 계속 스피너 애니메이션을 돌리게 된다.
      setState(() => _previewingPath = null);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              EntryViewerScreen(tempFilePath: tempUri.toFilePath(), name: entry.name),
        ),
      );
    } on OperationCancelledException {
      if (!mounted) return;
      setState(() => _previewingPath = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).previewFailed('$e'))),
      );
    }
  }

  /// `ExtractModeBar`(UI_UX.md 7장)의 세 버튼이 공통으로 타는 경로.
  /// 목적지 계산(`resolveExtractDestination`)과 실제 디스크 쓰기는
  /// `ExtractEntries` 유스케이스에 전부 위임하고, 이 메서드는 UI(폴더
  /// 선택 다이얼로그·진행률 다이얼로그·충돌 다이얼로그·결과 스낵바)만
  /// 책임진다 — 지금은 선택 UI가 없어 항상 전체 해제(`entryPaths: null`).
  Future<void> _runExtraction(ExtractDestinationMode mode) async {
    Uri? userChosenFolder;
    if (mode == ExtractDestinationMode.chooseFolder) {
      final picked = await getDirectoryPath();
      if (picked == null) return; // 사용자가 폴더 선택을 취소함
      userChosenFolder = Uri.directory(picked);
    }

    unawaited(ref.read(lastExtractModeProvider.notifier).remember(mode));

    final cancelToken = CancelToken();
    final progress = ValueNotifier<ExtractProgress?>(null);
    setState(() => _isExtracting = true);

    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          ExtractProgressDialog(progress: progress, onCancel: cancelToken.cancel),
    ));

    try {
      final destination = await _withPasswordRetry(
        (password) => widget.extractEntries(
          handle: widget.handle,
          mode: mode,
          userChosenFolder: userChosenFolder,
          password: password,
          onConflict: (conflict) => showConflictDialog(context, conflict),
          onProgress: (p) => progress.value = p,
          cancelToken: cancelToken,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // 진행률 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).extractCompleted(destination.toFilePath())),
        ),
      );
    } on OperationCancelledException {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).extractCancelled)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).extractFailed('$e'))),
      );
    } finally {
      progress.dispose();
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // 분할 압축의 특정 조각(.001 등)을 열었어도 제목엔 논리 압축파일
    // 이름만 보여준다 — PLAN.md 1.3 "분할 압축".
    final fileName =
        FormatRegistry.stripSplitVolumeSuffix(p.basename(widget.handle.location.toFilePath()));
    final capability = FormatRegistry.of(widget.handle.format);
    final entries = _visibleEntries;

    return Scaffold(
      appBar: AppBar(
        leading: _currentPath.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.parentFolderTooltip,
                onPressed: _goUp,
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.searchHint, border: InputBorder.none),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  _FormatBadge(canWrite: capability.canWrite),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? l10n.closeSearchTooltip : l10n.searchTooltip,
            onPressed: _toggleSearch,
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.closeTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_currentPath.isNotEmpty) _BreadcrumbBar(path: _currentPath),
          const _ColumnHeader(),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(l10n.emptyFolder, style: theme.textTheme.bodyMedium),
                  )
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isLoading = _previewingPath != null &&
                          entry.sourceEntry?.pathInArchive == _previewingPath;
                      return _EntryRow(
                        entry: entry,
                        isLoading: isLoading,
                        onTap: _previewingPath != null
                            ? null
                            : entry.isDirectory
                                ? () => _enterFolder(entry.name)
                                : () => _openFile(entry),
                      );
                    },
                  ),
          ),
          ExtractModeBar(
            onSelectMode: _runExtraction,
            enabled: !_isExtracting,
            highlightedMode: ref.watch(lastExtractModeProvider),
          ),
          const Divider(height: 1),
          _StatusBar(entryCount: entries.length),
        ],
      ),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        '/$path',
        style: theme.textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(l10n.columnName, style: style)),
          SizedBox(width: 72, child: Text(l10n.columnSize, style: style)),
          SizedBox(width: 72, child: Text(l10n.columnCompressedSize, style: style)),
          SizedBox(width: 96, child: Text(l10n.columnModified, style: style)),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap, this.isLoading = false});

  final ArchiveBrowserEntry entry;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = entry.sourceEntry;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _EntryIcon(entry: entry),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                entry.isDirectory ? '' : formatBytes(source?.uncompressedSize),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                entry.isDirectory ? '' : formatBytes(source?.compressedSize),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                formatModified(source?.modifiedAt),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({required this.entry});

  final ArchiveBrowserEntry entry;

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    if (entry.isDirectory) {
      return SvgPicture.asset(FileTypeStyle.genericFolderAsset, width: size, height: size);
    }

    final extension = p.extension(entry.name).replaceFirst('.', '');
    final asset = FileTypeStyle.assetForExtension(extension) ?? FileTypeStyle.unknownAsset;
    return SvgPicture.asset(asset, width: size, height: size);
  }
}

/// 압축 생성 가능(Success)/해제 전용(Warning) 배지 — UI_UX.md 3장.
class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.canWrite});

  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final color = canWrite ? AppColors.success : AppColors.warning;
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: canWrite ? l10n.formatWritableTooltip : l10n.formatReadOnlyTooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        AppLocalizations.of(context).statusBarItemCount(entryCount),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
