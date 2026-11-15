import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/bookmark_meta_store.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('书签备注与创建时间持久化，移除书签同时清理', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await BookmarkStore.toggle('book-1', 12);
    final metas = await BookmarkMetaStore.load('book-1');
    expect(metas[12], isNotNull);
    expect(metas[12]!.createdAt, greaterThan(0));

    await BookmarkMetaStore.setNote('book-1', 12, '这一句很重要');
    expect((await BookmarkMetaStore.load('book-1'))[12]!.note, '这一句很重要');

    await BookmarkStore.toggle('book-1', 12);
    expect(await BookmarkStore.load('book-1'), isEmpty);
    expect(await BookmarkMetaStore.load('book-1'), isEmpty);
  });

  test('同步替换备注集合不会留下旧条目', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await BookmarkMetaStore.replaceAll('book-2', <int, BookmarkMeta>{
      1: const BookmarkMeta(offset: 1, createdAt: 100, note: '旧'),
      2: const BookmarkMeta(offset: 2, createdAt: 200, note: '新'),
    });
    expect((await BookmarkMetaStore.load('book-2')).length, 2);
    await BookmarkMetaStore.replaceAll('book-2', <int, BookmarkMeta>{
      2: const BookmarkMeta(offset: 2, createdAt: 300, note: '更新'),
    });
    final values = await BookmarkMetaStore.load('book-2');
    expect(values.keys, <int>[2]);
    expect(values[2]!.note, '更新');
  });

  test('书籍标签随元数据往返保存', () {
    final book = Book(
      id: 'b',
      title: '书名',
      author: '作者',
      content: '正文',
      tags: <String>['小说', '收藏', '小说'],
    );
    final restored = Book.fromMeta(book.toMeta(), book.content);
    expect(restored.tags, <String>['小说', '收藏']);
  });
}
