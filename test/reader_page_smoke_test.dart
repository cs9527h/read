import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('阅读页按真实正文分页并可显示翻页菜单', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();

    final String body = '第一章 起\n\n${'山雨欲来，整座城都安静下来。' * 400}';
    final Book book = Book(
      id: 'smoke-1',
      title: '测试书',
      author: '测试',
      content: body,
    );

    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 正文已经进入真实分页：至少存在 PageView，且保存了首章位置。
    expect(find.byType(PageView), findsOneWidget);
    expect(book.chapterIndex.value, 0);
    expect(book.charOffset.value, greaterThanOrEqualTo(0));
    // 章节标题只出现一次：标题块渲染后，正文里的重复标题行被移除。
    expect(find.textContaining('第一章 起'), findsOneWidget);

    // 点击屏幕中央呼出菜单，顶部出现章节标题入口。
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });
}
