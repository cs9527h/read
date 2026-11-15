import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/reader_annotation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('repeated text stores distinct absolute anchors, not indexOf guesses', () async {
    const book = 'same-line';
    const text = '重复文字 + 重复文字';
    final store = ReaderAnnotationStore.instance;
    final left = await store.add(
      bookId: book, content: text, start: 0, end: 4,
      colorArgb: 0xFFF1D85B,
    );
    expect(left.single.start, 0);
    final right = await store.add(
      bookId: book, content: text, start: 7, end: 11,
      colorArgb: 0xFF99CCAA, note: '第二处',
    );
    expect(right.length, 2);
    expect(right.first.start, 0);
    expect(right.last.start, 7);
    expect(right.last.note, '第二处');
    final again = await store.load(book);
    expect(again.map((a) => a.start), <int>[0, 7]);
  });

  test('same range recolor does not duplicate annotation', () async {
    final store = ReaderAnnotationStore.instance;
    await store.add(bookId: 'b', content: '文章正文',
        start: 0, end: 2, colorArgb: 0xFFFFEE00);
    final second = await store.add(bookId: 'b', content: '文章正文',
        start: 0, end: 2, colorArgb: 0xFFEECCAA);
    expect(second.length, 1);
    expect(second.single.colorArgb, 0xFFEECCAA);
    final changed = await store.update('b', second.single.id, note: '记录想法');
    expect(changed.single.note, '记录想法');
    final deleted = await store.delete('b', changed.single.id);
    expect(deleted, isEmpty);
  });

  test('corrupt notes block destructive rewrites', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read.reader.annotations.v1.corrupt', '{"broken');
    final store = ReaderAnnotationStore.instance;
    await expectLater(store.load('corrupt'), throwsFormatException);
    await expectLater(
      store.add(bookId: 'corrupt', content: '正文',
          start: 0, end: 1, colorArgb: 0xFFFFFF00),
      throwsFormatException,
    );
    expect(prefs.getString('read.reader.annotations.v1.corrupt'), '{"broken');
  });

  test('rapid annotation writes preserve all independent ranges', () async {
    final store = ReaderAnnotationStore.instance;
    const text = '0123456789';
    await Future.wait(<Future<dynamic>>[
      store.add(bookId: 'rapid', content: text,
          start: 1, end: 2, colorArgb: 0xFFEEDDCC),
      store.add(bookId: 'rapid', content: text,
          start: 3, end: 4, colorArgb: 0xFFEEDDCC),
      store.add(bookId: 'rapid', content: text,
          start: 5, end: 6, colorArgb: 0xFFEEDDCC),
    ]);
    expect((await store.load('rapid')).map((a) => a.start), <int>[1, 3, 5]);
  });
}
