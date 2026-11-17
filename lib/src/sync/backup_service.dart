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
import '../services/bookmark_meta_store.dart';
import '../services/bookmark_store.dart';
import '../services/library_store.dart';
import '../services/reading_stats_store.dart';

DateTime? _epoch(Object? raw) {
  final value = (raw as num?)?.toInt() ?? 0;
  return value > 0 ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}

/// 单本书在备份中的真实状态。备份不再“静默跳过”任何一本书。
class BackupBookEntry {
  const BackupBookEntry({
    required this.hash,
    required this.title,
    required this.author,
    required this.format,
    required this.fileName,
    required this.bytes,
    required this.fileIncluded,
    required this.status,
    required this.reason,
    this.fileEntry,
  });

  final String hash;
  final String title;
  final String author;
  final String format;
  final String fileName;
  final int bytes;

  /// 书籍原文件是否真的写进了 ZIP。
  final bool fileIncluded;

  /// complete / metadata_only。
  final String status;

  /// 未包含文件时的具体原因（供界面与报告展示）。
  final String reason;

  final String? fileEntry;

  bool get complete => fileIncluded && reason.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'hash': hash,
        'title': title,
        'author': author,
        'format': format,
        'file_name': fileName,
        'file_size': bytes,
        'file_included': fileIncluded,
        'status': status,
        'reason': reason,
        if (fileEntry != null) 'file': fileEntry,
      };

  static BackupBookEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? hash = raw['hash'];
    if (hash is! String) return null;
    return BackupBookEntry(
      hash: hash,
      title: raw['title'] as String? ?? '',
      author: raw['author'] as String? ?? '',
      format: raw['format'] as String? ?? 'TXT',
      fileName: raw['file_name'] as String? ?? '',
      bytes: (raw['file_size'] as num?)?.toInt() ?? 0,
      fileIncluded: raw['file_included'] as bool? ?? raw['file'] != null,
      status: raw['status'] as String? ??
          (raw['file'] != null ? 'complete' : 'metadata_only'),
      reason: raw['reason'] as String? ?? '',
      fileEntry: raw['file'] as String?,
    );
  }
}

class BackupManifest {
  const BackupManifest({
    required this.schema,
    required this.createdAt,
    required this.books,
    required this.bookmarkCount,
    required this.hasSettings,
    required this.hasStats,
  });

  final int schema;
  final DateTime createdAt;
  final List<BackupBookEntry> books;
  final int bookmarkCount;
  final bool hasSettings;
  final bool hasStats;

  int get completeCount => books.where((BackupBookEntry b) => b.complete).length;
  int get metadataOnlyCount => books.where((BackupBookEntry b) => !b.complete).length;
  bool get isComplete => metadataOnlyCount == 0;
}

class BackupInfo {
  const BackupInfo({
    required this.path,
    required this.createdAt,
    required this.bytes,
    required this.books,
    required this.hasFiles,
    this.booksComplete = -1,
    this.booksMetadataOnly = 0,
    this.complete = true,
    this.issues = const <String>[],
  });

  final String path;
  final DateTime createdAt;
  final int bytes;
  final int books;
  final bool hasFiles;

  /// -1 表示旧备份/未解析（列表页不展示具体数量）。
  final int booksComplete;
  final int booksMetadataOnly;

  /// false 表示有书籍只备份了元数据，界面不得显示“完整备份成功”。
  final bool complete;
  final List<String> issues;

  String get name => p.basename(path);
}

class RestoreIssue {
  const RestoreIssue({required this.hash, required this.title, required this.reason});

  final String hash;
  final String title;
  final String reason;
}

class BackupReport {
  const BackupReport({
    required this.booksRestored,
    required this.booksSkipped,
    required this.bookmarks,
    required this.settings,
    required this.preRestoreBackup,
    this.booksFailed = 0,
    this.issues = const <RestoreIssue>[],
    this.complete = true,
    this.metadataRestored = true,
  });

  final int booksRestored;
  final int booksSkipped;
  final int booksFailed;
  final int bookmarks;
  final bool settings;
  final bool metadataRestored;
  final String preRestoreBackup;
  final List<RestoreIssue> issues;

  /// 任何一本书或元数据失败时为 false，界面必须显示“部分恢复”。
  final bool complete;
}

/// 恢复时的可选范围。默认全部恢复，但永远不删除现有数据。
class RestoreSelection {
  const RestoreSelection({
    this.hashes,
    this.metadataOnly = false,
    this.bookmarks = true,
    this.settings = true,
    this.stats = true,
  });

  /// null 表示全部书籍；否则只恢复这些内容哈希。
  final Set<String>? hashes;

  /// true 表示只恢复书籍元数据，不导入任何文件。
  final bool metadataOnly;
  final bool bookmarks;
  final bool settings;
  final bool stats;
}

class BackupPreview {
  const BackupPreview({
    required this.manifest,
    required this.bytes,
    required this.booksNew,
    required this.booksExisting,
    required this.bookmarks,
    required this.hasSettings,
    required this.hasStats,
    required this.legacy,
  });

  final BackupManifest manifest;
  final int bytes;
  final int booksNew;
  final int booksExisting;
  final int bookmarks;
  final bool hasSettings;
  final bool hasStats;

  /// 旧版（无清单）备份：文件是否包含只能靠 ZIP 条目推断。
  final bool legacy;

  bool get canRestoreFiles => manifest.books.any((BackupBookEntry b) => b.fileIncluded);
}

class BackupVerification {
  const BackupVerification({
    required this.ok,
    required this.problems,
    this.manifest,
    this.verifiedFiles = 0,
  });

  final bool ok;
  final List<String> problems;
  final BackupManifest? manifest;
  final int verifiedFiles;
}

/// 完整本地备份、完整性校验与可选择、非破坏性恢复。
///
/// 设计约束：
/// - 备份必须产出逐书清单：成功/仅元数据/失败原因，绝不静默跳过；
/// - 写盘后立即回读校验每个文件的 SHA-256；
/// - 恢复前必须先生成保护性快照，恢复过程只新增/合并，不删除现有书籍；
/// - 备份不完整时报告 complete=false，界面不得显示“完整备份成功”；
/// - 恢复是幂等的：中断后重跑会跳过已恢复的书，继续处理剩余部分。
class BackupService {
  BackupService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String format = 'read-backup-v1';
  static const int manifestSchema = 2;
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

  /// 创建备份并返回逐书真实状态。写入后会回读校验，校验失败直接抛错。
  Future<BackupInfo> createBackup() async {
    final now = _clock();
    final archive = Archive();
    final entries = <BackupBookEntry>[];
    final books = <Map<String, Object?>>[];
    final bookmarks = <String, List<int>>{};
    final bookmarkMeta = <String, List<Map<String, Object?>>>{};
    var totalFileBytes = 0;

    for (final book in LibraryStore.instance.books) {
      final hash = book.contentHash;
      final path = book.sourcePath;
      String? entryName;
      var included = false;
      var reason = '';
      var size = book.fileSize;

      if (hash == null || hash.isEmpty) {
        reason = '缺少内容标识（旧版本导入，未计算 SHA-256）';
      } else if (path == null) {
        reason = '缺少原始文件路径';
      } else {
        final file = File(path);
        if (!await file.exists()) {
          reason = '原始文件已丢失';
        } else {
          size = await file.length();
          if (size > maxEntryBytes) {
            reason = '单文件超过 256MB 上限';
          } else if (totalFileBytes + size > maxArchiveBytes) {
            reason = '超过整包 512MB 容量上限';
          } else {
            final bytes = await file.readAsBytes();
            if (sha256.convert(bytes).toString() != hash) {
              reason = '文件校验值不一致（可能已被外部修改）';
            } else {
              final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
              entryName = 'books/$hash.$ext';
              archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
              totalFileBytes += bytes.length;
              included = true;
              bookmarks[hash] = await BookmarkStore.load(book.id);
              final metas = await BookmarkMetaStore.load(book.id);
              bookmarkMeta[hash] = bookmarks[hash]!
                  .where((int offset) => metas.containsKey(offset))
                  .map((int offset) => metas[offset]!.toJson())
                  .toList();
            }
          }
        }
      }

      final entry = BackupBookEntry(
        hash: hash ?? '',
        title: book.title,
        author: book.author,
        format: book.format,
        fileName: book.fileName ?? (path == null ? '' : p.basename(path)),
        bytes: size,
        fileIncluded: included,
        status: included ? 'complete' : 'metadata_only',
        reason: reason,
        fileEntry: entryName,
      );
      entries.add(entry);
      books.add(<String, Object?>{
        'hash': entry.hash,
        'title': book.title,
        'author': book.author,
        'format': book.format,
        'file_name': entry.fileName,
        'file_size': size,
        'chapter_count': book.chapterCount,
        'last_read_at': book.lastReadAt?.millisecondsSinceEpoch ?? 0,
        'tags': book.tags,
        if (entryName != null) 'file': entryName,
        'file_included': included,
        'status': entry.status,
        'reason': reason,
      });
      // 即使元数据也带书签，方便只恢复书签。
      if (!included && hash != null && hash.isNotEmpty) {
        bookmarks[hash] = await BookmarkStore.load(book.id);
        final metas = await BookmarkMetaStore.load(book.id);
        bookmarkMeta[hash] = bookmarks[hash]!
            .where((int offset) => metas.containsKey(offset))
            .map((int offset) => metas[offset]!.toJson())
            .toList();
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final settings = ReaderSettingsStore.instance.exportJson();
    final metadata = <String, Object?>{
      'format': format,
      'schema': manifestSchema,
      'created_at': now.toUtc().toIso8601String(),
      'device': await SyncConfig.instance.deviceId(),
      'books': books,
      'manifest': <String, Object?>{
        'schema': manifestSchema,
        'books': entries.map((BackupBookEntry e) => e.toJson()).toList(),
        'bookmark_count': bookmarks.values.fold<int>(0, (int sum, List<int> v) => sum + v.length),
        'has_settings': settings.isNotEmpty,
        'has_stats': preferences.getString('read.stats.v1') != null,
      },
      'bookmarks': bookmarks,
      'bookmark_meta': bookmarkMeta,
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

    // 写盘后必须回读校验，避免磁盘错误或编码问题造成“假成功”。
    final verification = await verifyBackup(file.path);
    if (!verification.ok) {
      await file.delete();
      throw FormatException('备份完整性校验失败：${verification.problems.join('；')}');
    }

    final complete = entries.every((BackupBookEntry e) => e.complete);
    final issues = entries
        .where((BackupBookEntry e) => !e.complete)
        .map((BackupBookEntry e) => '${e.title}：${e.reason}')
        .toList();
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: now,
      kind: 'backup',
      status: complete ? 'success' : 'partial',
      message: complete
          ? '创建本地备份：${entries.length} 本书（含原文件），${zipBytes.length ~/ 1024}KB'
          : '创建部分备份：${entries.length} 本书，其中 ${issues.length} 本仅元数据，${zipBytes.length ~/ 1024}KB',
    ));
    return BackupInfo(
      path: file.path,
      createdAt: now,
      bytes: zipBytes.length,
      books: entries.length,
      hasFiles: entries.any((BackupBookEntry e) => e.fileIncluded),
      booksComplete: entries.where((BackupBookEntry e) => e.complete).length,
      booksMetadataOnly: entries.where((BackupBookEntry e) => !e.complete).length,
      complete: complete,
      issues: issues,
    );
  }

  /// 只读校验：结构、路径安全、逐文件 SHA-256、清单一致性。
  Future<BackupVerification> verifyBackup(String path) async {
    final problems = <String>[];
    final file = File(path);
    if (!await file.exists()) {
      return const BackupVerification(ok: false, problems: <String>['备份文件不存在']);
    }
    final length = await file.length();
    if (length > maxArchiveBytes) {
      return const BackupVerification(ok: false, problems: <String>['备份文件超过 512MB 上限']);
    }
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes(), verify: true);
    } catch (error) {
      return BackupVerification(ok: false, problems: <String>['压缩包损坏：$error']);
    }
    if (archive.length > maxEntries) {
      return const BackupVerification(ok: false, problems: <String>['备份条目过多']);
    }
    ArchiveFile? metaEntry;
    var totalUncompressed = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      totalUncompressed += entry.size;
      if (entry.size > maxEntryBytes || totalUncompressed > maxArchiveBytes) {
        return const BackupVerification(ok: false, problems: <String>['解压后超过安全上限']);
      }
      final name = entry.name;
      if (name.contains('..') || name.startsWith('/') || name.contains('\\')) {
        return const BackupVerification(ok: false, problems: <String>['备份包含非法路径']);
      }
      if (name == 'metadata.json') metaEntry = entry;
    }
    if (metaEntry == null) {
      return const BackupVerification(ok: false, problems: <String>['备份缺少 metadata.json']);
    }
    Map<String, dynamic> meta;
    try {
      final decoded = jsonDecode(utf8.decode(metaEntry.content));
      if (decoded is! Map<String, dynamic>) throw const FormatException('metadata 不是对象');
      meta = decoded;
    } catch (error) {
      return BackupVerification(ok: false, problems: <String>['metadata.json 无法解析：$error']);
    }
    if (meta['format'] != format) {
      return const BackupVerification(ok: false, problems: <String>['不是受支持的 Read 备份']);
    }
    final manifest = _manifestFrom(meta, archive);
    if (manifest == null) {
      return const BackupVerification(ok: false, problems: <String>['备份清单损坏']);
    }
    var verified = 0;
    for (final book in manifest.books) {
      if (!book.fileIncluded) continue;
      final name = book.fileEntry;
      if (name == null) {
        problems.add('《${book.title}》清单标记包含文件但缺少条目名');
        continue;
      }
      final ArchiveFile? entry = archive.findFile(name);
      if (entry == null) {
        problems.add('《${book.title}》文件缺失：$name');
        continue;
      }
      if (sha256.convert(entry.content).toString() != book.hash) {
        problems.add('《${book.title}》校验值不一致');
        continue;
      }
      verified++;
    }
    return BackupVerification(
      ok: problems.isEmpty,
      problems: problems,
      manifest: manifest,
      verifiedFiles: verified,
    );
  }

  /// 恢复前预览：书籍数量、已存在数量、书签与设置是否包含。
  Future<BackupPreview> previewRestore(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('备份文件不存在');
    final length = await file.length();
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final ArchiveFile? metaEntry = archive.findFile('metadata.json');
    if (metaEntry == null) throw const FormatException('备份缺少 metadata.json');
    final meta = jsonDecode(utf8.decode(metaEntry.content));
    if (meta is! Map<String, dynamic> || meta['format'] != format) {
      throw const FormatException('不是受支持的 Read 备份');
    }
    final manifest = _manifestFrom(meta, archive);
    if (manifest == null) throw const FormatException('备份清单损坏');
    var existing = 0;
    for (final book in manifest.books) {
      if (book.hash.isNotEmpty && LibraryStore.instance.hasHash(book.hash)) existing++;
    }
    return BackupPreview(
      manifest: manifest,
      bytes: length,
      booksNew: manifest.books.length - existing,
      booksExisting: existing,
      bookmarks: manifest.bookmarkCount,
      hasSettings: manifest.hasSettings,
      hasStats: manifest.hasStats,
      legacy: (meta['schema'] as num?)?.toInt() != manifestSchema,
    );
  }

  BackupManifest? _manifestFrom(Map<String, dynamic> meta, Archive archive) {
    final rawManifest = meta['manifest'];
    final books = <BackupBookEntry>[];
    if (rawManifest is Map && rawManifest['books'] is List) {
      for (final raw in rawManifest['books'] as List) {
        final entry = BackupBookEntry.fromJson(raw);
        if (entry != null) books.add(entry);
      }
      final bookmarks = meta['bookmarks'];
      return BackupManifest(
        schema: (rawManifest['schema'] as num?)?.toInt() ?? manifestSchema,
        createdAt: DateTime.tryParse(meta['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        books: books,
        bookmarkCount: (rawManifest['bookmark_count'] as num?)?.toInt() ??
            (bookmarks is Map
                ? bookmarks.values
                    .whereType<List<dynamic>>()
                    .fold<int>(0, (int sum, List<dynamic> v) => sum + v.length)
                : 0),
        hasSettings: rawManifest['has_settings'] as bool? ??
            (meta['settings'] is String),
        hasStats: rawManifest['has_stats'] as bool? ?? (meta['stats'] is String),
      );
    }

    // 旧版备份没有 manifest：按 books 数组重建，文件条目是否存在决定 fileIncluded。
    final rawBooks = meta['books'];
    if (rawBooks is! List || rawBooks.length > 2000) return null;
    for (final raw in rawBooks) {
      if (raw is! Map) continue;
      final hash = raw['hash'];
      if (hash is! String || hash.isEmpty) continue;
      final entryName = raw['file'] as String?;
      final exists = entryName != null && archive.findFile(entryName) != null;
      books.add(BackupBookEntry(
        hash: hash,
        title: raw['title'] as String? ?? '',
        author: raw['author'] as String? ?? '',
        format: raw['format'] as String? ?? 'TXT',
        fileName: raw['file_name'] as String? ?? '',
        bytes: (raw['file_size'] as num?)?.toInt() ?? 0,
        fileIncluded: exists,
        status: exists ? 'complete' : 'metadata_only',
        reason: exists ? '' : '旧版备份未包含该文件',
        fileEntry: exists ? entryName : null,
      ));
    }
    final bookmarks = meta['bookmarks'];
    return BackupManifest(
      schema: 1,
      createdAt: DateTime.tryParse(meta['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      books: books,
      bookmarkCount: bookmarks is Map
          ? bookmarks.values
              .whereType<List<dynamic>>()
              .fold<int>(0, (int sum, List<dynamic> v) => sum + v.length)
          : 0,
      hasSettings: meta['settings'] is String,
      hasStats: meta['stats'] is String,
    );
  }

  Future<BackupReport> restore(
    String path, {
    RestoreSelection selection = const RestoreSelection(),
  }) async {
    final file = File(path);
    if (!await file.exists()) throw const FormatException('备份文件不存在');
    final length = await file.length();
    if (length > maxArchiveBytes) throw const FormatException('备份文件过大');
    final verification = await verifyBackup(path);
    if (!verification.ok) {
      throw FormatException('备份校验失败，未做任何修改：${verification.problems.join('；')}');
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes(), verify: true);
    final ArchiveFile metaEntry = archive.findFile('metadata.json')!;
    final meta = jsonDecode(utf8.decode(metaEntry.content)) as Map<String, dynamic>;
    final manifest = verification.manifest!;

    // 恢复前保护性快照：即使后续任何一步失败，用户也能回到恢复前状态。
    final pre = await createBackup();

    var restored = 0;
    var skipped = 0;
    var failed = 0;
    var bookmarkCount = 0;
    final issues = <RestoreIssue>[];
    final selectedHashes = selection.hashes;

    for (final book in manifest.books) {
      if (selectedHashes != null && !selectedHashes.contains(book.hash)) continue;
      final raw = _rawBook(meta, book.hash);
      try {
        if (book.hash.isNotEmpty && LibraryStore.instance.hasHash(book.hash)) {
          if (raw != null) {
            await LibraryStore.instance.applySyncedMetadata(
              hash: book.hash,
              title: raw['title'] as String? ?? book.title,
              author: raw['author'] as String? ?? book.author,
              chapterCount: (raw['chapter_count'] as num?)?.toInt() ?? 0,
              lastReadAt: _epoch(raw['last_read_at']),
              tags: (raw['tags'] as List<dynamic>?)
                  ?.whereType<String>()
                  .where((String t) => t.trim().isNotEmpty)
                  .map((String t) => t.trim())
                  .toList(),
            );
          }
          skipped++;
          continue;
        }
        if (selection.metadataOnly || !book.fileIncluded || book.fileEntry == null) {
          skipped++;
          issues.add(RestoreIssue(
            hash: book.hash,
            title: book.title,
            reason: selection.metadataOnly ? '仅恢复元数据' : book.reason,
          ));
          continue;
        }
        final entry = archive.findFile(book.fileEntry!);
        if (entry == null) {
          failed++;
          issues.add(RestoreIssue(
              hash: book.hash, title: book.title, reason: '备份内文件缺失'));
          continue;
        }
        final bytes = entry.content;
        if (sha256.convert(bytes).toString() != book.hash) {
          failed++;
          issues.add(RestoreIssue(
              hash: book.hash, title: book.title, reason: '校验值不一致'));
          continue;
        }
        final importRaw = raw ?? <String, Object?>{};
        await LibraryStore.instance.importSyncedFile(
          bytes: bytes,
          hash: book.hash,
          fileName: importRaw['file_name'] as String? ?? book.fileName,
          title: importRaw['title'] as String? ?? book.title,
          author: importRaw['author'] as String? ?? book.author,
          format: importRaw['format'] as String? ?? book.format,
          chapterCount: (importRaw['chapter_count'] as num?)?.toInt() ?? 0,
          lastReadAt: _epoch(importRaw['last_read_at']),
          tags: (importRaw['tags'] as List<dynamic>?)
              ?.whereType<String>()
              .where((String t) => t.trim().isNotEmpty)
              .map((String t) => t.trim())
              .toList(),
        );
        restored++;
      } catch (error) {
        failed++;
        issues.add(RestoreIssue(
            hash: book.hash, title: book.title, reason: '导入失败：$error'));
      }
    }

    if (selection.bookmarks) {
      final bookmarkMap = meta['bookmarks'];
      if (bookmarkMap is Map) {
        for (final entry in bookmarkMap.entries) {
          final hash = entry.key.toString();
          if (selectedHashes != null && !selectedHashes.contains(hash)) continue;
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
      final bookmarkMetaMap = meta['bookmark_meta'];
      if (bookmarkMetaMap is Map) {
        for (final entry in bookmarkMetaMap.entries) {
          final hash = entry.key.toString();
          if (selectedHashes != null && !selectedHashes.contains(hash)) continue;
          final book = LibraryStore.instance.bookByHash(hash);
          if (book == null || entry.value is! List) continue;
          final values = <int, BookmarkMeta>{};
          for (final raw in entry.value as List) {
            final parsed = BookmarkMeta.fromJson(raw);
            if (parsed != null) values[parsed.offset] = parsed;
          }
          await BookmarkMetaStore.replaceAll(book.id, values);
        }
      }
    }

    var settingsRestored = false;
    if (selection.settings) {
      final settings = meta['settings'];
      if (settings is String && settings.length <= 2 * 1024 * 1024) {
        try {
          await ReaderSettingsStore.instance.importJson(settings);
          settingsRestored = true;
        } catch (_) {}
      }
    }
    if (selection.stats) {
      final prefs = await SharedPreferences.getInstance();
      final stats = meta['stats'];
      if (stats is String && stats.length <= 4 * 1024 * 1024) {
        await prefs.setString('read.stats.v1', stats);
        await ReadingStatsStore.instance.init();
      }
    }

    final complete = failed == 0;
    await SyncHistoryStore.instance.add(SyncHistoryEntry(
      at: _clock(),
      kind: 'restore',
      status: complete ? 'success' : 'partial',
      message: complete
          ? '恢复完成：导入 $restored 本，已有 $skipped 本，书签 $bookmarkCount 条'
          : '部分恢复：导入 $restored 本，失败 $failed 本，已有 $skipped 本',
    ));
    return BackupReport(
      booksRestored: restored,
      booksSkipped: skipped,
      booksFailed: failed,
      bookmarks: bookmarkCount,
      settings: settingsRestored,
      metadataRestored: complete,
      preRestoreBackup: pre.path,
      issues: issues,
      complete: complete,
    );
  }

  Map<String, dynamic>? _rawBook(Map<String, dynamic> meta, String hash) {
    final rawBooks = meta['books'];
    if (rawBooks is! List) return null;
    for (final raw in rawBooks) {
      if (raw is Map<String, dynamic> && raw['hash'] == hash) return raw;
    }
    return null;
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
      status: info.complete ? 'success' : 'partial',
      message: info.complete
          ? '上传加密云端备份 $key'
          : '上传加密云端备份 $key（${info.booksMetadataOnly} 本仅元数据）',
    ));
    return key;
  }

  Future<List<RemoteEntry>> listCloud(RemoteObjectStore store) =>
      store.list(prefix: cloudPrefix, max: 100);

  Future<BackupReport> restoreCloud(
    RemoteObjectStore store,
    String key,
    String password, {
    RestoreSelection selection = const RestoreSelection(),
  }) async {
    if (password.length < 12) throw const FormatException('同步密码至少 12 个字符');
    final snapshot = await store.read(key);
    if (snapshot == null) throw const FormatException('云端备份不存在');
    final plain = await EncryptedSyncEnvelope.decrypt(snapshot.bytes, password);
    final decoded = base64Decode(plain);
    final dir = await _backupDir();
    final temp = File('${dir.path}/cloud-restore-${DateTime.now().microsecondsSinceEpoch}.zip');
    await temp.writeAsBytes(decoded, flush: true);
    try {
      return await restore(temp.path, selection: selection);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}
