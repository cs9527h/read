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
  SyncJournal,
])
class ReadDatabase extends _$ReadDatabase {
  ReadDatabase(File file) : super(NativeDatabase.createInBackground(file));
  ReadDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

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
