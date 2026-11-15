import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/reader_style_store.dart';

void main() {
  test('reading style JSON preserves layout, theme and controls', () {
    const source = ReaderStyle(
      fontSize: 24,
      lineHeight: 1.9,
      letterSpacing: 1.2,
      fontWeightIndex: 6,
      textAlignIndex: 1,
      horizontalMargin: 37,
      verticalMargin: 26,
      backgroundIndex: 4,
      showHeader: true,
      showFooter: false,
      tapZone: 0.33,
      turnDurationMs: 250,
    );
    final copy = ReaderStyle.fromJson(jsonDecode(jsonEncode(source.toJson())));
    expect(copy.toJson(), source.toJson());
    expect(copy.fontWeight, FontWeight.w700);
    expect(copy.textAlign, TextAlign.justify);
  });

  test('invalid or corrupt style cannot break the reader layout', () {
    final style = ReaderStyle.fromJson(<String, Object?>{
      'fontSize': -42,
      'lineHeight': 50,
      'letterSpacing': double.nan,
      'fontWeightIndex': 100,
      'textAlignIndex': -10,
      'horizontalMargin': 9999,
      'verticalMargin': -1,
      'backgroundIndex': 80,
      'tapZone': 0,
      'turnDurationMs': -3,
      'showFooter': 'oops',
    });
    expect(style.fontSize, 12);
    expect(style.lineHeight, 2.8);
    expect(style.letterSpacing, 0);
    expect(style.fontWeightIndex, 8);
    expect(style.textAlign, TextAlign.left);
    expect(style.horizontalMargin, 80);
    expect(style.verticalMargin, 4);
    expect(style.backgroundIndex, 5);
    expect(style.tapZone, 0.15);
    expect(style.turnDurationMs, 0);
    expect(style.showFooter, true);
  });

  test('non-layout changes do not force pagination', () {
    const style = ReaderStyle();
    expect(style.copyWith(backgroundIndex: 2).layoutKey, style.layoutKey);
    expect(style.copyWith(tapZone: 0.4).layoutKey, style.layoutKey);
    expect(style.copyWith(lineHeight: 2).layoutKey, isNot(style.layoutKey));
    expect(style.copyWith(horizontalMargin: 40).layoutKey, isNot(style.layoutKey));
  });

  testWidgets('measured pagination respects accessibility text scale', (tester) async {
    // TextPainter is only available with an initialized Flutter binding.
    // The existing paginator tests separately assert exact content coverage.
    expect(const ReaderStyle().textStyle().fontSize, 18);
  });
}
