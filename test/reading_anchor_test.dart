import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/reading_anchor.dart';

void main() {
  const source = '前言\n卷1 第一部分\n正文abc\n卷2 第二部分\n正文XYZ';
  const custom = ChapterRule.custom(r'^卷[0-9]+');
  final chapters = splitChapters(source, rule: custom);

  test('custom heading offsets roundtrip accurately', () {
    expect(chapters.length, 3);
    for (int absolute = 0; absolute <= source.length; absolute++) {
      final a = ReadingAnchor.fromAbsolute(
        chapters: chapters, absoluteOffset: absolute,
      );
      final b = ReadingAnchor.fromChapter(
        chapters: chapters,
        chapterIndex: a.chapterIndex,
        chapterOffset: a.chapterOffset,
      );
      expect(b.absoluteOffset, absolute);
    }
  });

  test('cross rule resplit preserves absolute reading location', () {
    final a = ReadingAnchor.fromChapter(
      chapters: chapters, chapterIndex: 2, chapterOffset: 3,
    );
    final none = splitChapters(
      source, rule: const ChapterRule.none(),
    );
    final b = ReadingAnchor.fromAbsolute(
      chapters: none, absoluteOffset: a.absoluteOffset,
    );
    expect(b.absoluteOffset, a.absoluteOffset);
    expect(b.chapterIndex, 0);
  });

  test('negative and past-end positions are clamped', () {
    final first = ReadingAnchor.fromAbsolute(
      chapters: chapters, absoluteOffset: -200,
    );
    expect(first.absoluteOffset, 0);
    final last = ReadingAnchor.fromAbsolute(
      chapters: chapters, absoluteOffset: source.length + 200,
    );
    expect(last.absoluteOffset, source.length);
  });
}
