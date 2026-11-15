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
    expect(find.byType(SelectionArea), findsWidgets,
        reason: '正文应允许长按选择具体文字，而非只能复制整页');
    expect(book.chapterIndex.value, 0);
    expect(book.charOffset.value, greaterThanOrEqualTo(0));

    // 点击屏幕中央呼出菜单，顶部出现章节标题入口。
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });
  testWidgets('全书进度拖动使用真实字符位置而不是章节序号', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();
    final book = Book(
      id: 'seek-absolute',
      title: '长度差异',
      author: '本地',
      content: '第一章 长篇\n' +
          List<String>.filled(450, '这是一段很长的正文。').join() +
          '\n第二章 短篇\n结尾',
    );
    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 300));
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    // Call the same slider release callback deterministically. The separate
    // widget test above exercises pointer interaction and menu opening; this
    // assertion verifies the exact offset committed by the release callback.
    final widget = tester.widget<Slider>(slider);
    expect(widget.onChangeEnd, isNotNull);
    widget.onChangeEnd!(0.42);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(book.chapterIndex.value, 0);
    expect(book.charOffset.value, greaterThan(100),
        reason: '全书中段仍处于长第一章，不能跳回第一章开头');
  });

}
