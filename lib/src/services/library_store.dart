import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/book.dart';
import '../formats/format_engine.dart';
import '../formats/pdf_format.dart';
import 'bookmark_store.dart';
import 'manual_chapter_store.dart';
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

  // Capture immutable progress snapshots and serialize writes to prevent
  // older page turns racing a newer chapter/character position.
  Future<void> _progressWrites = Future<void>.value();

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

    final loadedBooks = <Book>[];
    final String? raw = _prefs!.getString(_metaKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        for (final dynamic item in list) {
          final Book? book = await _loadBook(item as Map<String, dynamic>);
          if (book != null) {
            _restoreProgress(book);
            loadedBooks.add(book);
          }
        }
      } catch (error) {
        // A damaged index must not silently be overwritten with sample data.
        throw StateError('书架索引读取失败。原书籍文件未删除；请备份后修复。$error');
      }
    }

    books
      ..clear()
      ..addAll(loadedBooks);
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
    final prefs = _prefs;
    if (prefs == null) return;
    final key = '$_progressPrefix${book.id}';
    final snapshot =
        '${book.chapterIndex.value}:${book.pageIndex.value}:${book.charOffset.value}';
    final write = _progressWrites.catchError((Object _) {}).then((_) async {
      if (!await prefs.setString(key, snapshot)) {
        throw StateError('阅读进度写入失败');
      }
    });
    _progressWrites = write;
    await write;
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
      type: FileType.any,
      withData: false,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.first;
    File? staged;
    String? path = picked.path;
    if (path == null || !await File(path).exists()) {
      staged = await _stageDocumentStream(picked);
      path = staged.path;
    }
    final String readablePath = path;
    try {
    final String ext = picked.name.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      final File source = File(readablePath);
      await PdfFormat.verifyHeader(source);
      final String hash = await _hashFile(source);
      final int fileSize = await source.length();
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory dir = Directory(base.path + '/books');
      await dir.create(recursive: true);
      final String id = DateTime.now().microsecondsSinceEpoch.toString();
      final File copy = await source.copy(dir.path + '/' + id + '.pdf');
      final String title = picked.name.toLowerCase().endsWith('.pdf')
          ? picked.name.substring(0, picked.name.length - 4)
          : picked.name;
      final Book book = Book(
        id: id,
        title: title,
        author: '本地 PDF',
        format: 'PDF',
        content: '',
        sourcePath: copy.path,
        contentHash: hash,
        fileName: picked.name,
        fileSize: fileSize,
      );
      return await _commitImportedBook(book);
    }
    if (!FormatEngine.supported.contains(ext)) {
      throw const FormatException(
        '当前支持 TXT、EPUB（文字版）、PDF、Markdown、HTML，其余格式开发中');
    }
    final File source = File(readablePath);
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
      contentHash: sha256.convert(bytes).toString(),
      fileName: picked.name,
      fileSize: fileSize,
    );
    return await _commitImportedBook(book);
    } finally {
      if (staged != null && await staged.exists()) {
        await staged.delete();
      }
    }
  }

  Future<File> _stageDocumentStream(PlatformFile selected) async {
    final stream = selected.readStream;
    if (stream == null) {
      throw const FormatException('文件提供者没有提供可读取的内容，请先下载到本地');
    }
    final ext = selected.name.split('.').last.toLowerCase();
    final limit = ext == 'pdf'
        ? 256 * 1024 * 1024 : FormatEngine.maxSourceBytes;
    final dir = await getTemporaryDirectory();
    final staged = File(dir.path + '/read-import-' +
        DateTime.now().microsecondsSinceEpoch.toString() + '.tmp');
    final sink = staged.openWrite();
    var bytes = 0;
    try {
      await for (final chunk in stream) {
        bytes += chunk.length;
        if (bytes > limit) {
          throw const FormatException('电子书超过当前支持的文件大小上限');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      if (bytes == 0) throw const FormatException('导入文件为空');
      return staged;
    } catch (_) {
      await sink.close();
      if (await staged.exists()) await staged.delete();
      rethrow;
    }
  }


  Future<Book> _commitImportedBook(Book book) async {
    books.add(book);
    _sortBooks();
    try {
      await _persistMeta();
      notifyListeners();
      return book;
    } catch (_) {
      // A storage failure must not leave an unreadable phantom entry.
      books.removeWhere((item) => item.id == book.id);
      final owned = book.sourcePath;
      if (owned != null) {
        try {
          final file = File(owned);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBook(Book book) async {
    final index = books.indexWhere((item) => item.id == book.id);
    if (index < 0) return;
    final removed = books.removeAt(index);
    try {
      // Commit the library change before deleting the only local copy.
      // A failed write must restore the visible book and preserve its bytes.
      await _persistMeta();
    } catch (_) {
      books.insert(index, removed);
      notifyListeners();
      rethrow;
    }
    final path = book.sourcePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _prefs?.remove('$_progressPrefix${book.id}');
    await BookmarkStore.clearForDeletedBook(book.id);
    await ChapterRuleStore.clearForDeletedBook(book.id);
    await ManualChapterStore.clearForDeletedBook(book.id);
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
      contentHash: book.contentHash,
      fileName: book.fileName,
      fileSize: book.fileSize,
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

  Future<String> _hashFile(File file) async {
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    final value = sink.value;
    if (value == null) throw StateError('文件哈希计算失败');
    return value.toString();
  }

  /// Computes and caches the SHA-256 identity for older imported books.
  Future<String> ensureContentHash(Book book) async {
    final cached = book.contentHash;
    if (cached != null && cached.length == 64) return cached;
    final path = book.sourcePath;
    if (path == null || !await File(path).exists()) {
      throw StateError('书籍原文件不存在，无法计算同步标识');
    }
    final hash = await _hashFile(File(path));
    book.contentHash = hash;
    book.fileSize = await File(path).length();
    await _persistMeta();
    return hash;
  }

  Book? bookByHash(String hash) {
    for (final book in books) {
      if (book.contentHash == hash) return book;
    }
    return null;
  }

  /// Applies metadata from a remote device without touching the local file.
  Future<void> applySyncedMetadata({
    required String hash,
    required String title,
    required String author,
    required int chapterCount,
    required DateTime? lastReadAt,
    List<String>? tags,
  }) async {
    final index = books.indexWhere((Book b) => b.contentHash == hash);
    if (index < 0) return;
    final old = books[index];
    final replacement = Book(
      id: old.id,
      title: title.trim().isEmpty ? old.title : title,
      author: author.trim().isEmpty ? old.author : author,
      content: old.content,
      format: old.format,
      sourcePath: old.sourcePath,
      lastReadAt: lastReadAt ?? old.lastReadAt,
      chapterCount: chapterCount,
      contentHash: old.contentHash,
      fileName: old.fileName,
      fileSize: old.fileSize,
      tags: tags ?? old.tags,
    );
    replacement.chapterIndex.value = old.chapterIndex.value;
    replacement.pageIndex.value = old.pageIndex.value;
    replacement.charOffset.value = old.charOffset.value;
    books[index] = replacement;
    _sortBooks();
    await _persistMeta();
    notifyListeners();
  }

  Future<void> updateTags(Book book, List<String> tags) async {
    final cleaned = tags
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty)
        .toSet()
        .toList();
    book.tags = cleaned;
    await _persistMeta();
    notifyListeners();
  }

  bool hasHash(String hash) => bookByHash(hash) != null;

  /// Restores a book from a remote file. The caller has already verified the
  /// SHA-256; the file is parsed and committed as a normal local book.
  Future<Book> importSyncedFile({
    required Uint8List bytes,
    required String hash,
    required String fileName,
    required String title,
    required String author,
    required String format,
    required int chapterCount,
    required DateTime? lastReadAt,
    List<String>? tags,
  }) async {
    final existing = bookByHash(hash);
    if (existing != null) return existing;
    if (bytes.isEmpty) throw const FormatException('云端书籍文件为空');
    final ext = fileName.split('.').last.toLowerCase();
    if (!FormatEngine.supported.contains(ext)) {
      throw FormatException('云端书籍格式不支持：$ext');
    }
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/books');
    await dir.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final target = File('${dir.path}/$id.$ext');
    await target.writeAsBytes(bytes, flush: true);
    final parsed = await FormatEngine.importBytes(bytes, fileName);
    if (sha256.convert(bytes).toString() != hash) {
      await target.delete();
      throw const FormatException('云端文件校验失败，未导入');
    }
    final book = Book(
      id: id,
      title: parsed.title?.isNotEmpty == true ? parsed.title! : title,
      author: parsed.author?.isNotEmpty == true ? parsed.author! : author,
      content: parsed.text,
      format: parsed.format,
      sourcePath: target.path,
      lastReadAt: lastReadAt,
      chapterCount: chapterCount,
      contentHash: hash,
      fileName: fileName,
      fileSize: bytes.length,
      tags: tags,
    );
    return _commitImportedBook(book);
  }

  Future<void> _persistMeta() async {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    final String raw = jsonEncode(books.map((Book b) => b.toMeta()).toList());
    if (!await p.setString(_metaKey, raw)) {
      throw StateError('书架索引保存失败，未继续修改本地文件');
    }
  }

  /// Kept for backwards compatibility with import tests and older callers.
  static Future<String> decodeText(Uint8List bytes) =>
      FormatEngine.decodeText(bytes);
}


class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
