import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/paginator.dart';
import 'package:read/src/services/reader_style_store.dart';
import 'package:read/src/services/reader_text_formatter.dart';

void main() {
  test('paragraph formatting preserves persisted source text and offsets', () {
    const input = '第一段\n第二段\n第三段';
    const style = ReaderStyle(indentCharacters: 2, paragraphBlankLines: 1);
    final formatted = ReaderTextFormatter.format(input, 0, input.length, style);
    expect(formatted, '　　第一段\n\n　　第二段\n\n　　第三段');
    expect(input, '第一段\n第二段\n第三段');
    expect(ReaderTextFormatter.format(input, 3, input.length, style),
        '\n\n　　第二段\n\n　　第三段');
  });

  testWidgets('formatted pages retain exact source coverage', (tester) async {
    final input = List<String>.generate(80, (i) => '第$i段：中文阅读内容和重复文字').join('\n');
    const style = ReaderStyle(indentCharacters: 2, paragraphBlankLines: 1);
    final pages = paginateSlices(input, style.textStyle(), 225, 150,
      formatPage: (source, start, end) =>
          ReaderTextFormatter.format(source, start, end, style));
    expect(pages.length, greaterThan(1));
    expect(pages.map((page) => page.textOf(input)).join(), input);
    for (var i = 1; i < pages.length; i++) {
      expect(pages[i - 1].end, pages[i].start);
    }
  });
}
