import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读统计：只记录真实发生的阅读时长与推进字数，不编造数据。
///
/// 存储结构：
/// `read.stats.v1` = {
///   "days": { "2026-11-15": {"seconds": 123, "chars": 456} },
///   "books": { "<bookId>": {"seconds": 12, "chars": 34} },
///   "finished": ["<bookId>"]
/// }
class ReadingStatsStore extends ChangeNotifier {
  ReadingStatsStore._();

  static final ReadingStatsStore instance = ReadingStatsStore._();

  static const String _key = 'read.stats.v1';

  SharedPreferences? _prefs;
  Map<String, Map<String, int>> _days = <String, Map<String, int>>{};
  Map<String, Map<String, int>> _books = <String, Map<String, int>>{};
  Set<String> _finished = <String>{};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
      _days = _decode(data['days']);
      _books = _decode(data['books']);
      final List<dynamic> finished = (data['finished'] as List<dynamic>?) ?? <dynamic>[];
      _finished = finished.map((dynamic e) => e.toString()).toSet();
    } catch (_) {
      // 统计数据损坏不应该让书架打不开：忽略坏数据，下次写入重建。
      _days = <String, Map<String, int>>{};
      _books = <String, Map<String, int>>{};
      _finished = <String>{};
    }
    notifyListeners();
  }

  Map<String, Map<String, int>> _decode(Object? raw) {
    if (raw is! Map) return <String, Map<String, int>>{};
    final Map<String, Map<String, int>> out = <String, Map<String, int>>{};
    raw.forEach((Object? key, Object? value) {
      if (value is! Map) return;
      out[key.toString()] = <String, int>{
        'seconds': (value['seconds'] as num?)?.toInt() ?? 0,
        'chars': (value['chars'] as num?)?.toInt() ?? 0,
        'reread': (value['reread'] as num?)?.toInt() ?? 0,
      };
    });
    return out;
  }

  /// 记录一段阅读：秒数与推进的字符数。
  Future<void> record({
    required String bookId,
    required int seconds,
    required int chars,
    int reread = 0,
    DateTime? at,
  }) async {
    if (seconds <= 0 && chars <= 0 && reread <= 0) return;
    final DateTime when = at ?? DateTime.now();
    final String day = _dayKey(when);
    final Map<String, int> dayEntry = _days.putIfAbsent(
      day,
      () => <String, int>{'seconds': 0, 'chars': 0, 'reread': 0},
    );
    dayEntry['seconds'] = dayEntry['seconds']! + seconds;
    dayEntry['chars'] = dayEntry['chars']! + chars;
    dayEntry['reread'] = (dayEntry['reread'] ?? 0) + reread;
    final Map<String, int> bookEntry = _books.putIfAbsent(
      bookId,
      () => <String, int>{'seconds': 0, 'chars': 0, 'reread': 0},
    );
    bookEntry['seconds'] = bookEntry['seconds']! + seconds;
    bookEntry['chars'] = bookEntry['chars']! + chars;
    bookEntry['reread'] = (bookEntry['reread'] ?? 0) + reread;
    await _persist();
    notifyListeners();
  }

  Future<void> markFinished(String bookId) async {
    if (_finished.add(bookId)) {
      await _persist();
      notifyListeners();
    }
  }

  bool isFinished(String bookId) => _finished.contains(bookId);

  Set<String> get finishedBooks => _finished;

  int get totalSeconds => _days.values.fold<int>(
        0,
        (int sum, Map<String, int> e) => sum + (e['seconds'] ?? 0),
      );

  int get totalChars =>
      _days.values.fold<int>(0, (int sum, Map<String, int> e) => sum + (e['chars'] ?? 0));

  /// 重复阅读字数，单独统计，不并入阅读字数。
  int get totalReread =>
      _days.values.fold<int>(0, (int sum, Map<String, int> e) => sum + (e['reread'] ?? 0));

  int get rereadChars =>
      _days.values.fold<int>(0, (int sum, Map<String, int> e) => sum + (e['reread'] ?? 0));

  /// 全部按天的秒数（YYYY-MM-DD → 秒），供统计页按周期过滤。
  Map<String, int> get daySeconds => <String, int>{
        for (final MapEntry<String, Map<String, int>> e in _days.entries)
          e.key: e.value['seconds'] ?? 0,
      };

  Map<String, int> get dayReread => <String, int>{
        for (final MapEntry<String, Map<String, int>> e in _days.entries)
          e.key: e.value['reread'] ?? 0,
      };

  Map<String, int> get dayChars => <String, int>{
        for (final MapEntry<String, Map<String, int>> e in _days.entries)
          e.key: e.value['chars'] ?? 0,
      };

  int get daysCount => _days.values.where((Map<String, int> e) => (e['seconds'] ?? 0) > 0).length;

  int get booksCount => _books.length;

  /// 某本书的累计统计（秒/新字数/重复字数）。
  Map<String, int> bookTotals(String bookId) =>
      _books[bookId] ??
      const <String, int>{'seconds': 0, 'chars': 0, 'reread': 0};

  /// 某一天(YYYY-MM-DD)的秒数。
  int secondsOn(String day) => _days[day]?['seconds'] ?? 0;

  /// 最近 N 天（含今天）每天的秒数，按时间正序。
  List<MapEntry<String, int>> recentDays(int n) {
    final DateTime now = DateTime.now();
    final List<MapEntry<String, int>> out = <MapEntry<String, int>>[];
    for (int i = n - 1; i >= 0; i--) {
      final DateTime day = DateTime(now.year, now.month, now.day - i);
      final String key = _dayKey(day);
      out.add(MapEntry<String, int>(key, secondsOn(key)));
    }
    return out;
  }

  /// 最近 N 天（含今天）的秒数总和。
  int secondsInLastDays(int n) {
    final DateTime now = DateTime.now();
    int sum = 0;
    for (int i = 0; i < n; i++) {
      final DateTime day = DateTime(now.year, now.month, now.day - i);
      sum += secondsOn(_dayKey(day));
    }
    return sum;
  }

  String _dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Future<void> _persist() async {
    await _prefs?.setString(
      _key,
      jsonEncode(<String, dynamic>{
        'days': _days,
        'books': _books,
        'finished': _finished.toList(),
      }),
    );
  }
}
