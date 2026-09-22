import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../application/usecases/create_archive.dart';
import '../../core/bytes_format.dart';
import '../../core/cancel_token.dart';
import '../../data/format_registry.dart';
import '../../data/split_volume_locator.dart';
import '../../domain/entities/archive_entry.dart';
import '../../domain/entities/compress_progress.dart';
import '../../domain/entities/compression_options.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/compress_progress_dialog.dart';
import '../widgets/error_snackbar.dart';

/// 새 압축 만들기 다이얼로그 (UI_UX.md 6.3).
///
/// 비밀번호 보호(PLAN.md 1.3 P1)는 zip만 지원한다 — `DartArchiveWriter`가
/// 아직 zip만 만들 수 있어서다. 분할 압축(볼륨 크기 지정)은 포맷과 무관하게
/// 지원한다 — 완성된 압축파일을 고정 크기로 잘라 붙이는 후처리라서다
/// (`FormatRegistry.isSplitVolumePart` 문서 참고, DoveZip 자신만 다시
/// 이어붙일 수 있는 실용적 절충).
class CompressDialog extends StatefulWidget {
  const CompressDialog({
    super.key,
    required this.sources,
    this.createArchive = const CreateArchive(),
  });

  final List<Uri> sources;

  /// 테스트에서 실제 디스크 I/O 없이 가짜 라이터를 주입할 수 있도록
  /// 기본값과 함께 노출한다.
  final CreateArchive createArchive;

  @override
  State<CompressDialog> createState() => _CompressDialogState();
}

class _CompressDialogState extends State<CompressDialog> {
  late ArchiveFormat _format;
  CompressionLevel _level = CompressionLevel.normal;
  late Uri _destination;
  bool _isCompressing = false;

  bool _passwordProtected = false;
  final _passwordController = TextEditingController();

  bool _splitEnabled = false;
  final _splitVolumeSizeController = TextEditingController();

  /// 압축 시작 전 미리 계산해 두는 원본(압축 전) 총 크기 — 폴더는 재귀
  /// 합산한다(PLAN.md 1.3 P1 "압축 전 예상 크기"). 계산이 끝나기 전엔
  /// null이라 [formatBytes]가 알아서 "--"로 보여준다.
  int? _originalSizeBytes;

  @override
  void initState() {
    super.initState();
    _format = ArchiveFormat.zip;
    _destination = _suggestDestination();
    unawaited(_computeOriginalSize());
  }

  Future<void> _computeOriginalSize() async {
    var total = 0;
    for (final source in widget.sources) {
      final path = source.toFilePath();
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.file) {
        total += await File(path).length();
      } else if (type == FileSystemEntityType.directory) {
        await for (final entity in Directory(
          path,
        ).list(recursive: true, followLinks: false)) {
          if (entity is File) total += await entity.length();
        }
      }
    }
    if (mounted) setState(() => _originalSizeBytes = total);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _splitVolumeSizeController.dispose();
    super.dispose();
  }

  Uri _suggestDestination() {
    final firstPath = widget.sources.first.toFilePath();
    final trimmed =
        firstPath.length > 1 && firstPath.endsWith(Platform.pathSeparator)
        ? firstPath.substring(0, firstPath.length - 1)
        : firstPath;
    final dir = p.dirname(trimmed);
    final base = p.basenameWithoutExtension(trimmed);
    final ext = FormatRegistry.of(_format).extensions.first;
    return Uri.file(p.join(dir, '$base.$ext'));
  }

  String _sourcesSummary(AppLocalizations l10n) {
    final names = widget.sources
        .map((u) => p.basename(u.toFilePath()))
        .toList();
    final preview = names.take(3).join(', ');
    final rest = names.length > 3
        ? l10n.sourcesSummaryMore(names.length - 3)
        : '';
    return '$preview$rest ${l10n.sourcesSummaryTotal(names.length)}';
  }

  /// 비밀번호 보호(AES-256)는 zip/7z만 지원한다 — koni_sevenz 도입 전에는
  /// zip뿐이었다.
  static bool _supportsPassword(ArchiveFormat format) =>
      format == ArchiveFormat.zip || format == ArchiveFormat.sevenZip;

  void _onFormatChanged(ArchiveFormat? format) {
    if (format == null) return;
    setState(() {
      _format = format;
      _destination = _suggestDestination();
      // 다른 포맷으로 바꾸면 체크된 채 비활성화된 UI가 남지 않도록 끈다.
      if (!_supportsPassword(_format)) _passwordProtected = false;
    });
  }

  Future<void> _changeDestination() async {
    final currentPath = _destination.toFilePath();
    final location = await getSaveLocation(
      suggestedName: p.basename(currentPath),
    );
    if (location == null) return;
    setState(() => _destination = Uri.file(location.path));
  }

  Future<void> _startCompress() async {
    int? splitVolumeBytes;
    if (_splitEnabled) {
      final mb = int.tryParse(_splitVolumeSizeController.text.trim());
      if (mb == null || mb <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).splitVolumeSizeInvalid),
          ),
        );
        return;
      }
      splitVolumeBytes = mb * 1024 * 1024;
    }

    setState(() => _isCompressing = true);

    final cancelToken = CancelToken();
    final progress = ValueNotifier<CompressProgress?>(null);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CompressProgressDialog(
          progress: progress,
          onCancel: cancelToken.cancel,
        ),
      ),
    );

    final password = _passwordProtected && _passwordController.text.isNotEmpty
        ? _passwordController.text
        : null;

    try {
      await widget.createArchive(
        sources: widget.sources,
        destination: _destination,
        options: CompressionOptions(
          format: _format,
          level: _level,
          password: password,
          splitVolumeBytes: splitVolumeBytes,
        ),
        onProgress: (value) => progress.value = value,
        cancelToken: cancelToken,
      );

      // 결과 파일 크기 읽기(압축률 표시)와 분할 조각 개수 세기는 둘 다
      // 부가 정보일 뿐이니, 실패해도 "압축 생성 완료" 자체는 그대로 알린다.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      String resultSuffix = '';
      try {
        // 분할했으면 실제 목적지 파일은 없고 "destination.001" 등 조각만
        // 있다 — 조각들을 찾아 크기를 합산하고 개수를 완료 메시지에 덧붙인다.
        final List<File> splitParts = splitVolumeBytes != null
            ? await findSplitVolumeParts(_destination)
            : const <File>[];
        var compressedSize = 0;
        if (splitParts.isNotEmpty) {
          for (final part in splitParts) {
            compressedSize += await part.length();
          }
        } else {
          compressedSize = await File(_destination.toFilePath()).length();
        }
        resultSuffix = _compressionRatioLabel(l10n, compressedSize);
        if (splitParts.isNotEmpty) {
          resultSuffix += l10n.splitVolumesCreated(splitParts.length);
        }
      } catch (_) {
        // 무시 — 부가 정보 없이 완료 메시지만 보여준다.
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // 진행률 다이얼로그 닫기
      Navigator.of(context).pop(); // CompressDialog 자체 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.compressCompleted(_destination.toFilePath())}$resultSuffix',
          ),
        ),
      );
    } on OperationCancelledException {
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _isCompressing = false);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 진행률 다이얼로그만 닫고 설정은 유지
      setState(() => _isCompressing = false);
      showErrorSnackBar(context, AppLocalizations.of(context).compressFailed('$e'));
    }
  }

  /// "(12.3 MB → 5.2 MB, 58% 감소)" 형태 — 원본 크기 계산이 아직 안 끝났거나
  /// 0바이트면 비율이 무의미하므로 빈 문자열을 반환한다.
  String _compressionRatioLabel(AppLocalizations l10n, int compressedSize) {
    final original = _originalSizeBytes;
    if (original == null || original <= 0) return '';
    final reducedPercent = (100 - compressedSize / original * 100)
        .clamp(0, 100)
        .round();
    return l10n.compressionRatioLabel(
      formatBytes(original),
      formatBytes(compressedSize),
      reducedPercent,
    );
  }

  String _levelLabel(AppLocalizations l10n, CompressionLevel level) =>
      switch (level) {
        CompressionLevel.store => l10n.compressionLevelStore,
        CompressionLevel.fast => l10n.compressionLevelFast,
        CompressionLevel.normal => l10n.compressionLevelNormal,
        CompressionLevel.max => l10n.compressionLevelMax,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final writableFormats = FormatRegistry.writableFormats;

    return AlertDialog(
      title: Text(l10n.newArchiveTitle),
      content: SizedBox(
        width: 420,
        // 비밀번호/분할 압축 필드가 둘 다 펼쳐지면 작은 화면(테스트 기본
        // 뷰포트 포함)에서 내용이 다이얼로그 높이를 넘을 수 있어 스크롤을
        // 허용한다.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.compressTargetLabel(_sourcesSummary(l10n))),
              Text(l10n.originalSizeLabel(formatBytes(_originalSizeBytes))),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(width: 80, child: Text(l10n.formatLabel)),
                  DropdownButton<ArchiveFormat>(
                    value: _format,
                    items: [
                      for (final format in writableFormats)
                        DropdownMenuItem(
                          value: format,
                          child: Text(FormatRegistry.of(format).displayName),
                        ),
                    ],
                    onChanged: _isCompressing ? null : _onFormatChanged,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(width: 80, child: Text(l10n.compressionLevelLabel)),
                  Expanded(
                    child: Slider(
                      value: CompressionLevel.values.indexOf(_level).toDouble(),
                      min: 0,
                      max: (CompressionLevel.values.length - 1).toDouble(),
                      divisions: CompressionLevel.values.length - 1,
                      label: _levelLabel(l10n, _level),
                      onChanged: _isCompressing
                          ? null
                          : (value) => setState(
                              () => _level =
                                  CompressionLevel.values[value.round()],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: (_isCompressing || !_supportsPassword(_format))
                    ? null
                    : () => setState(
                        () => _passwordProtected = !_passwordProtected,
                      ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _passwordProtected,
                      onChanged:
                          (_isCompressing || !_supportsPassword(_format))
                          ? null
                          : (checked) => setState(
                              () => _passwordProtected = checked ?? false,
                            ),
                    ),
                    Text(l10n.passwordProtectSupportedFormats),
                  ],
                ),
              ),
              if (_passwordProtected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_isCompressing,
                    decoration: InputDecoration(hintText: l10n.passwordHint),
                  ),
                ),
              InkWell(
                onTap: _isCompressing
                    ? null
                    : () => setState(() => _splitEnabled = !_splitEnabled),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _splitEnabled,
                      onChanged: _isCompressing
                          ? null
                          : (checked) => setState(
                              () => _splitEnabled = checked ?? false,
                            ),
                    ),
                    Text(l10n.splitArchiveLabel),
                  ],
                ),
              ),
              if (_splitEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _splitVolumeSizeController,
                          enabled: !_isCompressing,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: l10n.splitVolumeSizeHint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('MB'),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.saveLocationLabel(_destination.toFilePath()),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _isCompressing ? null : _changeDestination,
                    child: Text(l10n.changeButton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCompressing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isCompressing ? null : _startCompress,
          child: Text(l10n.startCompressButton),
        ),
      ],
    );
  }
}
