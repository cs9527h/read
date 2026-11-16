import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';

void main() {
  test('新增的元数据字段能完整往返，不会在持久化时丢失', () {
    final Book book = Book(
      id: 'b1',
      title: '书名',
      author: '作者',
      content: '正文',
      pinned: true,
      rating: 4,
      readingStatus: ReadingStatus.paused.code,
      category: '技术',
      tags: <String>['待读', '重读'],
      collections: <String>['书箱A'],
      coverPath: '/tmp/cover.png',
      coverTemplate: 'grid',
      isPrivate: true,
    );

    final Book restored = Book.fromMeta(book.toMeta(), book.content);

    expect(restored.pinned, isTrue);
    expect(restored.rating, 4);
    expect(restored.status, ReadingStatus.paused);
    expect(restored.category, '技术');
    expect(restored.tags, <String>['待读', '重读']);
    expect(restored.collections, <String>['书箱A']);
    expect(restored.coverPath, '/tmp/cover.png');
    expect(restored.coverTemplate, 'grid');
    expect(restored.isPrivate, isTrue);
  });

  test('旧索引没有新字段时给出安全默认值', () {
    final Book restored = Book.fromMeta(<String, dynamic>{
      'id': 'old',
      'title': '旧书',
      'author': '某人',
    }, '正文');

    expect(restored.pinned, isFalse);
    expect(restored.rating, 0);
    expect(restored.status, ReadingStatus.unread);
    expect(restored.coverTemplate, 'ink');
    expect(restored.tags, isEmpty);
    expect(restored.collections, isEmpty);
  });

  test('copyWith 保留阅读进度与未修改字段', () {
    final Book book = Book(id: 'b2', title: 'A', author: 'B', content: 'x');
    book.chapterIndex.value = 7;
    book.pageIndex.value = 3;
    book.charOffset.value = 1024;

    final Book copy = book.copyWith(tags: <String>['t']);

    expect(copy.chapterIndex.value, 7);
    expect(copy.pageIndex.value, 3);
    expect(copy.charOffset.value, 1024);
    expect(copy.title, 'A');
    expect(copy.tags, <String>['t']);
  });

  test('清除封面时 coverPath 置空但模板保留', () {
    final Book book = Book(
      id: 'b3',
      title: 'C',
      author: 'D',
      content: 'y',
      coverPath: '/tmp/a.png',
      coverTemplate: 'night',
    );
    final Book cleared = book.copyWith(clearCover: true);
    expect(cleared.coverPath, isNull);
    expect(cleared.coverTemplate, 'night');
  });

  test('progressRatio 按章节估算并夹在 0..1', () {
    final Book book = Book(id: 'b4', title: 'E', author: 'F', content: 'z');
    expect(book.progressRatio, 0);
    book.chapterCount = 10;
    book.chapterIndex.value = 4;
    expect(book.progressRatio, closeTo(0.5, 0.0001));
    book.chapterIndex.value = 99;
    expect(book.progressRatio, 1.0);
  });

  test('评分越界会被夹到 0..5', () {
    final Book restored = Book.fromMeta(<String, dynamic>{
      'id': 'b5',
      'title': 'G',
      'author': 'H',
      'rating': 99,
    }, '');
    expect(restored.rating, 5);
  });
}
