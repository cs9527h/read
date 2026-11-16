import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-preserving operational telemetry. No book text, titles, credentials,
/// URLs, document paths, or device identifiers are ever recorded.
class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  static const String _settingsKey = 'read.diagnostics.settings.v1';
  static const String _eventsKey = 'read.diagnostics.events.v1';
  static const Set<String> allowedEvents = <String>{
    'app_start', 'app_resume', 'app_background', 'sync_started',
    'sync_succeeded', 'sync_failed', 'feedback_opened',
  };

  SharedPreferences? _prefs;
  final List<Map<String, String>> _events = <Map<String, String>>[];
  bool enabled = false;
  String endpoint = '';
  DateTime? _lastUpload;
  bool _uploading = false;

  List<Map<String, String>> get events =>
      List<Map<String, String>>.unmodifiable(_events);

  static bool validEndpoint(String address) {
    final uri = Uri.tryParse(address.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.fragment.isEmpty &&
        uri.query.isEmpty;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_settingsKey);
    if (raw != null) {
      try {
        final settings = jsonDecode(raw) as Map<String, dynamic>;
        final configuredEndpoint = settings['endpoint'];
        if (configuredEndpoint is String &&
            validEndpoint(configuredEndpoint)) {
          endpoint = configuredEndpoint;
          enabled = settings['enabled'] == true;
        }
      } catch (_) {
        // Malformed telemetry settings must not prevent reading.
      }
    }
    final saved = _prefs!.getString(_eventsKey);
    if (saved != null) {
      try {
        for (final item in jsonDecode(saved) as List<dynamic>) {
          if (item is Map<String, dynamic> &&
              allowedEvents.contains(item['event']) &&
              item['at'] is String) {
            _events.add(<String, String>{
              'at': item['at'] as String,
              'event': item['event'] as String,
            });
          }
        }
        if (_events.length > 100) {
          _events.removeRange(0, _events.length - 100);
        }
      } catch (_) {
        _events.clear();
      }
    }
  }

  Future<void> configure({
    required bool consent,
    required String uploadEndpoint,
  }) async {
    final clean = uploadEndpoint.trim();
    if (consent && !validEndpoint(clean)) {
      throw const FormatException('请先填写有效的 HTTPS 日志接收地址');
    }
    _prefs ??= await SharedPreferences.getInstance();
    endpoint = validEndpoint(clean) ? clean : '';
    enabled = consent && endpoint.isNotEmpty;
    await _prefs!.setString(_settingsKey,
        jsonEncode(<String, Object>{'enabled': enabled, 'endpoint': endpoint}));
  }

  Future<void> record(String event) async {
    if (!allowedEvents.contains(event)) return;
    _prefs ??= await SharedPreferences.getInstance();
    _events.add(<String, String>{
      'at': DateTime.now().toUtc().toIso8601String(),
      'event': event,
    });
    if (_events.length > 100) _events.removeAt(0);
    await _prefs!.setString(_eventsKey, jsonEncode(_events));
    if (enabled) unawaited(uploadIfDue());
  }

  Future<void> clear() async {
    _events.clear();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_eventsKey);
  }

  /// Best-effort upload; no payload includes reading data or secrets.
  /// Endpoint is user-supplied because the app has no built-in log receiver.
  Future<bool> uploadIfDue({bool force = false}) async {
    if (!enabled || !validEndpoint(endpoint) || _uploading ||
        _events.isEmpty) return false;
    if (!force && _lastUpload != null &&
        DateTime.now().difference(_lastUpload!) <
            const Duration(minutes: 15)) return false;
    _uploading = true;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 6));
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(<String, Object>{
        'schema': 'read-diagnostics-v1',
        'events': _events,
      })));
      final response = await request.close()
          .timeout(const Duration(seconds: 8));
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      _lastUpload = DateTime.now();
      _events.clear();
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_eventsKey);
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
      _uploading = false;
    }
  }
}
