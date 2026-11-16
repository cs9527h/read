import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/ui/read_icon.dart';
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
    expect(find.byType(SelectableText), findsWidgets,
        reason: '正文应允许长按选择具体文字，而非只能复制整页');
    expect(book.chapterIndex.value, 0);
    expect(book.charOffset.value, greaterThanOrEqualTo(0));

    // 点击屏幕中央呼出菜单，顶部出现章节标题入口。
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 300));
    // 顶栏改用自有图标集（原版/墨水屏两套几何），不再用 Material 图标。
    expect(
      find.byWidgetPredicate(
          (Widget w) => w is ReadIcon && w.glyph == ReadGlyph.search),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
          (Widget w) => w is ReadIcon && w.glyph == ReadGlyph.type),
      findsWidgets,
    );
  });
  testWidgets('章末左滑哨兵页自动进入下一章', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();
    final Book book = Book(
      id: 'chapter-swipe',
      title: '跨章',
      author: '本地',
      content: '第一章 短\n只有一页。\n第二章 短\n下一章正文。',
    );
    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(book.chapterIndex.value, 0);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.childrenDelegate.estimatedChildCount, 2,
        reason: '本章一页 + 下一章首页（预取后为真实正文，不再是过渡卡片）');
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 700));
    expect(book.chapterIndex.value, 1,
        reason: '滑到哨兵页后应自动落到下一章第 1 页');
  });

  testWidgets('滑动跨章后显示下一章标题并且原章标题消失', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();
    final book = Book(
      id: 'neighbor-preview-title',
      title: '跨章预览',
      author: '本地',
      content: '第一章 起点\n第一章正文。\n第二章 远行\n第二章正文。',
    );
    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 700));
    expect(book.chapterIndex.value, 1);
    expect(find.text('第二章 远行'), findsWidgets);
    expect(find.text('第一章 起点'), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets('章首向前翻页进入上一章末页（反向跨章）', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();
    final book = Book(
      id: 'backward-chapter',
      title: '反向跨章',
      author: '本地',
      content: '第一章 短\n第一章正文。\n第二章 短\n第二章正文。',
    );
    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(book.chapterIndex.value, 0);

    // 第一章只有一页，点右侧下一页应自动进入第二章。
    await tester.tapAt(const Offset(750, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(book.chapterIndex.value, 1, reason: '正向翻页应进入下一章');

    // 第二章第一页向前翻，应回到上一章最后一页。
    await tester.tapAt(const Offset(50, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(book.chapterIndex.value, 0, reason: '章首向前应回到上一章');
  });

  testWidgets('快速连续点击翻页不产生控制器冲突或异常', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();
    final book = Book(
      id: 'rapid-tap',
      title: '快速翻页',
      author: '本地',
      content: '第一章 长\n${'快速连续翻页测试正文内容，验证控制器状态一致。' * 120}',
    );
    await tester.pumpWidget(MaterialApp(home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final int initialOffset = book.charOffset.value;

    // 短间隔连续点击下一页 8 次，模拟真实快速翻页。
    for (int i = 0; i < 8; i++) {
      await tester.tapAt(const Offset(750, 300));
      await tester.pump(const Duration(milliseconds: 40));
    }
    // 显式推进让翻页动画与防抖定时器全部走完，不用 pumpAndSettle
    // 避免阅读器内部周期性定时器导致其超时。
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    expect(book.charOffset.value, greaterThan(initialOffset),
        reason: '连续点击后阅读位置应向前推进');
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: '快速连点不得抛出控制器冲突或布局异常');
  });

}
