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
    required this.region,
    required this.bucket,
    required this.prefix,
    required this.accessKey,
    required this.secretKey,
    DateTime Function()? clock,
  })  : _endpoint = _parseEndpoint(endpoint),
        _clock = clock ?? DateTime.now;

  final Uri _endpoint;
  final String region;
  final String bucket;
  final String prefix;
  final String accessKey;
  final String secretKey;
  final DateTime Function() _clock;

  static const int maxObjectBytes = 64 * 1024 * 1024;

  static Uri _parseEndpoint(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('S3 Endpoint 必须是干净的 HTTPS 地址');
    }
    return uri;
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
      scheme: 'https',
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
      'host': _endpoint.host,
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
    final client = HttpClient();
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
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> testConnection() async {
    final uri = _objectUri('', <String, String>{'list-type': '2', 'max-keys': '1'});
    final response = await _send('GET', uri, Uint8List(0));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RemoteAuthException('S3 认证失败，请检查 Access Key 与 Secret Key');
    }
    if (response.statusCode != 200) {
      throw RemoteStoreException('S3 连接测试失败：HTTP ${response.statusCode}');
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
      throw RemoteStoreException('S3 下载失败：HTTP ${response.statusCode}');
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
      throw RemoteStoreException('S3 上传失败：HTTP ${response.statusCode}');
    }
    return response.headers.value(HttpHeaders.etagHeader);
  }

  @override
  Future<void> delete(String key) async {
    final response = await _send('DELETE', _objectUri(key), Uint8List(0));
    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteStoreException('S3 删除失败：HTTP ${response.statusCode}');
    }
  }

  @override
  Future<List<RemoteEntry>> list({String prefix = '', int max = 200}) async {
    final uri = _objectUri('', <String, String>{
      'list-type': '2',
      'prefix': '$_rootPrefix$prefix',
      'max-keys': '$max',
    });
    final response = await _send('GET', uri, Uint8List(0));
    final text = utf8.decode(response.bytes);
    if (response.statusCode != 200) {
      throw RemoteStoreException('S3 列目录失败：HTTP ${response.statusCode}');
    }
    final document = XmlDocument.parse(text);
    final entries = <RemoteEntry>[];
    for (final node in document.findAllElements('Contents')) {
      final key = node.getElement('Key')?.innerText ?? '';
      if (key.isEmpty) continue;
      final relative = key.startsWith(_rootPrefix)
          ? key.substring(_rootPrefix.length)
          : key;
      entries.add(RemoteEntry(
        key: relative,
        size: int.tryParse(node.getElement('Size')?.innerText ?? '') ?? 0,
        modifiedAt:
            DateTime.tryParse(node.getElement('LastModified')?.innerText ?? ''),
        etag: node.getElement('ETag')?.innerText.replaceAll('"', ''),
      ));
    }
    return entries;
  }
}
