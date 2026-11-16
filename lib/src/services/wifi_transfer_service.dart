import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:read/src/services/library_store.dart';

/// 局域网 WiFi 传书：手机开一个只接收文件的 HTTP 页面，电脑浏览器上传后
/// 直接走 [LibraryStore.importFileAtPath] 的同一套校验与入库流程。
///
/// 只监听局域网，不开放目录浏览；地址带随机路径令牌，停止后立即关闭端口。
class WifiTransferService {
  WifiTransferService._();

  static final WifiTransferService instance = WifiTransferService._();
  static const int _maxUploadBytes = 64 * 1024 * 1024;

  HttpServer? _server;
  String? _token;
  int? _port;
  List<String> _addresses = <String>[];
  String _lastMessage = '';

  bool get running => _server != null;
  int? get port => _port;
  String get lastMessage => _lastMessage;
  List<String> get addresses => List<String>.unmodifiable(_addresses);

  String? get url {
    final token = _token;
    final port = _port;
    if (token == null || port == null || _addresses.isEmpty) return null;
    return 'http://${_addresses.first}:$port/$token';
  }

  Future<void> start() async {
    if (_server != null) return;
    _addresses = await _localAddresses();
    if (_addresses.isEmpty) {
      throw const SocketException('没有可用的局域网 IPv4 地址');
    }
    final random = Random.secure();
    _token = List<int>.generate(10, (_) => random.nextInt(16))
        .map((i) => i.toRadixString(16))
        .join();
    HttpServer? server;
    for (int candidate = 8080; candidate <= 8089; candidate++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, candidate,
            shared: false);
        _port = candidate;
        break;
      } on SocketException {
        continue;
      }
    }
    if (server == null) {
      throw const SocketException('8080–8089 端口都被占用');
    }
    _server = server;
    _lastMessage = '';
    server.listen((HttpRequest request) {
      _handle(request).catchError((Object error) async {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.html;
          request.response.write(_page('上传失败', '<p>${_escape('$error')}</p>'));
          await request.response.close();
        } catch (_) {}
      });
    });
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _token = null;
    _port = null;
    _lastMessage = '';
    if (server != null) await server.close(force: true);
  }

  Future<List<String>> _localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final result = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.address.startsWith('169.254.')) continue;
        if (!result.contains(address.address)) result.add(address.address);
      }
    }
    return result;
  }

  Future<void> _handle(HttpRequest request) async {
    final token = _token;
    if (token == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/$token') {
      request.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      request.response.write(_page(
        'Read · WiFi 传书',
        '''
<p class="hint">把 EPUB / TXT / MD / HTML / PDF 拖到下面，或点击选择文件。上传后会直接进入书架。</p>
<form method="post" action="/$token/upload" enctype="multipart/form-data">
  <input type="file" name="file" accept=".epub,.txt,.md,.html,.htm,.pdf" required>
  <button type="submit">上传到手机</button>
</form>
<p class="hint">只在本机局域网开放；关闭手机上的接收开关后地址立即失效。</p>
''',
      ));
      await request.response.close();
      return;
    }
    if (request.method == 'POST' && path == '/$token/upload') {
      final length = request.contentLength;
      if (length > _maxUploadBytes) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        request.response.write(_page('文件太大', '<p>单次上传上限 64MB。</p>'));
        await request.response.close();
        return;
      }
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
        if (bytes.length > _maxUploadBytes) {
          request.response.statusCode = HttpStatus.requestEntityTooLarge;
          request.response.write(_page('文件太大', '<p>单次上传上限 64MB。</p>'));
          await request.response.close();
          return;
        }
      }
      final contentType = request.headers.contentType;
      final boundary = contentType?.parameters['boundary'];
      if (boundary == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(_page('格式错误', '<p>缺少 multipart boundary。</p>'));
        await request.response.close();
        return;
      }
      final files = parseMultipartFiles(bytes, boundary);
      if (files.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(_page('没有文件', '<p>请选择要上传的文件。</p>'));
        await request.response.close();
        return;
      }
      final imported = <String>[];
      final skipped = <String>[];
      final tempRoot = await getTemporaryDirectory();
      final tempDir = Directory('${tempRoot.path}/wifi_upload');
      await tempDir.create(recursive: true);
      for (final file in files) {
        final safeName = file.name
            .split(RegExp(r'[/\\]'))
            .last
            .replaceAll(RegExp(r'[^A-Za-z0-9._\-\u4e00-\u9fa5]'), '_');
        final temp = File(
            '${tempDir.path}/${DateTime.now().microsecondsSinceEpoch}-$safeName');
        await temp.writeAsBytes(file.bytes, flush: true);
        final book = await LibraryStore.instance.importFileAtPath(temp.path);
        try {
          await temp.delete();
        } catch (_) {}
        if (book == null) {
          skipped.add(safeName);
        } else {
          imported.add(book.title);
        }
      }
      _lastMessage = '新增 ${imported.length} 本，跳过 ${skipped.length} 个';
      request.response.headers.contentType =
          ContentType('text', 'html', charset: 'utf-8');
      request.response.write(_page(
        imported.isEmpty ? '没有导入成功' : '已导入 ${imported.length} 本',
        '''
${imported.isEmpty ? '' : '<p>${imported.map((e) => '《${_escape(e)}》').join('、')}</p>'}
${skipped.isEmpty ? '' : '<p class="hint">跳过：${skipped.map(_escape).join('、')}</p>'}
<p><a href="/$token">继续上传</a></p>
''',
      ));
      await request.response.close();
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  @visibleForTesting
  List<WifiUploadedFile> parseMultipartFiles(List<int> body, String boundary) {
    final marker = ascii.encode('--$boundary');
    final files = <WifiUploadedFile>[];
    int cursor = _indexOf(body, marker, 0);
    if (cursor < 0) return files;
    cursor += marker.length;
    while (cursor < body.length) {
      if (cursor + 1 < body.length &&
          body[cursor] == 45 &&
          body[cursor + 1] == 45) {
        break;
      }
      if (cursor + 1 < body.length &&
          body[cursor] == 13 &&
          body[cursor + 1] == 10) {
        cursor += 2;
      }
      final next = _indexOf(body, marker, cursor);
      if (next < 0) break;
      int end = next;
      if (end > cursor && body[end - 1] == 10) {
        end -= 1;
        if (end > cursor && body[end - 1] == 13) end -= 1;
      }
      final headerEnd = _indexOf(body, <int>[13, 10, 13, 10], cursor);
      if (headerEnd < 0 || headerEnd > end) {
        cursor = next + marker.length;
        continue;
      }
      final headers =
          utf8.decode(body.sublist(cursor, headerEnd), allowMalformed: true);
      final match = RegExp(r'filename="([^"]*)"').firstMatch(headers);
      if (match != null && match.group(1)!.isNotEmpty) {
        final contentStart = headerEnd + 4;
        if (contentStart <= end) {
          files.add(WifiUploadedFile(
            match.group(1)!,
            body.sublist(contentStart, end),
          ));
        }
      }
      cursor = next + marker.length;
    }
    return files;
  }

  int _indexOf(List<int> data, List<int> pattern, int start) {
    if (pattern.isEmpty) return -1;
    final first = pattern.first;
    for (int i = start; i <= data.length - pattern.length; i++) {
      if (data[i] != first) continue;
      bool match = true;
      for (int j = 1; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  String _page(String title, String body) => '''
<!doctype html>
<html lang="zh-CN"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape(title)}</title>
<style>
body{font-family:-apple-system,system-ui,sans-serif;background:#f7f7f4;color:#111;margin:0;padding:32px 18px}
main{max-width:560px;margin:0 auto;background:#fff;border:1px solid #ddd;border-radius:12px;padding:24px}
h1{font-size:22px;margin:0 0 16px}
p{line-height:1.7;font-size:14px}
input[type=file]{display:block;width:100%;box-sizing:border-box;padding:12px;border:1px dashed #999;border-radius:8px;margin:16px 0}
button{width:100%;padding:12px;border:0;border-radius:8px;background:#111;color:#fff;font-size:15px}
a{color:#111}.hint{color:#666;font-size:12px}
</style></head><body><main><h1>${_escape(title)}</h1>$body</main></body></html>
''';

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class WifiUploadedFile {
  const WifiUploadedFile(this.name, this.bytes);

  final String name;
  final List<int> bytes;
}
