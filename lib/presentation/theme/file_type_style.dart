import 'package:flutter/material.dart';

import 'app_theme.dart';

// daylight-commander-flutter의 lib/presentation/theme/file_type_style.dart를
// 그대로 이식 — 압축파일 내부 항목도 자매 앱과 동일한 아이콘/색상 체계로
// 표시한다(UI_UX.md 3장).

/// 파일을 아이콘/색상으로 분류하기 위한 카테고리 (UI_UX.md 3장).
enum FileCategory {
  folder,
  image,
  video,
  audio,
  archive,
  code,
  document,
  font,
  executable,
  unknown,
}

/// 파일 유형별 아이콘/색상 매핑.
///
/// 우선순위: assets/icons/filetypes 아래 icons8 "Windows 11 Color" 세트에
/// 정확히 매칭되는 확장자는 해당 컬러 SVG를 사용하고, 매칭이 없는 확장자는
/// [FileTypeStyle.unknownAsset](hexadecimal 아이콘)로 폴백한다.
class FileTypeStyle {
  const FileTypeStyle._();

  static const _iconBase = 'assets/icons/filetypes';
  static const _folderBase = 'assets/icons/folders';

  static const Map<String, String> _extensionToAsset = {
    'pdf': '$_iconBase/icons8-pdf-240.svg',
    'doc': '$_iconBase/icons8-doc-240.svg',
    'docx': '$_iconBase/icons8-doc-240.svg',
    'xls': '$_iconBase/icons8-xls-240.svg',
    'xlsx': '$_iconBase/icons8-xls-240.svg',
    'ppt': '$_iconBase/icons8-ppt-240.svg',
    'pptx': '$_iconBase/icons8-ppt-240.svg',
    'txt': '$_iconBase/icons8-txt-240.svg',
    'json': '$_iconBase/icons8-json-240.svg',
    'xml': '$_iconBase/icons8-xml-file-240.svg',
    'html': '$_iconBase/icons8-html-filetype-240.svg',
    'htm': '$_iconBase/icons8-html-filetype-240.svg',
    'css': '$_iconBase/icons8-css-filetype-240.svg',
    'java': '$_iconBase/icons8-java-file-240.svg',
    'sql': '$_iconBase/icons8-sql-240.svg',
    'dll': '$_iconBase/icons8-dll-240.svg',
    'exe': '$_iconBase/icons8-exe-240.svg',
    'apk': '$_iconBase/icons8-apk-240.svg',
    'ps': '$_iconBase/icons8-ps-240.svg',
    'zip': '$_iconBase/icons8-zip-240.svg',
    '7z': '$_iconBase/icons8-7zip-240.svg',
    'rar': '$_iconBase/icons8-rar-240.svg',
    'tar': '$_iconBase/icons8-tar-240.svg',
    'gz': '$_iconBase/icons8-archive-240.svg',
    'jpg': '$_iconBase/icons8-jpg-240.svg',
    'jpeg': '$_iconBase/icons8-jpg-240.svg',
    'png': '$_iconBase/icons8-png-240.svg',
    'ttf': '$_iconBase/icons8-ttf-240.svg',
    'otf': '$_iconBase/icons8-otf-240.svg',
    'woff': '$_iconBase/icons8-woff-240.svg',
    'mp3': '$_iconBase/icons8-mp3-240.svg',
    'wav': '$_iconBase/icons8-wav-240.svg',
    'wma': '$_iconBase/icons8-wma-240.svg',
    'aac': '$_iconBase/icons8-aac-240.svg',
    'ogg': '$_iconBase/icons8-ogg-240.svg',
    'avi': '$_iconBase/icons8-avi-240.svg',
    'mov': '$_iconBase/icons8-mov-240.svg',
    'mpg': '$_iconBase/icons8-mpg-240.svg',
    'mpeg': '$_iconBase/icons8-mpg-240.svg',
  };

  static const unknownAsset = '$_iconBase/icons8-hexadecimal-240.svg';
  static const genericFolderAsset = '$_folderBase/icons8-folder.svg';

  /// 확장자(마침표 제외, 소문자 무관)에 대응하는 컬러 SVG 에셋. 없으면 null.
  static String? assetForExtension(String extension) =>
      _extensionToAsset[extension.toLowerCase()];

  static FileCategory categoryForExtension(String extension) {
    final ext = extension.toLowerCase();
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'}.contains(ext)) {
      return FileCategory.image;
    }
    if (const {'mp4', 'mkv', 'webm', 'avi', 'mov', 'mpg', 'mpeg'}.contains(ext)) {
      return FileCategory.video;
    }
    if (const {'mp3', 'wav', 'wma', 'aac', 'ogg', 'flac'}.contains(ext)) {
      return FileCategory.audio;
    }
    if (const {'zip', '7z', 'rar', 'tar', 'gz'}.contains(ext)) {
      return FileCategory.archive;
    }
    if (const {
      'dart', 'java', 'py', 'js', 'ts', 'json', 'xml', 'html', 'htm', //
      'css', 'sql', 'yaml', 'yml',
    }.contains(ext)) {
      return FileCategory.code;
    }
    if (const {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'}
        .contains(ext)) {
      return FileCategory.document;
    }
    if (const {'ttf', 'otf', 'woff'}.contains(ext)) {
      return FileCategory.font;
    }
    if (const {'exe', 'apk', 'dll', 'app'}.contains(ext)) {
      return FileCategory.executable;
    }
    return FileCategory.unknown;
  }

  static Color colorFor(FileCategory category, {required bool isDark}) {
    switch (category) {
      case FileCategory.folder:
        return isDark ? AppColors.primary : AppColors.primaryDeep;
      case FileCategory.image:
        return isDark ? AppColors.imageDark : AppColors.imageLight;
      case FileCategory.video:
        return isDark ? AppColors.videoDark : AppColors.videoLight;
      case FileCategory.audio:
        return isDark ? AppColors.audioDark : AppColors.audioLight;
      case FileCategory.archive:
        return isDark ? AppColors.archiveDark : AppColors.archiveLight;
      case FileCategory.code:
        return isDark ? AppColors.codeDark : AppColors.codeLight;
      case FileCategory.document:
        return isDark ? AppColors.documentDark : AppColors.documentLight;
      case FileCategory.font:
      case FileCategory.executable:
        return isDark ? AppColors.executableDark : AppColors.executableLight;
      case FileCategory.unknown:
        return isDark ? AppColors.textLow : AppColors.textMidLight;
    }
  }
}
