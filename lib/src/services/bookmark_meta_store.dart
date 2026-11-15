import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bookmark annotations are stored separately from the bookmark offsets so
/// old `read.bookmarks.v1.*` lists remain readable and migration is lossless.
class BookmarkMeta {
  const BookmarkMeta({
    required this.offset,
    required this.createdAt,
    required this.note,
  });

  final int offset;
  final int createdAt;
  final String note;

  Map<String, Object?> toJson() => <String, Object?>{
        'offset': offset,
        'created_at': createdAt,
        'note': note,
      };

  static BookmarkMeta? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final offset = (raw['offset'] as num?)?.toInt();
    if (offset == null || offset < 0) return null;
    return BookmarkMeta(
      offset: offset,
      createdAt: (raw['created_at'] as num?)?.toInt() ?? 0,
      note: raw['note'] as String? ?? '',
    );
  }
}

class BookmarkMetaStore {
  static const String _prefix = 'read.bookmark_meta.v1.';

  static Future<Map<int, BookmarkMeta>> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$bookId');
    if (raw == null) return <int, BookmarkMeta>{};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final values = <int, BookmarkMeta>{};
      for (final item in decoded) {
        final meta = BookmarkMeta.fromJson(item);
        if (meta != null) values[meta.offset] = meta;
      }
      return values;
    } catch (_) {
      return <int, BookmarkMeta>{};
    }
  }

  static Future<void> ensure(String bookId, int offset) async {
    final values = await load(bookId);
    if (values.containsKey(offset)) return;
    values[offset] = BookmarkMeta(
      offset: offset,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      note: '',
    );
    await _persist(bookId, values);
  }

  static Future<void> remove(String bookId, int offset) async {
    final values = await load(bookId);
    if (values.remove(offset) == null) return;
    await _persist(bookId, values);
  }

  static Future<void> setNote(String bookId, int offset, String note) async {
    final values = await load(bookId);
    final existing = values[offset];
    values[offset] = BookmarkMeta(
      offset: offset,
      createdAt: existing?.createdAt ??
          DateTime.now().millisecondsSinceEpoch,
      note: note.trim(),
    );
    await _persist(bookId, values);
  }

  static Future<void> replaceAll(
    String bookId,
    Map<int, BookmarkMeta> metas,
  ) async {
    final values = <int, BookmarkMeta>{};
    for (final meta in metas.values) {
      if (meta.offset >= 0) values[meta.offset] = meta;
    }
    await _persist(bookId, values);
  }

  static Future<void> clearForDeletedBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bookId');
  }

  static Future<void> _persist(
    String bookId,
    Map<int, BookmarkMeta> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final list = values.values
        .toList()
      ..sort((BookmarkMeta a, BookmarkMeta b) => a.offset.compareTo(b.offset));
    final ok = await prefs.setString(
      '$_prefix$bookId',
      jsonEncode(list.map((BookmarkMeta m) => m.toJson()).toList()),
    );
    if (!ok) throw StateError('书签备注保存失败');
  }
}
