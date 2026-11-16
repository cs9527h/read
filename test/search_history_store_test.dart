import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = SearchHistoryStore.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store.resetForTesting();
  });

  test('搜索历史按书隔离、最近在前、去重', () async {
    await store.init();
    await store.record('book-A', '第一章');
    await store.record('book-A', '主角');
    await store.record('book-A', '第一章'); // 重复，移至最前且不新增
    await store.record('book-B', '另一本');

    expect(store.historyFor('book-A'), <String>['第一章', '主角']);
    expect(store.historyFor('book-B'), <String>['另一本']);
    expect(store.historyFor('book-C'), isEmpty);
  });

  test('单项删除与全部清除持久化', () async {
    await store.init();
    await store.record('book-A', '甲');
    await store.record('book-A', '乙');
    await store.remove('book-A', '甲');
    expect(store.historyFor('book-A'), <String>['乙']);

    // 模拟重新加载
    store.resetForTesting();
    await store.init();
    expect(store.historyFor('book-A'), <String>['乙']);

    await store.clearAll();
    expect(store.historyFor('book-A'), isEmpty);
    store.resetForTesting();
    await store.init();
    expect(store.historyFor('book-A'), isEmpty);
  });

  test('关闭隐私开关后不再记录，已有历史可清除', () async {
    await store.init();
    await store.record('book-A', '敏感词');
    await store.setEnabled(false);
    await store.record('book-A', '不该记');
    expect(store.historyFor('book-A'), <String>['敏感词']);

    // 设置持久化
    store.resetForTesting();
    await store.init();
    expect(store.enabled, isFalse);
    await store.clear('book-A');
    expect(store.historyFor('book-A'), isEmpty);
  });

  test('容量上限为 20', () async {
    await store.init();
    for (int i = 0; i < 30; i++) {
      await store.record('book-A', '词$i');
    }
    expect(store.historyFor('book-A').length, 20);
    expect(store.historyFor('book-A').first, '词29');
  });
}
