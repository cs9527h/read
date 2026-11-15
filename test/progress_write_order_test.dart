import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rapid progress changes end at the newest chapter and character', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LibraryStore.instance;
    await store.init();
    final book = Book(
      id: 'fast-progress',
      title: '进度测试',
      author: '本地',
      content: '第一章\n内容\n第二章\n内容',
    );
    final writes = <Future<void>>[];
    for (int i = 0; i < 30; i++) {
      book.chapterIndex.value = i ~/ 15;
      book.pageIndex.value = i;
      book.charOffset.value = i * 4;
      writes.add(store.saveProgress(book));
    }
    await Future.wait(writes);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('read.progress.fast-progress'), '1:29:116');
  });
}
