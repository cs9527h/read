import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/annotations/reader_annotation_spans.dart';
import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/services/reader_annotation_store.dart';

void main() {
  test('highlight spans preserve source text and distinguish repeated quotes', () {
    const display = DisplayChapter('甲甲乙甲甲', <int>[0, 1, 2, 3, 4], 5);
    const mark = ReaderAnnotation(
      id: 'mark-1',
      start: 3,
      end: 5,
      quote: '甲甲',
      note: '',
      colorArgb: 0xFFFFFF00,
      createdAt: 1,
    );
    final span = ReaderAnnotationSpans.render(
      text: display.text,
      bodyStyle: const TextStyle(fontSize: 18),
      display: display,
      displayStart: 0,
      chapterStart: 0,
      annotations: const <ReaderAnnotation>[mark],
    );
    expect(span.toPlainText(), '甲甲乙甲甲');
    final pieces = span.children!.cast<TextSpan>();
    expect(pieces.length, greaterThan(1));
    expect(pieces.first.style?.backgroundColor, isNull);
    expect(pieces.last.style?.backgroundColor, isNotNull);
  });

  test('reflowed page slice retains highlight at absolute source offset', () {
    const display = DisplayChapter('春夏秋冬', <int>[0, 1, 2, 3], 4);
    const mark = ReaderAnnotation(
      id: 'mark-2',
      start: 502,
      end: 503,
      quote: '秋',
      note: '',
      colorArgb: 0xFF99CC55,
      createdAt: 2,
    );
    final span = ReaderAnnotationSpans.render(
      text: '夏秋',
      bodyStyle: const TextStyle(fontSize: 18),
      display: display,
      displayStart: 1,
      chapterStart: 500,
      annotations: const <ReaderAnnotation>[mark],
    );
    expect(span.toPlainText(), '夏秋');
    expect(span.children!.cast<TextSpan>().last.style?.backgroundColor,
        isNotNull);
  });
}
