import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// WiFi 传书的安全策略。
///
/// 默认值刻意保守：服务默认关闭，必须由用户手动启动；只允许局域网私有地址
/// 访问；单文件 40MB；扩展名白名单；同时最多 2 个上传；每 IP 每分钟最多
/// 120 次请求；配对码 10 分钟过期。
class WifiTransferConfig {
  const WifiTransferConfig({
    this.maxFileBytes = 40 * 1024 * 1024,
    this.maxConcurrentUploads = 2,
    this.maxRequestsPerMinute = 120,
    this.maxPairAttempts = 5,
    this.sessionTtl = const Duration(minutes: 10),
    this.allowedExtensions = defaultExtensions,
    this.allowLoopback = false,
    this.bindAddress,
    this.portCandidates = const <int>[8765, 8766, 8767, 8768, 8769, 8770, 8771, 8772, 8773, 8774],
  });

  /// 与阅读器解析上限一致。
  static const Set<String> defaultExtensions = <String>{
    'txt',
    'epub',
    'pdf',
    'md',
    'markdown',
    'html',
    'htm',
  };

  final int maxFileBytes;
  final int maxConcurrentUploads;
  final int maxRequestsPerMinute;
  final int maxPairAttempts;
  final Duration sessionTtl;
  final Set<String> allowedExtensions;

  /// 仅供自动化测试使用；真机运行时保持 false，禁止回环地址。
  final bool allowLoopback;

  /// 指定监听地址。为空时自动选择本机局域网地址，失败后退回 0.0.0.0
  /// 并在请求层强制校验来源必须是私有网段。
  final InternetAddress? bindAddress;

  final List<int> portCandidates;
}

enum WifiTransferStatus { stopped, starting, running, failed }

/// 一次上传的进度/结果事件，供界面展示真实反馈。
class WifiTransferEvent {
  const WifiTransferEvent({
    required this.fileName,
    required this.state,
    this.received = 0,
    this.total = 0,
    this.message = '',
    this.at,
  });

  /// receiving / imported / duplicate / failed / rejected
  final String state;
  final String fileName;
  final int received;
  final int total;
  final String message;
  final DateTime? at;

  double get progress => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
}

/// 导入结果由调用方（LibraryStore）返回，服务层不解析书籍格式。
class WifiImportResult {
  const WifiImportResult({
    required this.ok,
    this.duplicate = false,
    this.message = '',
  });

  final bool ok;
  final bool duplicate;
  final String message;
}

typedef WifiImportHandler = Future<WifiImportResult> Function(
    File file, String fileName);

class _RateWindow {
  final List<DateTime> hits = <DateTime>[];
}

/// 真实的局域网 HTTP 传书服务。
///
/// 安全模型：
/// 1. 启动时才生成一次性 6 位配对码和 256 位会话令牌；
/// 2. 浏览器必须先用配对码换取令牌，之后每个上传请求都要带令牌；
/// 3. 配对码 10 分钟过期，连续输错 5 次作废；
/// 4. 每个来源 IP 独立限速，上传并发受限；
/// 5. 文件名、扩展名、文件头、大小全部校验，临时文件必然清理；
/// 6. 只接受私有网段来源，公网地址直接 403；
/// 7. 用户可随时停止，应用退到后台按策略停止。
class WifiTransferService extends ChangeNotifier {
  WifiTransferService({
    WifiTransferConfig config = const WifiTransferConfig(),
    required WifiImportHandler onImport,
    DateTime Function()? clock,
  })  : _config = config,
        _onImport = onImport,
        _clock = clock ?? DateTime.now;

  final WifiTransferConfig _config;
  final WifiImportHandler _onImport;
  final DateTime Function() _clock;

  final List<HttpServer> _servers = <HttpServer>[];
  final Random _random = Random.secure();
  final StreamController<WifiTransferEvent> _events =
      StreamController<WifiTransferEvent>.broadcast();
  final Map<String, _RateWindow> _rate = <String, _RateWindow>{};
  final Map<String, int> _activeByIp = <String, int>{};

  WifiTransferStatus _status = WifiTransferStatus.stopped;
  String? _lastError;
  String _code = '';
  String _token = '';
  DateTime? _expiresAt;
  int _pairFailures = 0;
  bool _pairLocked = false;
  int _port = 0;
  List<String> _addresses = <String>[];
  Directory? _tempDir;
  int _activeUploads = 0;
  bool _disposed = false;

  WifiTransferStatus get status => _status;
  String? get lastError => _lastError;
  bool get isRunning => _status == WifiTransferStatus.running;

  /// 界面上展示给用户的 6 位配对码。
  String get pairingCode => _code;
  DateTime? get expiresAt => _expiresAt;
  int get port => _port;
  List<String> get addresses => List<String>.unmodifiable(_addresses);
  int get activeUploads => _activeUploads;
  bool get pairingLocked => _pairLocked;

  /// 当前会话的临时目录；仅用于测试与诊断，正常情况下由服务自行清理。
  Directory? get tempDirectory => _tempDir;
  Stream<WifiTransferEvent> get events => _events.stream;

  bool get isExpired {
    final at = _expiresAt;
    return at == null || !_clock().isBefore(at);
  }

  /// 启动服务。默认关闭，只有用户主动调用才会真正监听端口。
  Future<void> start() async {
    if (_status == WifiTransferStatus.running ||
        _status == WifiTransferStatus.starting) {
      return;
    }
    _status = WifiTransferStatus.starting;
    _lastError = null;
    notifyListeners();

    _rotateSecrets();
    await _tempDir?.delete(recursive: true).catchError((Object _) => Directory(''));
    final Directory base = Directory.systemTemp;
    _tempDir = await Directory(
      '${base.path}${Platform.pathSeparator}read-wifi-'
      '${_clock().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}',
    ).create(recursive: true);

    final List<InternetAddress> candidates = <InternetAddress>[];
    final InternetAddress? forced = _config.bindAddress;
    if (forced != null) {
      candidates.add(forced);
    } else if (_config.allowLoopback) {
      // 测试模式：只监听回环，避免影响真实局域网。
      candidates.add(InternetAddress.loopbackIPv4);
    } else {
      try {
        final List<NetworkInterface> interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final NetworkInterface interface in interfaces) {
          for (final InternetAddress address in interface.addresses) {
            if (address.isLoopback) continue;
            if (_isPrivate(address)) candidates.add(address);
          }
        }
      } catch (_) {}
    }

    final List<String> bound = <String>[];
    int? usedPort;
    for (final int candidatePort in _config.portCandidates) {
      final List<HttpServer> opened = <HttpServer>[];
      final List<InternetAddress> targets = candidates.isEmpty
          ? <InternetAddress>[InternetAddress.anyIPv4]
          : candidates;
      for (final InternetAddress address in targets) {
        try {
          final HttpServer server = await HttpServer.bind(
            address,
            candidatePort,
            shared: false,
          );
          server.autoCompress = false;
          server.listen(_handle, onError: (Object error) {
            _lastError = '$error';
          });
          opened.add(server);
          bound.add(address.address);
        } on SocketException {
          continue;
        }
      }
      if (opened.isNotEmpty) {
        _servers.addAll(opened);
        // 允许 portCandidates 里传 0 让系统分配端口（测试与端口冲突时使用）。
        usedPort = opened.first.port;
        break;
      }
    }

    if (usedPort == null) {
      await _tempDir?.delete(recursive: true).catchError((Object _) => Directory(''));
      _tempDir = null;
      _status = WifiTransferStatus.failed;
      _lastError = '端口 ${_config.portCandidates.first}–${_config.portCandidates.last} '
          '都被占用，无法启动传书服务';
      notifyListeners();
      return;
    }

    _port = usedPort;
    _addresses = bound.toSet().toList();
    _status = WifiTransferStatus.running;
    notifyListeners();
  }

  /// 立即停止服务：关闭监听、清理未完成的上传临时文件。
  Future<void> stop() async {
    final List<HttpServer> servers = List<HttpServer>.from(_servers);
    _servers.clear();
    for (final HttpServer server in servers) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }
    final Directory? dir = _tempDir;
    _tempDir = null;
    if (dir != null) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    }
    _status = WifiTransferStatus.stopped;
    _addresses = <String>[];
    _port = 0;
    _activeUploads = 0;
    _activeByIp.clear();
    _rate.clear();
    _pairFailures = 0;
    _pairLocked = false;
    _code = '';
    _token = '';
    _expiresAt = null;
    if (!_disposed) notifyListeners();
  }

  /// 应用进入后台时的策略：默认停止，避免后台静默接受连接。
  Future<void> onAppPaused({bool keepRunning = false}) async {
    if (keepRunning) return;
    if (isRunning) await stop();
  }

  /// 重新生成配对码与令牌（旧令牌立即失效）。
  void rotateSecrets() {
    _rotateSecrets();
    notifyListeners();
  }

  void _rotateSecrets() {
    _code = List<int>.generate(6, (_) => _random.nextInt(10)).join();
    final List<int> bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    _token = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    _expiresAt = _clock().add(_config.sessionTtl);
    _pairFailures = 0;
    _pairLocked = false;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _events.close();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // HTTP
  // ---------------------------------------------------------------------

  Future<void> _handle(HttpRequest request) async {
    final String remote = request.connectionInfo?.remoteAddress.address ?? '';
    final HttpResponse response = request.response;
    try {
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('Referrer-Policy', 'no-referrer');
      response.headers.set('Cache-Control', 'no-store');

      if (!_isAllowedRemote(request.connectionInfo?.remoteAddress)) {
        await _json(response, HttpStatus.forbidden,
            <String, Object?>{'ok': false, 'message': '仅允许局域网设备访问'});
        return;
      }
      if (!_allowRate(remote)) {
        response.headers.set('Retry-After', '60');
        await _json(response, HttpStatus.tooManyRequests,
            <String, Object?>{'ok': false, 'message': '请求过于频繁，请稍后再试'});
        return;
      }

      final String path = request.uri.path;
      if (request.method == 'GET' && (path == '/' || path.isEmpty)) {
        response.headers.contentType =
            ContentType('text', 'html', charset: 'utf-8');
        response.headers.set('Content-Security-Policy',
            "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'");
        response.write(_pairingPage());
        await response.close();
        return;
      }
      if (request.method == 'POST' && path == '/pair') {
        await _handlePair(request, response);
        return;
      }
      if (request.method == 'POST' && path == '/upload') {
        await _handleUpload(request, response, remote);
        return;
      }
      if (request.method == 'GET' && path == '/status') {
        if (!_authorized(request)) {
          await _json(response, HttpStatus.unauthorized,
              <String, Object?>{'ok': false, 'message': '未配对或会话已过期'});
          return;
        }
        await _json(response, HttpStatus.ok, <String, Object?>{
          'ok': true,
          'uploads': _activeUploads,
          'expires_at': _expiresAt?.toUtc().toIso8601String(),
        });
        return;
      }
      await _json(response, HttpStatus.notFound,
          <String, Object?>{'ok': false, 'message': 'not found'});
    } catch (error) {
      try {
        await _json(response, HttpStatus.internalServerError,
            <String, Object?>{'ok': false, 'message': '服务异常：$error'});
      } catch (_) {}
    }
  }

  Future<void> _handlePair(HttpRequest request, HttpResponse response) async {
    final String body = await utf8.decoder
        .bind(request)
        .join()
        .timeout(const Duration(seconds: 10), onTimeout: () => '');
    String code = '';
    if (body.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map && decoded['code'] is String) {
          code = (decoded['code'] as String).trim();
        }
      } catch (_) {}
    }
    if (isExpired) {
      _pairLocked = true;
      await _json(response, HttpStatus.gone,
          <String, Object?>{'ok': false, 'message': '配对码已过期，请在手机上重新生成'});
      return;
    }
    if (_pairLocked) {
      await _json(response, HttpStatus.tooManyRequests,
          <String, Object?>{'ok': false, 'message': '尝试次数过多，请在手机上重新生成配对码'});
      return;
    }
    if (code != _code) {
      _pairFailures++;
      if (_pairFailures >= _config.maxPairAttempts) _pairLocked = true;
      await _json(response, HttpStatus.unauthorized,
          <String, Object?>{'ok': false, 'message': '配对码不正确'});
      return;
    }
    _pairFailures = 0;
    await _json(response, HttpStatus.ok, <String, Object?>{
      'ok': true,
      'token': _token,
      'expires_in': _expiresAt!.difference(_clock()).inSeconds,
    });
  }

  Future<void> _handleUpload(
      HttpRequest request, HttpResponse response, String remote) async {
    if (!_authorized(request)) {
      _events.add(WifiTransferEvent(
        fileName: request.uri.queryParameters['name'] ?? '',
        state: 'rejected',
        message: '未配对的上传请求已拦截',
        at: _clock(),
      ));
      await _json(response, HttpStatus.unauthorized,
          <String, Object?>{'ok': false, 'message': '未配对或令牌不正确'});
      return;
    }
    if (isExpired) {
      await _json(response, HttpStatus.unauthorized,
          <String, Object?>{'ok': false, 'message': '会话已过期，请重新配对'});
      return;
    }
    if (_activeUploads >= _config.maxConcurrentUploads) {
      response.headers.set('Retry-After', '3');
      await _json(response, HttpStatus.tooManyRequests,
          <String, Object?>{'ok': false, 'message': '同时上传的文件过多，请稍后重试'});
      return;
    }

    final String? rawName = request.uri.queryParameters['name'];
    final String? name = sanitizeFileName(rawName == null ? null : Uri.decodeComponent(rawName));
    if (name == null) {
      await _json(response, HttpStatus.badRequest,
          <String, Object?>{'ok': false, 'message': '文件名不合法'});
      return;
    }
    final String ext = _extension(name);
    if (!_config.allowedExtensions.contains(ext)) {
      await _json(response, HttpStatus.unsupportedMediaType,
          <String, Object?>{'ok': false, 'message': '不支持的文件类型：$ext'});
      return;
    }
    final int declared = request.contentLength;
    if (declared > _config.maxFileBytes) {
      await _json(response, HttpStatus.requestEntityTooLarge,
          <String, Object?>{'ok': false, 'message': '文件超过 40MB 上限'});
      return;
    }

    _activeUploads++;
    _activeByIp[remote] = (_activeByIp[remote] ?? 0) + 1;
    notifyListeners();
    final Directory? dir = _tempDir;
    if (dir == null) {
      _activeUploads--;
      await _json(response, HttpStatus.serviceUnavailable,
          <String, Object?>{'ok': false, 'message': '服务已停止'});
      return;
    }
    final File target = File('${dir.path}${Platform.pathSeparator}'
        '${_clock().microsecondsSinceEpoch}-$name');
    IOSink? sink;
    try {
      sink = target.openWrite();
      int received = 0;
      int lastReported = 0;
      await for (final List<int> chunk in request) {
        received += chunk.length;
        if (received > _config.maxFileBytes) {
          throw const _TooLarge();
        }
        sink.add(chunk);
        if (received - lastReported >= 256 * 1024 || received == declared) {
          lastReported = received;
          _emit(WifiTransferEvent(
            fileName: name,
            state: 'receiving',
            received: received,
            total: declared,
            at: _clock(),
          ));
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (received == 0) {
        throw const FormatException('文件内容为空');
      }
      if (!await _signatureMatches(target, ext)) {
        await _json(response, HttpStatus.unsupportedMediaType,
            <String, Object?>{'ok': false, 'message': '文件内容与扩展名不符，已拒绝'});
        _emit(WifiTransferEvent(fileName: name, state: 'rejected', message: '内容校验失败'));
        return;
      }

      WifiImportResult result;
      try {
        result = await _onImport(target, name);
      } catch (error) {
        result = WifiImportResult(ok: false, message: '导入失败：$error');
      }
      final String state = result.ok
          ? 'imported'
          : (result.duplicate ? 'duplicate' : 'failed');
      _emit(WifiTransferEvent(
        fileName: name,
        state: state,
        received: received,
        total: declared > 0 ? declared : received,
        message: result.message,
        at: _clock(),
      ));
      await _json(response, result.ok ? HttpStatus.ok : HttpStatus.badRequest,
          <String, Object?>{
            'ok': result.ok,
            'duplicate': result.duplicate,
            'message': result.message,
          });
    } on _TooLarge {
      _emit(WifiTransferEvent(
          fileName: name, state: 'failed', message: '超过 40MB 上限'));
      await _json(response, HttpStatus.requestEntityTooLarge,
          <String, Object?>{'ok': false, 'message': '文件超过 40MB 上限'});
    } catch (error) {
      _emit(WifiTransferEvent(
          fileName: name, state: 'failed', message: '上传中断：$error'));
      await _json(response, HttpStatus.badRequest,
          <String, Object?>{'ok': false, 'message': '上传失败：$error'});
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      // 无论成功、超限还是连接中断，临时文件都不留残余。
      try {
        if (await target.exists()) await target.delete();
      } catch (_) {}
      _activeUploads--;
      final int left = (_activeByIp[remote] ?? 1) - 1;
      if (left <= 0) {
        _activeByIp.remove(remote);
      } else {
        _activeByIp[remote] = left;
      }
      if (!_disposed) notifyListeners();
    }
  }

  bool _authorized(HttpRequest request) {
    if (isExpired) return false;
    final String? header = request.headers.value('x-read-token');
    final String? auth = request.headers.value(HttpHeaders.authorizationHeader);
    final String? cookie = request.headers.value(HttpHeaders.cookieHeader);
    String? cookieToken;
    if (cookie != null) {
      for (final String part in cookie.split(';')) {
        final List<String> pair = part.trim().split('=');
        if (pair.length == 2 && pair[0] == 'read_session') cookieToken = pair[1];
      }
    }
    final String? bearer =
        auth != null && auth.toLowerCase().startsWith('bearer ')
            ? auth.substring(7).trim()
            : null;
    return _constantEquals(header, _token) ||
        _constantEquals(bearer, _token) ||
        _constantEquals(cookieToken, _token);
  }

  /// 定长比较，避免通过响应时间推测令牌。
  bool _constantEquals(String? a, String b) {
    if (a == null || a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < b.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  bool _allowRate(String remote) {
    final DateTime now = _clock();
    final _RateWindow window = _rate.putIfAbsent(remote, () => _RateWindow());
    window.hits.removeWhere((DateTime at) =>
        now.difference(at) > const Duration(minutes: 1));
    if (window.hits.length >= _config.maxRequestsPerMinute) return false;
    window.hits.add(now);
    return true;
  }

  bool _isAllowedRemote(InternetAddress? address) {
    if (address == null) return false;
    if (address.isLoopback) return _config.allowLoopback;
    final List<int> raw = address.rawAddress;
    return _isPrivateBytes(raw);
  }

  static bool _isPrivate(InternetAddress address) =>
      _isPrivateBytes(address.rawAddress);

  static bool _isPrivateBytes(List<int> raw) {
    if (raw.length == 16) {
      // IPv4-mapped IPv6 ::ffff:a.b.c.d
      bool mapped = true;
      for (int i = 0; i < 10; i++) {
        if (raw[i] != 0) {
          mapped = false;
          break;
        }
      }
      if (mapped && raw[10] == 0xff && raw[11] == 0xff) {
        return _isPrivateBytes(raw.sublist(12));
      }
      if ((raw[0] & 0xfe) == 0xfc) return true; // fc00::/7
      if (raw[0] == 0xfe && (raw[1] & 0xc0) == 0x80) return true; // fe80::/10
      return false;
    }
    if (raw.length != 4) return false;
    if (raw[0] == 10) return true;
    if (raw[0] == 172 && raw[1] >= 16 && raw[1] <= 31) return true;
    if (raw[0] == 192 && raw[1] == 168) return true;
    if (raw[0] == 169 && raw[1] == 254) return true;
    return false;
  }

  /// 文件名清洗：去掉路径分隔符、控制字符、首尾点与 Windows 保留字符，
  /// 拒绝空名、`.`/`..` 与超长名。返回 null 表示不可用。
  static String? sanitizeFileName(String? raw) {
    if (raw == null) return null;
    String name = raw.trim();
    if (name.isEmpty) return null;
    // 只取最后一段，杜绝目录穿越。
    name = name.split(RegExp(r'[\\/]')).last;
    name = name.replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_');
    name = name.replaceAll(RegExp(r'^\.+'), '');
    name = name.trim();
    if (name.isEmpty || name == '.' || name == '..') return null;
    if (name.length > 120) {
      final int dot = name.lastIndexOf('.');
      final String ext = dot > 0 ? name.substring(dot) : '';
      name = name.substring(0, 120 - ext.length) + ext;
    }
    return name;
  }

  static String _extension(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// 不只信扩展名：PDF 必须以 %PDF 开头，EPUB 必须是 ZIP 容器。
  static Future<bool> _signatureMatches(File file, String ext) async {
    if (ext != 'pdf' && ext != 'epub') return true;
    final RandomAccessFile raf = await file.open();
    try {
      final List<int> head = await raf.read(4);
      if (ext == 'pdf') {
        return head.length >= 4 &&
            head[0] == 0x25 &&
            head[1] == 0x50 &&
            head[2] == 0x44 &&
            head[3] == 0x46;
      }
      return head.length >= 4 &&
          head[0] == 0x50 &&
          head[1] == 0x4b &&
          head[2] == 0x03 &&
          head[3] == 0x04;
    } finally {
      await raf.close();
    }
  }

  void _emit(WifiTransferEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> _json(
      HttpResponse response, int status, Map<String, Object?> body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    try {
      await response.close();
    } catch (_) {}
  }

  String _pairingPage() => '''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Read · WiFi 传书</title>
<style>
  :root{--ink:#1a1a18;--muted:#77726a;--line:#e7e1d6;--bg:#faf8f4}
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
       background:var(--bg);color:var(--ink);font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif}
  .card{width:min(92vw,440px);background:#fff;border:1px solid var(--line);border-radius:18px;padding:26px}
  h1{font-size:20px;margin:0 0 6px}
  p{font-size:13px;line-height:1.7;color:var(--muted);margin:0 0 16px}
  input{width:100%;font-size:26px;letter-spacing:.4em;text-align:center;padding:12px;
        border:1px solid var(--line);border-radius:12px;background:#fff;color:var(--ink)}
  button{width:100%;margin-top:12px;padding:12px;font-size:15px;border:0;border-radius:12px;
         background:#1a1a18;color:#faf8f4;cursor:pointer}
  button[disabled]{opacity:.4;cursor:default}
  .drop{border:1.5px dashed var(--line);border-radius:14px;padding:28px 16px;text-align:center;
        color:var(--muted);font-size:13px;cursor:pointer}
  .drop.hover{border-color:var(--ink);color:var(--ink)}
  .hide{display:none}
  #file{display:none}
  .log{margin-top:14px;font-size:12px;color:var(--muted);white-space:pre-wrap;min-height:18px}
  .ok{color:#2f6b4f}.err{color:#b4423a}
  progress{width:100%;height:6px;margin-top:8px}
</style></head>
<body><div class="card">
  <section id="pair">
    <h1>连接 Read</h1>
    <p>在手机的「WiFi 传书」页面查看 6 位配对码，输入后即可传书。配对码 10 分钟内有效。</p>
    <input id="code" inputmode="numeric" maxlength="6" placeholder="······" autocomplete="one-time-code" />
    <button id="pairBtn">配对</button>
    <div class="log" id="pairLog"></div>
  </section>
  <section id="send" class="hide">
    <h1>传到 Read</h1>
    <p>支持 TXT / EPUB（文字版）/ PDF / Markdown / HTML，单文件不超过 40MB。</p>
    <div class="drop" id="drop">点击选择文件，或把文件拖到这里<input type="file" id="file" multiple /></div>
    <div class="log" id="log"></div>
  </section>
</div>
<script>
const pairSec=document.getElementById('pair'),sendSec=document.getElementById('send');
const codeEl=document.getElementById('code'),pairLog=document.getElementById('pairLog');
const drop=document.getElementById('drop'),fileEl=document.getElementById('file'),log=document.getElementById('log');
let token='';
try{token=sessionStorage.getItem('read_token')||''}catch(e){}
if(token){pairSec.classList.add('hide');sendSec.classList.remove('hide')}
document.getElementById('pairBtn').onclick=async()=>{
  pairLog.textContent='正在配对…';
  try{
    const r=await fetch('/pair',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({code:codeEl.value.trim()})});
    const j=await r.json();
    if(!j.ok){pairLog.className='log err';pairLog.textContent=j.message;return}
    token=j.token;
    try{sessionStorage.setItem('read_token',token)}catch(e){}
    pairSec.classList.add('hide');sendSec.classList.remove('hide');
  }catch(e){pairLog.className='log err';pairLog.textContent='配对失败：'+e}
};
drop.onclick=()=>fileEl.click();
['dragenter','dragover'].forEach(e=>drop.addEventListener(e,ev=>{ev.preventDefault();drop.classList.add('hover')}));
['dragleave','drop'].forEach(e=>drop.addEventListener(e,ev=>{ev.preventDefault();drop.classList.remove('hover')}));
drop.addEventListener('drop',ev=>upload(ev.dataTransfer.files));
fileEl.addEventListener('change',()=>upload(fileEl.files));
function upload(files){
  for(const f of files) one(f);
}
function one(f){
  log.className='log';log.textContent='正在上传 '+f.name+' …';
  const bar=document.createElement('progress');bar.max=1;bar.value=0;
  log.textContent='';log.appendChild(document.createTextNode('正在上传 '+f.name+' '));log.appendChild(bar);
  const xhr=new XMLHttpRequest();
  xhr.open('POST','/upload?name='+encodeURIComponent(f.name));
  xhr.setRequestHeader('X-Read-Token',token);
  xhr.upload.onprogress=e=>{if(e.lengthComputable)bar.value=e.loaded/e.total};
  xhr.onload=()=>{
    let j={};try{j=JSON.parse(xhr.responseText)}catch(e){}
    log.className='log '+(j.ok?'ok':'err');
    log.textContent=j.message||('上传失败（HTTP '+xhr.status+'）');
    if(xhr.status===401){try{sessionStorage.removeItem('read_token')}catch(e){};token='';}
  };
  xhr.onerror=()=>{log.className='log err';log.textContent='网络中断，上传失败：'+f.name};
  xhr.send(f);
}
</script></body></html>''';
}

class _TooLarge implements Exception {
  const _TooLarge();
}
