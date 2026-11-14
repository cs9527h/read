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
}
