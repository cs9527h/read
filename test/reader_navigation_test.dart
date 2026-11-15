import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reader controls cross chapters and saves source position', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LibraryStore.instance.init();
    final book = Book(
      id: 'navigation-test',
      title: '测试文本',
      author: '本地',
      content: '第一章 起点\n内容\n第二章 终点\n结尾',
    );

    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pumpAndSettle();
    expect(find.text('第一章 起点', skipOffstage: false), findsWidgets);

    // Center tap reveals the contextual toolbar, without permanent chrome.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pumpAndSettle();
    // With a tall screen, chapter one fits on a page.
    final next = find.byTooltip('下一页');
    expect(next, findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(book.chapterIndex.value, 1);
    expect(find.text('第二章 终点', skipOffstage: false), findsWidgets);

    await tester.tap(find.byTooltip('上一页'));
    await tester.pumpAndSettle();
    expect(book.chapterIndex.value, 0);
    expect(book.charOffset.value, greaterThanOrEqualTo(0));
  });
}
