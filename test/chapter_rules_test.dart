import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/chapter_splitter.dart';

void main() {
  test('custom headings leave every source character intact', () {
    const text = '简介\n卷1 出发\n一段文字\n\n卷2 归来\n第二段\n';
    final chapters = splitChapters(
      text,
      rule: const ChapterRule.custom(r'^卷[0-9]+'),
    );
    expect(chapters.length, 3);
    expect(chapters.first.title, '前言');
    expect(chapters[1].title, '卷1 出发');
    expect(chapters[2].title, '卷2 归来');
    expect(chapters.map((c) => c.slice(text)).join(), text);
    for (int i = 1; i < chapters.length; i++) {
      expect(chapters[i].start, chapters[i - 1].end);
    }
  });

  test('none rule uses a single chapter and no content rewriting', () {
    const text = '第一章\n内容\n第二章\n内容';
    final chapters = splitChapters(text, rule: const ChapterRule.none());
    expect(chapters.single.slice(text), text);
  });

  test('invalid custom expression produces a readable error', () {
    for (final pattern in <String>['', 'Chapter', '(.*)+', '^a|^b', '^a(']) {
      expect(
        () => splitChapters('text', rule: ChapterRule.custom(pattern)),
        throwsFormatException,
      );
    }
  });

  test('single-line matching ignores long pseudo-headings', () {
    final fake = '卷9' + List<String>.filled(120, '正文').join();
    final text = '卷1 开头\n内容\n$fake\n卷2 结尾\n收尾';
    final chapters = splitChapters(
      text,
      rule: const ChapterRule.custom(r'^卷[0-9]+'),
    );
    expect(chapters.length, 2);
    expect(chapters.map((c) => c.slice(text)).join(), text);
  });

  test('fewer than two detected headings returns entire source', () {
    const text = '卷1 唯一\n正文';
    final chapters = splitChapters(
      text,
      rule: const ChapterRule.custom(r'^卷[0-9]+'),
    );
    expect(chapters.single.title, '全文');
    expect(chapters.single.slice(text), text);
  });
}
