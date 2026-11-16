import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:read/src/formats/format_engine.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';

/// 一次批量导入的结果。所有数字都来自真实操作，没有"假装成功"。
class ImportSummary {
  const ImportSummary({
    this.imported = 0,
    this.skipped = 0,
    this.failed = 0,
    this.errors = const <String>[],
    this.titles = const <String>[],
  });

  final int imported;
  final int skipped;
  final int failed;
  final List<String> errors;
  final List<String> titles;

  bool get isEmpty => imported == 0 && skipped == 0 && failed == 0;

  String get message {
    final List<String> parts = <String>[];
    if (imported > 0) parts.add('导入 $imported 本');
    if (skipped > 0) parts.add('跳过重复 $skipped 本');
    if (failed > 0) parts.add('失败 $failed 个');
    if (parts.isEmpty) return '没有可导入的文件';
    final String head = parts.join('，');
    if (errors.isEmpty) return head;
    return '$head。${errors.first}';
  }

  ImportSummary merge(ImportSummary other) => ImportSummary(
        imported: imported + other.imported,
        skipped: skipped + other.skipped,
        failed: failed + other.failed,
        errors: <String>[...errors, ...other.errors],
        titles: <String>[...titles, ...other.titles],
      );
}

/// 导入工具箱：本机多选、目录扫描、智能导入共用同一套落盘逻辑。
class ImportTools {
  const ImportTools._();

  static const Set<String> _supported = <String>{
    'txt',
    'epub',
    'pdf',
    'md',
    'markdown',
    'html',
    'htm',
  };

  static bool supported(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    final String ext = path.substring(dot + 1).toLowerCase();
    // PDF 不走 FormatEngine（它只负责纯文本格式），但同样是可导入的。
    if (ext == 'pdf') return true;
    return _supported.contains(ext) && FormatEngine.supported.contains(ext);
  }

  /// 从本机多选文件导入。
  static Future<ImportSummary> pickAndImport() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return const ImportSummary();
    final List<String> paths = result.files
        .map((PlatformFile f) => f.path)
        .whereType<String>()
        .toList();
    return importPaths(paths);
  }

  /// 选择一个文件夹，递归导入其中所有支持的电子书。
  static Future<ImportSummary> scanFolder() async {
    final String? dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择包含电子书的文件夹',
    );
    if (dir == null) return const ImportSummary();
    final Directory root = Directory(dir);
    if (!await root.exists()) {
      return const ImportSummary(failed: 1, errors: <String>['文件夹不存在']);
    }
    final List<String> paths = <String>[];
    await for (final FileSystemEntity entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!supported(entity.path)) continue;
      paths.add(entity.path);
      if (paths.length >= 500) break;
    }
    return importPaths(paths);
  }

  /// 智能导入：多选后按格式/大小排序，重复内容直接跳过，
  /// 并从「《书名》作者」这类文件名里补作者信息。
  static Future<ImportSummary> smartImport() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return const ImportSummary();
    final List<String> paths = result.files
        .map((PlatformFile f) => f.path)
        .whereType<String>()
        .where(supported)
        .toList()
      ..sort();
    ImportSummary total = const ImportSummary();
    for (final String path in paths) {
      final ImportSummary one = await _importOne(path, smart: true);
      total = total.merge(one);
    }
    return total;
  }

  static Future<ImportSummary> importPaths(List<String> paths) async {
    ImportSummary total = const ImportSummary();
    for (final String path in paths) {
      if (!supported(path)) {
        total = total.merge(const ImportSummary(skipped: 1));
        continue;
      }
      total = total.merge(await _importOne(path));
      if (total.imported >= 200) break;
    }
    return total;
  }

  static Future<ImportSummary> _importOne(String path, {bool smart = false}) async {
    try {
      final String name = path.split(Platform.pathSeparator).last;
      final Book? book = await LibraryStore.instance.importPath(path, displayName: name);
      if (book == null) {
        return const ImportSummary(skipped: 1);
      }
      if (smart) {
        final String? author = _guessAuthor(name, book.title);
        if (author != null && (book.author.isEmpty || book.author == '本地导入')) {
          await LibraryStore.instance.updateBook(book.copyWith(author: author));
        }
        final String folder = path.split(Platform.pathSeparator).length > 1
            ? path.split(Platform.pathSeparator)[path.split(Platform.pathSeparator).length - 2]
            : '';
        if (folder.isNotEmpty && book.category.isEmpty) {
          await LibraryStore.instance
              .updateBook(book.copyWith(category: folder));
        }
      }
      return ImportSummary(imported: 1, titles: <String>[book.title]);
    } catch (error) {
      return ImportSummary(failed: 1, errors: <String>['$error']);
    }
  }

  /// 从 "《书名》作者.txt" / "书名 - 作者.txt" 里尽力提取作者。
  static String? _guessAuthor(String fileName, String title) {
    final String base = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final RegExp afterTitle = RegExp(r'^《.+?》\s*(.+)$');
    final Match? m1 = afterTitle.firstMatch(base);
    if (m1 != null) {
      final String value = m1.group(1)!.trim();
      if (value.isNotEmpty && value.length <= 20) return value;
    }
    final int dash = base.lastIndexOf(' - ');
    if (dash > 0) {
      final String value = base.substring(dash + 3).trim();
      if (value.isNotEmpty && value.length <= 20 && value != title) return value;
    }
    return null;
  }
}
