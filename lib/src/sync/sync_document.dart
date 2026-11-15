import 'dart:convert';

import 'sync_record.dart';

/// Versioned, encrypted sync document containing record-level metadata,
/// bookmarks and optionally reader settings. Reading progress stays in its
/// own fast document so a page turn never uploads the whole library.
class SyncDocument {
  const SyncDocument({
    required this.deviceId,
    required this.createdAt,
    required this.records,
  });

  static const String format = 'read-sync-doc-v2';
  static const int maxDocumentBytes = 8 * 1024 * 1024;
  static const int maxRecords = 20000;

  final String deviceId;
  final DateTime createdAt;
  final Map<String, SyncRecord> records;

  factory SyncDocument.empty(String deviceId) => SyncDocument(
        deviceId: deviceId,
        createdAt: DateTime.now(),
        records: <String, SyncRecord>{},
      );

  factory SyncDocument.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('不是受支持的 Read 同步文档');
    }
    final deviceId = json['device_id'];
    final createdAt = json['created_at'];
    final rawRecords = json['records'];
    if (deviceId is! String || deviceId.isEmpty ||
        createdAt is! String || rawRecords is! List) {
      throw const FormatException('同步文档结构不完整');
    }
    if (rawRecords.length > maxRecords) {
      throw const FormatException('同步记录超过安全上限');
    }
    final records = <String, SyncRecord>{};
    for (final raw in rawRecords) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('同步记录类型非法');
      }
      final record = SyncRecord.fromJson(raw);
      if (record.id.length > 240) {
        throw const FormatException('同步记录 id 过长');
      }
      if (records.containsKey(record.id)) {
        throw const FormatException('同步记录 id 重复');
      }
      records[record.id] = record;
    }
    return SyncDocument(
      deviceId: deviceId,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      records: records,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': format,
        'device_id': deviceId,
        'created_at': createdAt.toUtc().toIso8601String(),
        'records': records.values.map((SyncRecord r) => r.toJson()).toList(),
      };

  String encode() {
    final value = jsonEncode(toJson());
    if (utf8.encode(value).length > maxDocumentBytes) {
      throw const FormatException('同步文档超过 8MB 上限');
    }
    return value;
  }
}

class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.kind,
    required this.localDevice,
    required this.remoteDevice,
  });

  final String id;
  final String kind;
  final String localDevice;
  final String remoteDevice;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'local_device': localDevice,
        'remote_device': remoteDevice,
      };
}

class SyncMergeResult {
  const SyncMergeResult({
    required this.document,
    required this.conflicts,
    required this.changed,
    required this.localWon,
    required this.remoteWon,
  });

  final SyncDocument document;
  final List<SyncConflict> conflicts;
  final bool changed;
  final int localWon;
  final int remoteWon;
}

/// Three-way record merge. A missing local record compared with a baseline
/// becomes a tombstone (never a silent resurrection when remote still has it).
class SyncDocumentMerger {
  static SyncMergeResult merge({
    required SyncDocument local,
    required SyncDocument? remote,
    required SyncDocument? baseline,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = <String, SyncRecord>{};
    final conflicts = <SyncConflict>[];
    var changed = false;
    var localWon = 0;
    var remoteWon = 0;

    final ids = <String>{
      ...local.records.keys,
      if (remote != null) ...remote.records.keys,
      if (baseline != null) ...baseline.records.keys,
    };

    bool same(SyncRecord? a, SyncRecord? b) {
      if (a == null || b == null) return a == null && b == null;
      return a.deleted == b.deleted &&
          const DeepCollectionEquality().equals(a.fields, b.fields);
    }

    for (final id in ids) {
      final l = local.records[id];
      final r = remote?.records[id];
      final b = baseline?.records[id];

      if (l == null) {
        if (r != null) {
          result[id] = r;
          changed = true;
          remoteWon++;
        } else if (b != null) {
          // Local deletion with an older remote snapshot that lacks a tombstone.
          result[id] = b.next(local.deviceId, now, const <String, dynamic>{},
              delete: true);
          changed = true;
        }
        continue;
      }
      if (r == null) {
        if (b != null && !l.deleted) {
          // Do not guess that a record absent from remote means deletion; keep
          // the local record so an interrupted upload cannot erase data.
          result[id] = l;
        } else {
          result[id] = l;
        }
        continue;
      }

      final localChanged = !same(l, b);
      final remoteChanged = !same(r, b);
      if (localChanged && remoteChanged && !same(l, r)) {
        conflicts.add(SyncConflict(
          id: id,
          kind: l.kind,
          localDevice: l.deviceId,
          remoteDevice: r.deviceId,
        ));
        final chosen = SyncMerger.resolve(l, r);
        result[id] = chosen;
        if (chosen.deviceId == l.deviceId && chosen.fields == l.fields) {
          localWon++;
        } else {
          remoteWon++;
        }
        changed = true;
        continue;
      }

      final chosen = SyncMerger.resolve(l, r);
      result[id] = chosen;
      if (!same(chosen, b)) changed = true;
      if (chosen.deviceId == l.deviceId && chosen.rev == l.rev) {
        localWon++;
      } else if (chosen.deviceId == r.deviceId && chosen.rev == r.rev) {
        remoteWon++;
      }
    }

    return SyncMergeResult(
      document: SyncDocument(
        deviceId: local.deviceId,
        createdAt: DateTime.now(),
        records: Map<String, SyncRecord>.unmodifiable(result),
      ),
      conflicts: conflicts,
      changed: changed ||
          remote == null ||
          remote.records.length != result.length,
      localWon: localWon,
      remoteWon: remoteWon,
    );
  }
}

/// Deep equality without adding a dependency to the app's public API.
class DeepCollectionEquality {
  const DeepCollectionEquality();

  bool equals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !equals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!equals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
