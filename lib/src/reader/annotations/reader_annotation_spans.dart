import 'package:flutter/material.dart';

import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/services/reader_annotation_store.dart';

/// Build visible highlights with exact UTF-16 source offsets. The original
/// source and page measurements remain unchanged because background color and
/// bold formatting do not add glyphs or modify the text itself.
class ReaderAnnotationSpans {
  const ReaderAnnotationSpans._();

  static TextSpan render({
    required String text,
    required TextStyle bodyStyle,
    required DisplayChapter display,
    required int displayStart,
    required int chapterStart,
    required List<ReaderAnnotation> annotations,
    String boldPattern = '',
  }) {
    if (text.isEmpty) return TextSpan(text: text, style: bodyStyle);

    RegExp? bold;
    if (boldPattern.trim().isNotEmpty) {
      try {
        bold = RegExp(boldPattern.trim());
      } on FormatException {
        bold = null;
      }
    }

    final lines = text.split('\n');
    final lineStarts = <int>[];
    final lineBold = <bool>[];
    final cuts = <int>{0, text.length};
    var offset = 0;
    for (final line in lines) {
      lineStarts.add(offset);
      lineBold.add(line.trim().isNotEmpty && (bold?.hasMatch(line) ?? false));
      offset += line.length + 1;
      if (offset <= text.length) cuts.add(offset);
    }

    final highlights = <({int start, int end, int argb})>[];
    for (final item in annotations) {
      final start = (item.start - chapterStart).clamp(0, display.sourceLength);
      final end = (item.end - chapterStart).clamp(0, display.sourceLength);
      if (end <= start) continue;
      final localStart =
          (display.displayOffset(start) - displayStart).clamp(0, text.length);
      final localEnd =
          (display.displayOffset(end) - displayStart).clamp(0, text.length);
      if (localEnd <= localStart) continue;
      highlights.add((
        start: localStart,
        end: localEnd,
        argb: item.colorArgb,
      ));
      cuts.add(localStart);
      cuts.add(localEnd);
    }
    final positions = cuts.toList()..sort();
    final children = <InlineSpan>[];
    var line = 0;
    for (var i = 0; i + 1 < positions.length; i++) {
      final start = positions[i];
      final end = positions[i + 1];
      if (start >= end) continue;
      while (line + 1 < lineStarts.length &&
          start >= lineStarts[line + 1]) {
        line++;
      }
      int? color;
      for (final item in highlights) {
        if (start >= item.start && start < item.end) color = item.argb;
      }
      children.add(TextSpan(
        text: text.substring(start, end),
        style: bodyStyle.copyWith(
          fontWeight: lineBold[line]
              ? FontWeight.w700
              : bodyStyle.fontWeight,
          backgroundColor: color == null
              ? null
              : Color(color).withValues(alpha: 0.33),
        ),
      ));
    }
    return TextSpan(children: children);
  }
}
