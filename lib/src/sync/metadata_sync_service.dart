import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../services/library_store.dart';
import 'encrypted_sync_envelope.dart';
import 'metadata_sync_source.dart';
import 'remote_store.dart';
import 's3_store.dart';
import 'sync_config.dart';
import 'sync_document.dart';
import 'sync_history.dart';
import 'webdav_store.dart';

class MetadataSyncReport {
  const MetadataSyncReport({
    required this.status,
    required this.uploaded,
    required this.downloaded,
    required this.conflicts,
    required this.filesUploaded,
    required this.filesDownloaded,
    required this.booksMissing,
    required this.remoteDeleted,
    required this.message,
  });

  final String status; // success | conflict
  final int uploaded;
  final int downloaded;
  final int conflicts;
  final int filesUploaded;
  final int filesDownloaded;
  final int booksMissing;
  final int remoteDeleted;
  final String message;
}

/// Owns metadata/bookmark/settings/file synchronization. Progress has a
/// separate lightweight service so book opening never waits for this.
class MetadataSyncService {
  MetadataSyncService({
    LocalSyncSource? source,
    LocalSyncApplier? applier,
    SyncBaselineStore? baselines,
    SyncHistoryStore? history,
  })  : source = source ?? LocalSyncSource(),
        applier = applier ?? LocalSyncApplier(),
        _baselines = baselines ?? SyncBaselineStore(),
        _history = history ?? SyncHistoryStore.instance;

  static const String metadataKey = 'metadata.enc';
  static const String filesPrefix = 'files/';
  static const int maxSyncFileBytes = 48 * 1024 * 1024;

  final LocalSyncSource source;
  final LocalSyncApplier applier;
  final SyncBaselineStore _baselines;
  final SyncHistoryStore _history;

  Future<MetadataSyncReport> sync({
    required RemoteObjectStore store,
    required String encryptionPassword,
    required bool includeBookmarks,
    required bool includeSettings,
    required bool includeStats,
    required bool includeFiles,
    required bool downloadMissingFiles,
    required String targetId,
  }) async {
    if (encryptionPassword.length < 12) {
      throw const FormatException('同步密码至少需要 12 个字符');
    }
    final deviceId = await SyncConfig.instance.deviceId();
    final baseline = await _baselines.load(targetId);
    SyncDocument? remote;
    String? remoteEtag;
    SyncMergeResult? merge;
    LocalSyncApplyResult? applied;

    for (var attempt = 0; attempt < 3; attempt++) {
      remote = null;
      remoteEtag = null;
      final snapshot = await store.read(metadataKey);
      if (snapshot != null) {
        final plaintext =
            await EncryptedSyncEnvelope.decrypt(snapshot.bytes, encryptionPassword);
        final decoded = _decodeDocument(plaintext);
        remote = decoded;
        remoteEtag = snapshot.etag;
      }
      final local = await source.build(
        deviceId: deviceId,
        includeBookmarks: includeBookmarks,
        includeSettings: includeSettings,
        includeStats: includeStats,
        baseline: baseline,
      );
      merge = SyncDocumentMerger.merge(
        local: local,
        remote: remote,
        baseline: baseline,
      );
      applied = await applier.apply(
        merge.document,
        includeBookmarks: includeBookmarks,
        includeSettings: includeSettings,
      );
      if (!merge.changed && remote != null) {
        break;
      }
      final bytes = await EncryptedSyncEnvelope.encrypt(
        merge.document.encode(),
        encryptionPassword,
      );
      try {
        await store.write(bytes, metadataKey, expectedEtag: remoteEtag);
        break;
      } on RemoteConflictException {
        if (attempt == 2) rethrow;
        // Re-read, merge again, never blind overwrite.
      }
    }
    if (merge == null) {
      throw const RemoteStoreException('同步未完成，请稍后重试');
    }
    final finalMerge = merge;
    await _baselines.save(targetId, finalMerge.document);

    var filesUploaded = 0;
    var filesDownloaded = 0;
    var missing = applied?.booksMissing ?? 0;
    if (includeFiles) {
      final remoteFiles = <String>{};
      try {
        final entries = await store.list(prefix: filesPrefix, max: 2000);
        remoteFiles.addAll(entries.map((RemoteEntry e) => e.key));
      } catch (_) {
        // File listing is optional; metadata sync must still succeed.
      }
      filesUploaded = await _uploadLocalFiles(
        store: store,
        remoteFiles: remoteFiles,
      );
      if (downloadMissingFiles) {
        filesDownloaded = await _downloadMissingFiles(
          store: store,
          remoteFiles: remoteFiles,
          document: finalMerge.document,
        );
        missing = 0;
      }
    }

    final status = finalMerge.conflicts.isEmpty ? 'success' : 'conflict';
    final message = _message(
      uploaded: finalMerge.localWon,
      downloaded: finalMerge.remoteWon,
      conflicts: finalMerge.conflicts.length,
      missing: missing,
      filesUploaded: filesUploaded,
      filesDownloaded: filesDownloaded,
    );
    await _history.add(SyncHistoryEntry(
      at: DateTime.now(),
      kind: 'full',
      status: status,
      message: message,
      uploaded: finalMerge.localWon,
      downloaded: finalMerge.remoteWon,
      conflicts: finalMerge.conflicts.length,
      device: '本机',
    ));
    return MetadataSyncReport(
      status: status,
      uploaded: finalMerge.localWon,
      downloaded: finalMerge.remoteWon,
      conflicts: finalMerge.conflicts.length,
      filesUploaded: filesUploaded,
      filesDownloaded: filesDownloaded,
      booksMissing: missing,
      remoteDeleted: applied?.remoteDeleted ?? 0,
      message: message,
    );
  }

  SyncDocument _decodeDocument(String plaintext) {
    if (plaintext.length > SyncDocument.maxDocumentBytes) {
      throw const FormatException('云端同步文档超过 8MB 上限');
    }
    final decoded = _json(plaintext);
    return SyncDocument.fromJson(decoded);
  }

  Map<String, dynamic> _json(String value) {
    final decoded = const JsonCodec().decode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('同步文档不是 JSON 对象');
    }
    return decoded;
  }

  Future<int> _uploadLocalFiles({
    required RemoteObjectStore store,
    required Set<String> remoteFiles,
  }) async {
    var count = 0;
    for (final book in LibraryStore.instance.books) {
      final hash = book.contentHash;
      final path = book.sourcePath;
      if (hash == null || path == null || !await File(path).exists()) continue;
      final file = File(path);
      final size = await file.length();
      if (size <= 0 || size > maxSyncFileBytes) continue;
      final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
      final key = '$filesPrefix$hash.$ext';
      if (remoteFiles.contains(key)) continue;
      final bytes = await file.readAsBytes();
      try {
        await store.write(Uint8List.fromList(bytes), key);
        count++;
      } on RemoteConflictException {
        // Another device uploaded the same content-addressed file first.
      }
      if (count >= 10) break; // bounded per run; remaining files next sync
    }
    return count;
  }

  Future<int> _downloadMissingFiles({
    required RemoteObjectStore store,
    required Set<String> remoteFiles,
    required SyncDocument document,
  }) async {
    var count = 0;
    for (final record in document.records.values) {
      if (record.kind != 'book' || record.deleted) continue;
      final hash = record.fields['hash'];
      final fileName = record.fields['file_name'];
      if (hash is! String || fileName is! String) continue;
      if (LibraryStore.instance.hasHash(hash)) continue;
      final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
      final key = '$filesPrefix$hash.$ext';
      if (!remoteFiles.contains(key)) continue;
      final snapshot = await store.read(key);
      if (snapshot == null) continue;
      if (sha256.convert(snapshot.bytes).toString() != hash) {
        await _history.add(SyncHistoryEntry(
          at: DateTime.now(),
          kind: 'full',
          status: 'failed',
          message: '云端文件哈希不匹配，已拒绝导入：$fileName',
        ));
        continue;
      }
      final title = record.fields['title'] as String? ?? fileName;
      final author = record.fields['author'] as String? ?? '云端导入';
      final format = record.fields['format'] as String? ?? ext.toUpperCase();
      final lastRead = record.fields['last_read_at'];
      try {
        await LibraryStore.instance.importSyncedFile(
          bytes: snapshot.bytes,
          hash: hash,
          fileName: fileName,
          title: title,
          author: author,
          format: format,
          chapterCount: (record.fields['chapter_count'] as num?)?.toInt() ?? 0,
          lastReadAt: lastRead is int && lastRead > 0
              ? DateTime.fromMillisecondsSinceEpoch(lastRead)
              : null,
        );
        count++;
      } catch (_) {
        // Format parser rejection is reported through history; no partial book.
      }
      if (count >= 5) break;
    }
    return count;
  }

  String _message({
    required int uploaded,
    required int downloaded,
    required int conflicts,
    required int missing,
    required int filesUploaded,
    required int filesDownloaded,
  }) {
    final parts = <String>[
      '本机变更 $uploaded 条',
      '云端变更 $downloaded 条',
    ];
    if (conflicts > 0) parts.add('冲突 $conflicts 条（已按设备顺序合并）');
    if (missing > 0) parts.add('$missing 本书本机缺少文件，仅同步了元数据');
    if (filesUploaded > 0) parts.add('上传文件 $filesUploaded 个');
    if (filesDownloaded > 0) parts.add('下载文件 $filesDownloaded 个');
    return parts.join('，');
  }
}



/// Builds the configured backend. Credentials are supplied only here, right
/// before the network call, so UI/state never retain a cloud password globally.
class SyncBackendFactory {
  static RemoteObjectStore create(SyncConfig config, SyncSecrets secrets) {
    if (config.provider == 'webdav') {
      return WebDavStore(
        serverUrl: config.webdavUrl,
        username: config.webdavUsername,
        password: secrets.webdavPassword,
        directory: config.webdavDirectory,
      );
    }
    if (config.provider == 's3') {
      return S3Store(
        endpoint: config.s3Endpoint,
        region: config.s3Region,
        bucket: config.s3Bucket,
        prefix: config.s3Prefix,
        accessKey: config.s3AccessKey,
        secretKey: secrets.s3SecretKey,
      );
    }
    throw const FormatException('未支持的云存储类型');
  }

  static String targetId(SyncConfig config) => SyncBaselineStore.targetId(
        provider: config.provider,
        endpoint:
            config.provider == 'webdav' ? config.webdavUrl : config.s3Endpoint,
        directory: config.provider == 'webdav'
            ? config.webdavDirectory
            : '${config.s3Bucket}/${config.s3Prefix}',
      );
}
