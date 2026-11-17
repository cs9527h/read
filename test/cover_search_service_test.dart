import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:read/src/bookshelf/cover_search_service.dart';

void main() {
  group('搜索页辅助', () {
    test('searchUrl 编码书名并指向图片搜索', () {
      expect(CoverSearchService.searchUrl('三体'), contains('q='));
      expect(CoverSearchService.searchUrl('三体'), contains('bing.com/images/search'));
    });

    test('parseInjectedCandidates 解析 JS 返回的 JSON 并清洗去重', () {
      final urls = CoverSearchService.parseInjectedCandidates(
        '["https://img.example.com/a.jpg","https://img.example.com/a.jpg",'
        '"/relative.png","https://img.example.com/b.webp"]',
      );
      expect(urls.length, 2);
      expect(urls, contains('https://img.example.com/a.jpg'));
      expect(urls, contains('https://img.example.com/b.webp'));
    });

    test('parseInjectedCandidates 对非法 JSON 返回空', () {
      expect(CoverSearchService.parseInjectedCandidates('not json'), isEmpty);
    });
  });

  group('extractImageUrls', () {
    test('识别单个图片直链', () {
      final urls = CoverSearchService.extractImageUrls(
        '  https://img.example.com/a/b/cover.JPG  ',
      );
      expect(urls, <String>['https://img.example.com/a/b/cover.JPG']);
    });

    test('从 HTML 的 src/data-src 提取并去重', () {
      const html = '''
        <img src="https://cdn.example.com/x.png">
        <img data-src="https://cdn.example.com/y.webp">
        <a href="https://cdn.example.com/x.png">dup</a>
        <img src="/relative.jpg">
      ''';
      final urls = CoverSearchService.extractImageUrls(html);
      expect(urls.length, 2);
      expect(urls, contains('https://cdn.example.com/x.png'));
      expect(urls, contains('https://cdn.example.com/y.webp'));
    });

    test('过滤网页落地页与非图片链接', () {
      final urls = CoverSearchService.extractImageUrls(
        'https://example.com/index.html https://example.com/page/ '
        'ftp://example.com/a.jpg https://example.com/cover.jpg?x=1',
      );
      expect(urls, <String>['https://example.com/cover.jpg?x=1']);
    });

    test('空输入返回空列表', () {
      expect(CoverSearchService.extractImageUrls('   '), isEmpty);
    });
  });

  group('cropToCover', () {
    test('横图被裁成 3:4 竖版并保留中心内容', () {
      final src = img.Image(width: 1200, height: 600);
      img.fill(src, color: img.ColorRgb8(255, 0, 0));
      final bytes = Uint8List.fromList(img.encodePng(src));

      final cropped = CoverSearchService.cropToCover(bytes);
      final out = img.decodeImage(cropped)!;
      expect(out.width / out.height, closeTo(0.75, 0.02));
      expect(out.width, lessThanOrEqualTo(1600));
    });

    test('竖图按比例裁切不拉伸', () {
      final src = img.Image(width: 600, height: 1200);
      img.fill(src, color: img.ColorRgb8(0, 128, 255));
      final out = img.decodeImage(
        CoverSearchService.cropToCover(Uint8List.fromList(img.encodePng(src))),
      )!;
      expect(out.width / out.height, closeTo(0.75, 0.02));
    });

    test('损坏字节抛出 FormatException', () {
      expect(
        () => CoverSearchService.cropToCover(Uint8List.fromList(<int>[1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('download', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest req) async {
        if (req.uri.path == '/ok.png') {
          final src = img.Image(width: 100, height: 100);
          img.fill(src, color: img.ColorRgb8(20, 40, 60));
          final bytes = img.encodePng(src);
          req.response.headers.contentType = ContentType.parse('image/png');
          req.response.add(bytes);
        } else if (req.uri.path == '/big') {
          req.response.headers.contentLength = 20 * 1024 * 1024;
          req.response.add(List<int>.filled(20 * 1024 * 1024, 0));
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    String base() => 'http://127.0.0.1:${server.port}';

    test('下载成功返回字节', () async {
      final bytes = await CoverSearchService.download('${base()}/ok.png');
      expect(bytes.isNotEmpty, isTrue);
      expect(img.decodeImage(bytes), isNotNull);
    });

    test('非 200 抛出可读错误', () async {
      expect(
        () => CoverSearchService.download('${base()}/missing.png'),
        throwsA(isA<FormatException>().having(
          (Object e) => e.toString(),
          'message',
          contains('HTTP 404'),
        )),
      );
    });

    test('超过大小上限被拒绝', () async {
      expect(
        () => CoverSearchService.download('${base()}/big', maxBytes: 1024),
        throwsFormatException,
      );
    });

    test('非 http 地址被拒绝', () async {
      expect(
        () => CoverSearchService.download('file:///etc/passwd'),
        throwsFormatException,
      );
    });
  });
}
