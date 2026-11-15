import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/formats/format_engine.dart';

void main() {
  test('EPUB3 embedded cover survives import without remote image requests', () async {
    const container = '<?xml version="1.0"?>'
        '<container><rootfiles><rootfile full-path="OEBPS/content.opf"/>'
        '</rootfiles></container>';
    const opf = '<?xml version="1.0"?>'
        '<package><metadata><title>封面书</title><creator>作者</creator></metadata>'
        '<manifest>'
        '<item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/>'
        '<item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>'
        '</manifest><spine><itemref idref="chapter"/></spine></package>';
    const chapter = '<html><body><h1>第1章</h1><p>阅读正文</p></body></html>';
    // Small one-pixel PNG, enough to confirm exact binary extraction.
    final cover = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+P6uoAAAAASUVORK5CYII=',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('META-INF/container.xml', utf8.encode(container).length,
          utf8.encode(container)))
      ..addFile(ArchiveFile('OEBPS/content.opf', utf8.encode(opf).length,
          utf8.encode(opf)))
      ..addFile(ArchiveFile('OEBPS/chapter.xhtml', utf8.encode(chapter).length,
          utf8.encode(chapter)))
      ..addFile(ArchiveFile('OEBPS/cover.png', cover.length, cover));
    final zipped = ZipEncoder().encode(archive);
    final result = await FormatEngine.importBytes(
      Uint8List.fromList(zipped), 'cover.epub',
    );
    expect(result.title, '封面书');
    expect(result.text, contains('阅读正文'));
    expect(result.coverBytes, orderedEquals(cover));
  });
}
