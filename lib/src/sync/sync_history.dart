import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/core_store.dart';
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
    this.errorType = '',
    this.suggestion = '',
  });

  final DateTime at;
  final String kind; // full | progress | backup | restore | test
  final String status; // success | failed | conflict | skipped
  final String message;
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final String device;
  /// Stable failure category (auth/timeout/rate_limit/…) and next step.
  final String errorType;
  final String suggestion;

  Map<String, Object?> toJson() => <String, Object?>{
        'at': at.toIso8601String(),
        'kind': kind,
        'status': status,
        'message': message,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'conflicts': conflicts,
        'device': device,
        'error_type': errorType,
        'suggestion': suggestion,
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
      errorType: raw['error_type'] as String? ?? '',
      suggestion: raw['suggestion'] as String? ?? '',
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
    this.bookHash = '',
    this.targetId = '',
    this.permanentlyFailed = false,
  });

  factory PendingSyncTask.fromJson(Map<String, dynamic> json) => PendingSyncTask(
        kind: json['kind'] as String? ?? 'full',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        nextAt:
            DateTime.tryParse(json['next_at'] as String? ?? '') ?? DateTime.now(),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['last_error'] as String? ?? '',
        bookHash: json['book_hash'] as String? ?? '',
        targetId: json['target_id'] as String? ?? '',
        permanentlyFailed: json['permanently_failed'] == true,
      );

  final String kind;
  final DateTime createdAt;
  DateTime nextAt;
  int attempts;
  String lastError;

  /// The exact book this task belongs to. Progress retries must never fall
  /// back to "the first book in the library".
  String bookHash;
  String targetId;
  bool permanentlyFailed;

  String get key => '$kind|$bookHash|$targetId';

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'created_at': createdAt.toIso8601String(),
        'next_at': nextAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
        'book_hash': bookHash,
        'target_id': targetId,
        'permanently_failed': permanentlyFailed,
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

  Future<void> enqueue(
    String kind, {
    String bookHash = '',
    String targetId = '',
  }) async {
    // Coalesce only the exact same operation; different books stay separate.
    final key = '$kind|$bookHash|$targetId';
    if (_tasks.any((PendingSyncTask t) => t.key == key)) return;
    _tasks.add(PendingSyncTask(
      kind: kind,
      createdAt: DateTime.now(),
      nextAt: DateTime.now(),
      bookHash: bookHash,
      targetId: targetId,
    ));
    await _persist();
    notifyListeners();
  }

  PendingSyncTask? nextDue(DateTime now) {
    final due = _tasks.where((PendingSyncTask t) =>
        !t.permanentlyFailed && !t.nextAt.isAfter(now));
    if (due.isEmpty) return null;
    return due.reduce((PendingSyncTask a, PendingSyncTask b) =>
        a.nextAt.isBefore(b.nextAt) ? a : b);
  }

  Future<void> complete(PendingSyncTask task) async {
    _tasks.removeWhere((PendingSyncTask t) => t.key == task.key);
    await _persist();
    notifyListeners();
  }

  Future<void> fail(PendingSyncTask task, String error) async {
    task.attempts++;
    task.lastError = error.length > 300 ? error.substring(0, 300) : error;
    final seconds = 1 << (task.attempts.clamp(1, 6)); // 2s … 64s
    task.nextAt = DateTime.now().add(Duration(seconds: seconds));
    if (task.attempts >= 8) {
      // Never silently discard a failure: keep it as a durable dead letter
      // until the user retries or clears it.
      task.permanentlyFailed = true;
      await SyncHistoryStore.instance.add(SyncHistoryEntry(
        at: DateTime.now(),
        kind: task.kind,
        status: 'failed',
        message: '重试 8 次仍失败，已保留任务：${task.bookHash.isEmpty ? task.kind : task.bookHash}'
            ' · ${task.lastError}',
      ));
    }
    await _persist();
    notifyListeners();
  }

  Future<void> retry(PendingSyncTask task) async {
    task
      ..attempts = 0
      ..permanentlyFailed = false
      ..lastError = ''
      ..nextAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  List<PendingSyncTask> get failedTasks =>
      _tasks.where((PendingSyncTask t) => t.permanentlyFailed).toList();

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
    // 镜像到 SQLite，进程被杀后仍可继续处理；JSON 键保留作为回滚路径。
    final CoreStore? core = CoreStore.active;
    if (core == null) return;
    try {
      await core.replaceQueueTasks(_tasks
          .map((PendingSyncTask task) => QueueSnapshot(
                id: task.key,
                kind: task.kind,
                bookId: task.bookHash,
                attempts: task.attempts,
                nextAttemptMs: task.nextAt.millisecondsSinceEpoch,
                state: task.permanentlyFailed ? 'failed' : 'pending',
                lastError: task.lastError,
              ))
          .toList());
    } catch (_) {}
  }
}
