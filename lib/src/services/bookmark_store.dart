import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable, absolute UTF-16 character anchors, independent of font/page size.
/// The original book bytes are never modified.
class BookmarkStore {
  static const String _prefix = 'read.bookmarks.v1.';

  static Future<List<int>> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$bookId');
    if (raw == null) return <int>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <int>[];
      final values = decoded.whereType<int>().where((x) => x >= 0).toSet().toList();
      values.sort();
      return values;
    } catch (_) {
      // Never replace damaged saved data until the user explicitly changes it.
      return <int>[];
    }
  }

  static Future<List<int>> toggle(String bookId, int absoluteOffset) async {
    if (absoluteOffset < 0) throw ArgumentError.value(absoluteOffset);
    final prefs = await SharedPreferences.getInstance();
    final positions = (await load(bookId)).toSet();
    if (!positions.add(absoluteOffset)) positions.remove(absoluteOffset);
    final sorted = positions.toList()..sort();
    final success = await prefs.setString('$_prefix$bookId', jsonEncode(sorted));
    if (!success) throw StateError('书签保存失败');
    return sorted;
  }

  /// Replaces the full bookmark set after a validated sync merge.
  static Future<void> replaceAll(String bookId, List<int> offsets) async {
    final prefs = await SharedPreferences.getInstance();
    final safe = offsets.where((int x) => x >= 0).toSet().toList()..sort();
    final success = await prefs.setString('$_prefix$bookId', jsonEncode(safe));
    if (!success) throw StateError('书签同步写入失败');
  }

  static Future<void> clearForDeletedBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bookId');
  }
}
