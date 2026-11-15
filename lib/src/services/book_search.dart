import 'chapter_splitter.dart';

/// Exact offsets are UTF-16 code-unit positions within the original book.
class BookSearchMatch {
  const BookSearchMatch({
    required this.start,
    required this.end,
    required this.chapterIndex,
    required this.snippet,
  });

  final int start;
  final int end;
  final int chapterIndex;
  final String snippet;
}

/// Searches the original text without changing whitespace or chapter offsets.
///
/// Results are ordered by their original positions. Non-overlapping matching
/// avoids showing essentially identical hits for a repeated query.
List<BookSearchMatch> searchBookText(
  String text,
  List<Chapter> chapters,
  String query, {
  int maxResults = 100,
  int contextChars = 24,
}) {
  final term = query.trim();
  if (term.isEmpty || text.isEmpty || chapters.isEmpty || maxResults <= 0) {
    return const <BookSearchMatch>[];
  }
  final results = <BookSearchMatch>[];
  final lowerText = text.toLowerCase();
  final lowerTerm = term.toLowerCase();
  int cursor = 0;
  int chapterIndex = 0;

  while (cursor < lowerText.length && results.length < maxResults) {
    final start = lowerText.indexOf(lowerTerm, cursor);
    if (start < 0) break;
    final end = start + lowerTerm.length;
    // Lowercasing can change length for a few Unicode characters. Only
    // accept a match if its original substring is the same code-unit length.
    // This preserves navigation offsets for the normal Chinese/ASCII case.
    if (end <= text.length &&
        text.substring(start, end).toLowerCase() == lowerTerm) {
      while (chapterIndex + 1 < chapters.length &&
          start >= chapters[chapterIndex].end) {
        chapterIndex++;
      }
      if (start >= chapters[chapterIndex].start &&
          start < chapters[chapterIndex].end) {
        final before = (start - contextChars).clamp(0, text.length);
        final after = (end + contextChars).clamp(0, text.length);
        final snippet = text.substring(before, after).replaceAll(
          RegExp(r'[\r\n\t]+'),
          ' ',
        );
        results.add(BookSearchMatch(
          start: start,
          end: end,
          chapterIndex: chapterIndex,
          snippet: snippet,
        ));
      }
    }
    cursor = end > cursor ? end : cursor + 1;
  }
  return results;
}
