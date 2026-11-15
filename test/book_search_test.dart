import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/book_search.dart';
import 'package:read/src/services/chapter_splitter.dart';

void main() {
  test('Chinese matches navigate to the right chapters', () {
    const text = '第一章 开始\n苹果\n第二章 后续\n苹果 苹果';
    final chapters = splitChapters(text);
    final hits = searchBookText(text, chapters, '苹果');
    expect(hits.length, 3);
    expect(hits.map((hit) => hit.chapterIndex).toList(), [0, 1, 1]);
    expect(text.substring(hits[2].start, hits[2].end), '苹果');
  });

  test('Repeated text uses original offsets, not indexOf a snippet', () {
    const text = 'abc abc abc';
    final hits = searchBookText(text, splitChapters(text), 'abc');
    expect(hits.map((hit) => hit.start).toList(), [0, 4, 8]);
  });

  test('Case insensitive English and emoji keep source offsets', () {
    const text = 'Hi😀 hello HELLO 😀';
    final hits = searchBookText(text, splitChapters(text), 'hello');
    expect(hits.length, 2);
    expect(text.substring(hits[1].start, hits[1].end), 'HELLO');
    final emojiHits = searchBookText(text, splitChapters(text), '😀');
    expect(emojiHits.length, 2);
    expect(emojiHits[1].start, text.lastIndexOf('😀'));
  });

  test('Empty query, capped matches and absent text', () {
    const text = '测试 测试 测试';
    final chapters = splitChapters(text);
    expect(searchBookText(text, chapters, '  '), isEmpty);
    expect(searchBookText(text, chapters, '没有'), isEmpty);
    expect(searchBookText(text, chapters, '测试', maxResults: 2).length, 2);
  });
}
