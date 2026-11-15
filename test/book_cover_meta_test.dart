import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';

void main() {
  test('EPUB cover path round-trips through persisted book metadata', () {
    final original = Book(
      id: 'cover-case',
      title: '有封面的书',
      author: '测试作者',
      format: 'EPUB',
      content: '第一章\n测试内容',
      sourcePath: '/app/books/cover-case.epub',
      coverPath: '/app/books/cover-case.cover.jpg',
      chapterCount: 2,
    );
    final loaded = Book.fromMeta(original.toMeta(), original.content);
    expect(loaded.coverPath, original.coverPath);
    expect(loaded.sourcePath, original.sourcePath);
    expect(loaded.chapterCount, 2);
  });

  test('Old library metadata without a cover remains readable', () {
    final loaded = Book.fromMeta(<String, dynamic>{
      'id': 'old',
      'title': '旧书',
      'format': 'TXT',
      'sourcePath': '/app/books/old.txt',
    }, '内容');
    expect(loaded.coverPath, isNull);
    expect(loaded.title, '旧书');
  });
}
