// 视觉走查：用 Flutter 框架真实光栅化阅读页 / 书架页，产出审核截图。
// 放到 tool/ 而非 test/，避免 CI 因字体与像素版本差异产生脆弱断言。
// 生成：flutter test tool/visual_review_test.dart --update-goldens
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/bookshelf/bookshelf_page.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadCjkFont() async {
  const String path = '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';
  final File file = File(path);
  if (!file.existsSync()) return;
  final Uint8List bytes = file.readAsBytesSync();
  final FontLoader loader = FontLoader('Roboto')
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

const String _body = '''
第一章 山雨

　　清晨的雾还没散，山道上只有一个人的脚步声。他背着一只旧布包，包里装着两本翻烂了的书和半块干粮。

　　走到半山腰时，雨忽然落了下来。雨点打在树叶上，声音细密，像有人在远处翻动书页。他停下脚步，抬头望了望天，把布包抱在胸前，继续往上走。

　　山顶有一座废弃的亭子。亭柱上的红漆已经剥落，露出灰白的木头。他把包放下，坐在石阶上，掏出那本《山海旧闻》，借着天光读了起来。

　　书页被翻过太多次，边缘已经起了毛。他读到第三页，忽然停住——那一页的空白处，有一行极细的铅笔字，是他自己的笔迹，可他分明记得，这本书是三天前才从旧书摊上买来的。

第二章 旧字

　　雨声渐小。他把书举到眼前，仔细辨认那行字。字迹很轻，像是怕被人看见，又像是写的时候手在抖。

　　那行字只有六个字：不要往西边走。

　　他合上书，看向西边。西边的山脊被云遮着，什么也看不见。可是他知道，翻过那道山脊，就是他要去的村子。
''';

Future<void> _initSettings({String themeId = 'paper'}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'read.reader.settings.global.v2': '{"themeId":"$themeId"}',
  });
  await ReaderSettingsStore.instance.init();
  await UserFontStore.instance.init();
}

void main() {
  testWidgets('阅读页 - 纸白', (tester) async {
    await _loadCjkFont();
    await _initSettings(themeId: 'paper');
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final Book book = Book(id: 'rv', title: '山雨', author: '佚名', content: _body);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/visual_audit/review_reader_paper.png'));
  });

  testWidgets('阅读页 - 米黄', (tester) async {
    await _loadCjkFont();
    await _initSettings(themeId: 'sepia');
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final Book book = Book(id: 'rv', title: '山雨', author: '佚名', content: _body);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/visual_audit/review_reader_sepia.png'));
  });

  testWidgets('阅读页 - 夜间', (tester) async {
    await _loadCjkFont();
    await _initSettings(themeId: 'night');
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final Book book = Book(id: 'rv', title: '山雨', author: '佚名', content: _body);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: ReaderPage(book: book)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/visual_audit/review_reader_night.png'));
  });

  testWidgets('书架页 - 多本封面', (tester) async {
    await _loadCjkFont();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LibraryStore.instance.init();
    final store = LibraryStore.instance;
    store.books
      ..clear()
      ..addAll(<Book>[
        Book(id: 'b1', title: '山雨', author: '佚名', content: '第一章', coverTemplate: 'ink', readingStatus: 'reading'),
        Book(id: 'b2', title: '百年孤独', author: '马尔克斯', content: '第一章', coverTemplate: 'block', pinned: true),
        Book(id: 'b3', title: '活着', author: '余华', content: '第一章', coverTemplate: 'serif'),
        Book(id: 'b4', title: '小王子', author: '圣埃克苏佩里', content: '第一章', coverTemplate: 'grid'),
        Book(id: 'b5', title: '围城', author: '钱钟书', content: '第一章', coverTemplate: 'frame'),
        Book(id: 'b6', title: '深夜记', author: '佚名', content: '第一章', coverTemplate: 'night'),
      ]);
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: const BookshelfPage(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/visual_audit/review_bookshelf.png'));
    store.books.clear();
  });
}
