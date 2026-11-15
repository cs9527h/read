import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reader can advance and return across chapter boundaries', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LibraryStore.instance.init();
    await ReadingStatsStore.instance.init();
    final book = Book(
      id: 'navigation-case',
      title: '章节切换测试',
      author: '作者',
      content: '第一章 起点\n' + List<String>.filled(3, '开始阅读。').join() +
          '\n第二章 继续\n' + List<String>.filled(3, '第二章内容。').join(),
    );
    await tester.pumpWidget(
      MaterialApp(home: ReaderPage(book: book)),
    );
    await tester.pumpAndSettle();
    expect(book.chapterIndex.value, 0);

    await tester.tap(find.byTooltip('下一页或下一章'));
    await tester.pumpAndSettle();
    expect(book.chapterIndex.value, 1);

    await tester.tap(find.byTooltip('上一页或上一章'));
    await tester.pumpAndSettle();
    expect(book.chapterIndex.value, 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}
