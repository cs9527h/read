import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A contiguous, UTF-16-code-unit range of the source text.
///
/// Unlike searching for the rendered page text with indexOf, this preserves
/// exact positions even when paragraphs, spaces and blank lines repeat.
class PageSlice {
  const PageSlice(this.start, this.end);

  final int start;
  final int end;

  String textOf(String source) => source.substring(start, end);
}

bool _highSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _lowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Measure into bounded pages, including a single extremely long paragraph.
///
/// - Every UTF-16 code unit is included in exactly one contiguous page.
/// - The common TXT case (a novel chapter without newlines) is supported.
/// - No page is allowed to end between a UTF-16 high/low surrogate pair.
/// - A huge character that cannot fit still makes forward progress.
///
/// A single chapter is still loaded into memory. True disk-backed lazy pages
/// for multi-hundred-MB books are a separate feature, not claimed here.
List<PageSlice> paginateSlices(
  String text,
  TextStyle style,
  double maxWidth,
  double maxHeight, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (!maxWidth.isFinite || !maxHeight.isFinite ||
      maxWidth <= 0 || maxHeight <= 0) {
    throw ArgumentError('分页区域必须有正的宽高');
  }
  if (text.isEmpty) return <PageSlice>[const PageSlice(0, 0)];

  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  );
  bool fits(int start, int count) {
    // TextPainter must never receive half a UTF-16 surrogate pair, even
    // temporarily during the binary/exponential measurement probes.
    int safeCount = count;
    final int end = start + safeCount;
    if (safeCount > 0 &&
        end < text.length &&
        _highSurrogate(text.codeUnitAt(end - 1)) &&
        _lowSurrogate(text.codeUnitAt(end))) {
      safeCount--;
    }
    if (safeCount <= 0) return false;
    painter.text = TextSpan(
      text: text.substring(start, start + safeCount),
      style: style,
    );
    painter.layout(maxWidth: maxWidth);
    return painter.height <= maxHeight + 0.5;
  }

  final result = <PageSlice>[];
  int start = 0;
  const int maxCandidate = 8192;
  while (start < text.length) {
    final int ceiling = math.min(maxCandidate, text.length - start);
    int probe = math.min(512, ceiling);
    int low = 0;
    int failedAt = ceiling + 1;

    // Exponential search avoids measuring multi-thousand-char strings for
    // every ordinary ~300-1000 character book page.
    while (true) {
      if (fits(start, probe)) {
        low = probe;
        if (probe == ceiling) break;
        probe = math.min(ceiling, probe * 2);
      } else {
        failedAt = probe;
        break;
      }
    }

    int high = failedAt == ceiling + 1 ? ceiling : failedAt - 1;
    while (low < high) {
      final int middle = (low + high + 1) ~/ 2;
      if (fits(start, middle)) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }

    // A screen too small to fit even one glyph must not hang forever.
    int end = start + math.max(low, 1);
    if (end < text.length &&
        _highSurrogate(text.codeUnitAt(end - 1)) &&
        _lowSurrogate(text.codeUnitAt(end))) {
      end--;
      if (end == start) end = math.min(text.length, start + 2);
    }

    result.add(PageSlice(start, end));
    start = end;
  }
  painter.dispose();
  return result;
}

/// Compatibility API used by existing tests and older reader code.
List<String> paginate(
  String text,
  TextStyle style,
  double maxWidth,
  double maxHeight,
) => paginateSlices(text, style, maxWidth, maxHeight)
    .map((PageSlice page) => page.textOf(text)).toList(growable: false);
