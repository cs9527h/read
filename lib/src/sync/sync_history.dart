import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_document.dart';

class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.at,
    required this.kind,
    required this.status,
    required this.message,
    this.uploaded = 0,
    this.downloaded = 0,
    this.conflicts = 0,
    this.device = '',
  });

  final DateTime at;
  final String kind; // full | progress | backup | restore | test
  final String status; // success | failed | conflict | skipped
  final String message;
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final String device;

  Map<String, Object?> toJson() => <String, Object?>{
        'at': at.toIso8601String(),
        'kind': kind,
        'status': status,
        'message': message,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'conflicts': conflicts,
        'device': device,
      };

  static SyncHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse(raw['at'] as String? ?? '');
    if (at == null) return null;
    return SyncHistoryEntry(
      at: at,
      kind: raw['kind'] as String? ?? 'full',
      status: raw['status'] as String? ?? 'failed',
      message: raw['message'] as String? ?? '',
      uploaded: (raw['uploaded'] as num?)?.toInt() ?? 0,
      downloaded: (raw['downloaded'] as num?)?.toInt() ?? 0,
      conflicts: (raw['conflicts'] as num?)?.toInt() ?? 0,
      device: raw['device'] as String? ?? '',
    );
  }
}

class SyncHistoryStore extends ChangeNotifier {
  SyncHistoryStore._();
  static final SyncHistoryStore instance = SyncHistoryStore._();
  static const String _key = 'read.sync.history.v2';

  final List<SyncHistoryEntry> _entries = <SyncHistoryEntry>[];
  List<SyncHistoryEntry> get entries => List<SyncHistoryEntry>.unmodifiable(_entries);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final entry = SyncHistoryEntry.fromJson(item);
        if (entry != null) _entries.add(entry);
      }
    } catch (_) {
      // A broken history must not block sync; keep an empty auditable list.
    }
    notifyListeners();
  }

  Future<void> add(SyncHistoryEntry entry) async {
    _entries.insert(0, entry);
    if (_entries.length > 120) _entries.removeRange(120, _entries.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_entries.map((SyncHistoryEntry e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}

/// Last accepted cloud document. It is stored per remote target so switching
/// providers cannot turn old data into fake deletions.
class SyncBaselineStore {
  static const String _prefix = 'read.sync.baseline.v2.';

  static String targetId({
    required String provider,
    required String endpoint,
    required String directory,
  }) =>
      sha256.convert(utf8.encode('$provider|$endpoint|$directory')).toString();

  Future<SyncDocument?> load(String targetId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$targetId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SyncDocument.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String targetId, SyncDocument document) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$targetId', document.encode());
  }

  Future<void> clear(String targetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$targetId');
  }
}

class PendingSyncTask {
  PendingSyncTask({
    required this.kind,
    required this.createdAt,
    required this.nextAt,
    this.attempts = 0,
    this.lastError = '',
  });

  factory PendingSyncTask.fromJson(Map<String, dynamic> json) => PendingSyncTask(
        kind: json['kind'] as String? ?? 'full',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        nextAt:
            DateTime.tryParse(json['next_at'] as String? ?? '') ?? DateTime.now(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['last_error'] as String? ?? '',
      );

  final String kind;
  final DateTime createdAt;
  DateTime nextAt;
  int attempts;
  String lastError;

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'created_at': createdAt.toIso8601String(),
        'next_at': nextAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
      };
}

/// Durable operation queue. Progress and metadata are separate kinds so a
/// quick page-turn push never waits behind a slow multi-megabyte backup.
class SyncTaskQueue extends ChangeNotifier {
  SyncTaskQueue._();
  static final SyncTaskQueue instance = SyncTaskQueue._();
  static const String _key = 'read.sync.queue.v2';

  final List<PendingSyncTask> _tasks = <PendingSyncTask>[];
  List<PendingSyncTask> get tasks => List<PendingSyncTask>.unmodifiable(_tasks);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        for (final item in jsonDecode(raw) as List<dynamic>) {
          if (item is Map<String, dynamic>) _tasks.add(PendingSyncTask.fromJson(item));
        }
      } catch (_) {
        _tasks.clear();
      }
    }
    notifyListeners();
  }

  Future<void> enqueue(String kind) async {
    // Coalesce repeated notifications into one pending operation per kind.
    if (_tasks.any((PendingSyncTask t) => t.kind == kind)) return;
    _tasks.add(PendingSyncTask(
      kind: kind,
      createdAt: DateTime.now(),
      nextAt: DateTime.now(),
    ));
    await _persist();
    notifyListeners();
  }

  PendingSyncTask? nextDue(DateTime now) {
    final due = _tasks.where((PendingSyncTask t) => !t.nextAt.isAfter(now));
    if (due.isEmpty) return null;
    return due.reduce((PendingSyncTask a, PendingSyncTask b) =>
        a.nextAt.isBefore(b.nextAt) ? a : b);
  }

  Future<void> complete(PendingSyncTask task) async {
    _tasks.removeWhere((PendingSyncTask t) => t.kind == task.kind);
    await _persist();
    notifyListeners();
  }

  Future<void> fail(PendingSyncTask task, String error) async {
    task.attempts++;
    task.lastError = error.length > 300 ? error.substring(0, 300) : error;
    final seconds = 1 << (task.attempts.clamp(1, 6)); // 2s … 64s
    task.nextAt = DateTime.now().add(Duration(seconds: seconds));
    if (task.attempts >= 8) {
      _tasks.removeWhere((PendingSyncTask t) => t.kind == task.kind);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _tasks.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_tasks.map((PendingSyncTask t) => t.toJson()).toList()),
    );
  }
}
