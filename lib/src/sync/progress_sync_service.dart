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
import 'progress_models.dart';
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
  });
  final int scanned;
  final int uploaded;
  final int downloaded;
  final int unmatched;
  final int conflicts;
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
  }) async {
    final transport = WebDavEncryptedObject(
      fileUrl: credentials.fileUrl,
      username: credentials.username,
      password: credentials.webdavPassword,
    );
    final preferences = await SharedPreferences.getInstance();
    final device = _getOrMakeDeviceId(preferences);
    final baselineKey =
        _baselinePrefix + sha256.convert(utf8.encode(credentials.fileUrl.toString())).toString();

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
      final path = book.sourcePath;
      if (path == null) continue; // sample book / no actual source file
      final file = File(path);
      if (!await file.exists()) continue;
      final digest = (await sha256.bind(file.openRead()).first).toString();
      final position = _snapshot(book, digest, device);
      if (position == null) continue;
      if (local.containsKey(digest) &&
          !local[digest]!.samePosition(position)) {
        throw FormatException('《' + book.title + '》存在内容相同但进度不同的本地副本，请先统一');
      }
      booksByHash.putIfAbsent(digest, () => <Book>[]).add(book);
      local[digest] = position;
    }

    final remoteSnapshot = await transport.read();
    final ProgressManifest remote;
    if (remoteSnapshot == null) {
      remote = const ProgressManifest(<String, ProgressRecord>{});
    } else {
      final plaintext = await EncryptedSyncEnvelope.decrypt(
        remoteSnapshot.bytes,
        credentials.encryptionPassword,
      );
      remote = ProgressManifest.decode(plaintext);
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

      if (here.samePosition(there)) {
        merged[hash] = there;
        continue;
      }

      // No common ancestor means both devices may have independently edited
      // their position. Never select a winner using untrusted wall clocks.
      final localChanged = last == null || !here.samePosition(last);
      final cloudChanged = last == null || !there.samePosition(last);

      ProgressChoice choice;
      if (localChanged && cloudChanged) {
        conflicts++;
        final decision = await resolveConflict(
          ProgressSyncConflict(booksByHash[hash]!.first.title, here, there),
        );
        if (decision == null) throw const ProgressSyncCancelled();
        choice = decision;
      } else if (localChanged) {
        choice = ProgressChoice.local;
      } else {
        choice = ProgressChoice.cloud;
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
        merged[hash] = (localChanged && cloudChanged)
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
        if (localChanged && cloudChanged) uploads++;
      }
    }

    // Keep entries for books not imported on this device. They must never be
    // treated as deleted simply because the local library is smaller.
    final hasCloudChanges = !_sameManifest(remote.entries, merged);
    if (hasCloudChanges) {
      final encrypted = await EncryptedSyncEnvelope.encrypt(
        ProgressManifest(merged).encode(),
        credentials.encryptionPassword,
      );
      // If-Match/If-None-Match refuses concurrent updates. No local progress
      // is modified before this conditional cloud commit succeeds.
      await transport.write(encrypted, expectedEtag: remoteSnapshot?.etag);
    }

    // A new, validated cloud version is now available. Apply downloaded
    // positions only to existing local copies matched by exact source hash.
    int downloaded = 0;
    for (final pair in toApply.entries) {
      for (final book in booksByHash[pair.key] ?? const <Book>[]) {
        await _apply(book, pair.value);
        downloaded++;
      }
    }
    final succeeded = await preferences.setString(
      baselineKey, ProgressManifest(merged).encode(),
    );
    if (!succeeded) {
      throw const StateError('云端操作已完成，但本地同步基线保存失败；请重新同步');
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
    );
  }

  String _getOrMakeDeviceId(SharedPreferences prefs) {
    final cached = prefs.getString(_deviceKey);
    if (cached != null && cached.length >= 16) return cached;
    final random = Random.secure();
    final value = List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    // The device id is not an authentication credential.
    prefs.setString(_deviceKey, value);
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
    );
  }

  Future<void> _apply(Book book, ProgressRecord remote) async {
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
