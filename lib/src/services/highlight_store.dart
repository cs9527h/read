import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../database/core_store.dart';

/// Layout-independent highlight/note anchors stored as absolute UTF-16 ranges
/// in the original book text. Unlike page numbers they survive font changes.
class HighlightRecord {
  const HighlightRecord({
    required this.start,
    required this.end,
    required this.color,
    required this.note,
    required this.createdAt,
  });

  final int start;
  final int end;
  final int color;
  final String note;
  final int createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'start': start,
        'end': end,
        'color': color,
        'note': note,
        'created_at': createdAt,
      };

  static HighlightRecord? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final start = raw['start'];
    final end = raw['end'];
    if (start is! int || end is! int || start < 0 || end <= start) return null;
    return HighlightRecord(
      start: start,
      end: end,
      color: (raw['color'] as num?)?.toInt() ?? 0xFFFFF176,
      note: raw['note'] as String? ?? '',
      createdAt: (raw['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

class HighlightStore {
  static const String _prefix = 'read.highlights.v1.';

  static Future<List<HighlightRecord>> load(String bookId) async {
    final CoreStore? core = CoreStore.active;
    if (core != null) {
      try {
        final rows = await core.highlightsOf(bookId);
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$bookId');
    if (raw == null) return <HighlightRecord>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final values = <HighlightRecord>[];
      for (final item in decoded) {
        final record = HighlightRecord.fromJson(item);
        if (record != null) values.add(record);
      }
      values.sort((HighlightRecord a, HighlightRecord b) => a.start.compareTo(b.start));
      return values;
    } catch (_) {
      return <HighlightRecord>[];
    }
  }

  static Future<List<HighlightRecord>> add(
    String bookId,
    HighlightRecord record,
  ) async {
    final values = await load(bookId);
    values.removeWhere((HighlightRecord r) =>
        r.start == record.start && r.end == record.end && r.note == record.note);
    values.add(record);
    values.sort((HighlightRecord a, HighlightRecord b) => a.start.compareTo(b.start));
    await _persist(bookId, values);
    return values;
  }

  static Future<void> remove(String bookId, HighlightRecord record) async {
    final values = await load(bookId);
    values.removeWhere((HighlightRecord r) => r.start == record.start && r.end == record.end);
    await _persist(bookId, values);
  }

  static Future<void> replaceAll(String bookId, List<HighlightRecord> values) =>
      _persist(bookId, values);

  static Future<void> _persist(String bookId, List<HighlightRecord> values) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      '$_prefix$bookId',
      jsonEncode(values.map((HighlightRecord r) => r.toJson()).toList()),
    );
    if (!ok) throw StateError('高亮保存失败');
    final CoreStore? core = CoreStore.active;
    if (core != null) {
      try {
        await core.replaceHighlights(bookId, values);
      } catch (_) {}
    }
  }
}
