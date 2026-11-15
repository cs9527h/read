/// 章节切分：按常见中文标题格式识别章节，返回标题与偏移区间。
class Chapter {
  const Chapter(this.title, this.start, this.length);

  final String title;
  final int start;
  final int length;

  int get end => start + length;

  String slice(String text) => text.substring(start, end);
}

final RegExp _heading = RegExp(
  r'^\s*(第\s*[0-9零一二三四五六七八九十百千万〇两]+\s*[章回卷节篇集部册]|'
  r'Chapter\s+\d+|CHAPTER\s+\d+|序章|楔子|引言|前言|后记|尾声|番外)\s*[^\n]*$',
  multiLine: true,
);

/// 少于两处标题时视为无章节，整本作为一章返回。
List<Chapter> splitChapters(String text) {
  // Avoid interpreting a whole novel paragraph as a chapter title, even if
  // its first characters accidentally match a heading prefix.
  final matches = _heading.allMatches(text)
      .where((match) => match.group(0)!.trim().length <= 100)
      .toList();
  if (matches.length < 2) {
    return <Chapter>[Chapter('全文', 0, text.length)];
  }

  final List<Chapter> chapters = <Chapter>[];
  final int first = matches.first.start;
  if (first > 0) {
    // 标题之前的内容（书名、简介等）单独成章。
    chapters.add(Chapter('前言', 0, first));
  }
  for (int i = 0; i < matches.length; i++) {
    final int start = matches[i].start;
    final int end = (i + 1 < matches.length) ? matches[i + 1].start : text.length;
    chapters.add(Chapter(matches[i].group(0)!.trim(), start, end - start));
  }
  return chapters;
}
