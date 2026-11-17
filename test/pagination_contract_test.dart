import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/reader/settings/reader_settings.dart';

/// 分页正确性契约测试（任务书 4.3）：
/// 以「规范化后的显示文本」为基准，把一本完整书籍分页后按显示顺序拼接，
/// 验证不多字、不少字、不重复，并覆盖任务书点名的困难排版场景矩阵。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReaderSettings settings(Map<String, Object?> patch) => ReaderSettings(patch);

  /// 核心断言：分页拼接 == 规范化显示文本，且页索引首尾闭合、连续。
  void expectLossless(PaginatedChapter result) {
    final String joined =
        result.pages.map((EnginePage p) => p.textOf(result.display)).join();
    expect(joined, result.display.text,
        reason: '分页拼接后正文必须与规范化显示文本完全一致（不多字/不少字/不重复）');
    if (result.display.text.isNotEmpty) {
      expect(result.pages.first.displayStart, 0);
      expect(result.pages.last.displayEnd, result.display.text.length);
      for (int i = 1; i < result.pages.length; i++) {
        expect(result.pages[i - 1].displayEnd, result.pages[i].displayStart,
            reason: '相邻页 display 索引必须首尾相接，不能重叠或留洞');
      }
    }
  }

  const String longChinese = '山雨欲来风满楼，章节之间文字连绵不绝，'
      '标点、引号「如此」与 English words 混合排版。';
  const String quoteEmoji = '他说：“这是一段📚含 emoji 与「引号」的中文。” Really mixed 文本。';

  final List<Map<String, Object?>> settingMatrix = <Map<String, Object?>>[
    <String, Object?>{'fontSize': 14.0, 'lineHeight': 1.4},
    <String, Object?>{'fontSize': 18.0, 'lineHeight': 1.6},
    <String, Object?>{'fontSize': 26.0, 'lineHeight': 1.9}, // 大字号 + 高行距
    <String, Object?>{'fontSize': 32.0, 'lineHeight': 2.2, 'letterSpacing': 1.5},
    <String, Object?>{'fontSize': 16.0, 'lineHeight': 1.5, 'align': 'justify'},
    <String, Object?>{'fontSize': 16.0, 'indentMode': 'none'},
  ];

  test('中文长篇 + 多字号/行距矩阵：分页无丢字无重复', () {
    final String body = longChinese * 200;
    for (final patch in settingMatrix) {
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: settings(patch),
        width: 360,
        height: 640,
        textScale: 1.0,
      );
      expect(result.pages.length, greaterThan(1), reason: '长文必须分成多页');
      expectLossless(result);
    }
  });

  test('超长单段（无换行）在任意字号下都不漏字', () {
    final String body = List<String>.filled(3000, '阅读').join();
    for (final patch in settingMatrix) {
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: settings(patch),
        width: 320,
        height: 560,
        textScale: 1.0,
      );
      expectLossless(result);
    }
  });

  test('中英混排 + 标点引号 + emoji 分页不切断、不丢失', () {
    final String body = quoteEmoji * 300;
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '',
      settings: settings(<String, Object?>{'fontSize': 19.0}),
      width: 300,
      height: 600,
      textScale: 1.0,
    );
    expectLossless(result);
  });

  test('空行很多的文本在保留/忽略空行两种模式下都不丢字', () {
    final String body = '段落一。\n\n\n段落二。\n\n段落三。' * 120;
    for (final bool preserve in <bool>[true, false]) {
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: settings(<String, Object?>{
          'preserveBlankLines': preserve,
          'ignoreExtraBlankLines': !preserve,
        }),
        width: 340,
        height: 500,
        textScale: 1.0,
      );
      expectLossless(result);
    }
  });

  test('系统大字体 textScale 放大后仍按同一基准无损分页', () {
    final String body = longChinese * 120;
    for (final double scale in <double>[1.0, 1.3, 1.6, 2.0]) {
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: settings(<String, Object?>{'fontSize': 16.0}),
        width: 360,
        height: 640,
        textScale: scale,
      );
      expect(result.pages.length, greaterThan(1));
      expectLossless(result);
    }
  });

  test('横屏与竖屏（不同宽高）切换后各自无损分页', () {
    final String body = longChinese * 150;
    final List<(double, double)> screens = <(double, double)>[
      (360, 780), // 竖屏手机
      (780, 360), // 横屏手机
      (1024, 768), // 平板
    ];
    for (final (double w, double h) in screens) {
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: settings(<String, Object?>{'fontSize': 17.0}),
        width: w,
        height: h,
        textScale: 1.0,
      );
      expectLossless(result);
    }
  });

  test('修改字号后重新分页：位置锚点仍落在新页面对应内容', () {
    final String body = longChinese * 200;
    const String marker = '山雨欲来风满楼';
    final int sourcePos = body.indexOf(marker, body.length ~/ 2);
    for (final double size in <double>[14.0, 22.0, 30.0]) {
      final s = settings(<String, Object?>{'fontSize': size});
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: s,
        width: 360,
        height: 640,
        textScale: 1.0,
      );
      expectLossless(result);
      final int page = result.pageForSourceOffset(sourcePos);
      expect(page, greaterThanOrEqualTo(0));
      expect(page, lessThanOrEqualTo(result.pages.length - 1));
      expect(result.pages[page].sourceStart, lessThanOrEqualTo(sourcePos + 1));
    }
  });
}
