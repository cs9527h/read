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
    final ReaderSettings s = settings();
    final DisplayChapter display =
        ReaderEngine.buildDisplay('第一段\n\n第二段', s, 1.0);
    expect(display.text.startsWith('  第一段'), isTrue);
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

}
