import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/lan_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('read-documents-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => documentsDir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await documentsDir.exists()) await documentsDir.delete(recursive: true);
  });

  test('未注入目录时，共享服务使用应用文档目录的 backups 子目录（与 BackupService 一致）',
      () async {
    // 关键回归：PR #51 之前用 Directory.current/backups，在 Android 上指向
    // 错误的当前工作目录，导致备份列表为空。这里不传 backupDir，强制走真实路径。
    final LanBackupService service = LanBackupService(
      deviceName: '真机模拟',
      portCandidates: const <int>[0],
      bindLoopback: true,
      // 故意不传 backupDir
    );
    await service.start();
    addTearDown(() async {
      await service.stop();
      service.dispose();
    });

    expect(service.servedDirectory, isNotNull);
    expect(
      service.servedDirectory!.path,
      '${documentsDir.path}${Platform.pathSeparator}backups',
      reason: '必须与 BackupService._backupDir 使用同一目录，否则 Android 上备份列表为空',
    );
  });

  test('应用文档 backups 目录中的真实备份能被列出（无注入）', () async {
    final Directory backups = Directory(
        '${documentsDir.path}${Platform.pathSeparator}backups');
    await backups.create(recursive: true);
    await File('${backups.path}${Platform.pathSeparator}read-2026.zip')
        .writeAsBytes(List<int>.generate(128, (i) => i % 251));

    final LanBackupService service = LanBackupService(
      deviceName: '真机模拟',
      portCandidates: const <int>[0],
      bindLoopback: true,
    );
    await service.start();
    addTearDown(() async {
      await service.stop();
      service.dispose();
    });

    final List<FileSystemEntity> items = await service.servedDirectory!.list().toList();
    final names = items.map((e) => e.path.split(Platform.pathSeparator).last).toList();
    expect(names, contains('read-2026.zip'));
  });
}
