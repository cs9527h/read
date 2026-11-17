import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:read/src/reader/settings/reader_settings.dart';

/// 把章节原文转换成“正文排版串”，同时记录每个显示字符对应的原文字符位置。
///
/// 为什么要这一步：
/// - 首行缩进、段距、空行折叠都会改变实际排版高度，必须进入真实测量；
/// - 但阅读进度、书签、同步都按原文偏移保存，所以显示串必须能映射回原文。
class DisplayChapter {
  const DisplayChapter(this.text, this.map, this.sourceLength);

  final String text;

  /// map[i] = 显示串第 i 个字符对应的章节内原文偏移（0..sourceLength）。
  final List<int> map;
  final int sourceLength;

  int sourceOffset(int displayIndex) {
    if (map.isEmpty) return 0;
    // 标题首行被跳过时，正文第一个显示字符对应 map[0]（标题之后），
    // 而不是 0（标题本身），否则进度锚点会指回已由标题块绘制的行。
    if (displayIndex <= 0) return map[0];
    if (displayIndex >= map.length) return sourceLength;
    return map[displayIndex];
  }

  /// 反向：找到包含原文偏移 [offset] 的第一个显示位置。
  int displayOffset(int offset) {
    // The source mapping is monotonically nondecreasing. A binary lower
    // bound keeps seek/reflow responsive even for very long TXT chapters.
    int low = 0;
    int high = map.length;
    while (low < high) {
      final int middle = low + ((high - low) >> 1);
      if (map[middle] >= offset) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low;
  }
}

class EnginePage {
  const EnginePage({
    required this.displayStart,
    required this.displayEnd,
    required this.sourceStart,
    required this.sourceEnd,
  });

  final int displayStart;
  final int displayEnd;
  final int sourceStart;
  final int sourceEnd;

  String textOf(DisplayChapter chapter) =>
      chapter.text.substring(displayStart, displayEnd);
}

class PaginatedChapter {
  const PaginatedChapter({
    required this.display,
    required this.pages,
    required this.titleHeight,
    required this.showTitle,
  });

  final DisplayChapter display;
  final List<EnginePage> pages;
  final double titleHeight;
  final bool showTitle;

  int pageForSourceOffset(int chapterRelativeOffset) {
    if (pages.isEmpty) return 0;
    int low = 0;
    int high = pages.length;
    while (low < high) {
      final int middle = low + ((high - low) >> 1);
      if (chapterRelativeOffset < pages[middle].sourceEnd) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low < pages.length ? low : pages.length - 1;
  }
}

/// 阅读引擎：负责正文排版串、真实文本测量和分页。
class ReaderEngine {
  const ReaderEngine._();

  /// 把「第一章 风起」拆成序号与标题，供“序号与标题分行显示”使用。
  static List<String> splitChapterTitle(String title) {
    final RegExp regex = RegExp(
      r'^((?:第[0-9零一二三四五六七八九十百千万〇两]+[章回卷节篇集部册])|(?:Chapter\s+[0-9]+))(.+)$',
    );
    final Match? match = regex.firstMatch(title.trim());
    if (match == null) return <String>[title];
    final String number = match.group(1)!.trim();
    final String rest = match.group(2)!.trim();
    if (rest.isEmpty) return <String>[title];
    return <String>[number, rest];
  }

  static TextStyle bodyStyle(ReaderSettings s, {Color? color, double textScale = 1.0}) {
    return TextStyle(
      fontFamily: s.fontFamily,
      fontSize: s.fontSize * textScale,
      fontWeight: FontWeight.values[(s.fontWeight ~/ 100) - 1],
      height: s.lineHeight,
      letterSpacing: s.letterSpacing,
      wordSpacing: s.wordSpacing,
      color: color,
    );
  }

  static TextAlign textAlignOf(String align) => switch (align) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => TextAlign.left,
      };

  /// 段距换算为“插入几个空行”。
  ///
  /// 渲染层是单一文本流，空行高度只能是整行，所以 px 无法精确兑现。
  /// 优先使用行数设置；只有旧配置（仅存 px）才做一次折算，
  /// 且不再用 `max(1, …)` —— 那会把 1px 也放大成一整行。
  static int _spacingLines(double lines, double legacyPx, double linePx) {
    if (lines > 0) return lines.round().clamp(0, 3);
    if (legacyPx <= 0) return 0;
    return (legacyPx / linePx).round().clamp(0, 3);
  }

  /// 章节标题块高度（含上下间距）。标题模板为 none 时返回 0。
  /// 分章器在「无法识别章节」时用「全文」作哨兵标题，不应当成真正的
  /// 章节标题画成巨大标题，因此这里对「全文」返回 0。
  static double titleBlockHeight(
    ReaderSettings s,
    String title,
    double width,
    double textScale,
  ) {
    if (s.titleTemplate == 'none' ||
        title.trim().isEmpty ||
        title.trim() == '全文') {
      return 0;
    }
    final TextStyle style = TextStyle(
      fontFamily: s.titleFontFamily ?? s.fontFamily,
      fontSize: s.titleFontSize * textScale,
      fontWeight: FontWeight.values[(s.titleWeight ~/ 100) - 1],
      height: 1.3,
    );
    final List<String> parts = s.titleNumberNewLine
        ? splitChapterTitle(title)
        : <String>[title];
    final String layoutText = parts.length > 1 ? parts.join('\n') : title;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: layoutText, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlignOf(s.titleAlign),
    )..layout(maxWidth: width);
    double height = painter.height;
    painter.dispose();
    // divider 模板在标题下方额外绘制 6px 间距 + 0.6px 细线；分页高度预算
    // 必须包含它，否则章首 Column 会溢出（文字被裁掉）。
    if (s.titleTemplate == 'divider') height += 7;
    return height + s.titleGapTop + s.titleGapBottom + s.chapterStartBlank;
  }

  static DisplayChapter buildDisplay(
    String source,
    ReaderSettings s,
    double textScale, {
    String title = '',
  }) {
    // 章节标题已由页首标题块绘制，正文不再重复显示同一标题首行，
    // 但必须把锚点映射指向标题之后，保证进度/书签仍定位到正文。
    int contentStart = 0;
    final String trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      int lead = 0;
      while (lead < source.length) {
        final int unit = source.codeUnitAt(lead);
        if (unit == 0xFEFF ||
            unit == 0x20 ||
            unit == 0x09 ||
            unit == 0x0A ||
            unit == 0x0D) {
          lead++;
        } else {
          break;
        }
      }
      if (lead < source.length && source.startsWith(trimmedTitle, lead)) {
        final int afterTitle = lead + trimmedTitle.length;
        // 标题必须是一整行：其后只能是换行、行尾空白或文件末尾。
        // 仅凭 startsWith 会把「前言」误判成「前言正文」的标题前缀。
        final int unit =
            afterTitle < source.length ? source.codeUnitAt(afterTitle) : -1;
        final bool isLineEnd = afterTitle >= source.length ||
            unit == 0x0A ||
            unit == 0x0D ||
            unit == 0x20 ||
            unit == 0x09 ||
            unit == 0x3000;
        if (isLineEnd) {
          contentStart = afterTitle;
          while (contentStart < source.length) {
            final int u = source.codeUnitAt(contentStart);
            if (u == 0x20 || u == 0x09 || u == 0x0A || u == 0x0D || u == 0x3000) {
              contentStart++;
            } else {
              break;
            }
          }
        }
      }
    }

    final double linePx = math.max(1.0, s.fontSize * s.lineHeight * textScale);
    final int blankAfter =
        _spacingLines(s.paragraphSpacingLines, s.paragraphSpacingAfter, linePx);
    final int blankBefore =
        _spacingLines(0, s.paragraphSpacingBefore, linePx);

    // 段落按原文切分，保留原始偏移，保证书签/进度与原文一致。
    // 从 contentStart 起切，标题首行不再进入正文排版串。
    final List<List<int>> paragraphs = <List<int>>[]; // [start, end]
    int paragraphStart = contentStart;
    for (int i = contentStart; i <= source.length; i++) {
      final bool atEnd = i == source.length;
      final int unit = atEnd ? 0x0A : source.codeUnitAt(i);
      if (unit == 0x0A || unit == 0x0D) {
        int end = i;
        if (unit == 0x0D && i + 1 < source.length && source.codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
        paragraphs.add(<int>[paragraphStart, end]);
        paragraphStart = i + 1;
      }
    }
    if (paragraphStart <= source.length &&
        (paragraphs.isEmpty || paragraphs.last[1] < paragraphStart)) {
      paragraphs.add(<int>[paragraphStart, source.length]);
    }

    final StringBuffer out = StringBuffer();
    final List<int> map = <int>[];
    bool firstContent = true;
    int blankRun = 0;

    void append(String text, int sourceOffset, {bool advance = true}) {
      out.write(text);
      for (int i = 0; i < text.length; i++) {
        map.add(advance ? sourceOffset + i : sourceOffset);
      }
    }

    void blankLines(int count, int sourceOffset) {
      for (int i = 0; i < count; i++) {
        append('\n', sourceOffset, advance: false);
      }
    }

    for (final List<int> range in paragraphs) {
      final int start = range[0];
      final int end = range[1];
      final String text = source.substring(start, end);
      final bool blank = text.trim().isEmpty;
      if (blank) {
        if (s.preserveBlankLines && !s.ignoreExtraBlankLines) {
          blankRun++;
          if (blankRun <= 2) append('\n', start, advance: false);
        }
        continue;
      }
      if (!firstContent && blankBefore > 0) blankLines(blankBefore, start);
      if (s.indentMode != 'none') {
        final int units = math.max(1, s.indentChars.round());
        // fixed = 半角空格（视觉约 0.5 字宽/个）；em = 全角空格（1 字宽/个）。
        append(
          s.indentMode == 'em' ? '\u3000' * units : ' ' * units,
          start,
          advance: false,
        );
      }
      append(text, start);
      append('\n', end, advance: false);
      if (blankAfter > 0) blankLines(blankAfter, end);
      firstContent = false;
      blankRun = 0;
    }

    // 去掉末尾多余换行，避免最后一页整页空白。
    while (map.isNotEmpty && map.length == out.length &&
        out.toString().endsWith('\n')) {
      final String current = out.toString();
      out.clear();
      out.write(current.substring(0, current.length - 1));
      map.removeLast();
    }

    return DisplayChapter(out.toString(), map, source.length);
  }

  /// 真实分页：按实际字体、行高、宽度、高度测量，不按固定字数切页。
  static PaginatedChapter paginate({
    required String chapterText,
    required String chapterTitle,
    required ReaderSettings settings,
    required double width,
    required double height,
    required double textScale,
  }) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw ArgumentError('分页区域必须有正的宽高');
    }
    final DisplayChapter display =
        buildDisplay(chapterText, settings, textScale, title: chapterTitle);
    final double titleHeight =
        titleBlockHeight(settings, chapterTitle, width, textScale);
    final bool showTitle = titleHeight > 0;

    if (display.text.isEmpty) {
      return PaginatedChapter(
        display: display,
        pages: const <EnginePage>[EnginePage(displayStart: 0, displayEnd: 0, sourceStart: 0, sourceEnd: 0)],
        titleHeight: titleHeight,
        showTitle: showTitle,
      );
    }

    final TextStyle style = bodyStyle(settings, textScale: textScale);
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: textAlignOf(settings.align),
    );
    bool fits(int start, int count, double maxHeight) {
      final int end = start + count;
      int safe = count;
      if (safe > 0 &&
          end < display.text.length &&
          _isHighSurrogate(display.text.codeUnitAt(end - 1)) &&
          _isLowSurrogate(display.text.codeUnitAt(end))) {
        safe--;
      }
      if (safe <= 0) return false;
      painter.text = TextSpan(text: display.text.substring(start, start + safe), style: style);
      painter.layout(maxWidth: width);
      return painter.height <= maxHeight + 0.5;
    }

    final List<EnginePage> pages = <EnginePage>[];
    int start = 0;
    while (start < display.text.length) {
      final double pageHeight = (pages.isEmpty && showTitle)
          ? math.max(1, height - titleHeight)
          : height;
      // Search around the expected page length. Measuring half of a
      // multi-megabyte chapter for *every* page made long TXT books slow.
      final int remaining = display.text.length - start;
      int low = 0;
      int probe = math.min(256, remaining);
      int high = remaining;
      while (true) {
        if (fits(start, probe, pageHeight)) {
          low = probe;
          if (probe == remaining) {
            high = probe;
            break;
          }
          probe = math.min(remaining, probe * 2);
        } else {
          high = probe - 1;
          break;
        }
      }
      while (low < high) {
        final int mid = (low + high + 1) ~/ 2;
        if (fits(start, mid, pageHeight)) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      int end = start + math.max(low, 1);
      if (end < display.text.length &&
          _isHighSurrogate(display.text.codeUnitAt(end - 1)) &&
          _isLowSurrogate(display.text.codeUnitAt(end))) {
        end--;
        if (end == start) end = math.min(display.text.length, start + 2);
      }
      final int sourceStart = display.sourceOffset(start);
      final int sourceEnd = display.sourceOffset(end);
      pages.add(EnginePage(
        displayStart: start,
        displayEnd: end,
        sourceStart: sourceStart,
        sourceEnd: math.max(sourceStart, sourceEnd),
      ));
      start = end;
    }
    painter.dispose();
    return PaginatedChapter(
      display: display,
      pages: pages,
      titleHeight: titleHeight,
      showTitle: showTitle,
    );
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}
