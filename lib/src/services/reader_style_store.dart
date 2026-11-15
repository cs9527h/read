import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout choices are independent of pagination indices. A book's stored
/// UTF-16 character anchor must survive every change to these values.
@immutable
class ReaderStyle {
  const ReaderStyle({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.letterSpacing = 0,
    this.fontWeightIndex = 3,
    this.textAlignIndex = 0,
    this.horizontalMargin = 24,
    this.verticalMargin = 16,
    this.backgroundIndex = 0,
    this.showHeader = false,
    this.showFooter = true,
    this.tapZone = 0.28,
    this.turnDurationMs = 150,
    this.indentCharacters = 0,
    this.paragraphBlankLines = 0,
    this.fontFamily = '',
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  /// FontWeight.values index: 0 = w100, 3 = w400, 8 = w900.
  final int fontWeightIndex;
  /// 0 = start, 1 = justified, 2 = centered, 3 = end.
  final int textAlignIndex;
  final double horizontalMargin;
  final double verticalMargin;
  final int backgroundIndex;
  final bool showHeader;
  final bool showFooter;
  final double tapZone;
  final int turnDurationMs;
  /// Visual first-line fullwidth spaces, source text and anchors are unchanged.
  final int indentCharacters;
  /// Optional visual blank lines inserted after a source newline.
  final int paragraphBlankLines;
  /// Empty selects the system font. Other values reference app-owned fonts.
  final String fontFamily;

  FontWeight get fontWeight => FontWeight.values[fontWeightIndex];
  TextAlign get textAlign => switch (textAlignIndex) {
    1 => TextAlign.justify,
    2 => TextAlign.center,
    3 => TextAlign.right,
    _ => TextAlign.left,
  };

  TextStyle textStyle({Color? color}) => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
        fontWeight: fontWeight,
        color: color,
        fontFamily: fontFamily.isEmpty ? null : fontFamily,
      );

  ReaderStyle copyWith({
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    int? fontWeightIndex,
    int? textAlignIndex,
    double? horizontalMargin,
    double? verticalMargin,
    int? backgroundIndex,
    bool? showHeader,
    bool? showFooter,
    double? tapZone,
    int? turnDurationMs,
    int? indentCharacters,
    int? paragraphBlankLines,
    String? fontFamily,
  }) =>
      ReaderStyle(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        fontWeightIndex: fontWeightIndex ?? this.fontWeightIndex,
        textAlignIndex: textAlignIndex ?? this.textAlignIndex,
        horizontalMargin: horizontalMargin ?? this.horizontalMargin,
        verticalMargin: verticalMargin ?? this.verticalMargin,
        backgroundIndex: backgroundIndex ?? this.backgroundIndex,
        showHeader: showHeader ?? this.showHeader,
        showFooter: showFooter ?? this.showFooter,
        tapZone: tapZone ?? this.tapZone,
        turnDurationMs: turnDurationMs ?? this.turnDurationMs,
        indentCharacters: indentCharacters ?? this.indentCharacters,
        paragraphBlankLines: paragraphBlankLines ?? this.paragraphBlankLines,
        fontFamily: fontFamily ?? this.fontFamily,
      );

  Map<String, Object> toJson() => <String, Object>{
        'version': 1,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'fontWeightIndex': fontWeightIndex,
        'textAlignIndex': textAlignIndex,
        'horizontalMargin': horizontalMargin,
        'verticalMargin': verticalMargin,
        'backgroundIndex': backgroundIndex,
        'showHeader': showHeader,
        'showFooter': showFooter,
        'tapZone': tapZone,
        'turnDurationMs': turnDurationMs,
        'indentCharacters': indentCharacters,
        'paragraphBlankLines': paragraphBlankLines,
        'fontFamily': fontFamily,
      };

  static ReaderStyle fromJson(Object? source, {ReaderStyle fallback = const ReaderStyle()}) {
    if (source is! Map) return fallback;
    final m = source;
    double number(String key, double initial, double min, double max) {
      final v = m[key];
      if (v is! num || !v.isFinite) return initial;
      return v.toDouble().clamp(min, max).toDouble();
    }
    int integer(String key, int initial, int min, int max) {
      final v = m[key];
      if (v is! num || !v.isFinite) return initial;
      return v.toInt().clamp(min, max).toInt();
    }
    bool boolean(String key, bool initial) => m[key] is bool ? m[key] as bool : initial;
    return ReaderStyle(
      fontSize: number('fontSize', fallback.fontSize, 12, 42),
      lineHeight: number('lineHeight', fallback.lineHeight, 1, 2.8),
      letterSpacing: number('letterSpacing', fallback.letterSpacing, -1, 5),
      fontWeightIndex: integer('fontWeightIndex', fallback.fontWeightIndex, 0, 8),
      textAlignIndex: integer('textAlignIndex', fallback.textAlignIndex, 0, 3),
      horizontalMargin: number('horizontalMargin', fallback.horizontalMargin, 8, 80),
      verticalMargin: number('verticalMargin', fallback.verticalMargin, 4, 80),
      backgroundIndex: integer('backgroundIndex', fallback.backgroundIndex, 0, 5),
      showHeader: boolean('showHeader', fallback.showHeader),
      showFooter: boolean('showFooter', fallback.showFooter),
      tapZone: number('tapZone', fallback.tapZone, 0.15, 0.42),
      turnDurationMs: integer('turnDurationMs', fallback.turnDurationMs, 0, 400),
      indentCharacters: integer('indentCharacters', fallback.indentCharacters, 0, 4),
      paragraphBlankLines: integer('paragraphBlankLines', fallback.paragraphBlankLines, 0, 2),
      fontFamily: m['fontFamily'] is String && (m['fontFamily'] as String).length <= 96
          ? m['fontFamily'] as String : fallback.fontFamily,
    );
  }

  /// Only geometry, not colors or tap settings, affects measured page slices.
  String get layoutKey => [
        fontSize, lineHeight, letterSpacing, fontWeightIndex,
        textAlignIndex, horizontalMargin, verticalMargin, showFooter,
        indentCharacters, paragraphBlankLines, fontFamily,
      ].join('/');
}

class ReaderStyleSelection {
  const ReaderStyleSelection(this.style, this.bookSpecific);
  final ReaderStyle style;
  final bool bookSpecific;
}

/// Global defaults + optional per-book override. The old 3 settings remain
/// readable for migration; this does not touch book content or WebDAV anchors.
class ReaderStyleStore {
  ReaderStyleStore._();
  static final ReaderStyleStore instance = ReaderStyleStore._();
  static const String _globalKey = 'read.reader.style.global.v1';
  static String _bookKey(String id) =>
      'read.reader.style.book.v1.' + Uri.encodeComponent(id);

  Future<void> _writes = Future<void>.value();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  ReaderStyle _decode(String? raw, ReaderStyle fallback) {
    if (raw == null) return fallback;
    try {
      return ReaderStyle.fromJson(jsonDecode(raw), fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<ReaderStyle> loadGlobal(ReaderStyle legacy) async {
    final p = await _prefs();
    return _decode(p.getString(_globalKey), legacy);
  }

  Future<ReaderStyleSelection> load(String bookId, ReaderStyle legacy) async {
    final p = await _prefs();
    final global = _decode(p.getString(_globalKey), legacy);
    final rawBook = p.getString(_bookKey(bookId));
    return ReaderStyleSelection(_decode(rawBook, global), rawBook != null);
  }

  /// Sequential writes prevent older rapid slider events overwriting newer
  /// values, including when a prior SharedPreferences call failed.
  Future<void> _enqueue(Future<void> Function(SharedPreferences) action) {
    final task = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await _prefs();
      await action(prefs);
    });
    _writes = task;
    return task;
  }

  Future<void> saveGlobal(ReaderStyle style) =>
      _enqueue((prefs) async {
        if (!await prefs.setString(_globalKey, jsonEncode(style.toJson()))) {
          throw StateError('无法保存全局阅读样式');
        }
      });

  Future<void> saveForBook(String bookId, ReaderStyle style) =>
      _enqueue((prefs) async {
        if (!await prefs.setString(_bookKey(bookId), jsonEncode(style.toJson()))) {
          throw StateError('无法保存本书阅读样式');
        }
      });

  Future<void> clearForBook(String bookId) =>
      _enqueue((prefs) async {
        if (!await prefs.remove(_bookKey(bookId))) {
          throw StateError('无法清除本书阅读样式');
        }
      });
}
