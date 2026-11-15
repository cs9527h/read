import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rapid page-turn writes finish with the newest source anchor', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LibraryStore.instance;
    await store.init();
    final book = Book(
      id: 'rapid-progress',
      title: '本地书',
      author: '测试',
      content: '一二三四五六七八九十',
    );
    final writes = <Future<void>>[];
    for (var page = 0; page < 30; page++) {
      book.chapterIndex.value = page ~/ 10;
      book.pageIndex.value = page;
      book.charOffset.value = page * 7;
      writes.add(store.saveProgress(book));
    }
    await Future.wait(writes);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('read.progress.rapid-progress'), '2:29:203');
  });

  test('corrupt bookshelf reload must not remove visible in-memory books', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LibraryStore.instance;
    await store.init();
    final existing = Book(
      id: 'dont-erase',
      title: '不能消失',
      author: '本地',
      content: '原始正文',
    );
    store.books.add(existing);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read.library.meta.v1', '{invalid json');
    await expectLater(store.init(), throwsA(isA<StateError>()));
    expect(store.books.any((book) => book.id == existing.id), isTrue);
    store.books.clear();
  });
}
