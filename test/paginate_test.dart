import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:read/src/reader/reader_page.dart';

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
}
