import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../../application/archive_browser_entries.dart';
import '../../application/usecases/extract_entries.dart';
import '../../application/usecases/open_archive.dart';
import '../../application/usecases/preview_archive_entry.dart';
import '../../core/bytes_format.dart';
import '../../core/cancel_token.dart';
import '../../core/date_format.dart';
import '../../data/format_registry.dart';
import '../../domain/entities/archive_handle.dart';
import '../../domain/entities/extract_destination_mode.dart';
import '../../domain/entities/extract_progress.dart';
import '../../domain/repositories/archive_reader.dart'
    show ArchivePasswordRequiredException;
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/file_type_style.dart';
import '../viewer/entry_viewer_screen.dart';
import '../widgets/conflict_dialog.dart';
import '../widgets/error_snackbar.dart';
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
    this.openArchive = const OpenArchive(),
  });

  final ArchiveHandle handle;

  /// 테스트에서 실제 디스크 I/O 없이 가짜 리더를 주입할 수 있도록 기본값과
  /// 함께 노출한다 — 실제 앱 실행에서는 항상 기본값(`DartArchiveReader`)을
  /// 그대로 쓴다.
  final ExtractEntries extractEntries;
  final PreviewArchiveEntry previewArchiveEntry;

  /// 중첩 압축 드릴다운(PLAN.md 1.1)에 쓴다 — 압축파일 안의 항목이 그
  /// 자체로 또 압축파일이면, 임시 폴더로 꺼낸 뒤 이 유스케이스로 열어
  /// [ArchiveBrowserScreen] 하나를 그 위에 더 쌓는다(재귀적으로 몇 단계든
  /// 들어갈 수 있음).
  final OpenArchive openArchive;

  @override
  ConsumerState<ArchiveBrowserScreen> createState() =>
      _ArchiveBrowserScreenState();
}

class _ArchiveBrowserScreenState extends ConsumerState<ArchiveBrowserScreen> {
  String _currentPath = '';
  bool _isExtracting = false;

  /// 미리보기를 위해 지금 임시 폴더로 꺼내는 중인 항목의 `pathInArchive`.
  /// 그 행에 스피너를 보여주고, 겹쳐 누르는 것도 막는다.
  String? _previewingPath;

  /// 선택된 항목들의 전체 가상 경로(PLAN.md 1.2 "선택 항목만 해제") —
  /// 실제 압축파일 경로 형식(`docs/sub/file.txt`)과 동일하게 저장한다.
  /// 폴더 이동과 무관하게 유지된다 — 다른 폴더의 항목까지 함께 골라서 한
  /// 번에 해제할 수 있어야 하므로 폴더를 나갈 때 지우지 않는다.
  final _selectedPaths = <String>{};

  /// Shift+클릭 범위 선택의 기준점 — 현재 폴더의 [_visibleEntries] 안
  /// 인덱스다(다른 폴더로 이동하면 의미가 없어지므로 폴더 전환 시 지운다).
  int? _lastInteractedIndex;

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
  Future<T> _withPasswordRetry<T>(
    Future<T> Function(String? password) action,
  ) async {
    var password = _sessionPassword;
    var showWrongHint = false;
    while (true) {
      try {
        final result = await action(password);
        if (password != null) _sessionPassword = password;
        return result;
      } on ArchivePasswordRequiredException {
        if (!mounted) throw const OperationCancelledException();
        final entered = await showPasswordPromptDialog(
          context,
          wrongPasswordHint: showWrongHint,
        );
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
      _lastInteractedIndex = null;
    });
  }

  void _goUp() {
    if (_currentPath.isEmpty) return;
    final slashIndex = _currentPath.lastIndexOf('/');
    setState(() {
      _currentPath = slashIndex == -1
          ? ''
          : _currentPath.substring(0, slashIndex);
      _lastInteractedIndex = null;
    });
  }

  /// [entry]의 전체 가상 경로(현재 폴더 기준) — `_selectedPaths`에 저장하는
  /// 형식과 동일하다.
  String _fullPathOf(ArchiveBrowserEntry entry) =>
      _currentPath.isEmpty ? entry.name : '$_currentPath/${entry.name}';

  /// 항목 하나의 선택 여부를 뒤집는다(Ctrl/Cmd+클릭 — PLAN.md 1.2 "선택
  /// 항목만 해제"). 폴더든 파일이든 동일하게 동작하고, 실제 해제 시
  /// 폴더는 [expandSelectionToEntryPaths]가 하위 전부로 펼친다.
  void _toggleSelectionAt(int index, List<ArchiveBrowserEntry> visible) {
    final path = _fullPathOf(visible[index]);
    setState(() {
      if (!_selectedPaths.remove(path)) _selectedPaths.add(path);
      _lastInteractedIndex = index;
    });
  }

  /// [_lastInteractedIndex]부터 [index]까지(둘 다 포함) 전부 선택에
  /// 더한다(Shift+클릭 범위 선택). 기준점이 아직 없으면 이 항목 하나만
  /// 선택한 것과 같다.
  void _selectRangeTo(int index, List<ArchiveBrowserEntry> visible) {
    final anchor = _lastInteractedIndex ?? index;
    final start = anchor < index ? anchor : index;
    final end = anchor < index ? index : anchor;
    setState(() {
      for (var i = start; i <= end; i++) {
        _selectedPaths.add(_fullPathOf(visible[i]));
      }
      _lastInteractedIndex = index;
    });
  }

  void _clearSelection() {
    if (_selectedPaths.isEmpty) return;
    setState(_selectedPaths.clear);
  }

  void _selectAllVisible(List<ArchiveBrowserEntry> visible) {
    setState(() {
      for (final entry in visible) {
        _selectedPaths.add(_fullPathOf(entry));
      }
    });
  }

  Future<void> _openFile(ArchiveBrowserEntry entry) async {
    final entryPath = entry.sourceEntry!.pathInArchive;
    setState(() => _previewingPath = entryPath);
    try {
      final tempUri = await _withPasswordRetry(
        (password) => widget.previewArchiveEntry(
          widget.handle,
          entryPath,
          password: password,
        ),
      );
      if (!mounted) return;

      // 중첩 압축 드릴다운(PLAN.md 1.1) — 이름으로 압축 형식이 인식되면
      // 미리보기 대신 곧장 그 안으로 들어간다. 지금 리더가 실제로 못
      // 읽는 형식(예: iso9660처럼 FormatRegistry엔 있지만 아직 구현이
      // 없는 것)이면 UnsupportedArchiveFormatException을 잡아 평소
      // 미리보기 경로로 계속 진행한다 — 이미 꺼낸 [tempUri]를 그대로
      // 재사용하니 다시 압축을 풀지 않는다.
      //
      // 알려진 한계: `archive` 패키지의 Zip/TarDecoder는 매직 바이트가
      // 전혀 없는 데이터도 에러 없이 "항목 0개"로 관대하게 디코딩한다 —
      // 그래서 이름만 `.zip`/`.tar`인 진짜 깨진 파일은 에러 대신 빈
      // 압축파일로 열린다. 최상위 "열기"를 포함해 이 앱 전체가 이미
      // 겪는 특성이라 드릴다운만의 문제는 아니다.
      if (FormatRegistry.detectFromFileName(entry.name) != null) {
        try {
          final nestedHandle = await _withPasswordRetry(
            (password) => widget.openArchive(tempUri, password: password),
          );
          if (!mounted) return;
          setState(() => _previewingPath = null);
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ArchiveBrowserScreen(handle: nestedHandle),
            ),
          );
          return;
        } on UnsupportedArchiveFormatException {
          // 이 형식은 아직 못 읽는다 — 아래 평소 미리보기로 계속 진행.
          if (!mounted) return;
        }
      }

      // 로딩 스피너는 임시 파일을 꺼내는 동안만 보여준다 — 뷰어 화면을
      // 닫을 때까지 기다리면(push의 Future는 pop돼야 완료됨) 이 화면이
      // 뒤에서 계속 스피너 애니메이션을 돌리게 된다.
      if (!mounted) return;
      setState(() => _previewingPath = null);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => EntryViewerScreen(
            tempFilePath: tempUri.toFilePath(),
            name: entry.name,
          ),
        ),
      );
    } on OperationCancelledException {
      if (!mounted) return;
      setState(() => _previewingPath = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingPath = null);
      showErrorSnackBar(
        context,
        AppLocalizations.of(context).previewFailed('$e'),
      );
    }
  }

  /// `ExtractModeBar`(UI_UX.md 7장)의 세 버튼이 공통으로 타는 경로.
  /// 목적지 계산(`resolveExtractDestination`)과 실제 디스크 쓰기는
  /// `ExtractEntries` 유스케이스에 전부 위임하고, 이 메서드는 UI(폴더
  /// 선택 다이얼로그·진행률 다이얼로그·충돌 다이얼로그·결과 스낵바)만
  /// 책임진다. 선택된 항목이 있으면(PLAN.md 1.2 "선택 항목만 해제")
  /// [expandSelectionToEntryPaths]로 펼친 목록만, 없으면 전체(`null`)를
  /// 해제 대상으로 넘긴다.
  Future<void> _runExtraction(ExtractDestinationMode mode) async {
    Uri? userChosenFolder;
    if (mode == ExtractDestinationMode.chooseFolder) {
      final picked = await getDirectoryPath();
      if (picked == null) return; // 사용자가 폴더 선택을 취소함
      userChosenFolder = Uri.directory(picked);
    }

    unawaited(ref.read(lastExtractModeProvider.notifier).remember(mode));

    final entryPaths = _selectedPaths.isEmpty
        ? null
        : expandSelectionToEntryPaths(
            widget.handle.entries,
            _selectedPaths,
          ).toList();

    final cancelToken = CancelToken();
    final progress = ValueNotifier<ExtractProgress?>(null);
    setState(() => _isExtracting = true);

    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ExtractProgressDialog(
          progress: progress,
          onCancel: cancelToken.cancel,
        ),
      ),
    );

    try {
      final destination = await _withPasswordRetry(
        (password) => widget.extractEntries(
          handle: widget.handle,
          mode: mode,
          entryPaths: entryPaths,
          userChosenFolder: userChosenFolder,
          password: password,
          onConflict: (conflict) => showConflictDialog(context, conflict),
          onProgress: (p) => progress.value = p,
          cancelToken: cancelToken,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // 진행률 다이얼로그 닫기
      _clearSelection(); // 해제가 끝났으니 선택 상태를 정리한다(성공 시에만)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .extractCompleted(destination.toFilePath()),
          ),
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
      showErrorSnackBar(
        context,
        AppLocalizations.of(context).extractFailed('$e'),
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
    final fileName = FormatRegistry.stripSplitVolumeSuffix(
      p.basename(widget.handle.location.toFilePath()),
    );
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
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(fileName, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  _FormatBadge(canWrite: capability.canWrite),
                ],
              ),
        actions: [
          if (_selectedPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: l10n.clearSelectionTooltip,
              onPressed: _clearSelection,
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching
                ? l10n.closeSearchTooltip
                : l10n.searchTooltip,
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
      body: Focus(
        autofocus: true,
        // Ctrl/Cmd+A만 여기서 직접 처리한다(UI_UX.md 8장) — Escape 등
        // 나머지 단축키는 아직 앱 전체에 키보드 단축키 인프라 자체가 없어
        // 이 기능만 앞서가지 않도록 범위를 좁혔다. 선택 해제는 앱바의
        // 아이콘 버튼으로 충분히 가능하다.
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final isCtrlOrCmd =
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;
          if (isCtrlOrCmd && event.logicalKey == LogicalKeyboardKey.keyA) {
            _selectAllVisible(entries);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            if (_currentPath.isNotEmpty) _BreadcrumbBar(path: _currentPath),
            const _ColumnHeader(),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.emptyFolder,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isLoading =
                            _previewingPath != null &&
                            entry.sourceEntry?.pathInArchive == _previewingPath;
                        return _EntryRow(
                          entry: entry,
                          isLoading: isLoading,
                          isSelected: _selectedPaths.contains(
                            _fullPathOf(entry),
                          ),
                          onTap: _previewingPath != null
                              ? null
                              : () => _onRowTap(index, entry, entries),
                        );
                      },
                    ),
            ),
            ExtractModeBar(
              onSelectMode: _runExtraction,
              enabled: !_isExtracting,
              highlightedMode: ref.watch(lastExtractModeProvider),
              hasSelection: _selectedPaths.isNotEmpty,
            ),
            const Divider(height: 1),
            _StatusBar(
              entryCount: entries.length,
              selectedCount: _selectedPaths.length,
              selectedSizeBytes: _selectedSizeBytes(entries),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태바에 보여줄 선택된 항목들의 원본 크기 합 — 폴더가 선택돼 있으면
  /// [expandSelectionToEntryPaths]로 펼친 실제 파일들의 크기를 더한다.
  int _selectedSizeBytes(List<ArchiveBrowserEntry> visible) {
    if (_selectedPaths.isEmpty) return 0;
    final expanded = expandSelectionToEntryPaths(
      widget.handle.entries,
      _selectedPaths,
    );
    var total = 0;
    for (final entry in widget.handle.entries) {
      if (expanded.contains(entry.pathInArchive)) {
        total += entry.uncompressedSize ?? 0;
      }
    }
    return total;
  }

  /// 목록 한 행을 눌렀을 때: Ctrl/Cmd는 하나씩, Shift는 범위로 선택하고
  /// (PLAN.md 1.2 "선택 항목만 해제"), 그 외(일반 클릭)는 기존과 동일하게
  /// 폴더 진입/파일 미리보기로 이어간다 — UI_UX.md 8장 "마우스 클릭과
  /// 다중선택 모델 분리" 원칙대로, 일반 클릭은 선택 상태를 건드리지 않는다.
  void _onRowTap(
    int index,
    ArchiveBrowserEntry entry,
    List<ArchiveBrowserEntry> visible,
  ) {
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      _toggleSelectionAt(index, visible);
      return;
    }
    if (keyboard.isShiftPressed) {
      _selectRangeTo(index, visible);
      return;
    }
    if (entry.isDirectory) {
      _enterFolder(entry.name);
    } else {
      _openFile(entry);
    }
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
          SizedBox(
            width: 72,
            child: Text(l10n.columnCompressedSize, style: style),
          ),
          SizedBox(width: 96, child: Text(l10n.columnModified, style: style)),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.onTap,
    this.isLoading = false,
    this.isSelected = false,
  });

  final ArchiveBrowserEntry entry;
  final VoidCallback? onTap;
  final bool isLoading;

  /// Ctrl/Cmd+클릭이나 Shift+클릭으로 선택된 상태(PLAN.md 1.2 "선택 항목만
  /// 해제") — daylight-commander-flutter의 선택 행 강조와 동일하게 Primary
  /// 색을 낮은 알파로 배경에 깐다.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = entry.sourceEntry;
    return ColoredBox(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
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
                  entry.isDirectory
                      ? ''
                      : formatBytes(source?.uncompressedSize),
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
      return SvgPicture.asset(
        FileTypeStyle.genericFolderAsset,
        width: size,
        height: size,
      );
    }

    final extension = p.extension(entry.name).replaceFirst('.', '');
    final asset =
        FileTypeStyle.assetForExtension(extension) ??
        FileTypeStyle.unknownAsset;
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
      message: canWrite
          ? l10n.formatWritableTooltip
          : l10n.formatReadOnlyTooltip,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.entryCount,
    this.selectedCount = 0,
    this.selectedSizeBytes = 0,
  });

  final int entryCount;

  /// 0이면 평소처럼 전체 항목 수를 보여주고, 1개 이상이면 선택 개수+크기로
  /// 바꿔 보여준다(PLAN.md 1.2 "선택 항목만 해제").
  final int selectedCount;
  final int selectedSizeBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = selectedCount > 0
        ? l10n.statusBarSelectedCount(
            selectedCount,
            formatBytes(selectedSizeBytes),
          )
        : l10n.statusBarItemCount(entryCount);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
