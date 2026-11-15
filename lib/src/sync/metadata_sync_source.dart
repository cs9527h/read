import 'dart:convert';

import 'package:path/path.dart' as p;

import '../model/book.dart';
import '../reader/settings/reader_settings_store.dart';
import '../services/bookmark_store.dart';
import '../services/highlight_store.dart';
import '../services/library_store.dart';
import '../services/reading_stats_store.dart';
import 'sync_document.dart';
import 'sync_record.dart';

/// Builds a local document without mutating book files. Revisions advance only
/// when record fields actually change, preventing an idle sync from churning
/// the cloud file.
class LocalSyncSource {
  LocalSyncSource({
    LibraryStore? library,
    ReaderSettingsStore? settings,
    ReadingStatsStore? stats,
  })  : library = library ?? LibraryStore.instance,
        settings = settings ?? ReaderSettingsStore.instance,
        stats = stats ?? ReadingStatsStore.instance;

  final LibraryStore library;
  final ReaderSettingsStore settings;
  final ReadingStatsStore stats;

  Future<SyncDocument> build({
    required String deviceId,
    required bool includeBookmarks,
    required bool includeSettings,
    required bool includeStats,
    bool includeBooks = true,
    SyncDocument? baseline,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final records = <String, SyncRecord>{};
    final bookHashes = <Book, String>{};
    final liveIds = <String>{};

    SyncRecord stableOrNext(
      String id,
      String kind,
      Map<String, dynamic> fields,
    ) {
      final base = baseline?.records[id];
      final unchanged = base != null &&
          !base.deleted &&
          const DeepCollectionEquality().equals(base.fields, fields);
      if (unchanged) return base;
      if (base != null && base.deleted) {
        // A local record came back after a local tombstone: explicit restore.
        return base.next(deviceId, now, fields);
      }
      return SyncRecord(
        id: id,
        kind: kind,
        rev: (base?.rev ?? 0) + 1,
        deviceId: deviceId,
        updatedAt: now,
        deleted: false,
        fields: Map<String, dynamic>.unmodifiable(fields),
      );
    }

    for (final book in library.books) {
      String? hash;
      try {
        hash = await library.ensureContentHash(book);
      } catch (_) {
        continue; // A missing local file cannot be represented remotely.
      }
      bookHashes[book] = hash;
      final id = 'book:$hash';
      if (!includeBooks) continue;
      liveIds.add(id);
      final fileName = book.fileName ??
          (book.sourcePath == null ? '' : p.basename(book.sourcePath!));
      records[id] = stableOrNext(id, 'book', <String, dynamic>{
        'hash': hash,
        'title': book.title,
        'author': book.author,
        'format': book.format,
        'file_name': fileName,
        'file_size': book.fileSize,
        'chapter_count': book.chapterCount,
        'last_read_at': book.lastReadAt?.millisecondsSinceEpoch ?? 0,
        'progress_chapter': book.chapterIndex.value,
        'progress_page': book.pageIndex.value,
      });
    }

    if (includeBookmarks) {
      for (final entry in bookHashes.entries) {
        final offsets = await BookmarkStore.load(entry.key.id);
        for (final offset in offsets) {
          final id = 'bookmark:${entry.value}:$offset';
          liveIds.add(id);
          records[id] = stableOrNext(id, 'bookmark', <String, dynamic>{
            'book_hash': entry.value,
            'offset': offset,
          });
        }
        final highlights = await HighlightStore.load(entry.key.id);
        for (final highlight in highlights) {
          final id =
              'highlight:${entry.value}:${highlight.start}:${highlight.end}:${highlight.createdAt}';
          liveIds.add(id);
          records[id] = stableOrNext(id, 'highlight', <String, dynamic>{
            'book_hash': entry.value,
            'start': highlight.start,
            'end': highlight.end,
            'color': highlight.color,
            'note': highlight.note,
            'created_at': highlight.createdAt,
          });
        }
      }
    }

    if (includeSettings) {
      final id = 'settings:reader';
      liveIds.add(id);
      final payload = _settingsPayload();
      records[id] = stableOrNext(id, 'settings', <String, dynamic>{
        'payload': payload,
      });
    }

    if (includeStats) {
      // Statistics are intentionally aggregated summaries, never fabricated.
      final id = 'stats:summary';
      liveIds.add(id);
      records[id] = stableOrNext(id, 'stats', <String, dynamic>{
        'total_seconds': stats.totalSeconds,
        'total_chars': stats.totalChars,
        'days_count': stats.daysCount,
        'books_count': stats.booksCount,
      });
    }

    // Anything present in the accepted baseline but absent locally is a
    // deletion. Tombstones are retained so another device cannot resurrect it.
    final baseRecords = baseline?.records ?? const <String, SyncRecord>{};
    for (final entry in baseRecords.entries) {
      if (liveIds.contains(entry.key) || entry.value.deleted) continue;
      if (!includeBookmarks && entry.key.startsWith('bookmark:')) continue;
      if (!includeSettings && entry.key.startsWith('settings:')) continue;
      if (!includeStats && entry.key.startsWith('stats:')) continue;
      if (!entry.key.startsWith('book:') &&
          !entry.key.startsWith('bookmark:') &&
          !entry.key.startsWith('highlight:') &&
          !entry.key.startsWith('settings:') &&
          !entry.key.startsWith('stats:')) {
        continue;
      }
      records[entry.key] = entry.value.next(
        deviceId,
        now,
        const <String, dynamic>{},
        delete: true,
      );
    }

    if (includeSettings && records['settings:reader'] == null) {
      final base = baseRecords['settings:reader'];
      if (base != null && !base.deleted) {
        final payload = _settingsPayload();
        records['settings:reader'] = SyncRecord(
          id: 'settings:reader',
          kind: 'settings',
          rev: base.rev + 1,
          deviceId: deviceId,
          updatedAt: now,
          deleted: false,
          fields: Map<String, dynamic>.unmodifiable(<String, dynamic>{
            'payload': payload,
          }),
        );
      }
    }

    return SyncDocument(
      deviceId: deviceId,
      createdAt: DateTime.now(),
      records: records,
    );
  }

  Map<String, dynamic> _settingsPayload() {
    final exported =
        jsonDecode(settings.exportJson()) as Map<String, dynamic>;
    // exportedAt makes every export differ. Strip volatile fields so only a
    // real setting/theme edit bumps the revision.
    exported.remove('exportedAt');
    exported.remove('book'); // book overrides are keyed by local device ids
    return exported;
  }
}

class LocalSyncApplyResult {
  const LocalSyncApplyResult({
    required this.booksMatched,
    required this.booksMissing,
    required this.remoteDeleted,
    required this.bookmarks,
    required this.settingsApplied,
  });

  final int booksMatched;
  final int booksMissing;
  final int remoteDeleted;
  final int bookmarks;
  final bool settingsApplied;
}

class LocalSyncApplier {
  LocalSyncApplier({
    LibraryStore? library,
    ReaderSettingsStore? settings,
  })  : library = library ?? LibraryStore.instance,
        settings = settings ?? ReaderSettingsStore.instance;

  final LibraryStore library;
  final ReaderSettingsStore settings;

  Future<LocalSyncApplyResult> apply(
    SyncDocument document, {
    required bool includeBookmarks,
    required bool includeSettings,
    bool includeBooks = true,
  }) async {
    var matched = 0;
    var missing = 0;
    var remoteDeleted = 0;
    var bookmarkCount = 0;
    var settingsApplied = false;

    final bookmarkSets = <String, Set<int>>{};
    final highlightSets = <String, List<HighlightRecord>>{};
    for (final book in library.books) {
      final hash = book.contentHash;
      if (hash != null) {
        bookmarkSets[hash] = <int>{};
        highlightSets[hash] = <HighlightRecord>[];
      }
    }

    for (final record in document.records.values) {
      if (record.kind == 'book') {
        final hash = record.fields['hash'];
        if (hash is! String) continue;
        if (record.deleted) {
          remoteDeleted++;
          continue;
        }
        final local = library.bookByHash(hash);
        if (local == null) {
          missing++;
          continue;
        }
        final lastReadRaw = record.fields['last_read_at'];
        await library.applySyncedMetadata(
          hash: hash,
          title: record.fields['title'] is String
              ? record.fields['title'] as String
              : local.title,
          author: record.fields['author'] is String
              ? record.fields['author'] as String
              : local.author,
          chapterCount: (record.fields['chapter_count'] as num?)?.toInt() ??
              local.chapterCount,
          lastReadAt: lastReadRaw is int && lastReadRaw > 0
              ? DateTime.fromMillisecondsSinceEpoch(lastReadRaw)
              : null,
        );
        matched++;
      } else if (record.kind == 'bookmark' && includeBookmarks) {
        final hash = record.fields['book_hash'];
        final offset = record.fields['offset'];
        if (hash is! String || offset is! int || offset < 0) continue;
        final set = bookmarkSets.putIfAbsent(hash, () => <int>{});
        if (!record.deleted) set.add(offset);
      } else if (record.kind == 'highlight' && includeBookmarks) {
        if (record.deleted) continue;
        final hash = record.fields['book_hash'];
        final start = record.fields['start'];
        final end = record.fields['end'];
        if (hash is! String || start is! int || end is! int || end <= start) {
          continue;
        }
        highlightSets.putIfAbsent(hash, () => <HighlightRecord>[]).add(
          HighlightRecord(
            start: start,
            end: end,
            color: (record.fields['color'] as num?)?.toInt() ?? 0xFFFFE082,
            note: record.fields['note'] as String? ?? '',
            createdAt: (record.fields['created_at'] as num?)?.toInt() ?? 0,
          ),
        );
      } else if (record.kind == 'settings' && includeSettings && !record.deleted) {
        final payload = record.fields['payload'];
        if (payload is! Map<String, dynamic>) continue;
        try {
          await settings.importJson(jsonEncode(payload));
          settingsApplied = true;
        } catch (_) {
          // A malformed remote settings payload must not break book metadata.
        }
      }
    }

    if (includeBookmarks) {
      for (final book in library.books) {
        final hash = book.contentHash;
        if (hash == null || !bookmarkSets.containsKey(hash)) continue;
        final offsets = bookmarkSets[hash]!.toList()..sort();
        await BookmarkStore.replaceAll(book.id, offsets);
        bookmarkCount += offsets.length;
        final notes = highlightSets[hash] ?? <HighlightRecord>[];
        notes.sort((HighlightRecord a, HighlightRecord b) => a.start.compareTo(b.start));
        await HighlightStore.replaceAll(book.id, notes);
      }
    }

    return LocalSyncApplyResult(
      booksMatched: matched,
      booksMissing: missing,
      remoteDeleted: remoteDeleted,
      bookmarks: bookmarkCount,
      settingsApplied: settingsApplied,
    );
  }
}
