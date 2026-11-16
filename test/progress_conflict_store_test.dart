import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/progress_conflict_store.dart';
import 'package:read/src/sync/progress_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProgressRecord _record(String device, int offset, int at) => ProgressRecord(
      hash: 'a' * 64,
      format: 'TXT',
      offset: offset,
      page: 0,
      revision: 3,
      device: device,
      updatedAt: at,
      textHash: 'b' * 64,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('询问策略的冲突可持久保存、可移除', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressConflictStore.instance.clear();
    await ProgressConflictStore.instance.put(PendingProgressConflict(
      targetId: 'target',
      bookHash: 'a' * 64,
      title: '测试书',
      local: _record('device-local', 100, 1000),
      remote: _record('device-cloud', 300, 2000),
      createdAt: DateTime(2026, 11, 16),
    ));
    expect(ProgressConflictStore.instance.items.length, 1);
    final saved = ProgressConflictStore.instance.items.single;
    expect(saved.local.device, 'device-local');
    expect(saved.remote.offset, 300);

    await ProgressConflictStore.instance.remove(saved.id);
    expect(ProgressConflictStore.instance.items, isEmpty);
  });
}
