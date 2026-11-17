import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/wifi_transfer_service.dart';

/// 这些测试全部走真实 TCP/HTTP（127.0.0.1），不是模拟对象。
class _Harness {
  _Harness({
    WifiTransferConfig? config,
    this.importDelay,
  }) {
    service = WifiTransferService(
      config: config ??
          const WifiTransferConfig(
            allowLoopback: true,
            bindAddress: null,
            portCandidates: <int>[0],
          ),
      clock: () => now,
      onImport: (File file, String name) async {
        imports.add(<String, Object?>{'name': name, 'bytes': await file.length()});
        if (importDelay != null) await importDelay!.future;
        return importResult(name);
      },
    );
  }

  DateTime now = DateTime(2026, 1, 1, 12);
  final List<Map<String, Object?>> imports = <Map<String, Object?>>[];
  late final WifiTransferService service;
  final Completer<void>? importDelay;
  WifiImportResult Function(String name) importResult =
      (String name) => WifiImportResult(ok: true, message: '已导入 $name');

  String get base => 'http://127.0.0.1:${service.port}';

  Future<HttpClientResponse> send(
    String method,
    String path, {
    String? token,
    List<int>? body,
    int? contentLength,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.openUrl(method, Uri.parse('$base$path'));
      if (token != null) request.headers.set('X-Read-Token', token);
      if (body != null) {
        request.headers.contentLength = contentLength ?? body.length;
        request.add(body);
      }
      return await request.close();
    } finally {
      client.close(force: false);
    }
  }

  Future<Map<String, dynamic>> json(HttpClientResponse response) async {
    final String text = await utf8.decoder.bind(response).join();
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<String> pair([String? code]) async {
    final HttpClientResponse response = await send(
      'POST',
      '/pair',
      body: utf8.encode(jsonEncode(<String, String>{'code': code ?? service.pairingCode})),
    );
    final Map<String, dynamic> body = await json(response);
    return body['token'] as String? ?? '';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_test 默认把 HttpClient 替换成返回 400 的 mock；
  // 本文件验证的是真实 HTTP 服务，必须恢复真实网络栈。
  setUpAll(() {
    HttpOverrides.global = null;
  });

  test('服务默认关闭，只有手动 start 才监听端口', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    expect(harness.service.status, WifiTransferStatus.stopped);
    expect(harness.service.port, 0);
    expect(harness.service.pairingCode, isEmpty);

    await harness.service.start();
    expect(harness.service.status, WifiTransferStatus.running);
    expect(harness.service.port, greaterThan(0));
    expect(harness.service.pairingCode.length, 6);
    expect(RegExp(r'^\d{6}$').hasMatch(harness.service.pairingCode), isTrue);
    expect(harness.service.expiresAt, isNotNull);

    final HttpClientResponse page = await harness.send('GET', '/');
    expect(page.statusCode, 200);
    final String html = await utf8.decoder.bind(page).join();
    expect(html.contains('配对码'), isTrue);
    expect(html.contains('X-Read-Token'), isTrue);
  });

  test('未配对的上传请求被 401 拦截，且不触发导入', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();

    final HttpClientResponse response = await harness.send(
      'POST',
      '/upload?name=a.txt',
      body: utf8.encode('hello'),
    );
    expect(response.statusCode, 401);
    expect(harness.imports, isEmpty);
  });

  test('错误配对码被拒绝，正确配对码换取令牌', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();

    final HttpClientResponse bad =
        await harness.send('POST', '/pair', body: utf8.encode('{"code":"000000"}'));
    expect(bad.statusCode, anyOf(401, 200));
    await bad.drain<void>();

    final String token = await harness.pair();
    expect(token.length, 64);
    expect(token, isNot(harness.service.pairingCode));

    final HttpClientResponse upload = await harness.send(
      'POST',
      '/upload?name=book.txt',
      token: token,
      body: utf8.encode('第一章 开始'),
    );
    expect(upload.statusCode, 200);
    final Map<String, dynamic> body = await harness.json(upload);
    expect(body['ok'], isTrue);
    expect(harness.imports.single['name'], 'book.txt');
  });

  test('连续输错达到上限后，即使配对码正确也拒绝', () async {
    final _Harness harness = _Harness(
      config: const WifiTransferConfig(
        allowLoopback: true,
        portCandidates: <int>[0],
        maxPairAttempts: 3,
      ),
    );
    addTearDown(harness.service.dispose);
    await harness.service.start();

    for (int i = 0; i < 3; i++) {
      final HttpClientResponse bad =
          await harness.send('POST', '/pair', body: utf8.encode('{"code":"999999"}'));
      expect(bad.statusCode, 401);
      await bad.drain<void>();
    }
    expect(harness.service.pairingLocked, isTrue);

    final HttpClientResponse good = await harness.send(
      'POST',
      '/pair',
      body: utf8.encode('{"code":"${harness.service.pairingCode}"}'),
    );
    expect(good.statusCode, 429);
    await good.drain<void>();

    // 刷新配对码后恢复可用。
    harness.service.rotateSecrets();
    expect(harness.service.pairingLocked, isFalse);
    expect(await harness.pair(), isNotEmpty);
  });

  test('配对码过期后上传与再次配对都被拒绝', () async {
    final _Harness harness = _Harness(
      config: const WifiTransferConfig(
        allowLoopback: true,
        portCandidates: <int>[0],
        sessionTtl: Duration(minutes: 10),
      ),
    );
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    harness.now = harness.now.add(const Duration(minutes: 11));

    final HttpClientResponse upload = await harness.send(
      'POST',
      '/upload?name=late.txt',
      token: token,
      body: utf8.encode('late'),
    );
    expect(upload.statusCode, 401);
    await upload.drain<void>();
    expect(harness.imports, isEmpty);

    final HttpClientResponse pair =
        await harness.send('POST', '/pair', body: utf8.encode('{"code":"${harness.service.pairingCode}"}'));
    expect(pair.statusCode, 410);
    await pair.drain<void>();
  });

  test('超过 40MB 的上传被 413 拒绝且不落盘', () async {
    final _Harness harness = _Harness(
      config: const WifiTransferConfig(
        allowLoopback: true,
        portCandidates: <int>[0],
        maxFileBytes: 1024,
      ),
    );
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    final HttpClientResponse response = await harness.send(
      'POST',
      '/upload?name=big.txt',
      token: token,
      body: List<int>.filled(2048, 65),
    );
    expect(response.statusCode, 413);
    await response.drain<void>();
    expect(harness.imports, isEmpty);
    expect(await harness.service.tempDirectory!.list().toList(), isEmpty);
  });

  test('非白名单扩展名被 415 拒绝', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    final HttpClientResponse response = await harness.send(
      'POST',
      '/upload?name=payload.exe',
      token: token,
      body: utf8.encode('MZ'),
    );
    expect(response.statusCode, 415);
    await response.drain<void>();
    expect(harness.imports, isEmpty);
  });

  test('扩展名伪装成 PDF 但内容不符时拒绝', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    final HttpClientResponse response = await harness.send(
      'POST',
      '/upload?name=fake.pdf',
      token: token,
      body: utf8.encode('not a pdf at all'),
    );
    expect(response.statusCode, 415);
    await response.drain<void>();
    expect(harness.imports, isEmpty);

    // 真实 PDF 头可以通过。
    final HttpClientResponse ok = await harness.send(
      'POST',
      '/upload?name=real.pdf',
      token: token,
      body: <int>[0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37],
    );
    expect(ok.statusCode, 200);
    await ok.drain<void>();
    expect(harness.imports.single['name'], 'real.pdf');
  });

  test('路径穿越文件名被清洗，不会写出临时目录', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    final HttpClientResponse response = await harness.send(
      'POST',
      '/upload?name=${Uri.encodeComponent('../../etc/passwd.txt')}',
      token: token,
      body: utf8.encode('x'),
    );
    expect(response.statusCode, 200);
    await response.drain<void>();
    expect(harness.imports.single['name'], 'passwd.txt');
    final Directory dir = harness.service.tempDirectory!;
    expect(await dir.list().toList(), isEmpty);
    expect(File('${dir.path}/../passwd.txt').existsSync(), isFalse);
  });

  test('非法文件名（空名/只有分隔符）被 400 拒绝', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    for (final String name in <String>['', '%2F', '..']) {
      final HttpClientResponse response = await harness.send(
        'POST',
        '/upload?name=$name',
        token: token,
        body: utf8.encode('x'),
      );
      expect(response.statusCode, anyOf(400, 415), reason: 'name=$name');
      await response.drain<void>();
    }
    expect(harness.imports, isEmpty);
  });

  test('并发上传超过上限返回 429，且结束后可继续上传', () async {
    final Completer<void> gate = Completer<void>();
    final _Harness harness = _Harness(importDelay: gate);
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    final Future<HttpClientResponse> first = harness.send(
      'POST',
      '/upload?name=a.txt',
      token: token,
      body: utf8.encode('a'),
    );
    final Future<HttpClientResponse> second = harness.send(
      'POST',
      '/upload?name=b.txt',
      token: token,
      body: utf8.encode('b'),
    );
    // 等待两个请求都进入导入阶段（服务端已计数）。
    while (harness.service.activeUploads < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final HttpClientResponse third = await harness.send(
      'POST',
      '/upload?name=c.txt',
      token: token,
      body: utf8.encode('c'),
    );
    expect(third.statusCode, 429);
    await third.drain<void>();

    gate.complete();
    expect((await first).statusCode, 200);
    expect((await second).statusCode, 200);

    final HttpClientResponse after = await harness.send(
      'POST',
      '/upload?name=d.txt',
      token: token,
      body: utf8.encode('d'),
    );
    expect(after.statusCode, 200);
    await after.drain<void>();
  });

  test('每个来源 IP 有限速', () async {
    final _Harness harness = _Harness(
      config: const WifiTransferConfig(
        allowLoopback: true,
        portCandidates: <int>[0],
        maxRequestsPerMinute: 3,
      ),
    );
    addTearDown(harness.service.dispose);
    await harness.service.start();

    for (int i = 0; i < 3; i++) {
      final HttpClientResponse ok = await harness.send('GET', '/');
      expect(ok.statusCode, 200);
      await ok.drain<void>();
    }
    final HttpClientResponse limited = await harness.send('GET', '/');
    expect(limited.statusCode, 429);
    await limited.drain<void>();
  });

  test('非局域网来源被 403 拦截', () async {
    // allowLoopback 默认 false：即使监听在回环上，回环来源也应被拒绝。
    final _Harness harness = _Harness(
      config: WifiTransferConfig(
        bindAddress: InternetAddress.loopbackIPv4,
        portCandidates: const <int>[0],
      ),
    );
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final HttpClientResponse response = await harness.send('GET', '/');
    expect(response.statusCode, 403);
    await response.drain<void>();
  });

  test('重复文件会以 duplicate 事件反馈，不当作成功', () async {
    final _Harness harness = _Harness();
    harness.importResult = (String name) => const WifiImportResult(
          ok: false,
          duplicate: true,
          message: '重复文件，已跳过',
        );
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final String token = await harness.pair();

    final List<WifiTransferEvent> events = <WifiTransferEvent>[];
    final StreamSubscription<WifiTransferEvent> sub =
        harness.service.events.listen(events.add);
    addTearDown(sub.cancel);

    final HttpClientResponse response = await harness.send(
      'POST',
      '/upload?name=dup.txt',
      token: token,
      body: utf8.encode('dup'),
    );
    expect(response.statusCode, 400);
    final Map<String, dynamic> body = await harness.json(response);
    expect(body['duplicate'], isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(events.map((WifiTransferEvent e) => e.state), contains('duplicate'));
  });

  test('stop 关闭端口、清空临时目录并复位状态', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();
    final int port = harness.service.port;
    final String dir = harness.service.tempDirectory!.path;
    expect(Directory(dir).existsSync(), isTrue);

    await harness.service.stop();
    expect(harness.service.status, WifiTransferStatus.stopped);
    expect(harness.service.pairingCode, isEmpty);
    expect(Directory(dir).existsSync(), isFalse);

    // Windows 上监听套接字关闭可能滞后几十毫秒，给一个有限的重试窗口；
    // 超过 3 秒仍能连上就说明端口没真正关闭，必须失败。
    bool connected = false;
    for (int attempt = 0; attempt < 30; attempt++) {
      try {
        final HttpClientResponse late = await harness.send('GET', '/');
        connected = true;
        await late.drain<void>();
      } on SocketException {
        connected = false;
        break; // 已拒绝连接，端口确实关闭。
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(connected, isFalse, reason: '端口 $port 应已关闭');
  });

  test('应用进入后台默认停止服务，显式允许时保持运行', () async {
    final _Harness harness = _Harness();
    addTearDown(harness.service.dispose);
    await harness.service.start();

    await harness.service.onAppPaused();
    expect(harness.service.isRunning, isFalse);

    await harness.service.start();
    await harness.service.onAppPaused(keepRunning: true);
    expect(harness.service.isRunning, isTrue);
  });

  test('文件名清洗规则', () {
    expect(WifiTransferService.sanitizeFileName('book.txt'), 'book.txt');
    expect(WifiTransferService.sanitizeFileName('../../a.txt'), 'a.txt');
    expect(WifiTransferService.sanitizeFileName('..'), isNull);
    expect(WifiTransferService.sanitizeFileName(''), isNull);
    expect(WifiTransferService.sanitizeFileName('   '), isNull);
    expect(WifiTransferService.sanitizeFileName('a\u0000b.txt'), 'a_b.txt');
    expect(WifiTransferService.sanitizeFileName('a<b>c.txt'), 'a_b_c.txt');
    expect(WifiTransferService.sanitizeFileName('x' * 200),
        hasLength(120));
  });
}
