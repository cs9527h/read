import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/book_name_parser.dart';

void main() {
  group('文件名拆分为书名与作者', () {
    test('书名 - 作者', () {
      final ParsedBookName r = parseBookName('三体 - 刘慈欣.txt');
      expect(r.title, '三体');
      expect(r.author, '刘慈欣');
    });

    test('《书名》作者', () {
      final ParsedBookName r = parseBookName('《活着》余华.epub');
      expect(r.title, '活着');
      expect(r.author, '余华');
    });

    test('书名 作者：某某', () {
      final ParsedBookName r = parseBookName('百年孤独 作者：加西亚·马尔克斯.txt');
      expect(r.title, '百年孤独');
      expect(r.author, '加西亚·马尔克斯');
    });

    test('书名（作者）', () {
      final ParsedBookName r = parseBookName('红楼梦（曹雪芹）.txt');
      expect(r.title, '红楼梦');
      expect(r.author, '曹雪芹');
    });

    test('没有作者信息时整体作为书名', () {
      final ParsedBookName r = parseBookName('1Q84.txt');
      expect(r.title, '1Q84');
      expect(r.author, isNull);
    });

    test('书名里的破折号不被误当作者分隔', () {
      final ParsedBookName r = parseBookName('哈利·波特与魔法石.txt');
      expect(r.title, '哈利·波特与魔法石');
      expect(r.author, isNull);
    });

    test('去掉常见版本标记噪声', () {
      final ParsedBookName r = parseBookName('围城[精校].txt');
      expect(r.title, '围城');
      expect(r.author, isNull);
    });

    test('作者名过长时不拆分，避免把副标题当作者', () {
      final ParsedBookName r = parseBookName(
        '一本书 - 这是一个非常非常长的副标题说明文字集合超过二十个字.txt',
      );
      expect(r.title, contains('一本书'));
      expect(r.author, isNull);
    });
  });
}
