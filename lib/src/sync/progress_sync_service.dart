import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256;
import 'package:shared_preferences/shared_preferences.dart';

import '../model/book.dart';
import '../services/chapter_splitter.dart';
import '../services/library_store.dart';
import 'encrypted_sync_envelope.dart';
import 'progress_history.dart';
import 'progress_models.dart';
import 'remote_store.dart';
import 'webdav_encrypted_object.dart';

class ProgressSyncCredentials {
  const ProgressSyncCredentials({
    required this.fileUrl,
    required this.username,
    required this.webdavPassword,
    required this.encryptionPassword,
  });

  final Uri fileUrl;
  final String username;
  final String webdavPassword;
  final String encryptionPassword;
}

class ProgressSyncConflict {
  const ProgressSyncConflict(this.title, this.local, this.remote);
  final String title;
  final ProgressRecord local;
  final ProgressRecord remote;
}

class ProgressSyncCancelled implements Exception {
  const ProgressSyncCancelled();
}

typedef ProgressConflictResolver = Future<ProgressChoice?> Function(
  ProgressSyncConflict conflict,
);

class ProgressSyncReport {
  const ProgressSyncReport({
    required this.scanned,
    required this.uploaded,
    required this.downloaded,
    required this.unmatched,
    required this.conflicts,
    this.downloadedHashes = const <String>{},
  });
  final int scanned;
  final int uploaded;
  final int downloaded;
  final int unmatched;
  final int conflicts;
  final Set<String> downloadedHashes;
}

abstract class ProgressTransport {
  Future<RemoteSnapshot?> read();
  Future<void> write(Uint8List bytes, {String? expectedEtag});
}

/// Metadata-only sync with encrypted conditional WebDAV writes.
///
/// Original book files are never uploaded or downloaded by this service.
/// Only books with stable hashes AND usable text anchors (or PDF page index)
/// participate. Neither a failed upload nor an aborted conflict resolution
/// changes local reading progress or the stored common ancestor.
class ProgressSyncService {
  ProgressSyncService(this.library);
  final LibraryStore library;

  static const _deviceKey = 'read.sync.device.v1';
  static const _baselinePrefix = 'read.sync.progress.baseline.v1.';

  Future<ProgressSyncReport> sync(
    ProgressSyncCredentials credentials, {
    required ProgressConflictResolver resolveConflict,
    Book? onlyBook,
    bool continueOnUnresolved = false,
  }) async {
    final client = WebDavEncryptedObject(
      fileUrl: credentials.fileUrl,
      username: credentials.username,
      password: credentials.webdavPassword,
    );
    return _sync(
      _WebDavProgressTransport(client),
      credentials.encryptionPassword,
      credentials.fileUrl.toString(),
      resolveConflict,
      onlyBook,
      continueOnUnresolved,
    );
  }

  Future<ProgressSyncReport> syncStore(
    RemoteObjectStore store,
    String encryptionPassword, {
    required String targetId,
    required ProgressConflictResolver resolveConflict,
    Book? onlyBook,
    bool continueOnUnresolved = false,
  }) async {
    return _sync(
      _ObjectStoreProgressTransport(store),
      encryptionPassword,
      targetId,
      resolveConflict,
      onlyBook,
      continueOnUnresolved,
    );
  }

  /// Reads one book's cloud position without merging or writing anything.
  /// Used by the reader's sync sheet to show local vs cloud before choosing.
  Future<ProgressRecord?> fetchRemoteStore(
    RemoteObjectStore store,
    String encryptionPassword,
    String targetId,
    String bookHash,
  ) async {
    final snapshot = await _ObjectStoreProgressTransport(store).read();
    if (snapshot == null) return null;
    final plaintext = await EncryptedSyncEnvelope.decrypt(
      snapshot.bytes,
      encryptionPassword,
    );
    final manifest = ProgressManifest.decode(plaintext);
    return manifest.entries[bookHash];
  }

  Future<ProgressSyncReport> _sync(
    ProgressTransport transport,
    String encryptionPassword,
    String targetId,
    ProgressConflictResolver resolveConflict,
    Book? onlyBook,
    bool continueOnUnresolved,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final device = await _getOrMakeDeviceId(preferences);
    final baselineKey =
        _baselinePrefix + sha256.convert(utf8.encode(targetId)).toString();

    ProgressManifest baseline;
    final savedBaseline = preferences.getString(baselineKey);
    if (savedBaseline == null) {
      baseline = const ProgressManifest(<String, ProgressRecord>{});
    } else {
      try {
        baseline = ProgressManifest.decode(savedBaseline);
      } catch (_) {
        throw const FormatException('本地同步基线损坏，已停止同步以保护阅读进度');
      }
    }

    final booksByHash = <String, List<Book>>{};
    final local = <String, ProgressRecord>{};

    for (final book in List<Book>.of(library.books)) {
      if (onlyBook != null && book.id != onlyBook.id) continue;
      final path = book.sourcePath;
      if (path == null) continue; // sample book / no actual source file
      final file = File(path);
      if (!await file.exists()) continue;
      final digest = await library.ensureContentHash(book);
      // Include unread books as matching targets: they may have no usable
      // local character anchor yet, but can safely receive cloud progress.
      booksByHash.putIfAbsent(digest, () => <Book>[]).add(book);
      final position = _snapshot(book, digest, device);
      if (position == null) {
        // New imports without a reading position can receive cloud progress.
        // But older page-only bookmarks must not be overwritten as "unread".
        if (book.lastReadAt != null ||
            book.chapterIndex.value > 0 ||
            book.pageIndex.value > 0) {
          throw FormatException('《' + book.title +
              '》还使用旧版页码进度。请先打开此书并翻页一次，生成准确字符位置后重试同步');
        }
        continue;
      }
      if (local.containsKey(digest) &&
          !local[digest]!.samePosition(position)) {
        throw FormatException('《' + book.title + '》存在内容相同但进度不同的本地副本，请先统一');
      }
      local[digest] = position;
    }

    final remoteSnapshot = await transport.read();
    final ProgressManifest remote;
    if (remoteSnapshot == null) {
      remote = const ProgressManifest(<String, ProgressRecord>{});
    } else {
      final plaintext = await EncryptedSyncEnvelope.decrypt(
        remoteSnapshot.bytes,
        encryptionPassword,
      );
      remote = ProgressManifest.decode(plaintext);
      await ProgressHistoryStore.instance.recordManifest(
        remote,
        <String, String>{
          for (final entry in booksByHash.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.first.title,
        },
      );
    }

    final merged = <String, ProgressRecord>{...remote.entries};
    final toApply = <String, ProgressRecord>{};
    int conflicts = 0;
    int uploads = 0;

    for (final pair in local.entries) {
      final hash = pair.key;
      final here = pair.value;
      final there = remote.entries[hash];
      final last = baseline.entries[hash];

      if (there == null) {
        final newVersion = (last?.revision ?? 0) + 1;
        merged[hash] = here.withRevision(
          newVersion, device, DateTime.now().millisecondsSinceEpoch,
        );
        uploads++;
        continue;
      }

      if (here.textHash != there.textHash) {
        throw FormatException('《' + booksByHash[hash]!.first.title +
            '》两台设备文本解析结果不一致，已停止同步以防止错位');
      }
      if (here.samePosition(there)) {
        merged[hash] = there;
        continue;
      }

      final decision = ProgressMerger.compareToBaseline(
        local: here, remote: there, baseline: last,
      );
      final isConflict = decision == ProgressDecision.conflict;

      ProgressChoice choice;
      if (isConflict) {
        conflicts++;
        final selection = await resolveConflict(
          ProgressSyncConflict(booksByHash[hash]!.first.title, here, there),
        );
        if (selection == null) {
          if (continueOnUnresolved) {
            // Keep the cloud position for this book, write nothing for it,
            // and continue so other books are never blocked.
            merged[hash] = there;
            continue;
          }
          throw const ProgressSyncCancelled();
        }
        choice = selection;
      } else {
        choice = decision == ProgressDecision.local
            ? ProgressChoice.local
            : ProgressChoice.cloud;
      }

      if (choice == ProgressChoice.local) {
        merged[hash] = here.withRevision(
          (there.revision > (last?.revision ?? 0)
                  ? there.revision
                  : (last?.revision ?? 0)) +
              1,
          device,
          DateTime.now().millisecondsSinceEpoch,
        );
        uploads++;
      } else {
        // Manual cloud selection is itself a new durable revision.
        merged[hash] = isConflict
            ? there.withRevision(
                (there.revision > (last?.revision ?? 0)
                        ? there.revision
                        : (last?.revision ?? 0)) +
                    1,
                device,
                DateTime.now().millisecondsSinceEpoch,
              )
            : there;
        toApply[hash] = merged[hash]!;
        if (isConflict) uploads++;
      }
    }

    // If this book has never been opened locally, do not invent position 0
    // or treat it as a conflicting edit. Adopt the matched cloud anchor.
    for (final pair in remote.entries.entries) {
      if (!local.containsKey(pair.key) && booksByHash.containsKey(pair.key)) {
        toApply[pair.key] = pair.value;
      }
    }

    // Validate all inbound positions before writing any cloud changes.
    for (final pair in toApply.entries) {
      for (final book in booksByHash[pair.key] ?? const <Book>[]) {
        _validateRemote(book, pair.value);
      }
    }

    // Keep entries for books not imported on this device. They must never be
    // treated as deleted simply because the local library is smaller.
    final hasCloudChanges = !_sameManifest(remote.entries, merged);
    if (hasCloudChanges) {
      final encrypted = await EncryptedSyncEnvelope.encrypt(
        ProgressManifest(merged).encode(),
        encryptionPassword,
      );
      // If-Match/If-None-Match refuses concurrent updates. No local progress
      // is modified before this conditional cloud commit succeeds.
      await transport.write(encrypted, expectedEtag: remoteSnapshot?.etag);
    }

    // A new, validated cloud version is now available. Apply downloaded
    // positions only to existing local copies matched by exact source hash.
    int downloaded = 0;
    final downloadedHashes = <String>{};
    for (final pair in toApply.entries) {
      for (final book in booksByHash[pair.key] ?? const <Book>[]) {
        await _apply(book, pair.value);
        downloaded++;
        downloadedHashes.add(pair.key);
      }
    }
    final succeeded = await preferences.setString(
      baselineKey, ProgressManifest(merged).encode(),
    );
    if (!succeeded) {
      throw StateError('云端操作已完成，但本地同步基线保存失败；请重新同步');
    }

    final unmatched = remote.entries.keys
        .where((hash) => !booksByHash.containsKey(hash))
        .length;
    return ProgressSyncReport(
      scanned: local.length,
      uploaded: uploads,
      downloaded: downloaded,
      unmatched: unmatched,
      conflicts: conflicts,
      downloadedHashes: downloadedHashes,
    );
  }

  Future<String> _getOrMakeDeviceId(SharedPreferences prefs) async {
    final cached = prefs.getString(_deviceKey);
    if (cached != null && cached.length >= 16) return cached;
    final random = Random.secure();
    final value = List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    // The device id is not an authentication credential.
    if (!await prefs.setString(_deviceKey, value)) {
      throw StateError('无法保存本机设备标识，已停止同步');
    }
    return value;
  }

  ProgressRecord? _snapshot(Book book, String digest, String device) {
    final format = book.format.toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (format == 'PDF') {
      return ProgressRecord(
        hash: digest, format: format, offset: -1,
        page: book.pageIndex.value.clamp(0, 10000000),
        revision: 0, device: device, updatedAt: now,
      );
    }

    if (book.charOffset.value < 0) return null; // legacy page-only position
    if (!<String>['TXT', 'EPUB', 'MD', 'MARKDOWN', 'HTML', 'HTM']
        .contains(format)) return null;
    final chapters = splitChapters(book.content);
    final index = book.chapterIndex.value.clamp(0, chapters.length - 1);
    final current = chapters[index];
    final absolute = current.start +
        book.charOffset.value.clamp(0, current.length);
    return ProgressRecord(
      hash: digest, format: format, offset: absolute,
      page: 0, revision: 0, device: device, updatedAt: now,
      textHash: sha256.convert(utf8.encode(book.content)).toString(),
    );
  }

  void _validateRemote(Book book, ProgressRecord remote) {
    if (remote.format != book.format.toUpperCase()) {
      throw const FormatException('云端书籍格式不匹配');
    }
    if (remote.format == 'PDF') return;
    final text = book.content;
    if (remote.textHash != sha256.convert(utf8.encode(text)).toString()) {
      throw const FormatException('云端文本与本地解析结果不一致');
    }
    if (remote.offset < 0 || remote.offset > text.length) {
      throw const FormatException('云端阅读位置超出文本长度');
    }
    if (remote.offset > 0 && remote.offset < text.length &&
        text.codeUnitAt(remote.offset) >= 0xDC00 &&
        text.codeUnitAt(remote.offset) <= 0xDFFF &&
        text.codeUnitAt(remote.offset - 1) >= 0xD800 &&
        text.codeUnitAt(remote.offset - 1) <= 0xDBFF) {
      throw const FormatException('云端阅读位置落在表情符号的半个字符中');
    }
  }

  Future<void> _apply(Book book, ProgressRecord remote) async {
    _validateRemote(book, remote);
    if (book.format.toUpperCase() == 'PDF') {
      await library.applySyncedProgress(
        book, chapterIndex: 0, pageIndex: remote.page, charOffset: -1,
      );
      return;
    }
    if (remote.offset < 0 || remote.offset > book.content.length) {
      throw const FormatException('云端字符位置超出本地文件范围');
    }
    final chapters = splitChapters(book.content);
    int index = chapters.length - 1;
    for (int i = 0; i < chapters.length; i++) {
      if (remote.offset < chapters[i].end) {
        index = i;
        break;
      }
    }
    final chapter = chapters[index];
    await library.applySyncedProgress(
      book,
      chapterIndex: index,
      pageIndex: 0,
      charOffset: (remote.offset - chapter.start).clamp(0, chapter.length),
    );
  }

  bool _sameManifest(
    Map<String, ProgressRecord> a,
    Map<String, ProgressRecord> b,
  ) {
    if (a.length != b.length) return false;
    for (final pair in a.entries) {
      final another = b[pair.key];
      if (another == null ||
          jsonEncode(pair.value.toJson()) != jsonEncode(another.toJson())) {
        return false;
      }
    }
    return true;
  }
}


class _WebDavProgressTransport implements ProgressTransport {
  _WebDavProgressTransport(this.client);
  final WebDavEncryptedObject client;

  @override
  Future<RemoteSnapshot?> read() async {
    final snapshot = await client.read();
    if (snapshot == null) return null;
    return RemoteSnapshot(bytes: snapshot.bytes, etag: snapshot.etag);
  }

  @override
  Future<void> write(Uint8List bytes, {String? expectedEtag}) async {
    try {
      await client.write(bytes, expectedEtag: expectedEtag);
    } on WebDavConflictException catch (error) {
      throw RemoteConflictException(error.message);
    } on WebDavSyncException catch (error) {
      throw RemoteStoreException(error.message);
    }
  }
}

class _ObjectStoreProgressTransport implements ProgressTransport {
  _ObjectStoreProgressTransport(this.store);
  final RemoteObjectStore store;

  @override
  Future<RemoteSnapshot?> read() => store.read('progress.enc');

  @override
  Future<void> write(Uint8List bytes, {String? expectedEtag}) async {
    await store.write(bytes, 'progress.enc', expectedEtag: expectedEtag);
  }
}
