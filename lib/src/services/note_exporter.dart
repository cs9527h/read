import 'package:read/src/services/bookmark_meta_store.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/highlight_store.dart';

/// 把一本书的高亮/划线与书签笔记导出为可分享的 Markdown（模块 15）。
///
/// 纯函数：输入原文 + 分章 + 记录，输出文本。不做 IO、不碰平台通道，便于单测。
/// 锚点是原文绝对 UTF-16 偏移，导出时切片并标注所属章节，排版变化不影响。
class NoteExporter {
  const NoteExporter._();

  /// 返回 offset 所在章节下标（找不到返回 -1）。
  static int _chapterIndexFor(List<Chapter> chapters, int offset) {
    for (int i = 0; i < chapters.length; i++) {
      if (offset >= chapters[i].start && offset < chapters[i].end) return i;
    }
    return chapters.isEmpty ? -1 : chapters.length - 1;
  }

  static String _safeSlice(String content, int start, int end) {
    if (start < 0 || end <= start || content.isEmpty) return '';
    final int s = start.clamp(0, content.length);
    final int e = end.clamp(0, content.length);
    if (e <= s) return '';
    return content.substring(s, e).trim().replaceAll('\n', ' ');
  }

  static String _stamp(int ms) {
    if (ms <= 0) return '';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// 导出高亮/划线。按原文位置排序，同章聚合。
  static String exportHighlights({
    required String title,
    required String author,
    required String content,
    required List<Chapter> chapters,
    required List<HighlightRecord> highlights,
  }) {
    final StringBuffer buf = StringBuffer();
    buf.writeln('# 《$title》划线与笔记');
    if (author.trim().isNotEmpty) buf.writeln();
    if (author.trim().isNotEmpty) buf.writeln('作者：$author');
    buf.writeln();
    buf.writeln('共 ${highlights.length} 条划线。');
    buf.writeln();

    final List<HighlightRecord> sorted = List<HighlightRecord>.from(highlights)
      ..sort((HighlightRecord a, HighlightRecord b) => a.start.compareTo(b.start));

    int lastChapter = -2;
    for (final HighlightRecord h in sorted) {
      final int ci = _chapterIndexFor(chapters, h.start);
      if (ci != lastChapter) {
        final String chapterTitle = ci >= 0 ? chapters[ci].title : '未知章节';
        buf.writeln('## $chapterTitle');
        buf.writeln();
        lastChapter = ci;
      }
      final String quote = _safeSlice(content, h.start, h.end);
      buf.writeln('> $quote');
      if (h.note.trim().isNotEmpty) {
        buf.writeln();
        buf.writeln('我的笔记：${h.note.trim()}');
      }
      final String date = _stamp(h.createdAt);
      if (date.isNotEmpty) buf.writeln();
      if (date.isNotEmpty) buf.writeln('记录于 $date');
      buf.writeln();
    }
    return buf.toString();
  }

  /// 导出书签笔记（带 note 的书签）。
  static String exportBookmarks({
    required String title,
    required String author,
    required String content,
    required List<Chapter> chapters,
    required Map<int, BookmarkMeta> bookmarks,
  }) {
    final StringBuffer buf = StringBuffer();
    buf.writeln('# 《$title》书签');
    if (author.trim().isNotEmpty) buf.writeln('作者：$author');
    buf.writeln();
    buf.writeln('共 ${bookmarks.length} 个书签。');
    buf.writeln();

    final List<int> offsets = bookmarks.keys.toList()..sort();
    int lastChapter = -2;
    for (final int off in offsets) {
      final int ci = _chapterIndexFor(chapters, off);
      if (ci != lastChapter) {
        final String chapterTitle = ci >= 0 ? chapters[ci].title : '未知章节';
        buf.writeln('## $chapterTitle');
        buf.writeln();
        lastChapter = ci;
      }
      final String snippet = _safeSlice(content, off, off + 40);
      buf.writeln('- 位置 $off${snippet.isEmpty ? '' : '：$snippet'}');
      final BookmarkMeta? meta = bookmarks[off];
      if (meta != null && meta.note.trim().isNotEmpty) {
        buf.writeln('  - 笔记：${meta.note.trim()}');
      }
    }
    return buf.toString();
  }
}
