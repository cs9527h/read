/// Splits a book file name into title and author.
///
/// Book files are commonly named after the pattern "书名 - 作者", "《书名》作者"
/// or "书名 作者：某某". Showing the raw file name as the title makes the
/// bookshelf display "书名 作者：某某" as one string, which the taskbook
/// explicitly forbids. Only the file name is parsed; the book text itself is
/// never modified.
class ParsedBookName {
  const ParsedBookName(this.title, this.author);

  final String title;
  final String? author;
}

final RegExp _bracketNoise = RegExp(
  r'[\[\(（【〔]\s*(?:精校|精排|全本|全集|完整版|校对版|未删节|TXT|txt|EPUB|epub)\s*[\]\)）】〕]',
);
final RegExp _angleTitle = RegExp(r'^《\s*(.+?)\s*》\s*(.*)$');
final RegExp _authorPrefix = RegExp(r'^(?:作者|著者|作\s*者)\s*[:：]\s*');
final RegExp _dashSplit = RegExp(r'\s+[-–—]+\s+|\s*[-–—]{2,}\s*');
final RegExp _parenAuthor = RegExp(
  r'^(.+?)\s*[\(（]\s*(?:作者\s*[:：]?\s*)?([^\(\)（）]{1,30}?)\s*[\)）]\s*$',
);
final RegExp _trailingAuthor = RegExp(
  r'^(.+?)\s+(?:作者\s*[:：]\s*|著\s*[:：]?\s*|by\s+)(.{1,30})$',
  caseSensitive: false,
);

/// Removes a file extension only when it looks like one (1–5 chars, no dots).
String _stripExtension(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  final String ext = name.substring(dot + 1);
  if (ext.isEmpty || ext.length > 5 || ext.contains(' ')) return name;
  return name.substring(0, dot);
}

ParsedBookName parseBookName(String rawFileName) {
  String name = _stripExtension(rawFileName.trim());
  name = name.replaceAll(_bracketNoise, '').trim();
  if (name.isEmpty) return ParsedBookName(rawFileName.trim(), null);

  // 《书名》 作者
  final RegExpMatch? angle = _angleTitle.firstMatch(name);
  if (angle != null) {
    final String title = angle.group(1)!.trim();
    final String rest =
        angle.group(2)!.replaceAll(_authorPrefix, '').trim();
    if (title.isNotEmpty) {
      return ParsedBookName(title, rest.isEmpty ? null : rest);
    }
  }

  // 书名 作者：某某
  final RegExpMatch? trailing = _trailingAuthor.firstMatch(name);
  if (trailing != null) {
    final String title = trailing.group(1)!.trim();
    final String author = trailing.group(2)!.trim();
    if (title.isNotEmpty && author.isNotEmpty) {
      return ParsedBookName(title, author);
    }
  }

  // 书名（作者）
  final RegExpMatch? paren = _parenAuthor.firstMatch(name);
  if (paren != null) {
    final String title = paren.group(1)!.trim();
    final String author = paren.group(2)!.trim();
    if (title.isNotEmpty && author.isNotEmpty && author.length <= 20) {
      return ParsedBookName(title, author);
    }
  }

  // 书名 - 作者
  final List<String> parts = name.split(_dashSplit);
  if (parts.length == 2) {
    final String title = parts.first.trim();
    final String author = parts.last.trim();
    if (title.isNotEmpty && author.isNotEmpty && author.length <= 20) {
      return ParsedBookName(title, author);
    }
  }

  return ParsedBookName(name, null);
}
