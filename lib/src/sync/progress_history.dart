import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_models.dart';

class CloudProgressPoint {
  const CloudProgressPoint({
    required this.hash,
    required this.title,
    required this.device,
    required this.updatedAt,
    required this.offset,
    required this.page,
    required this.format,
  });

  final String hash;
  final String title;
  final String device;
  final DateTime updatedAt;
  final int offset;
  final int page;
  final String format;

  Map<String, Object?> toJson() => <String, Object?>{
        'hash': hash,
        'title': title,
        'device': device,
        'updated_at': updatedAt.toIso8601String(),
        'offset': offset,
        'page': page,
        'format': format,
      };

  static CloudProgressPoint? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse(raw['updated_at'] as String? ?? '');
    final hash = raw['hash'];
    if (at == null || hash is! String) return null;
    return CloudProgressPoint(
      hash: hash,
      title: raw['title'] as String? ?? '未命名',
      device: raw['device'] as String? ?? '',
      updatedAt: at,
      offset: (raw['offset'] as num?)?.toInt() ?? -1,
      page: (raw['page'] as num?)?.toInt() ?? 0,
      format: raw['format'] as String? ?? 'TXT',
    );
  }
}

/// Rolling per-device cloud progress snapshots so "自动跳转云端进度" can be
/// explained and undone instead of silently teleporting the reader.
class ProgressHistoryStore extends ChangeNotifier {
  ProgressHistoryStore._();
  static final ProgressHistoryStore instance = ProgressHistoryStore._();
  static const String _key = 'read.sync.progress.history.v1';
  static const int maxPerBook = 20;

  final Map<String, List<CloudProgressPoint>> _byHash =
      <String, List<CloudProgressPoint>>{};

  List<CloudProgressPoint> forHash(String hash) =>
      List<CloudProgressPoint>.unmodifiable(_byHash[hash] ?? const []);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final list = entry.value;
        if (list is! List) continue;
        final points = <CloudProgressPoint>[];
        for (final item in list) {
          final point = CloudProgressPoint.fromJson(item);
          if (point != null) points.add(point);
        }
        _byHash[entry.key] = points;
      }
    } catch (_) {
      _byHash.clear();
    }
  }

  Future<void> recordManifest(
    ProgressManifest manifest,
    Map<String, String> titleByHash,
  ) async {
    for (final entry in manifest.entries.values) {
      final points = _byHash.putIfAbsent(entry.hash, () => <CloudProgressPoint>[]);
      if (points.any((CloudProgressPoint p) =>
          p.device == entry.device && p.updatedAt.millisecondsSinceEpoch == entry.updatedAt)) {
        continue;
      }
      points.insert(
        0,
        CloudProgressPoint(
          hash: entry.hash,
          title: titleByHash[entry.hash] ?? '未命名',
          device: entry.device,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(entry.updatedAt),
          offset: entry.offset,
          page: entry.page,
          format: entry.format,
        ),
      );
      if (points.length > maxPerBook) {
        points.removeRange(maxPerBook, points.length);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(<String, Object?>{
        for (final entry in _byHash.entries)
          entry.key: entry.value.map((CloudProgressPoint p) => p.toJson()).toList(),
      }),
    );
  }
}
