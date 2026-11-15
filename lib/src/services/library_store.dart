import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/book.dart';
import '../formats/format_engine.dart';
import '../formats/pdf_format.dart';
import 'bookmark_store.dart';
import 'chapter_rule_store.dart';

/// 书架与阅读设置的持久化。
class LibraryStore extends ChangeNotifier {
  LibraryStore._();

  static final LibraryStore instance = LibraryStore._();

  static const String _metaKey = 'read.library.meta.v1';
  static const String _progressPrefix = 'read.progress.';
  static const String _fontKey = 'read.reader.fontsize';
  static const String _lineKey = 'read.reader.lineheight';
  static const String _bgKey = 'read.reader.bg';

  final List<Book> books = <Book>[];
  SharedPreferences? _prefs;

  double _fontSize = 18;
  double _lineHeight = 1.7;
  int _backgroundIndex = 0;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  int get backgroundIndex => _backgroundIndex;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _fontSize = _prefs!.getDouble(_fontKey) ?? 18;
    _lineHeight = _prefs!.getDouble(_lineKey) ?? 1.7;
    _backgroundIndex = _prefs!.getInt(_bgKey) ?? 0;

    books.clear();
    final String? raw = _prefs!.getString(_metaKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        for (final dynamic item in list) {
          final Book? book = await _loadBook(item as Map<String, dynamic>);
          if (book != null) {
            _restoreProgress(book);
            books.add(book);
          }
        }
      } catch (error) {
        // A damaged index must not silently be overwritten with sample data.
        throw StateError('书架索引读取失败。原书籍文件未删除；请备份后修复。$error');
      }
    }

    _sortBooks();
    notifyListeners();
  }

  void _sortBooks() {
    books.sort((Book a, Book b) {
      final int ta = a.lastReadAt?.millisecondsSinceEpoch ?? 0;
      final int tb = b.lastReadAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
  }

  Future<Book?> _loadBook(Map<String, dynamic> meta) async {
    final String? id = meta['id'] as String?;
    if (id == null) return null;
    if (id == 'sample-1') {
      // 旧版本内置样章不再载入：直接跳过并让下一次持久化把它从索引里清掉。
      return null;
    }
    final String? path = meta['sourcePath'] as String?;
    if ((meta['format'] as String?)?.toUpperCase() == 'PDF') {
      if (path != null && await File(path).exists()) return Book.fromMeta(meta, '');
      return null;
    }
    String content = '';
    if (path != null) {
      final File file = File(path);
      if (await file.exists()) {
        final Uint8List bytes = await file.readAsBytes();
        final ImportedDocument parsed =
            await FormatEngine.importBytes(bytes, path);
        content = parsed.text;
      }
    }
    if (content.isEmpty) {
      return null;
    }
    return Book.fromMeta(meta, content);
  }

  void _restoreProgress(Book book) {
    final String? raw = _prefs?.getString('$_progressPrefix${book.id}');
    if (raw == null) return;
    final List<String> parts = raw.split(':');
    if (parts.length != 2 && parts.length != 3) return;
    book.chapterIndex.value = int.tryParse(parts[0]) ?? 0;
    book.pageIndex.value = int.tryParse(parts[1]) ?? 0;
    if (parts.length == 3) book.charOffset.value = int.tryParse(parts[2]) ?? -1;
  }

  Future<void> saveProgress(Book book) async {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    await p.setString(
      '$_progressPrefix${book.id}',
      '${book.chapterIndex.value}:${book.pageIndex.value}:${book.charOffset.value}',
    );
  }

  /// Apply validated remote progress without altering the imported file.
  /// This is called only after a successful WebDAV transaction.
  Future<void> applySyncedProgress(
    Book book, {
    required int chapterIndex,
    required int pageIndex,
    required int charOffset,
  }) async {
    final previousChapter = book.chapterIndex.value;
    final previousPage = book.pageIndex.value;
    final previousOffset = book.charOffset.value;
    book.chapterIndex.value = chapterIndex;
    book.pageIndex.value = pageIndex;
    book.charOffset.value = charOffset;
    try {
      await saveProgress(book);
    } catch (_) {
      book.chapterIndex.value = previousChapter;
      book.pageIndex.value = previousPage;
      book.charOffset.value = previousOffset;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value;
    await _prefs?.setDouble(_fontKey, value);
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    _lineHeight = value;
    await _prefs?.setDouble(_lineKey, value);
    notifyListeners();
  }

  Future<void> setBackgroundIndex(int value) async {
    _backgroundIndex = value;
    await _prefs?.setInt(_bgKey, value);
    notifyListeners();
  }

  /// 导入 TXT：把内容复制到应用目录，元数据写入本地存储。
  Future<Book?> importBook() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>[
        'txt', 'epub', 'pdf', 'md', 'markdown', 'html', 'htm',
      ],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.first;
    final String? path = picked.path;
    if (path == null || path.isEmpty) {
      throw const FormatException('系统未返回可读取的本地文件路径。请先将电子书保存到手机本地文件夹后重新选择。');
    }

    final String ext = picked.name.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      final File source = File(path);
      if (!await source.exists()) {
        throw const FormatException('所选 PDF 文件无法读取，请确认文件已下载到本地');
      }
      await PdfFormat.verifyHeader(source);
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory dir = Directory(base.path + '/books');
      await dir.create(recursive: true);
      final String id = DateTime.now().microsecondsSinceEpoch.toString();
      final File copy = await source.copy(dir.path + '/' + id + '.pdf');
      final String title = picked.name.toLowerCase().endsWith('.pdf')
          ? picked.name.substring(0, picked.name.length - 4)
          : picked.name;
      final Book book = Book(id: id, title: title, author: '本地 PDF',
          format: 'PDF', content: '', sourcePath: copy.path);
      books.add(book);
      _sortBooks();
      await _persistMeta();
      notifyListeners();
      return book;
    }
    if (!FormatEngine.supported.contains(ext)) {
      throw const FormatException(
        '当前支持 TXT、EPUB（文字版）、PDF、Markdown、HTML，其余格式开发中');
    }
    final File source = File(path);
    if (!await source.exists()) {
      throw const FormatException('所选文件无法读取，请确认文件已下载到本地');
    }
    final int fileSize = await source.length();
    if (fileSize > FormatEngine.maxSourceBytes) {
      throw const FormatException(
        '当前单本读取上限为 40MB；超大 TXT 的分块索引仍在开发，'
        '为避免内存不足，暂不导入。');
    }
    final Uint8List bytes = await source.readAsBytes();
    final ImportedDocument parsed =
        await FormatEngine.importBytes(bytes, picked.name);
    final String text = parsed.text;
    if (text.trim().isEmpty) {
      throw const FormatException('文件中没有可以阅读的文字内容');
    }

    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory booksDir = Directory('${dir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    final File target = File('${booksDir.path}/$id.$ext');
    // Preserve the original file, including EPUB structure, for future
    // richer layout support and content-addressed cloud sync.
    await target.writeAsBytes(bytes, flush: true);

    final String name = picked.name.substring(
      0, picked.name.lastIndexOf('.') > 0
          ? picked.name.lastIndexOf('.')
          : picked.name.length,
    );
    final Book book = Book(
      id: id,
      title: parsed.title?.isNotEmpty == true ? parsed.title! : name,
      author: parsed.author?.isNotEmpty == true ? parsed.author! : '本地导入',
      format: parsed.format,
      content: text,
      sourcePath: target.path,
    );
    books.add(book);
    _sortBooks();
    await _persistMeta();
    notifyListeners();
    return book;
  }

  Future<void> deleteBook(Book book) async {
    books.remove(book);
    final String? path = book.sourcePath;
    if (path != null) {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _prefs?.remove('$_progressPrefix${book.id}');
    await BookmarkStore.clearForDeletedBook(book.id);
    await ChapterRuleStore.clearForDeletedBook(book.id);
    await _persistMeta();
    notifyListeners();
  }

  /// 缓存章节总数（书架显示进度用）。不触发通知，避免在路由退出时重建界面。
  Future<void> noteChapterCount(Book book, int count) async {
    if (book.chapterCount == count) return;
    book.chapterCount = count;
    await _persistMeta();
  }

  Future<void> touch(Book book) async {
    final Book updated = Book(
      id: book.id,
      title: book.title,
      author: book.author,
      content: book.content,
      format: book.format,
      sourcePath: book.sourcePath,
      lastReadAt: DateTime.now(),
      chapterCount: book.chapterCount,
    );
    updated.chapterIndex.value = book.chapterIndex.value;
    updated.pageIndex.value = book.pageIndex.value;
    updated.charOffset.value = book.charOffset.value;
    final int index = books.indexWhere((Book b) => b.id == book.id);
    if (index >= 0) {
      books[index] = updated;
    }
    _sortBooks();
    await _persistMeta();
    notifyListeners();
  }

  Future<void> _persistMeta() async {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    final String raw = jsonEncode(books.map((Book b) => b.toMeta()).toList());
    await p.setString(_metaKey, raw);
  }

  /// Kept for backwards compatibility with import tests and older callers.
  static Future<String> decodeText(Uint8List bytes) =>
      FormatEngine.decodeText(bytes);
}
