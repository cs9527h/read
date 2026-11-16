import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/sync/encrypted_sync_envelope.dart';
import 'package:read/src/sync/metadata_sync_service.dart';
import 'package:read/src/sync/remote_store.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/sync/sync_document.dart';
import 'package:read/src/sync/sync_record.dart';

/// 一本书相对于云端的真实状态。
///
/// 这里刻意只区分三种"用户看得懂、且能验证"的状态，而不是给每本书都挂云朵：
/// - [localOnly] 仅本地（或云同步未开启 / 未确认 / 只同步了进度但没有文件）
/// - [synced] 云端有文件 + 本地也有文件
/// - [cloudOnly] 云端有完整记录但本地没有文件（可下载的占位书）
enum CloudState { localOnly, synced, cloudOnly }

/// 云端书目探测与状态缓存。
///
/// 判定规则（与产品要求一一对应）：
/// 1. 云同步未配置 → 一律 [CloudState.localOnly]；
/// 2. 书没有 contentHash（从未确认过云端身份）→ localOnly；
/// 3. 云端 `files/<hash>.<ext>` 存在且本地文件存在 → synced；
/// 4. 云端有该书元数据记录、本地没有文件 → cloudOnly；
/// 5. 只有进度、没有文件、也没有元数据 → localOnly（不显示云朵）。
class CloudPresence extends ChangeNotifier {
  CloudPresence._();

  static final CloudPresence instance = CloudPresence._();

  bool _refreshing = false;
  bool _available = false;
  String? _error;
  DateTime? _checkedAt;

  /// 本地文件存在性缓存。
  ///
  /// [stateFor] 会被书架每一帧、每一格调用，直接 `existsSync` 会在滚动时累积成
  /// 成百上千次系统调用。这里按路径缓存，并设 3 秒 TTL：删除/导入后最多 3 秒收敛，
  /// 远小于用户感知阈值，但省掉了滚动期间的重复 stat。
  final Map<String, bool> _existsCache = <String, bool>{};
  DateTime _existsCachedAt = DateTime.fromMillisecondsSinceEpoch(0);

  final Set<String> _remoteFileHashes = <String>{};
  final Set<String> _remoteMetaHashes = <String>{};
  final Map<String, String> _remoteTitles = <String, String>{};
  final Map<String, int> _remoteOffsets = <String, int>{};
  final Map<String, int> _remoteChapters = <String, int>{};
  final Map<String, int> _remotePages = <String, int>{};
  final Map<String, int> _remoteBookmarkCounts = <String, int>{};
  SyncDocument? _document;
  DateTime? _remoteSettingsAt;

  bool get refreshing => _refreshing;
  bool get available => _available;
  String? get error => _error;
  DateTime? get checkedAt => _checkedAt;
  Set<String> get remoteFileHashes => Set<String>.unmodifiable(_remoteFileHashes);
  Set<String> get remoteMetaHashes => Set<String>.unmodifiable(_remoteMetaHashes);
  Map<String, String> get remoteTitles => Map<String, String>.unmodifiable(_remoteTitles);
  Map<String, int> get remoteOffsets => Map<String, int>.unmodifiable(_remoteOffsets);
  Map<String, int> get remoteChapters => Map<String, int>.unmodifiable(_remoteChapters);
  Map<String, int> get remotePages => Map<String, int>.unmodifiable(_remotePages);
  Map<String, int> get remoteBookmarkCounts =>
      Map<String, int>.unmodifiable(_remoteBookmarkCounts);
  SyncDocument? get document => _document;
  DateTime? get remoteSettingsAt => _remoteSettingsAt;

  CloudState stateFor(Book book) {
    if (!_available) return CloudState.localOnly;
    final String? hash = book.contentHash;
    if (hash == null || hash.isEmpty) return CloudState.localOnly;
    final bool localExists = _localFileExists(book.sourcePath);
    final bool fileInCloud = _remoteFileHashes.contains(hash);
    final bool metaInCloud = _remoteMetaHashes.contains(hash);
    if (fileInCloud && localExists) return CloudState.synced;
    if (metaInCloud && !localExists) return CloudState.cloudOnly;
    return CloudState.localOnly;
  }

  bool _localFileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    final DateTime now = DateTime.now();
    if (now.difference(_existsCachedAt) > const Duration(seconds: 3)) {
      _existsCache.clear();
      _existsCachedAt = now;
    }
    return _existsCache.putIfAbsent(path, () => File(path).existsSync());
  }

  /// 只同步了进度、书文件不在云端的书：用于「云端数据对比」，不用于云朵。
  bool progressOnly(Book book) {
    final String? hash = book.contentHash;
    if (!_available || hash == null) return false;
    return _remoteMetaHashes.contains(hash) && !_remoteFileHashes.contains(hash);
  }

  void markUnavailable() {
    _available = false;
    _existsCache.clear();
    _remoteFileHashes.clear();
    _remoteMetaHashes.clear();
    _remoteTitles.clear();
    _remoteOffsets.clear();
    _remoteChapters.clear();
    _remotePages.clear();
    _remoteBookmarkCounts.clear();
    _remoteSettingsAt = null;
    _document = null;
    notifyListeners();
  }

  /// 真实读取云端：列出 files/ 并尝试解密 metadata.enc。
  /// 失败时不清空旧结果，只记录错误——避免一次网络抖动让书架云朵闪没。
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    final SyncConfig config = SyncConfig.instance;
    if (!config.configured) {
      markUnavailable();
      return;
    }
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final SyncSecrets secrets = await SyncSecrets.load();
      final RemoteObjectStore store = SyncBackendFactory.create(config, secrets);
      final List<RemoteEntry> entries = await store.list(prefix: 'files/', max: 2000);
      final Set<String> hashes = <String>{};
      for (final RemoteEntry entry in entries) {
        final String name = entry.key.split('/').last;
        final String base = name.endsWith('.enc')
            ? name.substring(0, name.length - 4)
            : name;
        final int dot = base.indexOf('.');
        if (dot > 8) hashes.add(base.substring(0, dot));
      }
      _remoteFileHashes
        ..clear()
        ..addAll(hashes);

      _remoteMetaHashes.clear();
      _remoteTitles.clear();
      _remoteOffsets.clear();
      _remoteChapters.clear();
      _remotePages.clear();
      _remoteBookmarkCounts.clear();
      _remoteSettingsAt = null;
      _document = null;
      final RemoteSnapshot? meta = await store.read(MetadataSyncService.metadataKey);
      if (meta != null && secrets.encryptionPassword.length >= 12) {
        try {
          final String plain = await EncryptedSyncEnvelope.decrypt(
            meta.bytes,
            secrets.encryptionPassword,
          );
          final SyncDocument doc =
              SyncDocument.fromJson(jsonDecode(plain) as Map<String, dynamic>);
          _document = doc;
          for (final SyncRecord record in doc.records.values) {
            if (record.deleted) continue;
            final Object? hash = record.fields['hash'];
            if (record.kind == 'book' && hash is String && hash.isNotEmpty) {
              _remoteMetaHashes.add(hash);
              final Object? title = record.fields['title'];
              if (title is String) _remoteTitles[hash] = title;
              final Object? chapter = record.fields['progress_chapter'];
              if (chapter is num) _remoteChapters[hash] = chapter.toInt();
              final Object? page = record.fields['progress_page'];
              if (page is num) _remotePages[hash] = page.toInt();
              final Object? offset = record.fields['offset'];
              if (offset is num) _remoteOffsets[hash] = offset.toInt();
            }
            if (record.kind == 'bookmark') {
              final Object? bookmarkHash = record.fields['book_hash'];
              if (bookmarkHash is String) {
                _remoteBookmarkCounts[bookmarkHash] =
                    (_remoteBookmarkCounts[bookmarkHash] ?? 0) + 1;
              }
            }
            if (record.kind == 'settings') {
              _remoteSettingsAt = DateTime.fromMillisecondsSinceEpoch(record.updatedAt);
            }
          }
        } on FormatException {
          // 密码不对或旧版明文文档：不猜测，保持"未确认"状态。
        }
      }
      _available = _remoteFileHashes.isNotEmpty || _remoteMetaHashes.isNotEmpty;
      _checkedAt = DateTime.now();
      // 云端状态刚刷新过，本地文件判定也一并重算。
      _existsCache.clear();
    } catch (error) {
      _error = error.toString();
      if (_checkedAt == null) _available = false;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }
}
