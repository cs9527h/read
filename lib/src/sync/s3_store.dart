import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

import 'remote_store.dart';

/// Minimal S3-compatible object storage adapter using AWS Signature V4,
/// path-style addressing and conditional writes. Works with MinIO, Cloudflare
/// R2, Backblaze B2 S3 endpoints and similar providers when region is correct.
class _S3Response {
  const _S3Response(this.statusCode, this.headers, this.bytes);
  final int statusCode;
  final HttpHeaders headers;
  final Uint8List bytes;
}

class S3Store implements RemoteObjectStore {
  S3Store({
    required String endpoint,
    required String region,
    required this.bucket,
    required this.prefix,
    required this.accessKey,
    required this.secretKey,
    DateTime Function()? clock,
    HttpClient Function()? httpClientFactory,
  })  : _endpoint = _parseEndpoint(endpoint),
        region = effectiveRegion(region),
        _clock = clock ?? DateTime.now,
        _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Uri _endpoint;
  final String region;
  final String bucket;
  final String prefix;
  final String accessKey;
  final String secretKey;
  final DateTime Function() _clock;
  final HttpClient Function() _httpClientFactory;

  static const int maxObjectBytes = 64 * 1024 * 1024;

  static Uri _parseEndpoint(String raw) {
    final uri = Uri.tryParse(raw.trim());
    // 允许 http：本地/内网 MinIO 常以明文部署；公网仍由用户自行选择 https。
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('S3 Endpoint 必须是干净的 http/https 地址');
    }
    return uri;
  }

  /// 签名所用的 region。'auto'/空在 SigV4 里不是合法 region，绝大多数 S3
  /// 兼容服务（MinIO/R2/B2/OSS）接受 us-east-1 作为签名 scope，回退到它
  /// 可修复 region 填 auto 时的 SignatureDoesNotMatch。
  static String effectiveRegion(String region) {
    final trimmed = region.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'auto') return 'us-east-1';
    return trimmed;
  }

  @override
  String get displayName => 'S3 · ${_endpoint.host}/$bucket';

  String get _rootPrefix {
    final cleaned = prefix.split('/').where((String e) => e.isNotEmpty).join('/');
    return cleaned.isEmpty ? '' : '$cleaned/';
  }

  String _objectKey(String key) => '$_rootPrefix$key';

  Uri _objectUri(String key, [Map<String, String>? query]) {
    final base = _endpoint.pathSegments.where((String e) => e.isNotEmpty).toList();
    final object = _objectKey(key).split('/').where((String e) => e.isNotEmpty);
    return Uri(
      scheme: _endpoint.scheme,
      host: _endpoint.host,
      port: _endpoint.hasPort ? _endpoint.port : null,
      pathSegments: <String>[...base, bucket, ...object],
      queryParameters: query,
    );
  }

  static String _encode(String value) {
    final bytes = utf8.encode(value);
    final buffer = StringBuffer();
    for (final byte in bytes) {
      final isUnreserved = (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2D ||
          byte == 0x2E ||
          byte == 0x5F ||
          byte == 0x7E;
      if (isUnreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return buffer.toString();
  }

  String _canonicalUri(Uri uri) {
    final encoded = uri.pathSegments.map(_encode).join('/');
    return '/$encoded';
  }

  String _canonicalQuery(Map<String, String> query) {
    if (query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys
        .map((String k) => '${_encode(k)}=${_encode(query[k]!)}')
        .join('&');
  }

  ({String authorization, String amzDate, String payloadHash}) _sign(
    String method,
    Uri uri,
    Uint8List body,
  ) {
    final now = _clock().toUtc();
    final amzDate =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';
    final dateStamp = amzDate.substring(0, 8);
    final payloadHash = sha256.convert(body).toString();
    final headers = <String, String>{
      // Non-default HTTPS ports are part of the HTTP Host header and must
      // also be signed for MinIO and other self-hosted endpoints.
      'host': _endpoint.hasPort ? '${_endpoint.host}:${_endpoint.port}' : _endpoint.host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
    };
    final signedHeaders = headers.keys.join(';');
    final canonicalHeaders =
        headers.entries.map((MapEntry<String, String> e) => '${e.key}:${e.value}\n').join();
    final canonicalRequest = '$method\n${_canonicalUri(uri)}\n'
        '${_canonicalQuery(uri.queryParameters)}\n'
        '$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final scope = '$dateStamp/$region/s3/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$scope\n'
        '${sha256.convert(utf8.encode(canonicalRequest))}';
    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    final signingKey = hmac(
      hmac(hmac(hmac(utf8.encode('AWS4$secretKey'), dateStamp), region), 's3'),
      'aws4_request',
    );
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign));
    final authorization = 'AWS4-HMAC-SHA256 Credential=$accessKey/$scope, '
        'SignedHeaders=$signedHeaders, Signature=$signature';
    return (authorization: authorization, amzDate: amzDate, payloadHash: payloadHash);
  }

  Future<_S3Response> _send(
    String method,
    Uri uri,
    Uint8List body, {
    Map<String, String>? headers,
  }) async {
    final signed = _sign(method, uri, body);
    final client = _httpClientFactory();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, signed.authorization);
      request.headers.set('x-amz-content-sha256', signed.payloadHash);
      request.headers.set('x-amz-date', signed.amzDate);
      headers?.forEach((String k, String v) => request.headers.set(k, v));
      if (body.isNotEmpty) {
        request.headers.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(const Duration(seconds: 40));
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > maxObjectBytes + 1024 * 1024) {
          throw const RemoteStoreException('S3 响应超过安全上限');
        }
      }
      return _S3Response(response.statusCode, response.headers, builder.takeBytes());
    } on RemoteStoreException {
      rethrow;
    } on SocketException {
      // 网络中断/不可达统一归类，供 UI 显示明确「同步失败」而非泄漏底层异常。
      throw const RemoteStoreException('S3 网络连接失败，请检查网络后重试');
    } on HttpException {
      throw const RemoteStoreException('S3 响应异常，请稍后重试');
    } on TimeoutException {
      throw const RemoteStoreException('S3 请求超时，请稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  /// Extract only the S3 error code and region hint, never echo credentials
  /// or the full remote response into UI/logs.
  static String _errorDetail(Uint8List body) {
    try {
      final doc = XmlDocument.parse(utf8.decode(body));
      final code = doc.findAllElements('Code').firstOrNull?.innerText.trim();
      final region = doc.findAllElements('Region').firstOrNull?.innerText.trim();
      return <String>[
        if (code != null && code.isNotEmpty) code,
        if (region != null && region.isNotEmpty) '服务端区域：$region',
      ].join(' · ');
    } catch (_) {
      return '';
    }
  }

  static String _statusMessage(String action, _S3Response response) {
    final detail = _errorDetail(response.bytes);
    return 'S3 $action失败：HTTP ${response.statusCode}'
        '${detail.isEmpty ? '' : ' · $detail'}';
  }

  /// 提取 S3 错误 XML 里的 <Code> 与 <Message>（仅用于内部兼容判断，
  /// 绝不拼进 UI 文案或日志；UI 用的是 [_statusMessage] 的脱敏结果）。
  static ({String code, String message}) _errorParts(Uint8List body) {
    try {
      final doc = XmlDocument.parse(utf8.decode(body));
      final code = doc.findAllElements('Code').firstOrNull?.innerText.trim() ?? '';
      final message =
          doc.findAllElements('Message').firstOrNull?.innerText.trim() ?? '';
      return (code: code, message: message);
    } catch (_) {
      return (code: '', message: '');
    }
  }

  /// 判断响应是否明确表示「服务端不支持条件请求头」。
  ///
  /// 不同 S3 兼容实现对 If-Match / If-None-Match 的态度不同：
  /// - AWS S3 / R2 / 现代 MinIO：原生支持；
  /// - 部分旧 MinIO、Backblaze B2 S3、网关型实现：返回 501，或
  ///   400 InvalidArgument 且 message 明确提到条件头。
  /// 只认这些明确信号，绝不把普通 400（如签名错误）误判为兼容问题，
  /// 否则会掩盖真实故障并可能放宽乐观锁。
  static bool isConditionalUnsupported(int statusCode, Uint8List body) {
    if (statusCode == 501) return true;
    if (statusCode != 400) return false;
    final parts = _errorParts(body);
    final code = parts.code.toLowerCase();
    final message = parts.message.toLowerCase();
    if (code == 'notimplemented' || code == 'methodnotallowed') return true;
    if (code == 'invalidargument' || code == 'invalidrequest') {
      return message.contains('if-match') ||
          message.contains('if-none-match') ||
          message.contains('conditional');
    }
    return false;
  }

  @override
  Future<void> testConnection() async {
    final uri = _objectUri('', <String, String>{'list-type': '2', 'max-keys': '1'});
    final response = await _send('GET', uri, Uint8List(0));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RemoteAuthException('S3 认证失败，请检查 Access Key 与 Secret Key');
    }
    if (response.statusCode != 200) {
      throw RemoteStoreException(_statusMessage('连接测试', response));
    }
  }

  @override
  Future<RemoteSnapshot?> read(String key) async {
    final response = await _send('GET', _objectUri(key), Uint8List(0));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RemoteAuthException('S3 认证失败');
    }
    if (response.statusCode != 200) {
      throw RemoteStoreException(_statusMessage('下载', response));
    }
    if (response.bytes.length > maxObjectBytes) {
      throw const RemoteStoreException('S3 文件超过 64MB 安全上限');
    }
    return RemoteSnapshot(
      bytes: response.bytes,
      etag: response.headers.value(HttpHeaders.etagHeader),
    );
  }

  @override
  Future<String?> write(Uint8List bytes, String key, {String? expectedEtag}) async {
    if (bytes.length > maxObjectBytes) {
      throw const RemoteStoreException('S3 文件超过 64MB 安全上限');
    }
    final headers = <String, String>{
      if (expectedEtag == null)
        'If-None-Match': '*'
      else
        'If-Match': expectedEtag,
    };
    final response = await _send('PUT', _objectUri(key), bytes, headers: headers);
    if (response.statusCode == 412) {
      throw const RemoteConflictException('S3 对象已被其他设备更新');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RemoteAuthException('S3 上传认证失败');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 某些 S3 兼容服务不支持条件请求头。改用客户端侧乐观锁降级，
      // 而不是让整个同步失败。降级仍严格校验 ETag，绝不静默覆盖。
      if (isConditionalUnsupported(response.statusCode, response.bytes)) {
        return _writeWithoutConditionalSupport(bytes, key, expectedEtag);
      }
      throw RemoteStoreException(_statusMessage('上传', response));
    }
    return response.headers.value(HttpHeaders.etagHeader);
  }

  /// 服务端不支持条件请求头时的降级路径。
  ///
  /// 用一次 GET 读取当前 ETag，模拟服务端条件写语义：
  /// - expectedEtag == null（首次创建）：远端若已存在对象则视为冲突，不覆盖；
  /// - expectedEtag != null（覆盖更新）：远端 ETag 与期望不一致则冲突；
  /// - 校验通过才执行无条件 PUT。
  /// 这样即使服务不支持 If-Match/If-None-Match，也不会因为一次失败而中断同步，
  /// 更不会因为忽略冲突而把较新的云端数据覆盖掉。
  Future<String?> _writeWithoutConditionalSupport(
    Uint8List bytes,
    String key,
    String? expectedEtag,
  ) async {
    final current = await read(key);
    final currentEtag = current?.etag;
    if (expectedEtag == null) {
      if (current != null) {
        throw const RemoteConflictException('云端对象已存在，且服务不支持条件请求，未覆盖');
      }
    } else if (currentEtag != expectedEtag) {
      throw const RemoteConflictException('云端对象已被其他设备更新，未覆盖');
    }
    final response = await _send('PUT', _objectUri(key), bytes);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RemoteAuthException('S3 上传认证失败');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteStoreException(_statusMessage('上传', response));
    }
    return response.headers.value(HttpHeaders.etagHeader);
  }

  @override
  Future<void> delete(String key) async {
    final response = await _send('DELETE', _objectUri(key), Uint8List(0));
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteStoreException(_statusMessage('删除', response));
    }
  }

  /// Parses one ListObjectsV2 response without relying on a specific XML
  /// namespace prefix. Keeping this pure makes pagination and object-key
  /// handling independently testable without any real account credentials.
  static ({
    List<RemoteEntry> entries,
    bool truncated,
    String? nextToken,
  }) parseListObjectsV2(String xml, {String rootPrefix = ''}) {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    if (root.name.local != 'ListBucketResult') {
      throw const FormatException('S3 列目录响应不是 ListBucketResult');
    }

    String? valueOf(XmlElement parent, String field) {
      for (final child in parent.childElements) {
        if (child.name.local == field) return child.innerText;
      }
      return null;
    }

    final entries = <RemoteEntry>[];
    for (final child in root.childElements) {
      if (child.name.local != 'Contents') continue;
      final key = valueOf(child, 'Key') ?? '';
      if (key.isEmpty || !key.startsWith(rootPrefix)) continue;
      final relative = key.substring(rootPrefix.length);
      entries.add(RemoteEntry(
        key: relative,
        size: int.tryParse(valueOf(child, 'Size') ?? '') ?? 0,
        modifiedAt: DateTime.tryParse(valueOf(child, 'LastModified') ?? ''),
        etag: valueOf(child, 'ETag')?.replaceAll('"', ''),
      ));
    }

    final truncated = valueOf(root, 'IsTruncated')?.trim().toLowerCase() == 'true';
    final token = valueOf(root, 'NextContinuationToken')?.trim();
    return (
      entries: entries,
      truncated: truncated,
      nextToken: token == null || token.isEmpty ? null : token,
    );
  }

  @override
  Future<List<RemoteEntry>> list({String prefix = '', int max = 200}) async {
    if (max <= 0) return <RemoteEntry>[];
    final entries = <RemoteEntry>[];
    final keys = <String>{};
    final seenTokens = <String>{};
    String? token;
    // A service may cap max-keys below the requested maximum. Fetch every
    // continuation page until max distinct objects have been collected.
    for (int pages = 0; entries.length < max; pages++) {
      if (pages >= 1000) {
        throw const RemoteStoreException('S3 列目录分页次数超过安全上限');
      }
      final query = <String, String>{
        'list-type': '2',
        'prefix': '$_rootPrefix$prefix',
        'max-keys': '${(max - entries.length).clamp(1, 1000)}',
        if (token != null) 'continuation-token': token,
      };
      final response = await _send(
        'GET',
        _objectUri('', query),
        Uint8List(0),
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const RemoteAuthException('S3 列目录认证失败');
      }
      if (response.statusCode != 200) {
        throw RemoteStoreException('S3 列目录失败：HTTP ${response.statusCode}');
      }
      final ({
        List<RemoteEntry> entries,
        bool truncated,
        String? nextToken,
      }) page;
      try {
        page = parseListObjectsV2(
          utf8.decode(response.bytes),
          rootPrefix: _rootPrefix,
        );
      } on FormatException {
        throw const RemoteStoreException('S3 列目录返回无效 XML，未修改本地数据');
      } catch (_) {
        throw const RemoteStoreException('S3 列目录 XML 解析失败，未修改本地数据');
      }
      for (final entry in page.entries) {
        if (!entry.key.startsWith(prefix) || !keys.add(entry.key)) continue;
        entries.add(entry);
        if (entries.length >= max) break;
      }
      if (!page.truncated) break;
      final next = page.nextToken;
      if (next == null || !seenTokens.add(next)) {
        throw const RemoteStoreException('S3 列目录未返回有效的下一页游标');
      }
      token = next;
    }
    return entries;
  }
}
