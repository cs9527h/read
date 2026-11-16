import 'package:flutter_test/flutter_test.dart';

import 'package:read/src/services/chapter_splitter.dart';

void main() {
  test('识别中文数字章节', () {
    const String text = '序章 开始\n正文\n第一章 出发\n内容一\n第二章 抵达\n内容二';
    final List<Chapter> chapters = splitChapters(text);
    expect(chapters.length, greaterThanOrEqualTo(3));
    expect(chapters.any((Chapter c) => c.title.startsWith('第一章')), isTrue);
  });

  test('有前言时单独成章', () {
    const String text = '书名与简介\n作者\n第一章 起点\n正文\n第二章 终点\n正文';
    final List<Chapter> chapters = splitChapters(text);
    expect(chapters.first.title, '前言');
    expect(chapters.first.start, 0);
  });

  test('无章节标记时整本一章', () {
    const String text = '一段没有章节标题的普通文本。\n第二段。';
    final List<Chapter> chapters = splitChapters(text);
    expect(chapters.length, 1);
    expect(chapters.first.title, '全文');
  });

  test('章节偏移连续覆盖全文', () {
    const String text = '前言部分\n第一章 甲\n内容\n第二章 乙\n内容\n第三章 丙\n结尾';
    final List<Chapter> chapters = splitChapters(text);
    for (int i = 0; i < chapters.length - 1; i++) {
      expect(chapters[i].end, chapters[i + 1].start);
    }
    expect(chapters.last.end, text.length);
  });
  test('章节标题不能吞掉前一行的换行符', () {
    const text = '第一章 开始\n第一段结束。\n\n第二章 后续\n第二段。\n';
    final chapters = splitChapters(text);
    expect(chapters.length, 2);
    expect(chapters.first.end, chapters.last.start);
    expect(chapters.map((c) => c.slice(text)).join(), text);
    expect(chapters.last.slice(text).startsWith('第二章'), isTrue);
  });

  test('标题不吞掉下一行无标点正文（\\s 不得跨行）', () {
    const text = '第一章\n正文没有句末标点但这里是内容\n第二章\n另一段无标点的正文内容';
    final chapters = splitChapters(text);
    // 章名不得包含换行，也不得把正文当章名
    expect(chapters.map((c) => c.title).any((t) => t.contains('\n')), isFalse);
    expect(chapters.map((c) => c.title).any((t) => t.contains('正文')), isFalse);
    expect(chapters.any((c) => c.title == '第一章'), isTrue);
    expect(chapters.any((c) => c.title == '第二章'), isTrue);
    // 原文字符不丢失、章节连续覆盖
    expect(chapters.map((c) => c.slice(text)).join(), text);
  });

  test('英文 Chapter 标题同样不跨行吞正文', () {
    const text = 'Chapter 1\nsome prose with no stop\nChapter 2\nmore prose here';
    final chapters = splitChapters(text);
    expect(chapters.map((c) => c.title).any((t) => t.contains('\n')), isFalse);
    expect(chapters.map((c) => c.slice(text)).join(), text);
  });

  test('超长假标题不是章节，避免误拆 TXT 正文', () {
    final bogus = '第一章' + List<String>.filled(180, '这仍是正文内容').join();
    final text = '第一章 真标题\n内容\n' + bogus +
        '\n第二章 真标题\n结尾';
    final chapters = splitChapters(text);
    expect(chapters.length, 2);
  });

}
