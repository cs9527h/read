// 本文件是从 test/ 移出的渲染审核脚本。放在 tool/ 是为了避免 CI 的
// 像素断言受字体版本影响，但它仍然使用 flutter_test 的测试专用 API。
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用 Flutter 框架真实光栅化阅读页，作为排版审核依据（不是设计稿）。
/// 生成：flutter test tool/render_audit_test.dart --update-goldens
/// 图片输出到 docs/visual_audit/reader_page.png。
/// 放在 tool/ 而不是 test/，避免 CI 因字体版本差异产生像素断言失败。
Future<void> _loadCjkFont() async {
  const String path =
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';
  final File file = File(path);
  if (!file.existsSync()) return;
  final Uint8List bytes = file.readAsBytesSync();
  // 覆盖测试环境默认的 Roboto，使中文不会渲染成方块。
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

void main() {
  testWidgets('阅读页真实渲染审核', (WidgetTester tester) async {
    await _loadCjkFont();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
    await UserFontStore.instance.init();

    // 412 × 915 逻辑像素，接近常见手机；2 倍密度便于观察字形。
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final Book book = Book(
      id: 'render-audit',
      title: '山雨',
      author: '佚名',
      content: _body,
    );
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ReaderPage(book: book),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/visual_audit/reader_page.png'),
    );
  });
}
