import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/remote_store.dart';
import 'package:read/src/sync/s3_store.dart';

/// 一个只实现最小 S3 语义的本地 HTTP 服务，用于真实验证 S3Store 的
/// PUT/GET/HEAD 行为与条件请求兼容逻辑（无需任何真实云账号）。
class _FakeS3 {
  _FakeS3({this.rejectConditional = false});

  final bool rejectConditional;
  final Map<String, Uint8List> objects = <String, Uint8List>{};
  final Map<String, String> etags = <String, String>{};
  int _etagSeq = 0;
  HttpServer? _server;
  final List<String> seenHeaders = <String>[];

  int get port => _server!.port;

  static const String _okXml =
      '<?xml version="1.0"?><ListBucketResult>'
      '<IsTruncated>false</IsTruncated></ListBucketResult>';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    await server.close(force: true);
    _server = null;
  }

  void _reply(HttpResponse res, int status, List<int> body,
      {String? etag, String contentType = 'application/octet-stream'}) {
    res.statusCode = status;
    res.headers.contentType = ContentType.parse(contentType);
    if (etag != null) res.headers.set(HttpHeaders.etagHeader, etag);
    res.add(body);
  }

  Future<void> _handle(HttpRequest req) async {
    final String path = req.uri.path;
    final String key = Uri.decodeComponent(path.split('/').skip(2).join('/'));
    final String? ifMatch = req.headers.value(HttpHeaders.ifMatchHeader);
    final String? ifNoneMatch = req.headers.value(HttpHeaders.ifNoneMatchHeader);
    if (ifMatch != null) seenHeaders.add('If-Match:$ifMatch');
    if (ifNoneMatch != null) seenHeaders.add('If-None-Match:$ifNoneMatch');

    // 模拟不支持条件请求的服务商。
    if (rejectConditional && (ifMatch != null || ifNoneMatch != null)) {
      _reply(
        req.response,
        400,
        utf8.encode(
          '<Error><Code>InvalidArgument</Code>'
          '<Message>Conditional requests (If-Match) are not supported</Message></Error>',
        ),
        contentType: 'application/xml',
      );
      await req.response.close();
      return;
    }

    switch (req.method) {
      case 'GET':
        if (path.endsWith('/') || req.uri.queryParameters.containsKey('list-type')) {
          _reply(req.response, 200, utf8.encode(_okXml),
              contentType: 'application/xml');
          break;
        }
        final data = objects[key];
        if (data == null) {
          _reply(req.response, 404, const <int>[]);
        } else {
          _reply(req.response, 200, data, etag: etags[key]);
        }
        break;
      case 'PUT':
        final body = await req.fold<BytesBuilder>(
          BytesBuilder(),
          (b, chunk) => b..add(chunk as List<int>),
        );
        if (ifNoneMatch == '*' && objects.containsKey(key)) {
          _reply(req.response, 412, const <int>[]);
          break;
        }
        if (ifMatch != null && ifMatch != etags[key]) {
          _reply(req.response, 412, const <int>[]);
          break;
        }
        final newEtag = '"${++_etagSeq}"';
        objects[key] = body.takeBytes();
        etags[key] = newEtag;
        _reply(req.response, 200, const <int>[], etag: newEtag);
        break;
      case 'HEAD':
        if (!objects.containsKey(key)) {
          _reply(req.response, 404, const <int>[]);
        } else {
          _reply(req.response, 200, const <int>[], etag: etags[key]);
        }
        break;
      default:
        _reply(req.response, 405, const <int>[]);
    }
    await req.response.close();
  }
}

S3Store _store(_FakeS3 server, {HttpClient Function()? factory}) => S3Store(
      endpoint: 'http://127.0.0.1:${server.port}',
      region: 'us-east-1',
      bucket: 'books',
      prefix: 'read',
      accessKey: 'AKIAFAKE',
      secretKey: 'secret',
      httpClientFactory: factory,
    );

void main() {
  late _FakeS3 server;

  setUp(() async {
    server = _FakeS3();
    await server.start();
  });

  tearDown(() async {
    await server.stop();
  });

  test('连接测试：正确配置返回成功', () async {
    await _store(server).testConnection();
  });

  test('上传新文件后下载内容完全一致', () async {
    final store = _store(server);
    final bytes = Uint8List.fromList(utf8.encode('一本测试小说\n第一章……'));
    final etag = await store.write(bytes, 'a.txt');
    expect(etag, isNotNull);
    final snapshot = await store.read('a.txt');
    expect(snapshot, isNotNull);
    expect(snapshot!.bytes, equals(bytes));
    expect(snapshot.etag, etag);
  });

  test('带正确 ETag 覆盖更新成功', () async {
    final store = _store(server);
    final first = await store.write(Uint8List.fromList(utf8.encode('v1')), 'b.txt');
    final second = await store.write(Uint8List.fromList(utf8.encode('v2')), 'b.txt',
        expectedEtag: first);
    expect(second, isNot(first));
    final snapshot = await store.read('b.txt');
    expect(utf8.decode(snapshot!.bytes), 'v2');
  });

  test('ETag 过期时覆盖被拒绝，抛出冲突异常（不丢数据）', () async {
    final store = _store(server);
    await store.write(Uint8List.fromList(utf8.encode('v1')), 'c.txt');
    expect(
      () => store.write(Uint8List.fromList(utf8.encode('v2')), 'c.txt',
          expectedEtag: '"stale"'),
      throwsA(isA<RemoteConflictException>()),
    );
    // 原内容未被破坏。
    expect(utf8.decode((await store.read('c.txt'))!.bytes), 'v1');
  });

  test('首次上传时远端已存在对象则冲突，绝不覆盖', () async {
    final store = _store(server);
    await store.write(Uint8List.fromList(utf8.encode('existing')), 'd.txt');
    expect(
      () => store.write(Uint8List.fromList(utf8.encode('overwrite')), 'd.txt'),
      throwsA(isA<RemoteConflictException>()),
    );
    expect(utf8.decode((await store.read('d.txt'))!.bytes), 'existing');
  });

  test('读取不存在的文件返回 null', () async {
    expect(await _store(server).read('missing.txt'), isNull);
  });

  test('服务端不支持条件请求时自动降级为客户端乐观锁，上传仍成功', () async {
    final conditionalServer = _FakeS3(rejectConditional: true);
    await conditionalServer.start();
    addTearDown(conditionalServer.stop);
    final store = _store(conditionalServer);

    // 首次创建：降级路径先 GET（404），确认不存在后无条件 PUT。
    final bytes = Uint8List.fromList(utf8.encode('降级上传成功'));
    final etag = await store.write(bytes, 'fallback.txt');
    expect(etag, isNotNull);
    expect((await store.read('fallback.txt'))!.bytes, equals(bytes));

    // 服务端确实收到了带条件头的请求（降级前先尝试过标准路径）。
    expect(conditionalServer.seenHeaders,
        contains('If-None-Match:*'));
  });

  test('不支持条件请求的服务端上，过期 ETag 覆盖仍被拒绝', () async {
    final conditionalServer = _FakeS3(rejectConditional: true);
    await conditionalServer.start();
    addTearDown(conditionalServer.stop);
    final store = _store(conditionalServer);

    await store.write(Uint8List.fromList(utf8.encode('old')), 'e.txt');
    expect(
      () => store.write(Uint8List.fromList(utf8.encode('new')), 'e.txt',
          expectedEtag: '"wrong-etag"'),
      throwsA(isA<RemoteConflictException>()),
    );
    // 旧内容保持。
    expect(utf8.decode((await store.read('e.txt'))!.bytes), 'old');
  });

  test('网络中断不会破坏已存在数据（连接失败抛出而非静默成功）', () async {
    final store = _store(server);
    await store.write(Uint8List.fromList(utf8.encode('safe')), 'f.txt');
    await server.stop();
    server = _FakeS3();
    await server.start(); // 新空服务，模拟旧连接断开
    expect(
      () => store.read('f.txt'),
      throwsA(isA<RemoteStoreException>()),
    );
  });

  group('isConditionalUnsupported 纯判断（保守识别，不误判普通错误）', () {
    bool unsupported(int status, String xml) =>
        S3Store.isConditionalUnsupported(status, Uint8List.fromList(utf8.encode(xml)));

    test('识别 501 与条件头 InvalidArgument / NotImplemented', () {
      expect(unsupported(501, ''), isTrue);
      expect(
        unsupported(
          400,
          '<Error><Code>InvalidArgument</Code><Message>if-match not supported</Message></Error>',
        ),
        isTrue,
      );
      expect(unsupported(400, '<Error><Code>NotImplemented</Code></Error>'), isTrue);
    });

    test('不把签名错误、普通 400 误判为兼容问题', () {
      expect(unsupported(403, '<Error><Code>InvalidAccessKeyId</Code></Error>'), isFalse);
      expect(unsupported(400, '<Error><Code>MalformedXML</Code></Error>'), isFalse);
      expect(unsupported(404, ''), isFalse);
    });
  });
}
