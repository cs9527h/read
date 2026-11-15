import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/formats/format_engine.dart';

void main() {
  test('TXT keeps Unicode text and UTF8 BOM support', () async {
    final result = await FormatEngine.importBytes(
        Uint8List.fromList(<int>[0xef, 0xbb, 0xbf, ...utf8.encode('中文\n内容')]),
        'sample.txt');
    expect(result.format, 'TXT');
    expect(result.text, '中文\n内容');
  });

  test('Markdown is readable without rendering raw HTML scripts', () async {
    final result = await FormatEngine.importBytes(
      Uint8List.fromList(utf8.encode('# 标题\n\n**加粗内容**')),
      'novel.md',
    );
    expect(result.format, 'MD');
    expect(result.text, contains('标题'));
    expect(result.text, contains('加粗内容'));
  });

  test('HTML keeps readable text but excludes scripts/styles', () {
    final text = FormatEngine.htmlToPlainText(
      '<html><head><style>bad css</style></head>'
      '<body><h1>第一章</h1><p>你好世界</p>'
      '<script>evil();</script><img alt="地图"></body></html>');
    expect(text, contains('第一章'));
    expect(text, contains('你好世界'));
    expect(text, contains('地图'));
    expect(text, isNot(contains('evil')));
    expect(text, isNot(contains('bad css')));
  });

  test('Unknown formats are rejected without pretending to decode', () async {
    expect(
      () => FormatEngine.importBytes(Uint8List.fromList(<int>[1, 2]), 'x.pdf'),
      throwsFormatException,
    );
  });

  test('Oversized file fails before attempting decompression', () async {
    expect(
      () => FormatEngine.importBytes(
          Uint8List(FormatEngine.maxSourceBytes + 1), 'oversize.epub'),
      throwsFormatException,
    );
  });
  test('Windows UTF-16 LE/BE TXT BOM variants are decoded accurately', () async {
    final le = await FormatEngine.importBytes(
      Uint8List.fromList(<int>[0xff, 0xfe, 0x2d, 0x4e, 0x87, 0x65]),
      'little.txt',
    );
    final be = await FormatEngine.importBytes(
      Uint8List.fromList(<int>[0xfe, 0xff, 0x4e, 0x2d, 0x65, 0x87]),
      'big.txt',
    );
    expect(le.text, '中文');
    expect(be.text, '中文');
  });

  test('Damaged UTF-16 must fail instead of losing the final byte', () async {
    expect(
      () => FormatEngine.importBytes(
          Uint8List.fromList(<int>[0xff, 0xfe, 0x4e]), 'broken.txt'),
      throwsFormatException,
    );
  });

}
