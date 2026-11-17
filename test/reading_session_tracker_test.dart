import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/reading_session_tracker.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('前进只算新内容，回看只算重复阅读，不虚增字数', () {
    final DateTime t0 = DateTime(2026, 1, 1, 10);
    final ReadingSessionTracker tracker = ReadingSessionTracker(now: t0);
    tracker.recordPosition(0, at: t0);
    tracker.recordPosition(100, at: t0.add(const Duration(seconds: 5)));
    var delta = tracker.drain();
    expect(delta.newChars, 100);
    expect(delta.rereadChars, 0);

    // 往回翻 40 字：这是回看，不是“又读了 40 字”。
    tracker.recordPosition(60, at: t0.add(const Duration(seconds: 10)));
    delta = tracker.drain();
    expect(delta.newChars, 0);
    expect(delta.rereadChars, 40);

    // 再回到 100：仍是已读区间内。
    tracker.recordPosition(100, at: t0.add(const Duration(seconds: 15)));
    delta = tracker.drain();
    expect(delta.newChars, 0);
    expect(delta.rereadChars, 40);

    // 越过最远位置后的 50 字才是新内容。
    tracker.recordPosition(150, at: t0.add(const Duration(seconds: 20)));
    delta = tracker.drain();
    expect(delta.newChars, 50);
    expect(delta.rereadChars, 0);
  });

  test('部分前进部分新读时按分界拆分', () {
    final ReadingSessionTracker tracker =
        ReadingSessionTracker(now: DateTime(2026, 1, 1));
    tracker.recordPosition(0);
    tracker.recordPosition(100);
    tracker.drain();
    // 从 100 走到 160：100~100 无重复，100~160 全新。
    tracker.recordPosition(160);
    var delta = tracker.drain();
    expect(delta.newChars, 60);
    expect(delta.rereadChars, 0);

    tracker.recordPosition(60); // 回看
    // 60→160 全部在已读区间（重复 100），160→200 才是新内容 40。
    tracker.recordPosition(200);
    delta = tracker.drain();
    expect(delta.newChars, 40);
    expect(delta.rereadChars, 200);
  });

  test('目录跳转不算阅读，跳转后继续阅读正常计数', () {
    final ReadingSessionTracker tracker =
        ReadingSessionTracker(now: DateTime(2026, 1, 1));
    tracker.recordPosition(100);
    tracker.drain();
    tracker.jumpTo(50000);
    var delta = tracker.drain();
    expect(delta.newChars, 0);
    expect(delta.rereadChars, 0);
    tracker.recordPosition(50010);
    delta = tracker.drain();
    expect(delta.newChars, 10);
  });

  test('长时间无操作与后台不再累计时长', () {
    final DateTime t0 = DateTime(2026, 1, 1, 10);
    final ReadingSessionTracker tracker =
        ReadingSessionTracker(now: t0, idleLimit: const Duration(minutes: 2));
    tracker.tick(active: true, at: t0.add(const Duration(seconds: 10)));
    expect(tracker.drain().seconds, 10);

    // 5 分钟没有翻页/点击：这一段不算阅读时长。
    tracker.tick(active: true, at: t0.add(const Duration(minutes: 5)));
    expect(tracker.drain().seconds, 0);

    // 用户回来翻页，恢复计时。
    tracker.markActivity(t0.add(const Duration(minutes: 5, seconds: 1)));
    tracker.tick(
        active: true, at: t0.add(const Duration(minutes: 5, seconds: 11)));
    expect(tracker.drain().seconds, 10);

    // 应用在后台：即使有 tick 也不计时。
    tracker.markActivity(t0.add(const Duration(minutes: 6)));
    tracker.tick(active: false,
        at: t0.add(const Duration(minutes: 6, seconds: 10)));
    expect(tracker.drain().seconds, 0);
  });

  test('系统休眠造成的异常间隔被忽略', () {
    final DateTime t0 = DateTime(2026, 1, 1, 10);
    final ReadingSessionTracker tracker = ReadingSessionTracker(now: t0);
    tracker.markActivity(t0);
    tracker.tick(active: true, at: t0.add(const Duration(minutes: 30)));
    expect(tracker.drain().seconds, 0);
  });

  test('统计存储分别累计新字数与重复字数', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ReadingStatsStore store = ReadingStatsStore.instance;
    await store.init();
    final DateTime day = DateTime(2026, 3, 1, 12);
    await store.record(bookId: 'b1', seconds: 60, chars: 800, reread: 200, at: day);
    expect(store.totalChars, 800);
    expect(store.totalReread, 200);
    expect(store.bookTotals('b1')['chars'], 800);
    expect(store.bookTotals('b1')['reread'], 200);
    expect(store.dayReread['2026-03-01'], 200);
  });
}
