import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/chapter_splitter.dart';

class ManualChapterMark {
  const ManualChapterMark({
    required this.offset,
    required this.title,
    required this.createdAt,
  });

  final int offset;
  final String title;
  final int createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'offset': offset,
        'title': title,
        'created_at': createdAt,
      };

  static ManualChapterMark? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final offset = (raw['offset'] as num?)?.toInt();
    if (offset == null || offset < 0) return null;
    return ManualChapterMark(
      offset: offset,
      title: (raw['title'] as String?)?.trim() ?? '',
      createdAt: (raw['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}

/// User-corrected chapter breaks. Automatic detection never rewrites the book;
/// manual marks are layered on top and can be removed independently.
class ManualChapterStore {
  static const String _prefix = 'read.manual_chapters.v1.';

  static Future<List<ManualChapterMark>> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$bookId');
    if (raw == null) return <ManualChapterMark>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final marks = <ManualChapterMark>[];
      for (final item in decoded) {
        final mark = ManualChapterMark.fromJson(item);
        if (mark != null) marks.add(mark);
      }
      marks.sort((ManualChapterMark a, ManualChapterMark b) =>
          a.offset.compareTo(b.offset));
      return marks;
    } catch (_) {
      return <ManualChapterMark>[];
    }
  }

  static Future<void> add(
    String bookId,
    int offset,
    String title,
  ) async {
    final marks = await load(bookId);
    marks.removeWhere((ManualChapterMark m) => m.offset == offset);
    marks.add(ManualChapterMark(
      offset: offset,
      title: title.trim().isEmpty ? '手动章节' : title.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _persist(bookId, marks);
  }

  static Future<void> remove(String bookId, int offset) async {
    final marks = await load(bookId);
    marks.removeWhere((ManualChapterMark m) => m.offset == offset);
    await _persist(bookId, marks);
  }

  static Future<void> clearForDeletedBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$bookId');
  }

  static Future<void> _persist(
    String bookId,
    List<ManualChapterMark> marks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    marks.sort((ManualChapterMark a, ManualChapterMark b) =>
        a.offset.compareTo(b.offset));
    final ok = await prefs.setString(
      '$_prefix$bookId',
      jsonEncode(marks.map((ManualChapterMark m) => m.toJson()).toList()),
    );
    if (!ok) throw StateError('手动章节保存失败');
  }
}

/// Splits detected chapters at manual offsets and names the new segment.
/// Marks outside the book or exactly at an existing boundary only rename it.
List<Chapter> applyManualChapters(
  String content,
  List<Chapter> chapters,
  List<ManualChapterMark> marks,
) {
  if (marks.isEmpty || chapters.isEmpty) return chapters;
  final result = <Chapter>[];
  final sorted = marks
      .where((ManualChapterMark m) => m.offset >= 0 && m.offset <= content.length)
      .toList()
    ..sort((ManualChapterMark a, ManualChapterMark b) =>
        a.offset.compareTo(b.offset));
  int markIndex = 0;
  for (final chapter in chapters) {
    int start = chapter.start;
    final end = chapter.end;
    String title = chapter.title;
    bool manual = chapter.manual;
    while (markIndex < sorted.length &&
        sorted[markIndex].offset < start) {
      markIndex++;
    }
    while (markIndex < sorted.length &&
        sorted[markIndex].offset < end) {
      final mark = sorted[markIndex];
      if (mark.offset <= start) {
        title = mark.title;
        manual = true;
        markIndex++;
        continue;
      }
      result.add(Chapter(title, start, mark.offset - start, manual: manual));
      start = mark.offset;
      title = mark.title;
      manual = true;
      markIndex++;
    }
    if (start < end || result.isEmpty) {
      result.add(Chapter(title, start, end - start, manual: manual));
    }
  }
  return result;
}
