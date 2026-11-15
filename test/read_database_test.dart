import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/database/read_database.dart';
import 'package:read/src/model/book.dart';

void main() {
  test('legacy books/progress are imported atomically without deleting old data', () async {
    final db = ReadDatabase.forTesting(NativeDatabase.memory());
    try {
      final book = Book(
        id: 'legacy-book-1',
        title: '旧书',
        author: '测试',
        format: 'TXT',
        content: '第一章\n文本',
        sourcePath: '/not/a/network/file.txt',
      );
      book.chapterIndex.value = 2;
      book.pageIndex.value = 4;
      book.charOffset.value = 123;
      await db.importLegacySnapshot(<Book>[book]);
      final books = await db.select(db.localBooks).get();
      final progress = await db.select(db.readingPositions).get();
      expect(books.length, 1);
      expect(books.first.title, '旧书');
      expect(progress.length, 1);
      expect(progress.first.chapterIndex, 2);
      expect(progress.first.pageIndex, 4);
      expect(progress.first.charOffset, 123);

      // Snapshot is idempotent; it must never overwrite a newer position.
      book.charOffset.value = 999;
      await db.importLegacySnapshot(<Book>[book]);
      final unchanged = await db.select(db.readingPositions).getSingle();
      expect(unchanged.charOffset, 123);
    } finally {
      await db.close();
    }
  });

  test('new SQLite schema includes note, bookmark and sync journal tables', () async {
    final db = ReadDatabase.forTesting(NativeDatabase.memory());
    try {
      expect(await db.select(db.localNotes).get(), isEmpty);
      expect(await db.select(db.localBookmarks).get(), isEmpty);
      expect(await db.select(db.syncJournal).get(), isEmpty);
    } finally {
      await db.close();
    }
  });
}
