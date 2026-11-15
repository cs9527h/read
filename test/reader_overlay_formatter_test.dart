import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/reader_overlay_formatter.dart';

void main() {
  test('page footer interpolates stable reading position', () {
    final label = ReaderOverlayFormatter.render(
      '{book} / {chapter} / {page}/{pages} / {progress}% / {time}',
      book: '本地书',
      chapter: '第二章',
      page: 5,
      pages: 20,
      absoluteOffset: 250,
      totalChars: 1000,
      now: DateTime(2026, 1, 2, 9, 7),
    );
    expect(label, '本地书 / 第二章 / 5/20 / 25.0% / 09:07');
  });

  test('unrecognized variables remain readable and progress is clamped', () {
    expect(ReaderOverlayFormatter.render(
      '{missing} {progress}',
      book: '', chapter: '', page: 1, pages: 1,
      absoluteOffset: 200, totalChars: 100,
    ), '{missing} 100.0');
  });
}
