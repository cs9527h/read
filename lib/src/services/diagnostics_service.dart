import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一条本地诊断记录。永远不包含书籍正文、笔记内容或账号凭据。
class DiagnosticEntry {
  const DiagnosticEntry({
    required this.at,
    required this.kind,
    required this.message,
    this.detail = '',
  });

  final DateTime at;

  /// app / flutter / reader / sync / storage / error
  final String kind;
  final String message;
  final String detail;

  Map<String, Object?> toJson() => <String, Object?>{
        'at': at.toIso8601String(),
        'kind': kind,
        'message': message,
        'detail': detail,
      };

  static DiagnosticEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final DateTime? at = DateTime.tryParse(raw['at'] as String? ?? '');
    if (at == null) return null;
    return DiagnosticEntry(
      at: at,
      kind: raw['kind'] as String? ?? 'app',
      message: raw['message'] as String? ?? '',
      detail: raw['detail'] as String? ?? '',
    );
  }
}

/// 本地诊断与崩溃记录。
///
/// 边界（对应用户第七阶段要求）：
/// - 只写本地，默认不上传；远程上传必须另行取得用户明确授权，本版本不提供；
/// - 环形缓冲 200 条，单条 600 字，超出自动轮转；
/// - 写入前统一脱敏：密码、令牌、Cookie、带凭据的 URL、邮箱全部打码；
/// - 崩溃/异常/同步失败/正文解析失败都记录，用户可导出复制。
class DiagnosticsService extends ChangeNotifier {
  DiagnosticsService._();

  static final DiagnosticsService instance = DiagnosticsService._();

  static const String _key = 'read.diagnostics.v1';
  static const String _enabledKey = 'read.diagnostics.enabled';
  static const int maxEntries = 200;
  static const int maxMessageLength = 600;

  final List<DiagnosticEntry> _entries = <DiagnosticEntry>[];
  SharedPreferences? _prefs;
  bool _enabled = true;
  bool _installed = false;

  List<DiagnosticEntry> get entries => List<DiagnosticEntry>.unmodifiable(_entries);
  bool get enabled => _enabled;
  int get count => _entries.length;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _enabled = _prefs!.getBool(_enabledKey) ?? true;
    _entries.clear();
    final String? raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final entry = DiagnosticEntry.fromJson(item);
            if (entry != null) _entries.add(entry);
          }
        }
      } catch (_) {
        _entries.clear();
      }
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_enabledKey, value);
    notifyListeners();
  }

  /// 安装全局错误捕获。只记录，不改变 Flutter 默认的错误展示。
  void install() {
    if (_installed) return;
    _installed = true;
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      unawaited(record(
        kind: 'flutter',
        message: details.exceptionAsString(),
        detail: details.context?.toDescription() ?? '',
        error: details.exception,
        stack: details.stack,
      ));
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(record(
        kind: 'error',
        message: '$error',
        error: error,
        stack: stack,
      ));
      return false;
    };
  }

  Future<void> record({
    required String kind,
    required String message,
    String detail = '',
    Object? error,
    StackTrace? stack,
  }) async {
    if (!_enabled) return;
    final String safeMessage = redact(message);
    final StringBuffer buffer = StringBuffer(redact(detail));
    if (error != null && '$error' != message) {
      if (buffer.isNotEmpty) buffer.write(' · ');
      buffer.write(redact('$error'));
    }
    if (stack != null) {
      final List<String> lines = stack.toString().split('\n');
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(redact(lines.take(6).join('\n')));
    }
    _entries.add(DiagnosticEntry(
      at: DateTime.now(),
      kind: kind,
      message: safeMessage.length > maxMessageLength
          ? '${safeMessage.substring(0, maxMessageLength)}…'
          : safeMessage,
      detail: buffer.length > maxMessageLength
          ? '${buffer.toString().substring(0, maxMessageLength)}…'
          : buffer.toString(),
    ));
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries.clear();
    await _prefs?.remove(_key);
    notifyListeners();
  }

  /// 导出为纯文本报告，用户可自行复制/保存后发给开发者。
  String exportReport({String appVersion = ''}) {
    final StringBuffer out = StringBuffer();
    out.writeln('Read 诊断报告');
    out.writeln('版本：${appVersion.isEmpty ? '未知' : appVersion}');
    out.writeln('平台：${defaultTargetPlatform.name}');
    out.writeln('导出时间：${DateTime.now().toIso8601String()}');
    out.writeln('记录条数：${_entries.length}');
    out.writeln('说明：本报告仅本地生成，未上传；内容已脱敏。');
    out.writeln('---');
    for (final DiagnosticEntry entry in _entries) {
      out.writeln('[${entry.at.toIso8601String()}] (${entry.kind}) ${entry.message}');
      if (entry.detail.isNotEmpty) {
        for (final String line in entry.detail.split('\n')) {
          out.writeln('    $line');
        }
      }
    }
    return out.toString();
  }

  /// 统一脱敏。保留足够定位问题的信息，但去掉任何可能的凭据。
  static String redact(String raw) {
    String text = raw;
    // Bearer 令牌要在键值脱敏之前处理，否则 "Authorization: Bearer xxx"
    // 只会把 "Bearer" 当作值替换掉，真正的令牌会漏出来。
    text = text.replaceAllMapped(
      RegExp(r'Bearer\s+[A-Za-z0-9._\-]+'),
      (Match m) => 'Bearer <redacted>',
    );
    // password / token / secret / authorization 等键值。
    text = text.replaceAllMapped(
      RegExp(
        r'(password|passwd|pwd|token|secret|authorization|cookie|apikey|api_key|access_key)'
        r'(["\s]*[:=]\s*["\u0027]?)([^\s,;"\u0027}]+)',
        caseSensitive: false,
      ),
      (Match m) => '${m.group(1)}${m.group(2)}<redacted>',
    );
    // URL 中的 user:pass@
    text = text.replaceAllMapped(
      RegExp(r'(\w+://)[^/\s:@]+:[^/\s@]+@'),
      (Match m) => '${m.group(1)}<redacted>@',
    );
    // 邮箱
    text = text.replaceAllMapped(
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
      (Match m) => '<email>',
    );
    return text;
  }

  Future<void> _persist() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final String payload = jsonEncode(
      _entries.map((DiagnosticEntry e) => e.toJson()).toList(),
    );
    // 容量兜底：极端情况下先丢最旧的记录，保证写入不会无限膨胀。
    if (payload.length > 256 * 1024) {
      while (_entries.length > 20 &&
          jsonEncode(_entries.map((DiagnosticEntry e) => e.toJson()).toList())
                  .length >
              256 * 1024) {
        _entries.removeAt(0);
      }
    }
    await prefs.setString(
      _key,
      jsonEncode(_entries.map((DiagnosticEntry e) => e.toJson()).toList()),
    );
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _entries.clear();
    _enabled = true;
    _prefs = await SharedPreferences.getInstance();
    await _prefs!.remove(_key);
    notifyListeners();
  }
}
