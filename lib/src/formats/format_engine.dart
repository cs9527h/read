import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class ImportedDocument {
  const ImportedDocument(this.text, this.format, {this.title, this.author, this.coverBytes});
  final String text;
  final String format;
  final String? title;
  final String? author;
  /// Optional embedded EPUB cover, accepted only for bounded raster images.
  final Uint8List? coverBytes;
}

/// Text-mode EPUB, Markdown and HTML import. Does not execute remote HTML.
class FormatEngine {
  static const int maxSourceBytes = 40 * 1024 * 1024;
  static const int maxEpubBytes = 100 * 1024 * 1024;
  static const List<String> supported = <String>[
    'txt', 'epub', 'md', 'markdown', 'html', 'htm',
  ];

  static Future<String> decodeText(Uint8List bytes) async {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 3 &&
        bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf) {
      return utf8.decode(bytes.sublist(3));
    }
    // Windows-exported TXT frequently uses UTF-16 LE/BE with BOM.
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
         (bytes[0] == 0xfe && bytes[1] == 0xff))) {
      final bool littleEndian = bytes[0] == 0xff;
      if ((bytes.length - 2).isOdd) {
        throw const FormatException('UTF-16 文本长度不完整');
      }
      final List<int> units = <int>[];
      for (int index = 2; index < bytes.length; index += 2) {
        final int a = bytes[index];
        final int b = bytes[index + 1];
        units.add(littleEndian ? a | (b << 8) : (a << 8) | b);
      }
      return String.fromCharCodes(units);
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {}
    try {
      final text = await CharsetConverter.decode('gb18030', bytes);
      if (text.isNotEmpty) return text;
    } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Future<ImportedDocument> importBytes(
      Uint8List bytes, String filename) async {
    if (bytes.isEmpty) throw const FormatException('文件为空');
    if (bytes.length > maxSourceBytes) {
      throw const FormatException('超过 40MB，当前尚未实现分块加载');
    }
    final ext = p.extension(filename).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'txt':
        return ImportedDocument(await decodeText(bytes), 'TXT');
      case 'epub':
        return _parseEpub(bytes);
      case 'md':
      case 'markdown':
        return ImportedDocument(
          htmlToPlainText(markdown.markdownToHtml(await decodeText(bytes))), 'MD');
      case 'html':
      case 'htm':
        return ImportedDocument(htmlToPlainText(await decodeText(bytes)), 'HTML');
      default:
        throw FormatException(
          '当前支持 TXT、EPUB 文字模式、Markdown、HTML；此文件格式尚未实现');
    }
  }

  static String htmlToPlainText(String html) {
    final document = html_parser.parse(html);
    final out = StringBuffer();
    const excluded = <String>{
      'head', 'script', 'style', 'noscript', 'iframe', 'svg', 'audio', 'video'
    };
    const blocks = <String>{
      'p', 'div', 'section', 'article', 'h1', 'h2', 'h3',
      'h4', 'h5', 'h6', 'br', 'li', 'tr', 'blockquote', 'pre'
    };
    void visit(dom.Node node) {
      if (node is dom.Element) {
        final tag = node.localName ?? '';
        if (excluded.contains(tag)) return;
        if (tag == 'img') {
          final alt = node.attributes['alt']?.trim();
          if (alt != null && alt.isNotEmpty) out.write('[图片：' + alt + ']');
          return;
        }
        if (blocks.contains(tag)) out.write('\n');
        for (final child in node.nodes) {
          visit(child);
        }
        if (blocks.contains(tag)) out.write('\n');
      } else if (node is dom.Text) {
        out.write(node.text.replaceAll(RegExp(r'[ \t\r\f]+'), ' '));
      }
    }
    visit(document.body ?? document);
    return out.toString()
        .replaceAll(RegExp(r'\n[ \t]*\n[ \t]*\n+'), '\n\n').trim();
  }

  static String _resolve(String base, String href) {
    late String name;
    try {
      name = Uri.decodeComponent(href.split('#').first.split('?').first);
    } catch (_) {
      throw const FormatException('EPUB 内链接编码错误');
    }
    if (name.startsWith('/') || name.contains('\\')) {
      throw const FormatException('EPUB 路径不安全');
    }
    final result = p.posix.normalize(p.posix.join(base, name));
    if (result == '..' || result.startsWith('../')) {
      throw const FormatException('EPUB 存在越界路径');
    }
    return result;
  }

  static ImportedDocument _parseEpub(Uint8List bytes) {
    late Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const FormatException('EPUB 文件损坏或加密，无法解包');
    }
    if (archive.files.length > 5000) {
      throw const FormatException('EPUB 内容条目过多');
    }
    int sum = 0;
    final entries = <String, ArchiveFile>{};
    for (final item in archive.files) {
      if (!item.isFile) continue;
      sum += item.size;
      if (sum > maxEpubBytes) throw const FormatException('EPUB 解压容量超限');
      final name = p.posix.normalize(item.name.replaceAll('\\', '/'));
      if (name == '..' || name.startsWith('../') || name.startsWith('/')) {
        throw const FormatException('EPUB 含不安全的内部路径');
      }
      entries[name] = item;
    }
    String read(String path) {
      final item = entries[path];
      if (item == null) throw FormatException('EPUB 缺少所需内容：' + path);
      if (item.size > 15 * 1024 * 1024) {
        throw const FormatException('EPUB 单个章节过大');
      }
      final data = item.readBytes();
      if (data == null) throw const FormatException('EPUB 章节解码失败');
      return utf8.decode(data, allowMalformed: true);
    }

    late XmlDocument container;
    try {
      container = XmlDocument.parse(read('META-INF/container.xml'));
    } catch (_) {
      throw const FormatException('EPUB container.xml 缺失或无效');
    }
    final roots = container.findAllElements('rootfile').toList();
    if (roots.isEmpty) throw const FormatException('EPUB 缺少 OPF 根文件');
    final opfPath = _resolve('', roots.first.getAttribute('full-path') ?? '');
    late XmlDocument opf;
    try {
      opf = XmlDocument.parse(read(opfPath));
    } catch (_) {
      throw const FormatException('EPUB OPF 内容清单损坏');
    }

    final manifest = <String, String>{};
    for (final item in opf.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      final type = item.getAttribute('media-type') ?? '';
      final property = item.getAttribute('properties') ?? '';
      if (id == null || href == null || property.split(' ').contains('nav')) {
        continue;
      }
      if (type == 'application/xhtml+xml' || type == 'text/html') {
        manifest[id] = _resolve(p.posix.dirname(opfPath), href);
      }
    }
    // EPUB3 uses properties="cover-image"; EPUB2 commonly uses
    // <meta name="cover" content="item-id">. Only bounded local raster bytes
    // are accepted: never execute/resolve remote SVG or URLs.
    String? coverId;
    for (final meta in opf.findAllElements('meta')) {
      if (meta.getAttribute('name') == 'cover') {
        coverId = meta.getAttribute('content');
        break;
      }
    }
    Uint8List? coverBytes;
    for (final item in opf.findAllElements('item')) {
      final type = item.getAttribute('media-type') ?? '';
      final properties = (item.getAttribute('properties') ?? '').split(' ');
      final cover = properties.contains('cover-image') ||
          (coverId != null && item.getAttribute('id') == coverId);
      if (!cover || !<String>['image/jpeg', 'image/png', 'image/webp']
          .contains(type)) continue;
      final href = item.getAttribute('href');
      if (href == null) continue;
      final imagePath = _resolve(p.posix.dirname(opfPath), href);
      final file = entries[imagePath];
      if (file == null || file.size <= 0 || file.size > 3 * 1024 * 1024) {
        continue;
      }
      final bytes = file.readBytes();
      if (bytes != null && bytes.isNotEmpty && bytes.length <= 3 * 1024 * 1024) {
        coverBytes = Uint8List.fromList(bytes);
        break;
      }
    }
    final sections = <String>[];
    for (final spine in opf.findAllElements('itemref')) {
      final path = manifest[spine.getAttribute('idref')];
      if (path == null) continue;
      final content = htmlToPlainText(read(path));
      if (content.isEmpty) continue;
      final firstLine = content.split('\n').first.trim();
      final title = firstLine.length <= 60 ? firstLine : '正文';
      sections.add('第' + (sections.length + 1).toString() +
          '章 ' + title + '\n' + content);
    }
    if (sections.isEmpty) {
      throw const FormatException('EPUB 中没有可读取的文字，图片/DRM 内容暂不支持');
    }
    final titles = opf.findAllElements('title').toList();
    final authors = opf.findAllElements('creator').toList();
    return ImportedDocument(
      sections.join('\n\n'), 'EPUB',
      title: titles.isEmpty ? null : titles.first.innerText.trim(),
      author: authors.isEmpty ? null : authors.first.innerText.trim(),
      coverBytes: coverBytes,
    );
  }
}
