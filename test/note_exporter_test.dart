import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/bookmark_meta_store.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/highlight_store.dart';
import 'package:read/src/services/note_exporter.dart';

void main() {
  // 原文：0-based。第一章[0,10)，第二章[10,20)
  const String content = '第一章正文甲乙丙丁\n第二章正文戊己庚辛';
  final List<Chapter> chapters = <Chapter>[
    const Chapter('第一章', 0, 10),
    const Chapter('第二章', 10, 9),
  ];

  test('导出高亮：按位置排序、标注章节、含划线原文与笔记', () {
    final List<HighlightRecord> highlights = <HighlightRecord>[
      HighlightRecord(
          start: 13,
          end: 17,
          color: 0xFFFFF176,
          note: '这个角色关键',
          createdAt: DateTime(2026, 1, 2).millisecondsSinceEpoch),
      HighlightRecord(
          start: 3,
          end: 7,
          color: 0xFF000000,
          note: '',
          createdAt: 0),
    ];
    final String md = NoteExporter.exportHighlights(
      title: '测试书',
      author: '作者甲',
      content: content,
      chapters: chapters,
      highlights: highlights,
    );
    // 标题与作者
    expect(md, contains('# 《测试书》划线与笔记'));
    expect(md, contains('作者：作者甲'));
    expect(md, contains('共 2 条划线'));
    // 章节顺序：第一章先于第二章
    expect(md.indexOf('## 第一章'), lessThan(md.indexOf('## 第二章')));
    // 划线原文（换行被替换为空格）
    expect(md, contains('正文甲乙'));
    expect(md, contains('正文戊己'));
    // 笔记与日期
    expect(md, contains('我的笔记：这个角色关键'));
    expect(md, contains('记录于 2026-01-02'));
  });

  test('导出高亮：无笔记时不输出笔记行，空列表给出计数', () {
    final String md = NoteExporter.exportHighlights(
      title: '书',
      author: '',
      content: content,
      chapters: chapters,
      highlights: const <HighlightRecord>[],
    );
    expect(md, contains('共 0 条划线'));
    expect(md, isNot(contains('我的笔记')));
    expect(md, isNot(contains('作者：')));
  });

  test('导出书签：排序、章节聚合、笔记', () {
    final Map<int, BookmarkMeta> marks = <int, BookmarkMeta>{
      12: const BookmarkMeta(
          offset: 12, createdAt: 0, note: '回头再看'),
      3: const BookmarkMeta(offset: 3, createdAt: 0, note: ''),
    };
    final String md = NoteExporter.exportBookmarks(
      title: '书',
      author: '',
      content: content,
      chapters: chapters,
      bookmarks: marks,
    );
    expect(md, contains('共 2 个书签'));
    expect(md.indexOf('## 第一章'), lessThan(md.indexOf('## 第二章')));
    expect(md, contains('笔记：回头再看'));
    expect(md, contains('位置 3'));
  });

  test('越界偏移不崩溃、被裁剪到原文范围', () {
    final String md = NoteExporter.exportHighlights(
      title: '书',
      author: '',
      content: content,
      chapters: chapters,
      highlights: <HighlightRecord>[
        const HighlightRecord(
            start: 8, end: 999, color: 0, note: '', createdAt: 0),
      ],
    );
    expect(md, contains('共 1 条划线'));
    // 不应抛异常，且能取到末尾片段
    expect(md.isNotEmpty, isTrue);
  });
}
