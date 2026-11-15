import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrupt index refresh leaves existing in-memory books untouched', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LibraryStore.instance;
    await store.init();
    final item = Book(
      id: 'recoverable-test',
      title: '仍可阅读',
      author: '本地',
      content: '原始正文',
    );
    store.books.add(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read.library.meta.v1', '{corrupted');
    await expectLater(store.init(), throwsStateError);
    expect(store.books.any((book) => book.id == item.id), isTrue);
    expect(store.books.first.content, '原始正文');
  });
}
