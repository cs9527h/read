import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史（R0316/R0317）。
///
/// - 按书籍隔离：每本书有独立历史，避免串书。
/// - 默认开启；用户可关闭（隐私选项 R0317），关闭后不再记录，
///   已有的历史仍可一键清除。
/// - 去重且保持最近在前，容量上限防止无限增长。
class SearchHistoryStore extends ChangeNotifier {
  SearchHistoryStore._();

  static final SearchHistoryStore instance = SearchHistoryStore._();

  static const String _enabledKey = 'read.search.history.enabled.v1';
  static const String _prefix = 'read.search.history.v1.';
  static const int maxPerBook = 20;

  final Map<String, List<String>> _byBook = <String, List<String>>{};
  bool _enabled = true;
  bool _loaded = false;

  bool get enabled => _enabled;
  bool get loaded => _loaded;

  /// 仅供测试：在切换 SharedPreferences mock 后重置内存缓存。
  @visibleForTesting
  void resetForTesting() {
    _byBook.clear();
    _enabled = true;
    _loaded = false;
  }

  Future<void> init() async {
    if (_loaded) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    for (final String key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final String bookId = key.substring(_prefix.length);
      final List<String> raw = prefs.getStringList(key) ?? const <String>[];
      if (raw.isNotEmpty) _byBook[bookId] = List<String>.from(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  List<String> historyFor(String bookId) =>
      List<String>.unmodifiable(_byBook[bookId] ?? const <String>[]);

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    notifyListeners();
  }

  /// 记录一次成功搜索；空词/未开启时忽略。
  Future<void> record(String bookId, String query) async {
    if (!_loaded || !_enabled) return;
    final String q = query.trim();
    if (q.isEmpty) return;
    final List<String> list = <String>[q];
    for (final String old in _byBook[bookId] ?? const <String>[]) {
      if (old.toLowerCase() != q.toLowerCase() && list.length < maxPerBook) {
        list.add(old);
      }
    }
    _byBook[bookId] = list;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefix + bookId, list);
  }

  Future<void> remove(String bookId, String query) async {
    final List<String>? list = _byBook[bookId];
    if (list == null) return;
    list.removeWhere((String item) => item == query);
    if (list.isEmpty) {
      _byBook.remove(bookId);
    }
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_byBook.containsKey(bookId)) {
      await prefs.setStringList(_prefix + bookId, list);
    } else {
      await prefs.remove(_prefix + bookId);
    }
  }

  Future<void> clear(String bookId) async {
    if (_byBook.remove(bookId) == null) return;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + bookId);
  }

  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
    _byBook.clear();
    notifyListeners();
  }
}
