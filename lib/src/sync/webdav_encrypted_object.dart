import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One atomic WebDAV object with optimistic concurrency via HTTP ETag.
///
/// This transport does NOT sync anything automatically. It accepts only
/// already-encrypted bytes from EncryptedSyncEnvelope and requires HTTPS.
/// Credentials are passed in memory, not logged, committed or hardcoded.
class WebDavEncryptedObject {
  WebDavEncryptedObject({
    required this.fileUrl,
    required this.username,
    required this.password,
  }) {
    if (fileUrl.scheme != 'https' ||
        fileUrl.userInfo.isNotEmpty ||
        fileUrl.query.isNotEmpty ||
        fileUrl.fragment.isNotEmpty ||
        fileUrl.path.isEmpty || fileUrl.path.endsWith('/')) {
      throw ArgumentError('WebDAV 只能使用不含凭据和参数的 HTTPS 文件地址');
    }
  }

  final Uri fileUrl;
  final String username;
  final String password;

  Future<WebDavSnapshot?> read() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(fileUrl);
      _authorize(request);
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw WebDavSyncException('下载失败：HTTP ' + response.statusCode.toString());
      }
      final length = response.contentLength;
      if (length > 16 * 1024 * 1024) {
        await response.drain<void>();
        throw const WebDavSyncException('远端同步文件超过 16MB');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > 16 * 1024 * 1024) {
          throw const WebDavSyncException('远端同步文件超过 16MB');
        }
      }
      return WebDavSnapshot(
        bytes: builder.takeBytes(),
        etag: response.headers.value(HttpHeaders.etagHeader),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> write(Uint8List encryptedBytes, {String? expectedEtag}) async {
    // New sync objects must be created explicitly with If-None-Match to
    // avoid silently overwriting an existing remote object.
    if (encryptedBytes.length > 16 * 1024 * 1024) {
      throw const WebDavSyncException('同步数据超过 16MB');
    }
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.putUrl(fileUrl);
      _authorize(request);
      request.headers.contentType = ContentType('application', 'octet-stream');
      if (expectedEtag == null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, '*');
      } else {
        request.headers.set(HttpHeaders.ifMatchHeader, expectedEtag);
      }
      request.add(encryptedBytes);
      final response = await request.close().timeout(const Duration(seconds: 30));
      await response.drain<void>();
      if (response.statusCode == HttpStatus.preconditionFailed ||
          response.statusCode == HttpStatus.conflict) {
        throw const WebDavConflictException('远端文件已被其他设备更新，请重新下载并合并');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WebDavSyncException('上传失败：HTTP ' + response.statusCode.toString());
      }
      return response.headers.value(HttpHeaders.etagHeader);
    } finally {
      client.close(force: true);
    }
  }

  void _authorize(HttpClientRequest request) {
    // Never follow a redirect with cloud credentials attached.
    request.followRedirects = false;
    final value = base64Encode(utf8.encode(username + ':' + password));
    request.headers.set(HttpHeaders.authorizationHeader, 'Basic ' + value);
  }
}

class WebDavSnapshot {
  const WebDavSnapshot({required this.bytes, required this.etag});
  final Uint8List bytes;
  final String? etag;
}

class WebDavSyncException implements Exception {
  const WebDavSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WebDavConflictException extends WebDavSyncException {
  const WebDavConflictException(super.message);
}
