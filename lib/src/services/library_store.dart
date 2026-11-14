import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sample_book.dart';
import '../model/book.dart';

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
      } catch (_) {
        books.clear();
      }
    }

    if (books.isEmpty) {
      books.add(
        Book(
          id: kSampleBookId,
          title: kSampleTitle,
          author: kSampleAuthor,
          content: kSampleContent,
        ),
      );
      await _persistMeta();
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
    if (id == kSampleBookId) {
      return Book.fromMeta(meta, kSampleContent);
    }
    final String? path = meta['sourcePath'] as String?;
    String content = '';
    if (path != null) {
      final File file = File(path);
      if (await file.exists()) {
        content = await decodeText(await file.readAsBytes());
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
    if (parts.length != 2) return;
    book.chapterIndex.value = int.tryParse(parts[0]) ?? 0;
    book.pageIndex.value = int.tryParse(parts[1]) ?? 0;
  }

  Future<void> saveProgress(Book book) async {
    final SharedPreferences? p = _prefs;
    if (p == null) return;
    await p.setString(
      '$_progressPrefix${book.id}',
      '${book.chapterIndex.value}:${book.pageIndex.value}',
    );
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
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.first;
    final String? path = picked.path;
    if (path == null) return null;

    final Uint8List bytes = await File(path).readAsBytes();
    final String text = await decodeText(bytes);
    if (text.trim().isEmpty) return null;

    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory booksDir = Directory('${dir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    final File target = File('${booksDir.path}/$id.txt');
    await target.writeAsString(text);

    final String name = picked.name.replaceAll(RegExp(r'\.(txt|epub|md)$', caseSensitive: false), '');
    final Book book = Book(
      id: id,
      title: name,
      author: '本地导入',
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
    await _persistMeta();
    notifyListeners();
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
    );
    updated.chapterIndex.value = book.chapterIndex.value;
    updated.pageIndex.value = book.pageIndex.value;
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

  /// 编码兜底：优先 UTF-8，失败后按 GB18030 解码（中文 TXT 常见）。
  static Future<String> decodeText(Uint8List bytes) async {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // 继续尝试 GBK 系编码
    }
    try {
      final String text = await CharsetConverter.decode('gb18030', bytes);
      if (text.isNotEmpty) return text;
    } catch (_) {
      // 落到宽松 UTF-8
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
