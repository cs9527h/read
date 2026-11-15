import 'reader_style_store.dart';

/// Format a rendered slice without modifying the stored source or its anchor.
/// The result can be larger than the original because indentation and visual
/// paragraph spacing are presentation features, not imported book content.
class ReaderTextFormatter {
  const ReaderTextFormatter._();

  static String format(String source, int start, int end, ReaderStyle style) {
    if (start < 0 || end < start || end > source.length) {
      throw RangeError.range(end, start, source.length);
    }
    if (start == end) return '';
    if (style.indentCharacters == 0 && style.paragraphBlankLines == 0) {
      return source.substring(start, end);
    }
    final out = StringBuffer();
    final indent = List<String>.filled(style.indentCharacters, '\u3000').join();
    var atParagraphStart = start == 0 ||
        source.codeUnitAt(start - 1) == 0x0A;
    for (var i = start; i < end; i++) {
      final unit = source.codeUnitAt(i);
      if (atParagraphStart && unit != 0x0A && unit != 0x0D) {
        out.write(indent);
        atParagraphStart = false;
      }
      out.writeCharCode(unit);
      if (unit == 0x0A) {
        if (style.paragraphBlankLines > 0 &&
            i + 1 < source.length &&
            source.codeUnitAt(i + 1) != 0x0A) {
          out.write(List<String>.filled(style.paragraphBlankLines, '\n').join());
        }
        atParagraphStart = true;
      }
    }
    return out.toString();
  }
}
