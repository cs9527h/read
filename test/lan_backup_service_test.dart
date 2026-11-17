import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/lan_backup_service.dart';

void main() {
  late Directory dir;
  late LanBackupService service;
  late List<int> goodBytes;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('read-lan-test-');
    goodBytes = List<int>.generate(2048, (int i) => i % 251);
    await File('${dir.path}${Platform.pathSeparator}read-2026-11-17.zip')
        .writeAsBytes(goodBytes);
    await File('${dir.path}${Platform.pathSeparator}notes.txt').writeAsString('ignore');
    service = LanBackupService(
      deviceName: '测试手机',
      portCandidates: const <int>[0],
      bindLoopback: true,
      backupDir: dir,
    );
    await service.start();
  });

  tearDown(() async {
    await service.stop();
    service.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Uri base() => Uri.parse('http://127.0.0.1:${service.port}');

  Future<(int, Uint8List)> fetch(Uri uri, {bool authorized = true}) async {
    final Uri resolved = authorized
        ? uri.replace(queryParameters: <String, String>{
            ...uri.queryParameters,
            'key': service.accessToken,
          })
        : uri;
    final HttpClient client = HttpClient();
    try {
      final request = await client.getUrl(resolved);
      final response = await request.close();
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return (response.statusCode, builder.takeBytes());
    } finally {
      client.close(force: true);
    }
  }

  test('启动后在私有回环端口可访问，并提供设备信息', () async {
    expect(service.isRunning, isTrue);
    expect(service.port, greaterThan(0));
    final (int status, Uint8List body) = await fetch(base().resolve('/api/info'));
    expect(status, 200);
    final Map<String, dynamic> info = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    expect(info['format'], 'read-lan-backup-v1');
    expect(info['device'], '测试手机');
  });

  test('共享链接临时令牌授权：无令牌或错令牌被拒绝，同 WiFi 陌生人不能下载', () async {
    // 无令牌：设备信息、备份列表、下载都必须 401。
    expect((await fetch(base().resolve('/api/info'), authorized: false)).$1, 401);
    expect((await fetch(base().resolve('/api/backups'), authorized: false)).$1, 401);
    expect(
      (await fetch(base().resolve('/api/download?name=read-2026-11-17.zip'),
              authorized: false))
          .$1,
      401,
    );
    // 错误令牌同样拒绝。
    final Uri wrong = base().resolve('/api/info').replace(
          queryParameters: <String, String>{'key': 'not-the-token'},
        );
    expect((await fetch(wrong, authorized: false)).$1, 401);
    // 停止共享后令牌清空，旧链接失效。
    await service.stop();
    expect(service.accessToken, isEmpty);
  });

  test('备份列表只列 zip，按修改时间给出文件名与大小', () async {
    final (int status, Uint8List body) = await fetch(base().resolve('/api/backups'));
    expect(status, 200);
    final Map<String, dynamic> data = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    final List<dynamic> backups = data['backups'] as List<dynamic>;
    expect(backups.length, 1);
    expect(backups.first['name'], 'read-2026-11-17.zip');
    expect(backups.first['size'], goodBytes.length);
  });

  test('下载备份字节与源文件完全一致，无需任何密码', () async {
    final (int status, Uint8List body) =
        await fetch(base().resolve('/api/download?name=read-2026-11-17.zip'));
    expect(status, 200);
    expect(body, equals(goodBytes));
  });

  test('路径穿越、伪装扩展名、绝对路径都被拒绝', () async {
    for (final bad in <String>[
      '../secret.zip',
      '..%2Fsecret.zip',
      'a/b.zip',
      '/etc/passwd.zip',
      'notes.txt',
      'noextension',
    ]) {
      expect(LanBackupService.safeBackupName(bad), isNull, reason: bad);
    }
    final (int status, _) =
        await fetch(base().resolve('/api/download?name=..%2Fsecret.zip'));
    expect(status, 400);
  });

  test('不存在的文件返回 404，未知路径返回 404', () async {
    expect((await fetch(base().resolve('/api/download?name=missing.zip'))).$1, 404);
    expect((await fetch(base().resolve('/whatever'))).$1, 404);
  });

  test('停止后端口释放，服务不再运行', () async {
    final int port = service.port;
    await service.stop();
    expect(service.isRunning, isFalse);
    expect(service.port, 0);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final HttpServer? rebound = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    expect(rebound, isNotNull);
    await rebound!.close(force: true);
  });

  test('未启动时 addresses 为空，启动后包含实际绑定地址', () async {
    final LanBackupService fresh = LanBackupService(
      deviceName: 'x',
      portCandidates: const <int>[0],
      bindLoopback: true,
      backupDir: dir,
    );
    expect(fresh.addresses, isEmpty);
    await fresh.start();
    expect(fresh.addresses, isNotEmpty);
    await fresh.stop();
    fresh.dispose();
  });
}
