import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_models.dart';

/// A progress conflict that automatic sync refused to resolve silently.
///
/// The local and cloud records are kept verbatim so the user can see device,
/// position and time, then choose one; no local progress is modified until
/// they do.
class PendingProgressConflict {
  const PendingProgressConflict({
    required this.targetId,
    required this.bookHash,
    required this.title,
    required this.local,
    required this.remote,
    required this.createdAt,
  });

  final String targetId;
  final String bookHash;
  final String title;
  final ProgressRecord local;
  final ProgressRecord remote;
  final DateTime createdAt;

  String get id => '$targetId|$bookHash';

  Map<String, Object?> toJson() => <String, Object?>{
        'target_id': targetId,
        'book_hash': bookHash,
        'title': title,
        'local': local.toJson(),
        'remote': remote.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  static PendingProgressConflict? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse(raw['created_at'] as String? ?? '');
    if (at == null) return null;
    try {
      return PendingProgressConflict(
        targetId: raw['target_id'] as String? ?? '',
        bookHash: raw['book_hash'] as String? ?? '',
        title: raw['title'] as String? ?? '未知书籍',
        local: ProgressRecord.fromJson(
            Map<String, dynamic>.from(raw['local'] as Map)),
        remote: ProgressRecord.fromJson(
            Map<String, dynamic>.from(raw['remote'] as Map)),
        createdAt: at,
      );
    } catch (_) {
      return null; // corrupt conflict entries must never crash sync UI
    }
  }
}

class ProgressConflictStore extends ChangeNotifier {
  ProgressConflictStore._();
  static final ProgressConflictStore instance = ProgressConflictStore._();
  static const String _key = 'read.sync.progress.conflicts.v1';

  final Map<String, PendingProgressConflict> _items =
      <String, PendingProgressConflict>{};

  List<PendingProgressConflict> get items =>
      _items.values.toList(growable: false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      for (final item in jsonDecode(raw) as List<dynamic>) {
        final conflict = PendingProgressConflict.fromJson(item);
        if (conflict != null) _items[conflict.id] = conflict;
      }
    } catch (_) {
      _items.clear();
    }
    notifyListeners();
  }

  Future<void> put(PendingProgressConflict conflict) async {
    _items[conflict.id] = conflict;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_items.values.map((PendingProgressConflict c) => c.toJson()).toList()),
    );
  }
}
