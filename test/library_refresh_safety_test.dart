import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt library metadata never removes currently visible books', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LibraryStore.instance;
    await store.init();
    final book = Book(
      id: 'keep-me',
      title: '本地书籍',
      author: '作者',
      content: '已经导入并且正在阅读',
    );
    store.books.add(book);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'read.library.meta.v1': '{corrupt json',
    });
    await expectLater(store.init(), throwsStateError);
    expect(store.books.length, 1);
    expect(store.books.single.id, 'keep-me');
    expect(store.books.single.content, contains('正在阅读'));
    store.books.clear();
  });
}
