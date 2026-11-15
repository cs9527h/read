import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/formats/format_engine.dart';

Uint8List sampleEpub(List<int> cover, {bool declared = true}) {
  final archive = Archive();
  archive.addFile(ArchiveFile.string(
    'META-INF/container.xml',
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<container><rootfiles><rootfile full-path="OEBPS/content.opf"/>'
    '</rootfiles></container>',
  ));
  archive.addFile(ArchiveFile.string(
    'OEBPS/content.opf',
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<package><metadata><title>封面测试</title><creator>作者</creator></metadata>'
    '<manifest>'
    '<item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>'
    '<item id="front" href="images/cover.jpg" media-type="image/jpeg"'
    '${declared ? ' properties="cover-image"' : ''}/>'
    '</manifest><spine><itemref idref="chapter"/></spine></package>',
  ));
  archive.addFile(ArchiveFile.string(
    'OEBPS/chapter.xhtml',
    '<html><body><h1>第一章</h1><p>这里是正文内容。</p></body></html>',
  ));
  archive.addFile(ArchiveFile.bytes('OEBPS/images/cover.jpg', cover));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('EPUB3 cover image is extracted without changing readable text', () async {
    final jpeg = <int>[0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4];
    final doc = await FormatEngine.importBytes(sampleEpub(jpeg), 'one.epub');
    expect(doc.format, 'EPUB');
    expect(doc.text, contains('这里是正文内容'));
    expect(doc.coverExtension, 'jpg');
    expect(doc.coverBytes, orderedEquals(jpeg));
  });

  test('unreferenced or invalid cover is ignored safely', () async {
    final jpeg = <int>[0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4];
    final hidden = await FormatEngine.importBytes(
      sampleEpub(jpeg, declared: false),
      'two.epub',
    );
    expect(hidden.coverBytes, isNull);
    final invalid = await FormatEngine.importBytes(
      sampleEpub(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
      'three.epub',
    );
    expect(invalid.coverBytes, isNull);
    expect(invalid.text, contains('正文内容'));
  });
}
