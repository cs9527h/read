import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'lan_backup_service.dart';

/// 局域网备份客户端：连接另一台设备上运行的 [LanBackupService]，
/// 拉取其备份列表、下载备份到本地临时文件，供 BackupService.restore 使用。
///
/// 不含任何密码；连接地址由对端界面显示，用户在同一局域网内手动输入或粘贴。
class LanBackupClient {
  LanBackupClient({this.timeout = const Duration(seconds: 15)});

  final Duration timeout;

  /// 规范化用户输入的地址，支持 `192.168.1.5:8769`、`http://...`、
  /// 以及完整 `http://.../api/info`。返回可直接请求的基础 Uri。
  static Uri? normalizeBase(String raw) {
    String value = raw.trim();
    if (value.isEmpty || value.length > 256) return null;
    if (!value.contains('://')) value = 'http://$value';
    final Uri parsed = Uri.tryParse(value) ?? Uri();
    if (parsed.host.isEmpty) return null;
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
    // 剥掉路径，只保留 scheme://host:port
    return Uri(scheme: parsed.scheme, host: parsed.host, port: parsed.port);
  }

  Future<Map<String, Object?>> info(Uri base) async {
    final Uint8List body = await _get(base.resolve('/api/info'));
    final Object? decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map<String, dynamic>) throw const FormatException('设备信息格式错误');
    if (decoded['format'] != 'read-lan-backup-v1') {
      throw const FormatException('对端不是 Read 局域网备份服务');
    }
    return decoded;
  }

  Future<List<Map<String, Object?>>> listBackups(Uri base) async {
    final Uint8List body = await _get(base.resolve('/api/backups'));
    final Object? decoded = jsonDecode(utf8.decode(body));
    if (decoded is! Map<String, dynamic> ||
        decoded['backups'] is! List<dynamic>) {
      throw const FormatException('备份列表格式错误');
    }
    return (decoded['backups'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// 下载指定备份到临时文件；返回文件路径。校验大小上限，防止恶意超大响应。
  Future<String> downloadBackup(
    Uri base,
    String name, {
    int maxBytes = 512 * 1024 * 1024,
  }) async {
    final String? safe = _safeName(name);
    if (safe == null) throw const FormatException('非法备份文件名');
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request =
          await client.getUrl(base.resolve('/api/download').replace(
                queryParameters: <String, String>{'name': safe},
              ));
      final HttpClientResponse response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        throw FormatException('下载失败：HTTP ${response.statusCode}');
      }
      final Directory temp = await Directory.systemTemp.createTemp('read-lan-dl-');
      final File file = File('${temp.path}${Platform.pathSeparator}$safe');
      final IOSink sink = file.openWrite();
      int total = 0;
      await for (final List<int> chunk in response) {
        total += chunk.length;
        if (total > maxBytes) {
          await sink.close();
          await temp.delete(recursive: true);
          throw const FormatException('备份超过安全大小上限，已放弃');
        }
        sink.add(chunk);
      }
      await sink.close();
      if (total == 0) {
        await temp.delete(recursive: true);
        throw const FormatException('下载文件为空');
      }
      return file.path;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> _get(Uri uri) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        throw FormatException('请求失败：HTTP ${response.statusCode}');
      }
      final BytesBuilder builder = BytesBuilder(copy: false);
      await for (final List<int> chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  static String? _safeName(String name) => LanBackupService.safeBackupName(name);

  Future<void> close() async {}
}
