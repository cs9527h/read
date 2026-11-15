import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/progress_models.dart';

ProgressRecord entry(int offset, int revision, String device) =>
    ProgressRecord(
      hash: List<String>.filled(64, 'a').join(),
      format: 'TXT',
      offset: offset,
      page: 0,
      revision: revision,
      device: device,
      updatedAt: 100,
      textHash: List<String>.filled(64, 'b').join(),
    );

void main() {
  test('Progress records serialize and validate strict content hashes', () {
    final item = entry(124, 5, 'phone');
    final encoded = ProgressManifest(<String, ProgressRecord>{
      item.hash: item,
    }).encode();
    final result = ProgressManifest.decode(encoded);
    expect(result.entries[item.hash]!.offset, 124);
    expect(result.entries[item.hash]!.revision, 5);
    expect(() => ProgressManifest.decode('{}'), throwsFormatException);
    expect(
      () => ProgressRecord.fromJson(<String, dynamic>{
        ...item.toJson(), 'text_hash': 'bad',
      }),
      throwsFormatException,
    );
    expect(
      () => ProgressRecord.fromJson(<String, dynamic>{
        ...item.toJson(), 'offset': -1,
      }),
      throwsFormatException,
    );
    expect(
      () => ProgressRecord.fromJson(<String, dynamic>{
        ...item.toJson(), 'hash': '../secrets',
      }),
      throwsFormatException,
    );
    final duplicate = jsonEncode(<String, dynamic>{
      'format': ProgressManifest.format,
      'entries': <Map<String, dynamic>>[item.toJson(), item.toJson()],
    });
    expect(() => ProgressManifest.decode(duplicate), throwsFormatException);
  });

  test('Conflicting edits are not silently overwritten', () {
    expect(
      ProgressMerger.decide(
        local: entry(500, 4, 'phone'),
        remote: entry(600, 5, 'windows'),
        locallyChanged: true,
        baseRevision: 3,
      ),
      ProgressDecision.conflict,
    );
    expect(
      ProgressMerger.decide(
        local: entry(500, 4, 'phone'),
        remote: entry(600, 5, 'windows'),
        locallyChanged: false,
        baseRevision: 3,
      ),
      ProgressDecision.cloud,
    );
    expect(
      ProgressMerger.decide(
        local: entry(500, 4, 'phone'),
        remote: entry(600, 4, 'windows'),
        locallyChanged: true,
        baseRevision: 4,
      ),
      ProgressDecision.local,
    );
  });

  test('Explicit resolution creates a new revision', () {
    final chosen = ProgressMerger.resolved(
      entry(100, 5, 'phone'), entry(200, 6, 'pc'), 'reader-device', 999,
    );
    expect(chosen.offset, 100);
    expect(chosen.revision, 7);
    expect(chosen.updatedAt, 999);
  });
  test('three-way merge protects truly concurrent progress changes', () {
    final baseline = entry(100, 1, 'phone');
    final movedLocally = entry(200, 1, 'phone');
    final movedRemotely = entry(300, 2, 'pc');
    expect(
      ProgressMerger.compareToBaseline(
        local: movedLocally,
        remote: movedRemotely,
        baseline: baseline,
      ),
      ProgressDecision.conflict,
    );
    expect(
      ProgressMerger.compareToBaseline(
        local: baseline,
        remote: movedRemotely,
        baseline: baseline,
      ),
      ProgressDecision.cloud,
    );
    expect(
      ProgressMerger.compareToBaseline(
        local: movedLocally,
        remote: baseline,
        baseline: baseline,
      ),
      ProgressDecision.local,
    );
    expect(
      ProgressMerger.compareToBaseline(
        local: movedLocally,
        remote: movedRemotely,
        baseline: null,
      ),
      ProgressDecision.conflict,
    );
    expect(
      ProgressMerger.compareToBaseline(
        local: movedLocally,
        remote: movedLocally,
        baseline: null,
      ),
      ProgressDecision.cloud,
    );
  });

}
