import 'package:flutter_test/flutter_test.dart';

import 'package:read/src/model/book.dart';

void main() {
  Book sample() => Book(
        id: 'local-1',
        title: '深海余烬',
        author: '远瞳',
        content: '正文',
        format: 'EPUB',
        contentHash: 'a' * 64,
        tags: <String>['科幻', '待读'],
        category: '科幻',
        rating: 4,
        pinned: true,
        isPrivate: true,
        readingStatus: 'shelved',
        coverPath: '/tmp/cover.png',
      );

  test('编辑信息字段写入元数据并可完整还原', () {
    final book = sample();
    final meta = book.toMeta();
    final restored = Book.fromMeta(meta, book.content);

    expect(meta['category'], '科幻');
    expect(meta['rating'], 4);
    expect(meta['pinned'], isTrue);
    expect(meta['isPrivate'], isTrue);
    expect(meta['readingStatus'], 'shelved');
    expect(meta['coverPath'], '/tmp/cover.png');

    expect(restored.category, '科幻');
    expect(restored.rating, 4);
    expect(restored.pinned, isTrue);
    expect(restored.isPrivate, isTrue);
    expect(restored.readingStatus, 'shelved');
    expect(restored.coverPath, '/tmp/cover.png');
    expect(restored.tags, containsAll(<String>['科幻', '待读']));
  });

  test('旧索引没有新字段时回落为未读且不伪造评分', () {
    final restored = Book.fromMeta(<String, dynamic>{
      'id': 'old',
      'title': '旧书',
      'author': '某人',
      'format': 'TXT',
    }, '正文');

    expect(restored.category, '');
    expect(restored.rating, 0);
    expect(restored.pinned, isFalse);
    expect(restored.isPrivate, isFalse);
    expect(restored.readingStatus, 'unread');
    expect(restored.coverPath, isNull);
  });

  test('评分越界会被裁剪而不是写坏索引', () {
    final restored = Book.fromMeta(<String, dynamic>{
      'id': 'bad-rating',
      'title': '书',
      'author': '人',
      'rating': 9,
    }, '正文');
    expect(restored.rating, 5);
  });

  test('copyWith 保留进度并复制标签，不共享可变列表', () {
    final book = sample()
      ..chapterIndex.value = 7
      ..pageIndex.value = 2
      ..charOffset.value = 128;

    final copy = book.copyWith(title: '新书名', pinned: false);
    book.tags.add('新标签');

    expect(copy.title, '新书名');
    expect(copy.pinned, isFalse);
    expect(copy.chapterIndex.value, 7);
    expect(copy.pageIndex.value, 2);
    expect(copy.charOffset.value, 128);
    expect(copy.tags, isNot(contains('新标签')));
  });
}
