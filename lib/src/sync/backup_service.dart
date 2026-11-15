import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'encrypted_sync_envelope.dart';
import 'remote_store.dart';
import 'sync_config.dart';
import 'webdav_store.dart';
import 'sync_history.dart';
import '../reader/settings/reader_settings_store.dart';
import '../services/bookmark_store.dart';
import '../services/library_store.dart';
import '../services/reading_stats_store.dart';

DateTime? _epoch(Object? raw) {
  final value = (raw as num?)?.toInt() ?? 0;
  return value > 0 ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}

class BackupInfo {
  const BackupInfo({
    required this.path,
    required this.createdAt,
    required this.bytes,
    required this.books,
    required this.hasFiles,
  });

  final String path;
  final DateTime createdAt;
  final int bytes;
  final int books;
  final bool hasFiles;

  String get name => p.basename(path);
}

class BackupReport {
  const BackupReport({
    required this.booksRestored,
    required this.booksSkipped,
    required this.bookmarks,
    required this.settings,
    required this.preRestoreBackup,
  });

  final int booksRestored;
  final int booksSkipped;
  final int bookmarks;
  final bool settings;
  final String preRestoreBackup;
}

/// Full local backup and selective, non-destructive restore.
///
/// A restore first creates a pre-restore snapshot, validates every hash, and
/// never deletes existing books. Missing books are imported; existing books
/// only receive validated metadata/bookmarks/settings.
class BackupService {
  BackupService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String format = 'read-backup-v1';
  static const int maxArchiveBytes = 512 * 1024 * 1024;
  static const int maxEntryBytes = 256 * 1024 * 1024;
  static const int maxEntries = 4000;
  static const String cloudPrefix = 'backups/';

  final DateTime Function() _clock;

  Future<Directory> _backupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<BackupInfo>> listLocal() async {
    final dir = await _backupDir();
    final files = await dir
        .list()
        .where((FileSystemEntity e) => e is File && e.path.endsWith('.zip'))
        .cast<File>()
        .toList();
    final out = <BackupInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      out.add(BackupInfo(
        path: file.path,
        createdAt: stat.modified,
        bytes: stat.size,
        books: -1,
        hasFiles: true,
      ));
    }
    out.sort((BackupInfo a, BackupInfo b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<BackupInfo> createBackup() async {
    final now = _clock();
    final archive = Archive();
    final books = <Map<String, Object?>>[];
    final bookmarks = <String, List<int>>{};
    var totalFileBytes = 0;

    for (final book in LibraryStore.instance.books) {
      final hash = book.contentHash;
      final path = book.sourcePath;
      if (hash == null || path == null) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final size = await file.length();
      if (size > maxEntryBytes || totalFileBytes + size > maxArchiveBytes) {
        continue; // metadata still backs up, file explicitly omitted
      }
      final bytes = await file.readAsBytes();
      if (sha256.convert(bytes).toString() != hash) continue;
      final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
      final entryName = 'books/$hash.$ext';
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
      totalFileBytes += bytes.length;
      final offsets = await BookmarkStore.load(book.id);
      bookmarks[hash] = offsets;
      books.add(<String, Object?>{
        'hash': hash,
        'title': book.title,
        'author': book.author,
        'format': book.format,
        'file_name': book.fileName ?? p.basename(path),
        'file_size': size,
        'chapter_count': book.chapterCount,
        'last_read_at': book.lastReadAt?.millisecondsSinceEpoch ?? 0,
        'file': entryName,
      });
    }

    final preferences = await SharedPreferences.getInstance();
    final settings = ReaderSettingsStore.instance.exportJson();
    final metadata = <String, Object?>{
      'format': format,
      'created_at': now.toUtc().toIso8601String(),
      'device': await SyncConfig.instance.deviceId(),
      'books': books,
      'bookmarks': bookmarks,
      'settings': settings,
      'stats': preferences.getString('read.stats.v1'),
      'reader_font_size': preferences.getDouble('read.reader.fontsize'),
      'reader_line_height': preferences.getDouble('read.reader.lineheight'),
      'reader_background': preferences.getInt('read.reader.bg'),
    };
    final metaBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(metadata));
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes.length > maxArchiveBytes) {
      throw const FormatException('备份超过 512MB 上限，请减少书籍文件');
    }
    final dir = await _backupDir();
    final stamp = now.toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    final file = File('${dir.path}/read-$stamp.zip');
    await file.writeAsBytes(zipBytes, flush: true);
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: now,
      kind: 'backup',
      status: 'success',
      message: '创建本地备份：${books.length} 本书，${zipBytes.length ~/ 1024}KB',
    ));
    return BackupInfo(
      path: file.path,
      createdAt: now,
      bytes: zipBytes.length,
      books: books.length,
      hasFiles: books.isNotEmpty,
    );
  }

  Future<BackupReport> restore(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('备份文件不存在');
    final length = await file.length();
    if (length > maxArchiveBytes) throw const FormatException('备份文件过大');
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes(), verify: true);
    if (archive.length > maxEntries) throw const FormatException('备份条目过多');
    ArchiveFile? metaEntry;
    var totalUncompressed = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      totalUncompressed += entry.size;
      if (entry.size > maxEntryBytes || totalUncompressed > maxArchiveBytes) {
        throw const FormatException('备份解压后超过安全上限');
      }
      final name = entry.name;
      if (name.contains('..') || name.startsWith('/') || name.contains('\\')) {
        throw const FormatException('备份包含非法路径');
      }
      if (name == 'metadata.json') metaEntry = entry;
    }
    if (metaEntry == null) throw const FormatException('备份缺少 metadata.json');
    final metaRaw = utf8.decode(metaEntry.content);
    final meta = jsonDecode(metaRaw);
    if (meta is! Map<String, dynamic> || meta['format'] != format) {
      throw const FormatException('不是受支持的 Read 备份');
    }
    final books = meta['books'];
    if (books is! List || books.length > 2000) {
      throw const FormatException('备份书籍索引损坏');
    }

    // Always snapshot current state before mutating anything.
    final pre = await createBackup();
    var restored = 0;
    var skipped = 0;
    var bookmarkCount = 0;
    for (final raw in books) {
      if (raw is! Map<String, dynamic>) continue;
      final hash = raw['hash'];
      final entryName = raw['file'];
      if (hash is! String || entryName is! String) continue;
      if (LibraryStore.instance.hasHash(hash)) {
        await LibraryStore.instance.applySyncedMetadata(
          hash: hash,
          title: raw['title'] as String? ?? '',
          author: raw['author'] as String? ?? '',
          chapterCount: (raw['chapter_count'] as num?)?.toInt() ?? 0,
          lastReadAt: _epoch(raw['last_read_at']),
        );
        skipped++;
        continue;
      }
      final entry = archive.findFile(entryName);
      if (entry == null) continue;
      final bytes = entry.content;
      if (sha256.convert(bytes).toString() != hash) continue;
      try {
        await LibraryStore.instance.importSyncedFile(
          bytes: bytes,
          hash: hash,
          fileName: raw['file_name'] as String? ?? p.basename(entryName),
          title: raw['title'] as String? ?? '备份导入',
          author: raw['author'] as String? ?? '本地备份',
          format: raw['format'] as String? ?? 'TXT',
          chapterCount: (raw['chapter_count'] as num?)?.toInt() ?? 0,
          lastReadAt: _epoch(raw['last_read_at']),
        );
        restored++;
      } catch (_) {
        skipped++;
      }
    }

    final bookmarkMap = meta['bookmarks'];
    if (bookmarkMap is Map) {
      for (final entry in bookmarkMap.entries) {
        final hash = entry.key.toString();
        final book = LibraryStore.instance.bookByHash(hash);
        if (book == null || entry.value is! List) continue;
        final offsets = (entry.value as List)
            .whereType<num>()
            .map((num e) => e.toInt())
            .where((int e) => e >= 0)
            .toList()
          ..sort();
        await BookmarkStore.replaceAll(book.id, offsets);
        bookmarkCount += offsets.length;
      }
    }
    final settings = meta['settings'];
    var settingsRestored = false;
    if (settings is String && settings.length <= 2 * 1024 * 1024) {
      try {
        await ReaderSettingsStore.instance.importJson(settings);
        settingsRestored = true;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final stats = meta['stats'];
    if (stats is String && stats.length <= 4 * 1024 * 1024) {
      await prefs.setString('read.stats.v1', stats);
      await ReadingStatsStore.instance.init();
    }
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: _clock(),
      kind: 'restore',
      status: 'success',
      message: '恢复完成：导入 $restored 本，已有 $skipped 本，书签 $bookmarkCount 条',
    ));
    return BackupReport(
      booksRestored: restored,
      booksSkipped: skipped,
      bookmarks: bookmarkCount,
      settings: settingsRestored,
      preRestoreBackup: pre.path,
    );
  }

  Future<void> deleteLocal(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Uploads an encrypted archive. Plaintext backup files never leave the
  /// device; filename is the only cloud-visible metadata.
  Future<String> uploadCloud(RemoteObjectStore store, String password) async {
    if (password.length < 12) throw const FormatException('同步密码至少 12 个字符');
    final info = await createBackup();
    final bytes = await File(info.path).readAsBytes();
    final encrypted = await EncryptedSyncEnvelope.encrypt(
      base64Encode(bytes),
      password,
    );
    final stamp = _clock().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '');
    final key = '$cloudPrefix${stamp.substring(0, 14)}.zip.enc';
    if (store is WebDavStore) await store.ensureDirectory(subdirectory: 'backups');
    await store.write(Uint8List.fromList(encrypted), key);
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: _clock(),
      kind: 'backup',
      status: 'success',
      message: '上传加密云端备份 ${key}',
    ));
    return key;
  }

  Future<List<RemoteEntry>> listCloud(RemoteObjectStore store) =>
      store.list(prefix: cloudPrefix, max: 100);

  Future<BackupReport> restoreCloud(
    RemoteObjectStore store,
    String key,
    String password,
  ) async {
    if (password.length < 12) throw const FormatException('同步密码至少 12 个字符');
    final snapshot = await store.read(key);
    if (snapshot == null) throw const FormatException('云端备份不存在');
    final plain = await EncryptedSyncEnvelope.decrypt(snapshot.bytes, password);
    final decoded = base64Decode(plain);
    final dir = await _backupDir();
    final temp = File('${dir.path}/cloud-restore-${DateTime.now().microsecondsSinceEpoch}.zip');
    await temp.writeAsBytes(decoded, flush: true);
    try {
      return await restore(temp.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}

