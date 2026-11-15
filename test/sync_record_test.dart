import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/sync_record.dart';

SyncRecord record({
  String id = 'same-book',
  String kind = 'progress',
  int rev = 1,
  String device = 'android',
  int updatedAt = 1,
  bool deleted = false,
  Map<String, dynamic> fields = const <String, dynamic>{'offset': 3},
}) => SyncRecord(
  id: id, kind: kind, rev: rev, deviceId: device,
  updatedAt: updatedAt, deleted: deleted, fields: fields,
);

void main() {
  test('Newer revision wins even when device clock moves backwards', () {
    final newer = record(rev: 2, updatedAt: 1);
    final older = record(rev: 1, updatedAt: 99999999, device: 'windows');
    expect(SyncMerger.resolve(newer, older), same(newer));
    expect(SyncMerger.resolve(older, newer), same(newer));
  });

  test('Deletion tombstone wins same revision ties', () {
    final deleted = record(deleted: true, device: 'a');
    final stale = record(device: 'z');
    expect(SyncMerger.resolve(deleted, stale).deleted, isTrue);
    expect(SyncMerger.resolve(stale, deleted).deleted, isTrue);
  });

  test('Tie breaking for progress is independent from argument order', () {
    final a = record(device: 'phone', fields: <String, dynamic>{'offset': 10});
    final b = record(device: 'tablet', fields: <String, dynamic>{'offset': 12});
    final one = SyncMerger.resolve(a, b);
    final two = SyncMerger.resolve(b, a);
    expect(one.deviceId, two.deviceId);
    expect(one.fields, two.fields);
  });

  test('Simultaneously edited notes retain both versions', () {
    final a = record(kind: 'note', device: 'phone',
        fields: <String, dynamic>{'body': 'phone edit'});
    final b = record(kind: 'note', device: 'windows',
        fields: <String, dynamic>{'body': 'desktop edit'});
    final result = SyncMerger.resolve(a, b);
    expect(result.rev, 2);
    final variants = result.fields['_conflict_variants'] as Map;
    expect(variants.length, 2);
    expect((variants['phone'] as Map)['body'], 'phone edit');
    expect((variants['windows'] as Map)['body'], 'desktop edit');
  });

  test('Roundtrip retains stable ID and deletion marker', () {
    final start = record(deleted: true, rev: 4);
    final parsed = SyncRecord.fromJson(start.toJson());
    expect(parsed.encode(), start.encode());
  });

  test('Cross-entity merge refuses data corruption', () {
    expect(() => SyncMerger.resolve(record(id: 'a'), record(id: 'b')),
        throwsArgumentError);
  });
}
