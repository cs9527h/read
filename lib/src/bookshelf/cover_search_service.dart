import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 封面在线搜索的纯逻辑：搜索地址构造、图片直链提取、裁切。
///
/// 设计约束：
/// - 不在代码里硬编码任何"图片搜索 API 密钥"，避免假服务；
/// - 搜索页用内置 WebView 打开（由页面层负责），本服务只负责解析用户复制回来的
///   页面 HTML / 图片直链，以及把图片裁成书籍封面比例；
/// - 所有函数都是纯函数或显式注入 IO，便于真实测试。
abstract final class CoverSearchService {
  /// Bing 图片搜索地址（无需 API key，内置浏览器可直接打开）。
  static String searchUrl(String query) {
    final String q = Uri.encodeQueryComponent('$query 封面');
    return 'https://www.bing.com/images/search?q=$q';
  }

  /// 注入内置浏览器：抓取页面所有 img 的 src/data-src，作为候选图片直链返回。
  /// 返回 JSON 字符串数组，由页面层 decode 后用 [extractImageUrls] 复用同一套清洗。
  static const String extractImagesJs = r'''
    (function(){
      var out = [];
      var imgs = document.querySelectorAll('img');
      for (var i=0;i<imgs.length;i++){
        var s = imgs[i].getAttribute('data-src') || imgs[i].getAttribute('src') || '';
        if (s) out.push(s);
      }
      return JSON.stringify(out);
    })();
  ''';

  /// 解析 WebView 注入脚本返回的 JSON 数组，走统一清洗与去重。
  static List<String> parseInjectedCandidates(String json) {
    try {
      final Object? decoded = jsonDecode(json);
      if (decoded is! List) return const <String>[];
      final StringBuffer sb = StringBuffer();
      for (final Object? item in decoded) {
        if (item is String) sb.writeln(item);
      }
      return extractImageUrls(sb.toString());
    } catch (_) {
      return const <String>[];
    }
  }

  /// 用户可复制图片直链，或复制整个搜索结果页的 HTML。
  /// 这里从两种输入里提取候选 http(s) 图片地址。
  static List<String> extractImageUrls(String input) {
    final String text = input.trim();
    if (text.isEmpty) return const <String>[];

    final Set<String> found = <String>{};

    // 1) 单个直链（前后可有空白或引号；中间不得有空白，否则交给裸 URL 分支）
    const String quote = '"' "'";
    final String trimmed = text
        .replaceFirst(RegExp('^[$quote]+'), '')
        .replaceFirst(RegExp('[$quote]+\$'), '');
    if (!trimmed.contains(RegExp(r'\s'))) {
      final Uri? direct = Uri.tryParse(trimmed);
      if (_isImageUrl(direct)) found.add(direct.toString());
    }

    // 2) HTML 里的 src / data-src / href 指向的图片
    final RegExp attr = RegExp(
      '(?:src|data-src|data-original|href)\\s*=\\s*[$quote]([^$quote]+)[$quote]',
      caseSensitive: false,
    );
    for (final RegExpMatch m in attr.allMatches(text)) {
      final Uri? uri = Uri.tryParse((m.group(1) ?? '').replaceAll('&amp;', '&'));
      if (_isImageUrl(uri)) found.add(uri.toString());
    }

    // 3) 裸 URL（如 JSON、纯文本里的一段）
    final RegExp bare = RegExp('https?://[^\\s$quote<>\\\\]+');
    for (final RegExpMatch m in bare.allMatches(text)) {
      final Uri? uri = Uri.tryParse(m.group(0) ?? '');
      if (_isImageUrl(uri)) found.add(uri.toString());
    }
    return found.toList(growable: false);
  }

  static bool _isImageUrl(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    final String path = uri.path.toLowerCase();
    if (_looksLikeLandingPage(path)) return false;
    return _imageExts.any((String e) => path.endsWith(e)) ||
        uri.queryParameters.containsKey('image') ||
        uri.queryParameters.containsKey('img') ||
        uri.host.contains('image');
  }

  static const List<String> _imageExts = <String>[
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp',
  ];

  static bool _looksLikeLandingPage(String path) =>
      path.endsWith('.html') || path.endsWith('.htm') || path == '/' || path.isEmpty;

  /// 书籍封面比例 3:4（宽/高 = 0.75）。
  static const double coverAspectRatio = 0.75;

  /// 把任意图片字节居中裁切成封面比例，再编码为 JPEG。
  /// 返回裁切后的字节；无法解码时抛出 FormatException。
  static Uint8List cropToCover(
    Uint8List bytes, {
    double aspect = coverAspectRatio,
    int maxEdge = 1600,
    int quality = 88,
  }) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('无法解码图片');

    final int srcW = decoded.width;
    final int srcH = decoded.height;
    if (srcW <= 0 || srcH <= 0) throw const FormatException('图片尺寸无效');

    // 以目标比例计算最大内接矩形，居中裁切。
    int cropW;
    int cropH;
    final double srcRatio = srcW / srcH;
    if (srcRatio > aspect) {
      cropH = srcH;
      cropW = (srcH * aspect).round().clamp(1, srcW);
    } else {
      cropW = srcW;
      cropH = (srcW / aspect).round().clamp(1, srcH);
    }
    final int x = ((srcW - cropW) / 2).round();
    final int y = ((srcH - cropH) / 2).round();

    img.Image cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: cropW,
      height: cropH,
    );
    // 超大图等比缩小，控制封面文件大小。
    if (cropped.width > maxEdge || cropped.height > maxEdge) {
      final double scale = maxEdge / (cropped.width > cropped.height ? cropped.width : cropped.height);
      cropped = img.copyResize(
        cropped,
        width: (cropped.width * scale).round().clamp(1, maxEdge),
      );
    }
    return Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
  }

  /// 下载图片字节（显式注入 client 便于测试；生产传 null 用真实 HttpClient）。
  static Future<Uint8List> download(
    String url, {
    HttpClient? client,
    int maxBytes = 12 * 1024 * 1024,
  }) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw const FormatException('只支持 http/https 图片地址');
    }
    final HttpClient http = client ?? HttpClient()..connectionTimeout = const Duration(seconds: 15);
    final bool owned = client == null;
    try {
      final HttpClientRequest request = await http.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        throw FormatException('图片下载失败：HTTP ${response.statusCode}');
      }
      final BytesBuilder builder = BytesBuilder(copy: false);
      int total = 0;
      await for (final List<int> chunk in response) {
        total += chunk.length;
        if (total > maxBytes) {
          throw const FormatException('图片超过 12MB');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      if (owned) http.close();
    }
  }
}
