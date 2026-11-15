import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:read/src/services/paginator.dart';

void main() {
  test('分页结果覆盖全文且不为空', () {
    const String text = '第一行\n第二行\n第三行';
    final List<String> pages = paginate(
      text,
      const TextStyle(fontSize: 16),
      300,
      2000,
    );
    expect(pages, isNotEmpty);
    expect(pages.join('\n'), contains('第三行'));
  });

  test('高度受限时会分成多页', () {
    final String text = List<String>.generate(60, (int i) => '第 $i 行').join('\n');
    final List<String> pages = paginate(
      text,
      const TextStyle(fontSize: 16),
      300,
      120,
    );
    expect(pages.length, greaterThan(1));
  });

  test('超长无换行 TXT 段落分页，不能溢出一个页面', () {
    final String text = List<String>.filled(2000, '阅读').join();
    final slices = paginateSlices(text, const TextStyle(fontSize: 18), 240, 140);
    expect(slices.length, greaterThan(1));
    expect(slices.map((s) => s.textOf(text)).join(), text);
    for (final slice in slices) {
      expect(slice.end, greaterThan(slice.start));
      expect(slice.end - slice.start, lessThan(8193));
    }
  });

  test('空行和重复文本也保留精确偏移，不靠 indexOf 猜测', () {
    const text = '相同段落\n\n相同段落\n\n相同段落\n';
    final slices = paginateSlices(text, const TextStyle(fontSize: 18), 130, 72);
    expect(slices.map((s) => s.textOf(text)).join(), text);
    expect(slices.first.start, 0);
    expect(slices.last.end, text.length);
    for (int i = 1; i < slices.length; i++) {
      expect(slices[i - 1].end, slices[i].start);
    }
  });

  test('中文与表情符号不能从 UTF-16 代理项之间断页', () {
    final text = List<String>.filled(300, '汉字📚阅读').join();
    final slices = paginateSlices(text, const TextStyle(fontSize: 19), 120, 75);
    expect(slices.length, greaterThan(1));
    expect(slices.map((s) => s.textOf(text)).join(), text);
    for (final slice in slices) {
      if (slice.end < text.length) {
        final code = text.codeUnitAt(slice.end);
        expect(code >= 0xDC00 && code <= 0xDFFF, isFalse);
      }
    }
  });

  test('无效宽高被拒绝，不会进入无限循环', () {
    expect(
      () => paginateSlices('内容', const TextStyle(fontSize: 16), 0, 100),
      throwsArgumentError,
    );
  });

}
