import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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

  test('EPUB spine keeps opening prose once and does not duplicate headings', () async {
    final archive = Archive();
    void addFile(String name, String content) {
      final data = utf8.encode(content);
      archive.addFile(ArchiveFile(name, data.length, data));
    }
    addFile('META-INF/container.xml',
        '<container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>');
    addFile('OEBPS/content.opf',
        '<package><metadata><title>验证书</title></metadata>'
        '<manifest>'
        '<item id="one" href="one.xhtml" media-type="application/xhtml+xml"/>'
        '<item id="two" href="two.xhtml" media-type="application/xhtml+xml"/>'
        '</manifest><spine><itemref idref="one"/><itemref idref="two"/></spine></package>');
    addFile('OEBPS/one.xhtml',
        '<html><body><p>开篇正文。</p><p>后续内容。</p></body></html>');
    addFile('OEBPS/two.xhtml',
        '<html><body><h1>第二章 远行</h1><p>第二章正文内容。</p></body></html>');
    final zip = ZipEncoder().encode(archive);
    final result = await FormatEngine.importBytes(
        Uint8List.fromList(zip), 'book.epub');
    expect(result.format, 'EPUB');
    expect(result.text.split('开篇正文。').length - 1, 1,
        reason: 'No-heading spine prose must not be used as a duplicated title');
    expect(result.text.split('第二章 远行').length - 1, 1,
        reason: 'An explicit leading heading should render exactly once');
    expect(result.text, contains('后续内容。'));
    expect(result.text, contains('第二章正文内容。'));
    expect(result.text.indexOf('开篇正文。'),
        lessThan(result.text.indexOf('第二章正文内容。')));
  });

}
