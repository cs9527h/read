import 'chapter_splitter.dart';

/// Stable bridge between layout-dependent chapters and source-text offsets.
///
/// The source text is never rewritten. This works with automatic, no-chapter,
/// and per-book custom chapter rules and survives changes in font/page width.
class ReadingAnchor {
  const ReadingAnchor({
    required this.chapterIndex,
    required this.chapterOffset,
    required this.absoluteOffset,
  });

  final int chapterIndex;
  final int chapterOffset;
  final int absoluteOffset;

  static ReadingAnchor fromChapter({
    required List<Chapter> chapters,
    required int chapterIndex,
    required int chapterOffset,
  }) {
    if (chapters.isEmpty) throw ArgumentError('章节列表不能为空');
    final index = chapterIndex.clamp(0, chapters.length - 1);
    final chapter = chapters[index];
    final local = chapterOffset.clamp(0, chapter.length);
    return ReadingAnchor(
      chapterIndex: index,
      chapterOffset: local,
      absoluteOffset: chapter.start + local,
    );
  }

  static ReadingAnchor fromAbsolute({
    required List<Chapter> chapters,
    required int absoluteOffset,
  }) {
    if (chapters.isEmpty) throw ArgumentError('章节列表不能为空');
    final end = chapters.last.end;
    final target = absoluteOffset.clamp(0, end);
    int index = chapters.length - 1;
    // Chapters are sorted and non-overlapping, including prefatory text.
    int low = 0;
    int high = chapters.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (target < chapters[mid].start) {
        high = mid - 1;
      } else if (target >= chapters[mid].end && mid < chapters.length - 1) {
        low = mid + 1;
      } else {
        index = mid;
        break;
      }
    }
    final chapter = chapters[index];
    return ReadingAnchor(
      chapterIndex: index,
      chapterOffset: (target - chapter.start).clamp(0, chapter.length),
      absoluteOffset: target,
    );
  }
}
