import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:read/src/sync/encrypted_sync_envelope.dart';
import 'package:read/src/sync/metadata_sync_service.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/sync/sync_document.dart';

/// 真实云端书库索引。
///
/// 书架上的云朵不是装饰：只有云端元数据中存在 `book` 记录，或云端文件区
/// 确实存在对应 64 位哈希文件时，才认为该书在云端。同步失败、未配置、
/// 仅本地有进度都不会显示云朵。
class CloudLibraryIndex extends ChangeNotifier {
  CloudLibraryIndex._();

  static final CloudLibraryIndex instance = CloudLibraryIndex._();
  static const String _key = 'read.cloud.library.index.v1';

  final Map<String, CloudBookState> _states = <String, CloudBookState>{};
  DateTime? _lastRefresh;
  String _lastError = '';

  DateTime? get lastRefresh => _lastRefresh;
  String get lastError => _lastError;

  bool hasCloud(String? hash) {
    if (hash == null || hash.length != 64) return false;
    return _states[hash]?.inCloud ?? false;
  }

  bool hasMetadata(String? hash) =>
      hash != null && (_states[hash]?.metadata ?? false);

  bool hasFile(String? hash) => hash != null && (_states[hash]?.file ?? false);

  CloudBookState? stateFor(String? hash) => hash == null ? null : _states[hash];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.length > 1024 * 1024) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _lastRefresh =
          data['at'] is String ? DateTime.tryParse(data['at'] as String) : null;
      final books = data['books'];
      if (books is Map<String, dynamic>) {
        for (final entry in books.entries) {
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            _states[entry.key] = CloudBookState(
              metadata: value['metadata'] == true,
              file: value['file'] == true,
            );
          }
        }
      }
    } catch (_) {
      _states.clear();
    }
  }

  /// Reads the cloud metadata document and file list. Read-only: never uploads.
  Future<void> refresh({bool force = false}) async {
    if (!SyncConfig.instance.configured) {
      _states.clear();
      _lastError = '未配置云存储';
      _lastRefresh = null;
      await _persist();
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastRefresh != null &&
        now.difference(_lastRefresh!).inMinutes < 2 &&
        _states.isNotEmpty) {
      return;
    }
    _lastError = '';
    try {
      final secrets = await SyncSecrets.load();
      final store = SyncBackendFactory.create(SyncConfig.instance, secrets);
      final bytes = <String, CloudBookState>{};

      final snapshot = await store.read(MetadataSyncService.metadataKey);
      if (snapshot != null) {
        final plaintext = await EncryptedSyncEnvelope.decrypt(
          snapshot.bytes,
          secrets.encryptionPassword,
        );
        final decoded = jsonDecode(plaintext);
        if (decoded is Map<String, dynamic>) {
          final document = SyncDocument.fromJson(decoded);
          for (final record in document.records.values) {
            if (record.deleted || record.kind != 'book') continue;
            final hash = record.fields['hash'];
            if (hash is String && hash.length == 64) {
              bytes.putIfAbsent(hash, () => const CloudBookState());
              bytes[hash] = bytes[hash]!.withMetadata();
            }
          }
        }
      }

      try {
        final entries = await store.list(
            prefix: MetadataSyncService.filesPrefix, max: 4000);
        final hashPattern = RegExp(r'([a-f0-9]{64})');
        for (final entry in entries) {
          final match = hashPattern.firstMatch(entry.key);
          if (match == null) continue;
          final hash = match.group(1)!;
          bytes.putIfAbsent(hash, () => const CloudBookState());
          bytes[hash] = bytes[hash]!.withFile();
        }
      } catch (_) {
        // 文件列表失败时保留元数据结论，不能把“没列出来”当“不存在”。
      }

      _states
        ..clear()
        ..addAll(bytes);
      _lastRefresh = now;
    } catch (error) {
      _lastError = '$error';
      // 保留上一次成功索引，避免网络抖动让所有云朵消失。
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(<String, Object?>{
        'at': _lastRefresh?.toIso8601String(),
        'books': <String, Object?>{
          for (final entry in _states.entries)
            entry.key: <String, Object?>{
              'metadata': entry.value.metadata,
              'file': entry.value.file,
            },
        },
      }),
    );
  }
}

@immutable
class CloudBookState {
  const CloudBookState({this.metadata = false, this.file = false});

  final bool metadata;
  final bool file;

  bool get inCloud => metadata || file;

  CloudBookState withMetadata() => CloudBookState(metadata: true, file: file);
  CloudBookState withFile() => CloudBookState(metadata: metadata, file: true);
}
