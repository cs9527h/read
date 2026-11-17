import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/book.dart';
import '../services/highlight_store.dart';
import 'read_database.dart';

class MigrationReport {
  const MigrationReport({
    required this.books,
    required this.positions,
    required this.bookmarks,
    required this.highlights,
    required this.alreadyPresent,
  });

  final int books;
  final int positions;
  final int bookmarks;
  final int highlights;
  final int alreadyPresent;

  bool get isEmpty =>
      books == 0 && positions == 0 && bookmarks == 0 && highlights == 0;

  @override
  String toString() =>
      'books=$books positions=$positions bookmarks=$bookmarks '
      'highlights=$highlights existing=$alreadyPresent';
}

/// 同步队列在 SQLite 中的快照，避免 CoreStore 依赖同步层类型。
class QueueSnapshot {
  const QueueSnapshot({
    required this.id,
    required this.kind,
    required this.bookId,
    required this.attempts,
    required this.nextAttemptMs,
    required this.state,
    required this.lastError,
  });

  final String id;
  final String kind;
  final String bookId;
  final int attempts;
  final int nextAttemptMs;
  final String state;
  final String lastError;
}

/// 核心业务数据的 SQLite 门面。
///
/// 设计原则（对应用户 P0-3）：
/// - SQLite 是书籍元数据、阅读进度、书签、高亮/笔记、同步队列的权威副本；
/// - 旧 SharedPreferences 数据一个字节都不删除，迁移只做 `INSERT OR IGNORE`；
/// - 因此回滚只需不再打开 [CoreStore]，旧路径仍可完整读取；
/// - 每次写入都在事务内完成，唯一约束防重复，索引保证按书查询效率。
class CoreStore {
  CoreStore._(this.db);

  final ReadDatabase db;

  static CoreStore? _active;

  /// 未初始化时为 null：所有调用方必须回退到 SharedPreferences。
  static CoreStore? get active => _active;

  static Future<CoreStore> open(File file) async {
    await closeActive();
    final store = CoreStore._(ReadDatabase(file));
    // 触发一次真实查询，确保 schema 创建/迁移在这里完成而不是首帧。
    await store.db.customSelect('SELECT 1').get();
    _active = store;
    return store;
  }

  /// 包装一个已有数据库（测试或高级调用方使用），不改变全局 active。
  static CoreStore wrap(ReadDatabase db) => CoreStore._(db);

  static Future<void> closeActive() async {
    final store = _active;
    _active = null;
    if (store != null) await store.db.close();
  }

  static const String _bookmarkPrefix = 'read.bookmarks.v1.';
  static const String _highlightPrefix = 'read.highlights.v1.';

  // -------------------------------------------------------------------
  // 写入
  // -------------------------------------------------------------------

  Future<void> saveBooks(Iterable<Book> books) async {
    await db.transaction(() async {
      for (final Book book in books) {
        await db.into(db.localBooks).insert(
              LocalBooksCompanion.insert(
                id: book.id,
                title: book.title,
                author: book.author,
                format: book.format,
                sourcePath: Value(book.sourcePath),
                contentHash: Value(book.contentHash),
                lastReadAtMs:
                    Value(book.lastReadAt?.millisecondsSinceEpoch),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> saveProgress(Book book) async {
    await db.into(db.readingPositions).insert(
          ReadingPositionsCompanion.insert(
            bookId: book.id,
            chapterIndex: Value(book.chapterIndex.value),
            pageIndex: Value(book.pageIndex.value),
            charOffset: Value(book.charOffset.value),
            modifiedAtMs:
                Value(DateTime.now().millisecondsSinceEpoch),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> replaceBookmarks(String bookId, List<int> offsets) async {
    await db.transaction(() async {
      await (db.delete(db.localBookmarks)
            ..where((LocalBookmarks t) => t.bookId.equals(bookId)))
          .go();
      for (final int offset in offsets.toSet()) {
        if (offset < 0) continue;
        await db.into(db.localBookmarks).insert(
              LocalBookmarksCompanion.insert(
                id: '$bookId:$offset',
                bookId: bookId,
                chapterIndex: 0,
                charOffset: offset,
                revision: Value(DateTime.now().millisecondsSinceEpoch),
                deviceId: const Value('local'),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  Future<void> replaceHighlights(
      String bookId, List<HighlightRecord> values) async {
    await db.transaction(() async {
      await (db.delete(db.localHighlights)
            ..where((LocalHighlights t) => t.bookId.equals(bookId)))
          .go();
      for (final HighlightRecord record in values) {
        final int now = DateTime.now().millisecondsSinceEpoch;
        await db.into(db.localHighlights).insert(
              LocalHighlightsCompanion.insert(
                id: '$bookId:${record.start}:${record.end}',
                bookId: bookId,
                startOffset: record.start,
                endOffset: record.end,
                color: Value(record.color),
                noteText: Value(record.note),
                createdAtMs: Value(record.createdAt),
                updatedAtMs: Value(now),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  Future<void> replaceQueueTasks(List<QueueSnapshot> tasks) async {
    await db.transaction(() async {
      await db.delete(db.syncQueueItems).go();
      for (final QueueSnapshot task in tasks) {
        await db.into(db.syncQueueItems).insert(
              SyncQueueItemsCompanion.insert(
                id: task.id,
                kind: task.kind,
                bookId: Value(task.bookId),
                attempts: Value(task.attempts),
                nextAttemptMs: Value(task.nextAttemptMs),
                createdAtMs:
                    Value(DateTime.now().millisecondsSinceEpoch),
                state: Value(task.state),
                lastError: Value(task.lastError),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
  }

  /// 记录一次冲突，供“被覆盖的本地值”追溯。
  Future<void> recordConflict({
    required String bookId,
    required String field,
    required String localValue,
    required String remoteValue,
    String deviceId = '',
  }) async {
    await db.into(db.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: '$bookId:$field:${DateTime.now().microsecondsSinceEpoch}',
            bookId: bookId,
            field: field,
            localValue: Value(localValue),
            remoteValue: Value(remoteValue),
            deviceId: Value(deviceId),
            createdAtMs:
                Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  // -------------------------------------------------------------------
  // 读取
  // -------------------------------------------------------------------

  Future<List<int>> bookmarksOf(String bookId) async {
    final rows = await (db.select(db.localBookmarks)
          ..where((LocalBookmarks t) =>
              t.bookId.equals(bookId) & t.deleted.equals(false))
          ..orderBy(<OrderClauseGenerator<LocalBookmarks>>[
            (LocalBookmarks t) => OrderingTerm.asc(t.charOffset),
          ]))
        .get();
    return rows.map((LocalBookmark r) => r.charOffset).toList();
  }

  Future<List<HighlightRecord>> highlightsOf(String bookId) async {
    final rows = await (db.select(db.localHighlights)
          ..where((LocalHighlights t) =>
              t.bookId.equals(bookId) & t.deleted.equals(false))
          ..orderBy(<OrderClauseGenerator<LocalHighlights>>[
            (LocalHighlights t) => OrderingTerm.asc(t.startOffset),
          ]))
        .get();
    return rows
        .map((LocalHighlight r) => HighlightRecord(
              start: r.startOffset,
              end: r.endOffset,
              color: r.color,
              note: r.noteText,
              createdAt: r.createdAtMs,
            ))
        .toList();
  }

  Future<Map<String, String>> progressSnapshot() async {
    final rows = await db.select(db.readingPositions).get();
    return <String, String>{
      for (final ReadingPosition row in rows)
        row.bookId: '${row.chapterIndex}:${row.pageIndex}:${row.charOffset}',
    };
  }

  // -------------------------------------------------------------------
  // 迁移
  // -------------------------------------------------------------------

  /// 把旧版 SharedPreferences 中的进度/书签/高亮一次性导入 SQLite。
  ///
  /// 使用 `INSERT OR IGNORE`：已有行（例如更新版本写入的位置）不会被旧值
  /// 覆盖；旧键原样保留，随时可以回滚。
  Future<MigrationReport> migrateLegacy({
    required SharedPreferences prefs,
    required Iterable<Book> books,
    bool includeBookmarks = true,
    bool includeHighlights = true,
  }) async {
    final List<Book> list = books.toList();
    final int beforeBooks = await _count('local_books');
    final int beforePositions = await _count('reading_positions');
    final int beforeBookmarks = await _count('local_bookmarks');
    final int beforeHighlights = await _count('local_highlights');

    await db.transaction(() async {
      for (final Book book in list) {
        await db.customStatement(
          'INSERT OR IGNORE INTO local_books '
          '(id, title, author, format, source_path, content_hash, '
          'last_read_at_ms, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, 0)',
          <Object?>[
            book.id,
            book.title,
            book.author,
            book.format,
            book.sourcePath,
            book.contentHash,
            book.lastReadAt?.millisecondsSinceEpoch,
          ],
        );
        await db.customStatement(
          'INSERT OR IGNORE INTO reading_positions '
          '(book_id, chapter_index, page_index, char_offset, '
          'revision, device_id, modified_at_ms, deleted) '
          'VALUES (?, ?, ?, ?, 0, ?, ?, 0)',
          <Object?>[
            book.id,
            book.chapterIndex.value,
            book.pageIndex.value,
            book.charOffset.value,
            'legacy',
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
        if (includeBookmarks) {
          for (final int offset in _parseIntList(
              prefs.getString('$_bookmarkPrefix${book.id}'))) {
            await db.customStatement(
              'INSERT OR IGNORE INTO local_bookmarks '
              '(id, book_id, chapter_index, char_offset, label, revision, '
              'device_id, deleted) VALUES (?, ?, 0, ?, ?, ?, ?, 0)',
              <Object?>[
                '${book.id}:$offset',
                book.id,
                offset,
                '',
                DateTime.now().millisecondsSinceEpoch,
                'legacy',
              ],
            );
          }
        }
        if (includeHighlights) {
          for (final HighlightRecord record in _parseHighlights(
              prefs.getString('$_highlightPrefix${book.id}'))) {
            await db.customStatement(
              'INSERT OR IGNORE INTO local_highlights '
              '(id, book_id, start_offset, end_offset, color, note_text, '
              'excerpt, created_at_ms, updated_at_ms, deleted) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
              <Object?>[
                '${book.id}:${record.start}:${record.end}',
                book.id,
                record.start,
                record.end,
                record.color,
                record.note,
                '',
                record.createdAt,
                DateTime.now().millisecondsSinceEpoch,
              ],
            );
          }
        }
      }
    });

    final int booksNow = await _count('local_books');
    final int positionsNow = await _count('reading_positions');
    final int bookmarksNow = await _count('local_bookmarks');
    final int highlightsNow = await _count('local_highlights');
    final int insertedBooks = booksNow - beforeBooks;
    final int insertedPositions = positionsNow - beforePositions;
    return MigrationReport(
      books: insertedBooks,
      positions: insertedPositions,
      bookmarks: bookmarksNow - beforeBookmarks,
      highlights: highlightsNow - beforeHighlights,
      alreadyPresent: list.length - insertedBooks,
    );
  }

  Future<int> _count(String table) async {
    final row = await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
    return row.read<int>('c');
  }

  static List<int> _parseIntList(String? raw) {
    if (raw == null) return <int>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <int>[];
      return decoded
          .whereType<num>()
          .map((num e) => e.toInt())
          .where((int e) => e >= 0)
          .toSet()
          .toList();
    } catch (_) {
      return <int>[];
    }
  }

  static List<HighlightRecord> _parseHighlights(String? raw) {
    if (raw == null) return <HighlightRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <HighlightRecord>[];
      final out = <HighlightRecord>[];
      for (final item in decoded) {
        final record = HighlightRecord.fromJson(item);
        if (record != null) out.add(record);
      }
      return out;
    } catch (_) {
      return <HighlightRecord>[];
    }
  }
}
