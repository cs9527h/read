import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/reader/settings/reader_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReaderSettings settings([
    Map<String, Object?> patch = const <String, Object?>{},
  ]) =>
      ReaderSettings(patch);

  test('显示串保留首行缩进与段落空行，并能映射回原文', () {
    // 显式开启“保留原文空行”验证该能力仍然存在；默认值见下一条测试。
    final ReaderSettings s = settings(<String, Object?>{
      'preserveBlankLines': true,
      'ignoreExtraBlankLines': false,
    });
    final DisplayChapter display =
        ReaderEngine.buildDisplay('第一段\n\n第二段', s, 1.0);
    expect(display.text.startsWith('\u3000\u3000第一段'), isTrue);
    expect(display.text.contains('\n\n'), isTrue);
    expect(display.sourceLength, 8);
    // 显示串第一个缩进空格映射到第一段起点。
    expect(display.sourceOffset(0), 0);
    // 第二段正文起点映射回原文的第 6 个字符（0-based 5）。
    final int secondIndex = display.text.indexOf('第二段');
    expect(secondIndex, greaterThan(0));
    expect(display.sourceOffset(secondIndex), 5);
    final int mapped = display.displayOffset(5);
    expect(mapped, lessThanOrEqualTo(secondIndex));
    expect(display.sourceOffset(mapped), 5);
  });

  test('默认排版忽略原文空行，段间不产生额外留白', () {
    // 中文阅读默认靠首行缩进区分段落；原文空行不再叠加成整页留白。
    final ReaderSettings s = settings();
    final DisplayChapter display =
        ReaderEngine.buildDisplay('第一段\n\n\n第二段', s, 1.0);
    expect(display.text.startsWith('\u3000\u3000第一段'), isTrue);
    expect(display.text.contains('\n\n'), isFalse,
        reason: '默认不应出现连续空行，否则段落间距会过大');
    expect(display.text.contains('\u3000\u3000第二段'), isTrue);
  });

  test('段距按整行生效：0 行无空行，1 行插一行，2 行插两行', () {
    int blankLines(int lines) {
      final DisplayChapter d = ReaderEngine.buildDisplay(
        '甲段\n乙段',
        settings(<String, Object?>{'paragraphSpacingLines': lines.toDouble()}),
        1.0,
      );
      final int yi = d.text.indexOf('乙段');
      // 段尾换行 + 额外空行数
      return '\n'.allMatches(d.text.substring(0, yi)).length - 1;
    }

    expect(blankLines(0), 0);
    expect(blankLines(1), 1);
    expect(blankLines(2), 2);
  });

  test('CRLF 原文不会被当成两个空行，偏移仍然正确', () {
    final ReaderSettings s = settings();
    final DisplayChapter display =
        ReaderEngine.buildDisplay('甲\r\n乙', s, 1.0);
    expect(display.text.contains('\r'), isFalse);
    final int yi = display.text.indexOf('乙');
    expect(display.sourceOffset(yi), 3);
  });

  test('关闭缩进与空行保留时输出更紧凑', () {
    final ReaderSettings s = settings(<String, Object?>{
      'indentMode': 'none',
      'preserveBlankLines': false,
      'paragraphSpacingBefore': 0.0,
      'paragraphSpacingAfter': 0.0,
    });
    final DisplayChapter display =
        ReaderEngine.buildDisplay('一\n\n二', s, 1.0);
    expect(display.text, '一\n二');
  });

  test('真实分页覆盖整段正文且分页连续', () {
    final String body = '山雨欲来的时候，整座城都安静下来。' * 90;
    final ReaderSettings s = settings(<String, Object?>{
      'fontSize': 18.0,
      'lineHeight': 1.8,
      'indentMode': 'fixed',
    });
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '第一章 风起',
      settings: s,
      width: 320,
      height: 520,
      textScale: 1.0,
    );
    expect(result.pages.length, greaterThan(1));
    expect(result.showTitle, isTrue);
    expect(result.titleHeight, greaterThan(0));
    int expected = 0;
    for (final EnginePage page in result.pages) {
      expect(page.displayStart, expected);
      expect(page.displayEnd, greaterThan(page.displayStart));
      expect(page.sourceEnd, greaterThanOrEqualTo(page.sourceStart));
      expected = page.displayEnd;
    }
    expect(expected, result.display.text.length);
    expect(result.pages.last.sourceEnd, result.display.sourceLength);
  });

  test('分页大小与页面高度负相关', () {
    final String body = '测试正文内容。' * 120;
    final ReaderSettings s = settings();
    final PaginatedChapter tall = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '标题',
      settings: s,
      width: 340,
      height: 700,
      textScale: 1.0,
    );
    final PaginatedChapter short = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '标题',
      settings: s,
      width: 340,
      height: 420,
      textScale: 1.0,
    );
    expect(short.pages.length, greaterThan(tall.pages.length));
  });

  test('按原文偏移定位页码', () {
    final String body = '甲' * 2000;
    final ReaderSettings s = settings();
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '',
      settings: s,
      width: 330,
      height: 500,
      textScale: 1.0,
    );
    expect(result.pageForSourceOffset(0), 0);
    expect(
      result.pageForSourceOffset(result.display.sourceLength),
      result.pages.length - 1,
    );
    for (int i = 0; i < result.pages.length; i++) {
      expect(result.pageForSourceOffset(result.pages[i].sourceStart), i);
    }
  });

  test('标题模板 none 时不占高度', () {
    final ReaderSettings s = settings(<String, Object?>{'titleTemplate': 'none'});
    final double height =
        ReaderEngine.titleBlockHeight(s, '第一章', 300, 1.0);
    expect(height, 0);
  });
  test('无章节哨兵标题「全文」不占高度，不画成巨大标题', () {
    final ReaderSettings s = settings();
    expect(ReaderEngine.titleBlockHeight(s, '全文', 300, 1.0), 0);
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: '正文内容。' * 200,
      chapterTitle: '全文',
      settings: s,
      width: 320,
      height: 500,
      textScale: 1.0,
    );
    expect(result.showTitle, isFalse);
    expect(result.titleHeight, 0);
  });
  test('重复映射字符的二分定位使用最早合法原文锚点', () {
    const display = DisplayChapter('abcdef', <int>[0, 0, 1, 2, 2, 3], 4);
    expect(display.displayOffset(-1), 0);
    expect(display.displayOffset(0), 0);
    expect(display.displayOffset(1), 2);
    expect(display.displayOffset(2), 3);
    expect(display.displayOffset(3), 5);
    expect(display.displayOffset(4), 6);
    expect(display.displayOffset(100), 6);
  });

  test('分页偏移二分定位保持边界和尾页语义', () {
    const display = DisplayChapter('abcdef', <int>[0, 1, 2, 3, 4, 5], 6);
    const result = PaginatedChapter(
      display: display,
      titleHeight: 0,
      showTitle: false,
      pages: <EnginePage>[
        EnginePage(displayStart: 0, displayEnd: 2, sourceStart: 0, sourceEnd: 2),
        EnginePage(displayStart: 2, displayEnd: 4, sourceStart: 2, sourceEnd: 4),
        EnginePage(displayStart: 4, displayEnd: 6, sourceStart: 4, sourceEnd: 6),
      ],
    );
    expect(result.pageForSourceOffset(-1), 0);
    expect(result.pageForSourceOffset(0), 0);
    expect(result.pageForSourceOffset(1), 0);
    expect(result.pageForSourceOffset(2), 1);
    expect(result.pageForSourceOffset(4), 2);
    expect(result.pageForSourceOffset(6), 2);
    expect(result.pageForSourceOffset(999), 2);
  });

  test('章节原文首行与标题重复时，正文跳过标题且锚点指向正文', () {
    final ReaderSettings s = settings(<String, Object?>{'indentMode': 'none'});
    final String source = '第一章 风起\n山雨欲来。';
    final DisplayChapter display = ReaderEngine.buildDisplay(
      source,
      s,
      1.0,
      title: '第一章 风起',
    );
    expect(display.text.contains('第一章 风起'), isFalse);
    expect(display.text.trim(), '山雨欲来。');
    final int shan = display.text.indexOf('山');
    expect(shan, greaterThanOrEqualTo(0));
    expect(display.sourceOffset(shan), source.indexOf('山'));
    expect(display.sourceOffset(0), source.indexOf('山'));
  });

  test('标题与原文不匹配时正文不被误删', () {
    final ReaderSettings s = settings(<String, Object?>{'indentMode': 'none'});
    final DisplayChapter display = ReaderEngine.buildDisplay(
      '前言正文。',
      s,
      1.0,
      title: '前言',
    );
    expect(display.text.contains('前言正文'), isTrue);
  });

  test('分页不遗漏、不重复任何正文字符', () {
    final String body =
        '这是一段用于验证分页完整性的中文文本，包含标点，以及English words混合。' * 50;
    final ReaderSettings s = settings(<String, Object?>{
      'fontSize': 16.0,
      'lineHeight': 1.6,
      'indentMode': 'none',
      'paragraphSpacingBefore': 0.0,
      'paragraphSpacingAfter': 0.0,
    });
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '',
      settings: s,
      width: 300,
      height: 480,
      textScale: 1.0,
    );
    final String joined = result.pages.map((EnginePage p) => p.textOf(result.display)).join();
    expect(joined, result.display.text);
    expect(result.pages.last.sourceEnd, result.display.sourceLength);
  });

  test('带重复标题的章节分页后正文不含标题且起始锚点正确', () {
    final String source = '第一章 风起\n${'山雨欲来。' * 100}';
    final ReaderSettings s = settings(<String, Object?>{'indentMode': 'none'});
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: source,
      chapterTitle: '第一章 风起',
      settings: s,
      width: 320,
      height: 500,
      textScale: 1.0,
    );
    final String joined = result.pages.map((EnginePage p) => p.textOf(result.display)).join();
    expect(joined.contains('第一章 风起'), isFalse);
    expect(joined.trim().startsWith('山雨欲来'), isTrue);
    expect(result.pages.first.sourceStart, source.indexOf('山'));
  });

  test('空章节正文返回单个空页而不崩溃', () {
    final ReaderSettings s = settings();
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: '',
      chapterTitle: '空章节',
      settings: s,
      width: 320,
      height: 500,
      textScale: 1.0,
    );
    expect(result.pages.length, 1);
    expect(result.pages.first.displayStart, 0);
    expect(result.pages.first.displayEnd, 0);
  });

  test('超长无换行单行文本也能稳定分页且不漏字', () {
    final String body = '超长单行文本用于验证无段落情况下分页的稳定性与完整性。' * 300;
    final ReaderSettings s = settings(<String, Object?>{
      'fontSize': 18.0,
      'lineHeight': 1.6,
      'indentMode': 'none',
      'paragraphSpacingBefore': 0.0,
      'paragraphSpacingAfter': 0.0,
    });
    final PaginatedChapter result = ReaderEngine.paginate(
      chapterText: body,
      chapterTitle: '',
      settings: s,
      width: 340,
      height: 520,
      textScale: 1.0,
    );
    expect(result.pages.length, greaterThan(1));
    final String joined = result.pages.map((EnginePage p) => p.textOf(result.display)).join();
    expect(joined, result.display.text);
  });

  test('不同字号下分页均保持字符连续，位置按锚点恢复', () {
    final String body = '正文内容用于验证字号变化后的重新分页。' * 120;
    for (final double size in <double>[12, 18, 26, 34]) {
      final ReaderSettings s = settings(<String, Object?>{
        'fontSize': size,
        'indentMode': 'none',
        'paragraphSpacingBefore': 0.0,
        'paragraphSpacingAfter': 0.0,
      });
      final PaginatedChapter result = ReaderEngine.paginate(
        chapterText: body,
        chapterTitle: '',
        settings: s,
        width: 330,
        height: 500,
        textScale: 1.0,
      );
      final String joined = result.pages.map((EnginePage p) => p.textOf(result.display)).join();
      expect(joined, result.display.text, reason: '字号 $size 下分页应不漏不重');
      // 锚点应能定位到非首页。
      final int mid = result.display.sourceLength ~/ 2;
      final int page = result.pageForSourceOffset(mid);
      expect(page, greaterThanOrEqualTo(0));
      expect(result.pages[page].sourceStart, lessThanOrEqualTo(mid));
    }
  });

}
