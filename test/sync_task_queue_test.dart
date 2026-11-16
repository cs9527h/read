import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/sync_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('进度重试任务绑定书籍哈希和目标，且不会丢弃', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SyncHistoryStore.instance.clear();
    await SyncTaskQueue.instance.init();
    await SyncTaskQueue.instance.clear();

    await SyncTaskQueue.instance.enqueue(
      'progress',
      bookHash: 'hash-a',
      targetId: 'target-1',
    );
    await SyncTaskQueue.instance.enqueue(
      'progress',
      bookHash: 'hash-a',
      targetId: 'target-1',
    );
    expect(SyncTaskQueue.instance.tasks.length, 1);

    await SyncTaskQueue.instance.enqueue(
      'progress',
      bookHash: 'hash-b',
      targetId: 'target-1',
    );
    expect(SyncTaskQueue.instance.tasks.length, 2);

    final task = SyncTaskQueue.instance.tasks.first;
    for (var i = 0; i < 8; i++) {
      await SyncTaskQueue.instance.fail(task, '网络超时');
    }
    expect(task.permanentlyFailed, isTrue);
    expect(SyncTaskQueue.instance.tasks.length, 2);
    expect(SyncTaskQueue.instance.nextDue(DateTime.now().add(const Duration(hours: 1))), isNotNull);
    expect(SyncTaskQueue.instance.failedTasks.length, 1);

    await SyncTaskQueue.instance.retry(task);
    expect(task.permanentlyFailed, isFalse);
    expect(task.attempts, 0);
    expect(SyncTaskQueue.instance.failedTasks, isEmpty);

    await SyncTaskQueue.instance.complete(task);
    expect(SyncTaskQueue.instance.tasks.length, 1);
    expect(SyncTaskQueue.instance.tasks.single.bookHash, 'hash-b');
  });
}
