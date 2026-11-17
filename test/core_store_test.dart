import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/database/core_store.dart';
import 'package:read/src/database/read_database.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/highlight_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

Book _book(String id) {
  final Book book = Book(
    id: id,
    title: '书 $id',
    author: '作者',
    format: 'TXT',
    content: '第一章\n正文内容',
    sourcePath: '/tmp/$id.txt',
    contentHash: 'hash-$id',
  );
  book.chapterIndex.value = 3;
  book.pageIndex.value = 2;
  book.charOffset.value = 88;
  return book;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('旧版 SharedPreferences 数据增量迁移，且旧键原样保留', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'read.bookmarks.v1.b1': '[12,34]',
      'read.highlights.v1.b1':
          '[{"start":1,"end":5,"color":16776960,"note":"重点","created_at":99}]',
      'read.library.meta.v1': '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    final ReadDatabase db = ReadDatabase.forTesting(NativeDatabase.memory());
    final CoreStore store = CoreStore.wrap(db);
    try {
      final Book book = _book('b1');
      final MigrationReport first =
          await store.migrateLegacy(prefs: prefs, books: <Book>[book]);
      expect(first.books, 1);
      expect(first.positions, 1);
      expect(first.bookmarks, 2);
      expect(first.highlights, 1);

      // 幂等：第二次不会再插入。
      final MigrationReport second =
          await store.migrateLegacy(prefs: prefs, books: <Book>[book]);
      expect(second.books, 0);
      expect(second.positions, 0);
      expect(second.bookmarks, 0);
      expect(second.highlights, 0);
      expect(second.alreadyPresent, 1);

      // 旧键仍可读，回滚路径有效。
      expect(prefs.getString('read.bookmarks.v1.b1'), '[12,34]');
      expect(prefs.getString('read.library.meta.v1'), '[]');

      expect(await store.bookmarksOf('b1'), <int>[12, 34]);
      final List<HighlightRecord> highlights = await store.highlightsOf('b1');
      expect(highlights.single.note, '重点');
      expect(highlights.single.start, 1);

      final Map<String, String> progress = await store.progressSnapshot();
      expect(progress['b1'], '3:2:88');
    } finally {
      await db.close();
    }
  });

  test('书签唯一约束防重复，替换后数量正确', () async {
    final ReadDatabase db = ReadDatabase.forTesting(NativeDatabase.memory());
    final CoreStore store = CoreStore.wrap(db);
    try {
      await store.replaceBookmarks('b1', <int>[1, 1, 2, 2, 3]);
      expect(await store.bookmarksOf('b1'), <int>[1, 2, 3]);
      await store.replaceBookmarks('b1', <int>[9]);
      expect(await store.bookmarksOf('b1'), <int>[9]);
      // 其他书的书签不受影响。
      await store.replaceBookmarks('b2', <int>[5]);
      expect(await store.bookmarksOf('b1'), <int>[9]);
      expect(await store.bookmarksOf('b2'), <int>[5]);
    } finally {
      await db.close();
    }
  });

  test('进度与高亮写入后重新打开数据库仍然存在', () async {
    final Directory dir = await Directory.systemTemp.createTemp('read-core-');
    final File file = File('${dir.path}/core.sqlite');
    final Book book = _book('b1');
    CoreStore first = await CoreStore.open(file);
    await first.saveProgress(book);
    await first.replaceHighlights('b1', <HighlightRecord>[
      const HighlightRecord(start: 0, end: 4, color: 1, note: 'n', createdAt: 5),
    ]);
    await CoreStore.closeActive();

    first = await CoreStore.open(file);
    final Map<String, String> progress = await first.progressSnapshot();
    expect(progress['b1'], '3:2:88');
    expect((await first.highlightsOf('b1')).single.note, 'n');
    await CoreStore.closeActive();
    await dir.delete(recursive: true);
  });

  test('v1 数据库升级到 v2 保留原有数据并新增表', () async {
    final Directory dir = await Directory.systemTemp.createTemp('read-upgrade-');
    final File file = File('${dir.path}/v1.sqlite');
    final Database raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE local_books (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
        author TEXT NOT NULL, format TEXT NOT NULL, source_path TEXT,
        content_hash TEXT, last_read_at_ms INTEGER,
        deleted INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE reading_positions (book_id TEXT NOT NULL PRIMARY KEY,
        chapter_index INTEGER NOT NULL DEFAULT 0, page_index INTEGER NOT NULL DEFAULT 0,
        char_offset INTEGER NOT NULL DEFAULT -1, revision INTEGER NOT NULL DEFAULT 0,
        device_id TEXT NOT NULL DEFAULT 'legacy', modified_at_ms INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE local_bookmarks (id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL, char_offset INTEGER NOT NULL,
        label TEXT NOT NULL DEFAULT '', revision INTEGER NOT NULL DEFAULT 0,
        device_id TEXT NOT NULL DEFAULT 'local', deleted INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE local_notes (id TEXT NOT NULL PRIMARY KEY, book_id TEXT NOT NULL,
        start_offset INTEGER NOT NULL, end_offset INTEGER NOT NULL,
        note_text TEXT NOT NULL, excerpt TEXT NOT NULL DEFAULT '',
        revision INTEGER NOT NULL DEFAULT 0, device_id TEXT NOT NULL DEFAULT 'local',
        deleted INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE sync_journal (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL,
        revision INTEGER NOT NULL, device_id TEXT NOT NULL, serialized TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL, completed INTEGER NOT NULL DEFAULT 0);
    ''');
    raw.execute(
        "INSERT INTO local_books (id,title,author,format) VALUES ('old','旧书','作者','TXT')");
    raw.execute(
        "INSERT INTO reading_positions (book_id,chapter_index,page_index,char_offset) "
        "VALUES ('old',7,3,456)");
    raw.execute("PRAGMA user_version = 1");
    raw.dispose();

    final CoreStore store = await CoreStore.open(file);
    try {
      expect((await store.progressSnapshot())['old'], '7:3:456');
      final rows = await store.db.select(store.db.localBooks).get();
      expect(rows.single.title, '旧书');
      // v2 新表可用。
      await store.recordConflict(
        bookId: 'old',
        field: 'title',
        localValue: '旧书',
        remoteValue: '新标题',
      );
      final conflicts = await store.db.select(store.db.syncConflicts).get();
      expect(conflicts.single.field, 'title');
      expect(await store.highlightsOf('old'), isEmpty);
    } finally {
      await CoreStore.closeActive();
      await dir.delete(recursive: true);
    }
  });

  test('同步队列快照可整体落库并被替换', () async {
    final ReadDatabase db = ReadDatabase.forTesting(NativeDatabase.memory());
    final CoreStore store = CoreStore.wrap(db);
    try {
      await store.replaceQueueTasks(<QueueSnapshot>[
        const QueueSnapshot(
            id: 'q1',
            kind: 'progress',
            bookId: 'b1',
            attempts: 2,
            nextAttemptMs: 100,
            state: 'pending',
            lastError: 'timeout'),
      ]);
      var rows = await db.select(db.syncQueueItems).get();
      expect(rows.single.attempts, 2);
      await store.replaceQueueTasks(const <QueueSnapshot>[]);
      rows = await db.select(db.syncQueueItems).get();
      expect(rows, isEmpty);
    } finally {
      await db.close();
    }
  });
}
