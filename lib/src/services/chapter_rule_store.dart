import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'chapter_splitter.dart';

/// Independent per-book configuration; does not touch the imported file.
class ChapterRuleStore {
  static const String _prefix = 'read.chapter-rule.v1.';

  static Future<ChapterRule> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$bookId');
    if (raw == null) return const ChapterRule.automatic();
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) {
        return const ChapterRule.automatic();
      }
      final mode = parsed['mode'];
      if (mode == 'none') return const ChapterRule.none();
      if (mode == 'custom') {
        final pattern = parsed['pattern'];
        if (pattern is! String) return const ChapterRule.automatic();
        validateChapterPattern(pattern);
        return ChapterRule.custom(pattern);
      }
    } catch (_) {
      // Preserve malformed settings for manual recovery rather than overwrite.
      return const ChapterRule.automatic();
    }
    return const ChapterRule.automatic();
  }

  static Future<void> save(String bookId, ChapterRule rule) async {
    if (rule.mode == ChapterRuleMode.custom) {
      validateChapterPattern(rule.pattern);
    }
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(<String, String>{
      'mode': rule.mode.name,
      'pattern': rule.mode == ChapterRuleMode.custom ? rule.pattern : '',
    });
    if (!await prefs.setString('$_prefix$bookId', serialized)) {
      throw StateError('分章设置保存失败');
    }
  }

  static Future<void> clearForDeletedBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bookId');
  }
}
