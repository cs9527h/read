import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:read/src/services/reader_style_store.dart';
import 'package:read/src/services/paginator.dart';

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

  testWidgets('pagination respects actual accessibility text scaling', (tester) async {
    final content = List<String>.filled(240, '阅读器中文正文 ').join();
    const style = TextStyle(fontSize: 18, height: 1.6);
    final standard = paginateSlices(content, style, 240, 450);
    final scaled = paginateSlices(
      content,
      style,
      240,
      450,
      textScaler: const TextScaler.linear(1.4),
    );
    expect(standard.map((slice) => slice.textOf(content)).join(), content);
    expect(scaled.map((slice) => slice.textOf(content)).join(), content);
    expect(scaled.length, greaterThan(standard.length));
  });
  test('global and per-book settings persist separately', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = ReaderStyleStore.instance;
    await store.saveGlobal(const ReaderStyle(fontSize: 21, backgroundIndex: 3));
    final inherited = await store.load('book-one', const ReaderStyle());
    expect(inherited.bookSpecific, isFalse);
    expect(inherited.style.fontSize, 21);

    await store.saveForBook('book-one', const ReaderStyle(fontSize: 28));
    final custom = await store.load('book-one', const ReaderStyle());
    final other = await store.load('book-two', const ReaderStyle());
    expect(custom.bookSpecific, isTrue);
    expect(custom.style.fontSize, 28);
    expect(other.style.fontSize, 21);

    await store.clearForBook('book-one');
    final restored = await store.load('book-one', const ReaderStyle());
    expect(restored.bookSpecific, isFalse);
    expect(restored.style.fontSize, 21);
  });

}
