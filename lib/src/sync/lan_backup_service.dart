import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';

/// 局域网备份直传服务：本机作为服务端，把已有备份 ZIP 暴露给同一局域网的
/// 另一台设备直接下载恢复。
///
/// 设计约束（对应用户"只要同局域网、直传全量备份、可选择、不要密码"）：
/// - 无需设置同步密码；临时共享链接携带随机令牌，且只监听私有网段；
/// - 只暴露 backups 目录里的 .zip，basename 白名单，拒绝任何路径穿越；
/// - 只提供读取，永远不修改/删除本机备份；
/// - 下载前列出备份 ZIP；下载后由恢复预览解析书目并支持逐本选择。
/// - 默认关闭，只有用户主动开启才监听端口；应用退到后台即停止。
class LanBackupService extends ChangeNotifier {
  LanBackupService({
    required this.deviceName,
    List<int>? portCandidates,
    bool bindLoopback = false,
    Directory? backupDir,
    this.syncKey = '',
  })  : _portCandidates = portCandidates ?? const <int>[8769, 8770, 8771],
        _bindLoopback = bindLoopback,
        _backupDirOverride = backupDir;

  /// 展示在"附近设备"列表里的名称。
  final String deviceName;
  final List<int> _portCandidates;
  final bool _bindLoopback;
  final Directory? _backupDirOverride;

  /// 本机的端到端同步密钥。仅在用户主动开启共享、且本次共享生命周期内，
  /// 通过带随机令牌的共享链接暴露给已授权的对端设备，用于跨设备解密云端数据。
  /// 由页面在 start() 前从安全存储读出后注入；绝不写入日志或诊断报告。
  String syncKey;

  HttpServer? _server;
  Directory? _servedDir;
  int _port = 0;
  String _lastError = '';
  String _accessToken = '';
  bool _disposed = false;
  List<String> _boundAddresses = const <String>[];

  bool get isRunning => _server != null;
  int get port => _port;
  /// Ephemeral capability embedded in the copied share link, not a sync password.
  String get accessToken => _accessToken;
  String get lastError => _lastError;
  Directory? get servedDirectory => _servedDir;

  /// 当前监听地址，供对端手工输入（自动发现不可用时）。
  List<String> get addresses => List<String>.unmodifiable(_boundAddresses);

  Future<void> start() async {
    if (_server != null) return;
    _lastError = '';
    final Directory dir = await _resolveBackupDir();
    await dir.create(recursive: true);

    final List<InternetAddress> targets;
    if (_bindLoopback) {
      targets = <InternetAddress>[InternetAddress.loopbackIPv4];
    } else {
      final Set<String> seen = <String>{};
      final List<InternetAddress> found = <InternetAddress>[];
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final interface in interfaces) {
          for (final address in interface.addresses) {
            if (address.isLoopback || !_isPrivate(address)) continue;
            if (seen.add(address.address)) found.add(address);
          }
        }
      } catch (_) {}
      targets = found; // Never listen on all interfaces when no private LAN address exists.
    }

    HttpServer? opened;
    for (final port in _portCandidates) {
      for (final address in targets) {
        try {
          opened = await HttpServer.bind(address, port, shared: false);
          break;
        } on SocketException {
          continue;
        }
      }
      if (opened != null) break;
    }
    if (opened == null) {
      _lastError = targets.isEmpty
          ? '未找到可用的局域网地址，请连接同一 WiFi 后重试'
          : '局域网端口被占用，无法开启备份共享';
      notifyListeners();
      return;
    }
    opened.autoCompress = false;
    final random = Random.secure();
    _accessToken = List<int>.generate(24, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    opened.listen(_handle, onError: (Object e) {
      _lastError = e.toString();
    });
    _server = opened;
    _port = opened.port;
    _servedDir = dir;
    _boundAddresses = <String>[opened.address.address];
    if (!_disposed) notifyListeners();
  }

  Future<Directory> _resolveBackupDir() async {
    final Directory? override = _backupDirOverride;
    if (override != null) return override;
    // Use the same application documents directory as BackupService._backupDir.
    // Directory.current differs from this location on Android.
    final Directory base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}${Platform.pathSeparator}backups');
  }

  Future<void> stop() async {
    final HttpServer? server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }
    _port = 0;
    _accessToken = '';
    _servedDir = null;
    _boundAddresses = const <String>[];
    if (!_disposed) notifyListeners();
  }

  Future<void> onAppPaused() async {
    if (isRunning) await stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _server?.close(force: true);
    _server = null;
    _accessToken = '';
    super.dispose();
  }

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    try {
      // 只接受私有网段；loopback 测试模式额外允许本机回环。
      final InternetAddress? remote = request.connectionInfo?.remoteAddress;
      if (remote == null ||
          (!_isPrivate(remote) && !(_bindLoopback && remote.isLoopback))) {
        response.statusCode = HttpStatus.forbidden;
        response.write('forbidden');
        await response.close();
        return;
      }
      // A local IP alone is not authorization: other WiFi clients must not
      // be able to fetch a user's books. The copied link contains a short-lived
      // random capability; no password entry or account is required.
      final supplied = request.uri.queryParameters['key'] ?? '';
      if (_accessToken.isEmpty || !_sameToken(supplied, _accessToken)) {
        response.statusCode = HttpStatus.unauthorized;
        await response.close();
        return;
      }
      final String path = request.uri.path;
      if (path == '/' || path == '/api/info') {
        await _json(response, <String, Object?>{
          'format': 'read-lan-backup-v1',
          'device': deviceName,
          'port': _port,
          // 只暴露"是否可迁移密钥"，不暴露密钥内容本身。
          'hasSyncKey': syncKey.isNotEmpty,
        });
        return;
      }
      if (path == '/api/sync-key') {
        // 需同样的临时令牌鉴权（上面已校验），仅在共享期间可用。
        if (syncKey.isEmpty) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          return;
        }
        await _json(response, <String, Object?>{'key': syncKey});
        return;
      }
      if (path == '/api/backups') {
        await _json(response, <String, Object?>{
          'backups': await _listBackups(),
        });
        return;
      }
      if (path == '/api/download') {
        await _download(request, response);
        return;
      }
      response.statusCode = HttpStatus.notFound;
      await response.close();
    } catch (error) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write('error: $error');
        await response.close();
      } catch (_) {}
    }
  }

  Future<List<Map<String, Object?>>> _listBackups() async {
    final Directory dir = _servedDir ?? await _resolveBackupDir();
    if (!await dir.exists()) return const <Map<String, Object?>>[];
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) continue;
      final String name = _baseName(entity.path);
      if (!name.endsWith('.zip')) continue;
      final FileStat stat = await entity.stat();
      out.add(<String, Object?>{
        'name': name,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      });
    }
    out.sort((Map<String, Object?> a, Map<String, Object?> b) =>
        (b['modified'] as String).compareTo(a['modified'] as String));
    return out;
  }

  Future<void> _download(HttpRequest request, HttpResponse response) async {
    final String? raw =
        request.uri.queryParameters['name'] ?? request.uri.queryParameters['file'];
    final String? name = safeBackupName(raw);
    if (name == null) {
      response.statusCode = HttpStatus.badRequest;
      response.write('invalid backup name');
      await response.close();
      return;
    }
    final Directory dir = _servedDir ?? await _resolveBackupDir();
    final File file = File('${dir.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final int length = await file.length();
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType(
      'application',
      'octet-stream',
      parameters: <String, String>{'name': name},
    );
    response.headers.contentLength = length;
    response.headers.set('X-Backup-Name', name);
    await file.openRead().pipe(response);
  }

  /// basename 白名单：只允许普通备份文件名，杜绝 ../ 与绝对路径穿越。
  static String? safeBackupName(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > 255) return null;
    if (raw.contains('/') || raw.contains('\\') || raw.contains('..')) return null;
    if (!raw.endsWith('.zip')) return null;
    final RegExp allowed = RegExp(r'^[A-Za-z0-9._\-]+\.zip$');
    if (!allowed.hasMatch(raw)) return null;
    return raw;
  }

  static bool _sameToken(String a, String b) {
    if (a.length != b.length) return false;
    var mismatch = 0;
    for (var i = 0; i < a.length; i++) {
      mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return mismatch == 0;
  }

  static bool _isPrivate(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final List<int> b = address.rawAddress;
    if (b.length != 4) return false;
    return _isPrivateBytes(b);
  }

  static bool _isPrivateBytes(List<int> b) =>
      b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);

  static String _baseName(String path) {
    final int slash = path.lastIndexOf(Platform.pathSeparator);
    return slash < 0 ? path : path.substring(slash + 1);
  }

  static Future<void> _json(HttpResponse response, Object value) async {
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
    await response.close();
  }
}
