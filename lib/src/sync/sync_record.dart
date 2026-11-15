import 'dart:convert';

/// Immutable sync operation for later WebDAV and Windows transports.
///
/// A local change always bumps rev. The device ID breaks exact revision ties.
/// Tombstones are retained to prevent deleted data from reappearing.
class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.kind,
    required this.rev,
    required this.deviceId,
    required this.updatedAt,
    required this.deleted,
    required this.fields,
  });

  final String id;
  final String kind;
  final int rev;
  final String deviceId;
  final int updatedAt;
  final bool deleted;
  final Map<String, dynamic> fields;

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = json['kind'];
    final rev = json['rev'];
    final deviceId = json['device_id'];
    final updatedAt = json['updated_at'];
    final deleted = json['deleted'];
    final fields = json['fields'];
    if (id is! String || id.isEmpty ||
        kind is! String || kind.isEmpty ||
        rev is! int || rev < 0 ||
        deviceId is! String || deviceId.isEmpty ||
        updatedAt is! int || deleted is! bool ||
        fields is! Map<String, dynamic>) {
      throw const FormatException('无效的同步记录');
    }
    return SyncRecord(
      id: id, kind: kind, rev: rev, deviceId: deviceId,
      updatedAt: updatedAt, deleted: deleted,
      fields: Map<String, dynamic>.unmodifiable(fields),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id, 'kind': kind, 'rev': rev, 'device_id': deviceId,
    'updated_at': updatedAt, 'deleted': deleted, 'fields': fields,
  };

  String encode() => jsonEncode(toJson());

  SyncRecord next(String localDeviceId, int now, Map<String, dynamic> newFields,
      {bool delete = false}) {
    return SyncRecord(
      id: id, kind: kind, rev: rev + 1,
      deviceId: localDeviceId, updatedAt: now,
      deleted: delete, fields: Map<String, dynamic>.unmodifiable(newFields),
    );
  }
}

/// Deterministic, order-independent metadata conflict resolution.
///
/// A tombstone wins same-revision collisions so an existing deletion is
/// never accidentally resurrected. For simultaneous notes, preserve both
/// payloads as separate conflict variants; don't silently discard text.
class SyncMerger {
  static SyncRecord resolve(SyncRecord a, SyncRecord b) {
    if (a.id != b.id || a.kind != b.kind) {
      throw ArgumentError('只能合并相同 id 与 kind 的记录');
    }
    if (a.rev != b.rev) return a.rev > b.rev ? a : b;
    if (a.deleted != b.deleted) return a.deleted ? a : b;
    if (a.deleted && b.deleted) {
      return a.deviceId.compareTo(b.deviceId) >= 0 ? a : b;
    }
    if (a.deviceId == b.deviceId && a.encode() == b.encode()) return a;

    final leftFirst = a.deviceId.compareTo(b.deviceId) <= 0;
    final first = leftFirst ? a : b;
    final second = leftFirst ? b : a;
    if (a.kind == 'note') {
      // Keep each conflicting note revision rather than choosing one text.
      final mergedFields = Map<String, dynamic>.from(first.fields);
      final snapshots = <String, dynamic>{
        first.deviceId: first.fields,
        second.deviceId: second.fields,
      };
      mergedFields['_conflict_variants'] = snapshots;
      return SyncRecord(
        id: first.id, kind: first.kind, rev: first.rev + 1,
        deviceId: 'merge', updatedAt: first.updatedAt > second.updatedAt
            ? first.updatedAt : second.updatedAt,
        deleted: false, fields: mergedFields,
      );
    }
    // Tie-breaking intentionally ignores device wall clock skew.
    return a.deviceId.compareTo(b.deviceId) >= 0 ? a : b;
  }
}
