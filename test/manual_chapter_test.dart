import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/manual_chapter_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('手动章节在自动章节内部切开且不丢原文', () {
    const content = '第一章 开头\n正文A\n第二章 中间\n正文B\n第三章 结尾\n正文C';
    final chapters = splitChapters(content);
    final result = applyManualChapters(content, chapters, <ManualChapterMark>[
      const ManualChapterMark(offset: 8, title: '手动一', createdAt: 1),
      const ManualChapterMark(offset: 18, title: '手动二', createdAt: 2),
    ]);
    expect(result.length, greaterThan(chapters.length));
    expect(result.every((Chapter c) => c.start >= 0 && c.end <= content.length), isTrue);
    expect(result.where((Chapter c) => c.manual).map((Chapter c) => c.title),
        containsAll(<String>['手动一', '手动二']));
    final rebuilt = result.map((Chapter c) => c.slice(content)).join();
    expect(rebuilt.length, content.length);
  });

  test('手动章节持久化、去重与删除', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ManualChapterStore.add('book', 10, '第一节');
    await ManualChapterStore.add('book', 10, '改名');
    await ManualChapterStore.add('book', 20, '');
    final marks = await ManualChapterStore.load('book');
    expect(marks.length, 2);
    expect(marks.first.title, '改名');
    expect(marks.last.title, '手动章节');
    await ManualChapterStore.remove('book', 10);
    expect((await ManualChapterStore.load('book')).single.offset, 20);
  });
}
