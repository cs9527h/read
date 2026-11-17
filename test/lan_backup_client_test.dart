import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/lan_backup_client.dart';
import 'package:read/src/sync/lan_backup_service.dart';

void main() {
  late Directory dir;
  late LanBackupService service;
  late List<int> goodBytes;
  late Uri base;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('read-lan-client-');
    goodBytes = List<int>.generate(4096, (int i) => (i * 7) % 256);
    await File('${dir.path}${Platform.pathSeparator}backup-A.zip')
        .writeAsBytes(goodBytes);
    service = LanBackupService(
      deviceName: '对端设备',
      portCandidates: const <int>[0],
      bindLoopback: true,
      backupDir: dir,
    );
    await service.start();
    base = Uri.parse('http://127.0.0.1:${service.port}/?key=${service.accessToken}');
  });

  tearDown(() async {
    await service.stop();
    service.dispose();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('normalizeBase 支持裸地址、带 scheme 与带路径输入', () {
    expect(LanBackupClient.normalizeBase('192.168.1.5:8769')?.host, '192.168.1.5');
    expect(LanBackupClient.normalizeBase('192.168.1.5:8769')?.port, 8769);
    expect(LanBackupClient.normalizeBase('http://10.0.0.2:9000/api/info')?.port, 9000);
    expect(LanBackupClient.normalizeBase(base.toString())?.queryParameters['key'], service.accessToken);
    expect(LanBackupClient.normalizeBase('  '), isNull);
    expect(LanBackupClient.normalizeBase('ftp://10.0.0.2'), isNull);
  });

  test('无共享链接令牌不能读取备份', () async {
    final client = LanBackupClient();
    final noKey = Uri.parse('http://127.0.0.1:${service.port}');
    await expectLater(client.listBackups(noKey), throwsFormatException);
    await expectLater(client.downloadBackup(noKey, 'backup-A.zip'), throwsFormatException);
  });

  test('客户端能读取对端设备信息与备份列表', () async {
    final LanBackupClient client = LanBackupClient();
    final Map<String, Object?> info = await client.info(base);
    expect(info['device'], '对端设备');
    final List<Map<String, Object?>> backups = await client.listBackups(base);
    expect(backups.length, 1);
    expect(backups.first['name'], 'backup-A.zip');
  });

  test('下载备份字节完整且可用于恢复', () async {
    final LanBackupClient client = LanBackupClient();
    final String path = await client.downloadBackup(base, 'backup-A.zip');
    final File file = File(path);
    addTearDown(() async {
      if (await file.exists()) await file.parent.delete(recursive: true);
    });
    expect(await file.readAsBytes(), equals(goodBytes));
  });

  test('拒绝恶意文件名与超限响应', () async {
    final LanBackupClient client = LanBackupClient();
    expect(
      () => client.downloadBackup(base, '../evil.zip'),
      throwsFormatException,
    );
    expect(
      () => client.downloadBackup(base, 'backup-A.zip', maxBytes: 100),
      throwsFormatException,
    );
  });

  group('跨设备同步密钥迁移（免手动密码）', () {
    test('info 只暴露是否可迁移密钥，不泄露密钥内容', () async {
      final Map<String, Object?> info = await LanBackupClient().info(base);
      expect(info['hasSyncKey'], isFalse);
      expect(info.containsKey('key'), isFalse);
    });

    test('带密钥的共享：对端可获取密钥，且需令牌鉴权', () async {
      const String secret = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345';
      final LanBackupService sharer = LanBackupService(
        deviceName: '旧设备',
        portCandidates: const <int>[0],
        bindLoopback: true,
        backupDir: dir,
        syncKey: secret,
      );
      await sharer.start();
      addTearDown(() async {
        await sharer.stop();
        sharer.dispose();
      });
      final Uri shareBase =
          Uri.parse('http://127.0.0.1:${sharer.port}/?key=${sharer.accessToken}');
      final LanBackupClient client = LanBackupClient();

      final Map<String, Object?> info = await client.info(shareBase);
      expect(info['hasSyncKey'], isTrue);
      expect(info.containsKey('key'), isFalse);

      expect(await client.fetchSyncKey(shareBase), secret);

      // 无令牌的陌生人拿不到密钥。
      final Uri noKey = Uri.parse('http://127.0.0.1:${sharer.port}');
      expect(() => client.fetchSyncKey(noKey), throwsFormatException);
    });

    test('停止共享后密钥端点失效', () async {
      const String secret = 'KEY123456789012345678901234567890';
      final LanBackupService sharer = LanBackupService(
        deviceName: '旧设备',
        portCandidates: const <int>[0],
        bindLoopback: true,
        backupDir: dir,
        syncKey: secret,
      );
      await sharer.start();
      final Uri shareBase =
          Uri.parse('http://127.0.0.1:${sharer.port}/?key=${sharer.accessToken}');
      await sharer.stop();
      expect(() => LanBackupClient().fetchSyncKey(shareBase), throwsA(anything));
      sharer.dispose();
    });
  });
}
