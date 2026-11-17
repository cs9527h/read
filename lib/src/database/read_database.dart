import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../model/book.dart';

part 'read_database.g.dart';

/// Persisted book metadata; large original files stay in app-managed storage.
class LocalBooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get format => text()();
  TextColumn get sourcePath => text().nullable()();
  TextColumn get contentHash => text().nullable()();
  IntColumn get lastReadAtMs => integer().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Layout-independent text reading position; PDF uses pageIndex instead.
class ReadingPositions extends Table {
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();
  IntColumn get pageIndex => integer().withDefault(const Constant(0))();
  IntColumn get charOffset => integer().withDefault(const Constant(-1))();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().withDefault(const Constant('legacy'))();
  IntColumn get modifiedAtMs => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {bookId};
}

class LocalBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get charOffset => integer()();
  TextColumn get label => text().withDefault(const Constant(''))();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().withDefault(const Constant('local'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get noteText => text()();
  TextColumn get excerpt => text().withDefault(const Constant(''))();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().withDefault(const Constant('local'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 高亮与笔记：绝对字符区间锚点，重新排版后仍然准确。
class LocalHighlights extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get color => integer().withDefault(const Constant(0xFFFFF176))();
  TextColumn get noteText => text().withDefault(const Constant(''))();
  TextColumn get excerpt => text().withDefault(const Constant(''))();
  IntColumn get createdAtMs => integer().withDefault(const Constant(0))();
  IntColumn get updatedAtMs => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => <Set<Column>>[
        <Column>{bookId, startOffset, endOffset},
      ];
}

/// 待同步队列：应用被杀掉后下次启动继续处理。
class SyncQueueItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get bookId => text().withDefault(const Constant(''))();
  TextColumn get payload => text().withDefault(const Constant(''))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptMs => integer().withDefault(const Constant(0))();
  IntColumn get createdAtMs => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  TextColumn get lastError => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 同步冲突留痕：任何被覆盖的本地值都必须可追溯，不能静默丢失。
class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get field => text()();
  TextColumn get localValue => text().withDefault(const Constant(''))();
  TextColumn get remoteValue => text().withDefault(const Constant(''))();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncJournal extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  IntColumn get revision => integer()();
  TextColumn get deviceId => text()();
  TextColumn get serialized => text()();
  IntColumn get createdAtMs => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Initial schema. Existing SharedPreferences remains readable and is NOT
/// deleted by this migration; conversion is an additive, atomic snapshot.
@DriftDatabase(tables: [
  LocalBooks,
  ReadingPositions,
  LocalBookmarks,
  LocalNotes,
  LocalHighlights,
  SyncQueueItems,
  SyncConflicts,
  SyncJournal,
])
class ReadDatabase extends _$ReadDatabase {
  ReadDatabase(File file) : super(NativeDatabase.createInBackground(file));
  ReadDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // v2 只做增量：新增高亮、同步队列、冲突表，不改动任何旧列。
            await m.createTable(localHighlights);
            await m.createTable(syncQueueItems);
            await m.createTable(syncConflicts);
            await _createIndexes();
          }
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// 索引用于按书查询与队列扫描；IF NOT EXISTS 保证重复执行安全。
  Future<void> _createIndexes() async {
    const List<String> statements = <String>[
      'CREATE INDEX IF NOT EXISTS idx_bookmarks_book '
          'ON local_bookmarks (book_id, char_offset)',
      'CREATE INDEX IF NOT EXISTS idx_notes_book ON local_notes (book_id)',
      'CREATE INDEX IF NOT EXISTS idx_highlights_book '
          'ON local_highlights (book_id, start_offset)',
      'CREATE INDEX IF NOT EXISTS idx_queue_state '
          'ON sync_queue_items (state, next_attempt_ms)',
      'CREATE INDEX IF NOT EXISTS idx_conflicts_book '
          'ON sync_conflicts (book_id, resolved)',
      'CREATE INDEX IF NOT EXISTS idx_positions_modified '
          'ON reading_positions (modified_at_ms)',
    ];
    for (final String statement in statements) {
      await customStatement(statement);
    }
  }

  /// One-way snapshot into empty/missing SQLite rows without rewriting legacy
  /// app data or overwriting more recent rows.
  Future<int> importLegacySnapshot(Iterable<Book> books) async {
    int inserted = 0;
    await transaction(() async {
      for (final book in books) {
        await customStatement(
          'INSERT OR IGNORE INTO local_books '
          '(id, title, author, format, source_path, last_read_at_ms, deleted) '
          'VALUES (?, ?, ?, ?, ?, ?, 0)',
          <Object?>[
            book.id, book.title, book.author, book.format, book.sourcePath,
            book.lastReadAt?.millisecondsSinceEpoch,
          ],
        );
        await customStatement(
          'INSERT OR IGNORE INTO reading_positions '
          '(book_id, chapter_index, page_index, char_offset, '
          'revision, device_id, modified_at_ms, deleted) '
          'VALUES (?, ?, ?, ?, 0, ?, 0, 0)',
          <Object?>[
            book.id,
            book.chapterIndex.value,
            book.pageIndex.value,
            book.charOffset.value,
            'legacy',
          ],
        );
        inserted++;
      }
    });
    return inserted;
  }
}
