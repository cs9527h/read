import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'remote_store.dart';

/// Standard WebDAV over HTTPS. The configured URL is the server root (for
/// example https://dav.jianguoyun.com/dav/) and [directory] is a folder such
/// as Read. Conditional writes use ETag / If-Match to prevent overwrites.
class WebDavStore implements RemoteObjectStore {
  WebDavStore({
    required String serverUrl,
    required this.username,
    required this.password,
    required String directory,
  }) : _server = _parseServer(serverUrl), directory = _safeDirectory(directory);

  final Uri _server;
  final String username;
  final String password;
  final String directory;

  static const int maxObjectBytes = 64 * 1024 * 1024;

  static Uri _parseServer(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('WebDAV 地址必须是干净的 HTTPS 服务器地址');
    }
    if (uri.pathSegments.any((String part) => part == '..')) {
      throw const FormatException('WebDAV 地址包含非法路径');
    }
    return uri;
  }

  static String _safeDirectory(String raw) {
    final cleaned = raw
        .split('/')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty && e != '.' && e != '..')
        .join('/');
    if (cleaned.length > 240) {
      throw const FormatException('同步目录过长');
    }
    return cleaned.isEmpty ? 'Read' : cleaned;
  }

  @override
  String get displayName => 'WebDAV · ${_server.host}';

  Uri _folderUri() => _join(directory);
  Uri _objectUri(String key) => _join(key);

  Uri _join(String relative) {
    final base = <String>[..._server.pathSegments.where((String s) => s.isNotEmpty)];
    final parts = <String>[
      ...base,
      ...relative.split('/').where((String s) => s.isNotEmpty),
    ];
    return Uri(
      scheme: 'https',
      host: _server.host,
      port: _server.hasPort ? _server.port : null,
      pathSegments: parts,
    );
  }

  HttpClient _client() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => false;
    return client;
  }

  void _authorize(HttpClientRequest request) {
    request.followRedirects = false;
    final value = base64Encode(utf8.encode('$username:$password'));
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic $value');
    request.headers.set(HttpHeaders.userAgentHeader, 'Read/1.0');
  }

  Future<int> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Uint8List? body,
  }) async {
    final client = _client();
    try {
      final request = await client.openUrl(method, uri);
      _authorize(request);
      headers?.forEach((String k, String v) => request.headers.set(k, v));
      if (body != null) {
        request.headers.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(const Duration(seconds: 35));
      await response.drain<void>();
      return response.statusCode;
    } on HandshakeException {
      throw const RemoteStoreException('TLS 证书校验失败，已拒绝连接');
    } on SocketException catch (error) {
      throw RemoteStoreException('网络不可达：${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> testConnection() async {
    if (username.isEmpty || password.isEmpty) {
      throw const RemoteAuthException('请填写 WebDAV 用户名和应用密码');
    }
    final status = await _request(
      'PROPFIND',
      _folderUri(),
      headers: const <String, String>{'Depth': '0', 'Content-Type': 'application/xml'},
      body: Uint8List.fromList(utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:resourcetype/><d:getlastmodified/></d:prop></d:propfind>',
      )),
    );
    if (status == 401 || status == 403) {
      throw const RemoteAuthException('WebDAV 认证失败，请检查账号与应用密码');
    }
    if (status != 207 && status != 200 && status != 404) {
      throw RemoteStoreException('WebDAV 测试失败：HTTP $status');
    }
  }

  Future<void> ensureDirectory({String? subdirectory}) async {
    final base = <String>[..._server.pathSegments.where((String s) => s.isNotEmpty)];
    final folders = <String>[];
    final allParts = <String>[
      ...directory.split('/'),
      if (subdirectory != null) ...subdirectory.split('/'),
    ];
    for (final part in allParts) {
      if (part.isEmpty) continue;
      folders.add(part);
      final uri = Uri(
        scheme: 'https',
        host: _server.host,
        port: _server.hasPort ? _server.port : null,
        pathSegments: <String>[...base, ...folders],
      );
      final status = await _request('MKCOL', uri);
      if (status == 401 || status == 403) {
        throw const RemoteAuthException('没有创建同步目录的权限');
      }
      if (status != 201 && status != 200 && status != 405 && status != 409) {
        throw RemoteStoreException('创建同步目录失败：HTTP $status');
      }
    }
  }

  @override
  Future<RemoteSnapshot?> read(String key) async {
    final client = _client();
    try {
      final request = await client.getUrl(_objectUri(key));
      _authorize(request);
      final response = await request.close().timeout(const Duration(seconds: 35));
      if (response.statusCode == 404) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await response.drain<void>();
        throw const RemoteAuthException('云端认证失败，请重新输入密码');
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw RemoteStoreException('下载失败：HTTP ${response.statusCode}');
      }
      if (response.contentLength > maxObjectBytes) {
        await response.drain<void>();
        throw const RemoteStoreException('云端文件超过 64MB 安全上限');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > maxObjectBytes) {
          throw const RemoteStoreException('云端文件超过 64MB 安全上限');
        }
      }
      return RemoteSnapshot(
        bytes: builder.takeBytes(),
        etag: response.headers.value(HttpHeaders.etagHeader),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String?> write(Uint8List bytes, String key, {String? expectedEtag}) async {
    if (bytes.length > maxObjectBytes) {
      throw const RemoteStoreException('上传文件超过 64MB 安全上限');
    }
    final client = _client();
    try {
      final request = await client.putUrl(_objectUri(key));
      _authorize(request);
      request.headers.contentType = ContentType('application', 'octet-stream');
      if (expectedEtag == null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, '*');
      } else {
        request.headers.set(HttpHeaders.ifMatchHeader, expectedEtag);
      }
      request.add(bytes);
      final response = await request.close().timeout(const Duration(seconds: 45));
      await response.drain<void>();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const RemoteAuthException('上传认证失败');
      }
      if (response.statusCode == 412 || response.statusCode == 409) {
        throw const RemoteConflictException('云端文件已被其他设备更新');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RemoteStoreException('上传失败：HTTP ${response.statusCode}');
      }
      return response.headers.value(HttpHeaders.etagHeader);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> delete(String key) async {
    final status = await _request('DELETE', _objectUri(key));
    if (status == 404) return;
    if (status < 200 || status >= 300) {
      throw RemoteStoreException('删除失败：HTTP $status');
    }
  }

  @override
  Future<List<RemoteEntry>> list({String prefix = '', int max = 200}) async {
    final client = _client();
    try {
      final request = await client.openUrl('PROPFIND', _folderUri());
      _authorize(request);
      request.headers.set('Depth', '1');
      request.headers.contentType = ContentType('application', 'xml');
      request.add(utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop>'
        '<d:displayname/><d:getcontentlength/><d:getlastmodified/><d:resourcetype/>'
        '</d:prop></d:propfind>',
      ));
      final response = await request.close().timeout(const Duration(seconds: 35));
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) return <RemoteEntry>[];
      if (response.statusCode != 207) {
        throw RemoteStoreException('列目录失败：HTTP ${response.statusCode}');
      }
      final document = XmlDocument.parse(text);
      final entries = <RemoteEntry>[];
      final folderPath = _folderUri().path;
      for (final node in document.findAllElements('response')) {
        final href = node.getElement('href')?.innerText ?? '';
        final decoded = Uri.decodeFull(href);
        if (decoded.endsWith('/')) continue;
        if (!decoded.startsWith(folderPath)) continue;
        final key = decoded.substring(folderPath.length).replaceFirst(RegExp(r'^/'), '');
        if (key.isEmpty || !key.startsWith(prefix)) continue;
        final size = int.tryParse(
                node.getElement('getcontentlength')?.innerText ?? '') ??
            0;
        final modified = DateTime.tryParse(
            node.getElement('getlastmodified')?.innerText ?? '');
        entries.add(RemoteEntry(
          key: key,
          size: size,
          modifiedAt: modified,
          etag: node.getElement('getetag')?.innerText,
        ));
        if (entries.length >= max) break;
      }
      entries.sort((RemoteEntry a, RemoteEntry b) => b.key.compareTo(a.key));
      return entries;
    } finally {
      client.close(force: true);
    }
  }
}
