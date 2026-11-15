/// Chapter ranges always refer to the unmodified UTF-16 source string.
class Chapter {
  const Chapter(this.title, this.start, this.length, {this.manual = false});

  final String title;
  final int start;
  final int length;

  /// True when the boundary was added or renamed by the user.
  final bool manual;

  int get end => start + length;

  String slice(String text) => text.substring(start, end);
}

enum ChapterRuleMode { automatic, custom, none }

/// Book-local chapter rules; changing a rule must never rewrite original text.
class ChapterRule {
  const ChapterRule.automatic()
      : mode = ChapterRuleMode.automatic,
        pattern = '';

  const ChapterRule.custom(this.pattern) : mode = ChapterRuleMode.custom;

  const ChapterRule.none()
      : mode = ChapterRuleMode.none,
        pattern = '';

  final ChapterRuleMode mode;
  final String pattern;
}

final RegExp _heading = RegExp(
  r'^[ \t]*(第[ \t]*[0-9零一二三四五六七八九十百千万〇两]+[ \t]*[章回卷节篇集部册]|'
  r'Chapter\s+\d+|CHAPTER\s+\d+|序章|楔子|引言|前言|后记|尾声|番外)\s*[^\n]*$',
  multiLine: true,
);

/// Validate a deliberately constrained, line-anchored regular expression.
///
/// Custom patterns are run against heading-length lines only. To limit
/// pathological backtracking, groups, alternations and backreferences are
/// rejected (this is not a general-purpose regex editor).
RegExp validateChapterPattern(String pattern) {
  if (pattern.isEmpty || pattern.length > 120 || !pattern.startsWith('^')) {
    throw const FormatException('正则必须以 ^ 开头，长度不能超过 120 个字符');
  }
  if (pattern.contains('(') ||
      pattern.contains(')') ||
      pattern.contains('|') ||
      RegExp(r'\\[1-9]').hasMatch(pattern)) {
    throw const FormatException('暂不支持分组、分支和反向引用，请使用简单的章节标题规则');
  }
  final int quantifiers = RegExp(r'[*+?{]').allMatches(pattern).length;
  if (quantifiers > 6) {
    throw const FormatException('正则重复量词过多，请简化表达式');
  }
  // Repeated unbounded wildcards are another common source of backtracking.
  if (pattern.contains('.*.*') || pattern.contains('.+.+')) {
    throw const FormatException('请避免重复的通配符量词');
  }
  try {
    final RegExp result = RegExp(pattern, caseSensitive: false);
    if (result.hasMatch('')) {
      throw const FormatException('规则不能匹配空行');
    }
    return result;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('正则表达式格式错误');
  }
}

class _ChapterHeading {
  const _ChapterHeading(this.position, this.title);

  final int position;
  final String title;
}

/// Splits into contiguous source ranges, including all newlines and prefaces.
///
/// Zero or one recognized headings keeps the entire book in a single chapter.
/// A custom expression is checked against individual lines of <=100 code
/// units, so it cannot accidentally match paragraphs spanning multiple lines.
List<Chapter> splitChapters(
  String text, {
  ChapterRule rule = const ChapterRule.automatic(),
}) {
  if (rule.mode == ChapterRuleMode.none) {
    return <Chapter>[Chapter('全文', 0, text.length)];
  }
  final List<_ChapterHeading> headings = <_ChapterHeading>[];

  if (rule.mode == ChapterRuleMode.automatic) {
    for (final match in _heading.allMatches(text)) {
      final title = match.group(0)!.trim();
      if (title.isNotEmpty && title.length <= 100) {
        headings.add(_ChapterHeading(match.start, title));
      }
    }
  } else {
    final regex = validateChapterPattern(rule.pattern);
    int cursor = 0;
    while (cursor < text.length) {
      final int newline = text.indexOf('\n', cursor);
      final int end = newline < 0 ? text.length : newline;
      // Limit each regex input to a heading-length line.
      if (end - cursor <= 100) {
        final line = text.substring(cursor, end).trimRight();
        if (line.trim().isNotEmpty && regex.hasMatch(line)) {
          headings.add(_ChapterHeading(cursor, line.trim()));
          if (headings.length > 20000) {
            throw const FormatException('匹配章节过多，请缩小规则范围');
          }
        }
      }
      if (newline < 0) break;
      cursor = newline + 1;
    }
  }

  if (headings.length < 2) {
    return <Chapter>[Chapter('全文', 0, text.length)];
  }

  final List<Chapter> chapters = <Chapter>[];
  if (headings.first.position > 0) {
    chapters.add(Chapter('前言', 0, headings.first.position));
  }
  for (int i = 0; i < headings.length; i++) {
    final int start = headings[i].position;
    final int end =
        i + 1 < headings.length ? headings[i + 1].position : text.length;
    chapters.add(Chapter(headings[i].title, start, end - start));
  }
  return chapters;
}
