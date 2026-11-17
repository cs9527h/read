import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('read-lazy-');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    LibraryStore.instance.books.clear();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<File> writeBook(String name, String text) async {
    final File file = File('${dir.path}/$name');
    await file.writeAsString(text);
    return file;
  }

  test('启动只读元数据，打开书籍时才解析正文', () async {
    final File file = await writeBook('a.txt', '第一章 开始\n正文内容');
    final Book source = Book(
      id: 'a',
      title: '甲',
      author: '作者',
      format: 'TXT',
      content: '',
      sourcePath: file.path,
      fileName: 'a.txt',
      fileSize: await file.length(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'read.library.meta.v1', jsonEncode(<Object>[source.toMeta()]));

    final LibraryStore store = LibraryStore.instance;
    await store.init();
    expect(store.books.length, 1);
    final Book loaded = store.books.single;
    expect(loaded.content, isEmpty, reason: '启动时不应读取整本书正文');
    expect(loaded.contentError, isNull);

    final bool ready = await store.ensureContent(loaded);
    expect(ready, isTrue);
    expect(loaded.content.contains('正文内容'), isTrue);
    expect(loaded.contentError, isNull);
  });

  test('文件丢失时只标记该书错误，不影响其他书与书架', () async {
    final File good = await writeBook('good.txt', '第一章\n可读内容');
    final Book ok = Book(
      id: 'good',
      title: '好书',
      author: '',
      format: 'TXT',
      content: '',
      sourcePath: good.path,
      fileName: 'good.txt',
    );
    final Book missing = Book(
      id: 'missing',
      title: '丢失书',
      author: '',
      format: 'TXT',
      content: '',
      sourcePath: '${dir.path}/not-here.txt',
      fileName: 'not-here.txt',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read.library.meta.v1',
        jsonEncode(<Object>[ok.toMeta(), missing.toMeta()]));

    final LibraryStore store = LibraryStore.instance;
    await store.init();
    expect(store.books.length, 2);

    final Book broken =
        store.books.firstWhere((Book b) => b.id == 'missing');
    expect(await store.ensureContent(broken), isFalse);
    expect(broken.contentError, contains('丢失'));

    final Book healthy =
        store.books.firstWhere((Book b) => b.id == 'good');
    expect(await store.ensureContent(healthy), isTrue);
    expect(healthy.content, contains('可读内容'));
  });

  test('单条损坏的书目元数据不会让整座书库打不开', () async {
    final File file = await writeBook('b.txt', '第一章\n正文');
    final Map<String, dynamic> valid = Book(
      id: 'ok',
      title: '正常',
      author: '',
      format: 'TXT',
      content: '',
      sourcePath: file.path,
    ).toMeta();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read.library.meta.v1',
        jsonEncode(<Object>[<String, Object?>{'id': 123}, valid]));

    final LibraryStore store = LibraryStore.instance;
    await store.init();
    expect(store.books.length, 1);
    expect(store.books.single.id, 'ok');
  });

  test('500 本书的元数据加载不读取正文，耗时可控', () async {
    final File file = await writeBook('x.txt', '第一章\n正文');
    final List<Map<String, dynamic>> metas = <Map<String, dynamic>>[];
    for (int i = 0; i < 500; i++) {
      metas.add(Book(
        id: 'b$i',
        title: '书 $i',
        author: '作者',
        format: 'TXT',
        content: '',
        sourcePath: file.path,
      ).toMeta());
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read.library.meta.v1', jsonEncode(metas));

    final LibraryStore store = LibraryStore.instance;
    final Stopwatch watch = Stopwatch()..start();
    await store.init();
    watch.stop();
    expect(store.books.length, 500);
    expect(store.books.every((Book b) => b.content.isEmpty), isTrue);
    // 只是元数据解析；若退回逐本读文件，这里会远超阈值。
    expect(watch.elapsedMilliseconds, lessThan(3000),
        reason: '500 本元数据加载耗时 ${watch.elapsedMilliseconds}ms');
  });
}
