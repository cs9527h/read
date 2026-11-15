import 'dart:async';

import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/chapter_rule_store.dart';
import 'package:read/src/services/book_search.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/paginator.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reader_style_store.dart';
import 'package:read/src/services/reader_text_formatter.dart';
import 'package:read/src/services/reader_font_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/theme.dart';

/// 阅读页：按章节分页，支持目录跳转、字号/行距/背景调整，进度自动保存。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  late List<Chapter> _chapters;
  ChapterRule _chapterRule = const ChapterRule.automatic();
  late int _chapterIndex;
  late final int _openingChapterIndex;
  late final int _openingCharOffset;
  int _pageIndex = 0;

  List<PageSlice> _pageSlices = const <PageSlice>[];
  String? _measureKey;
  PageController? _controller;
  List<int> _bookmarks = const <int>[];

  final Stopwatch _activeReading = Stopwatch();
  late int _lastRecordedChar;
  int _accountedReadingSeconds = 0;

  ReaderStyle _style = const ReaderStyle();
  bool _bookSpecificStyle = false;
  bool _showChrome = false;
  bool _styleLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activeReading.start();
    _chapters = splitChapters(widget.book.content);
    _chapterIndex = widget.book.chapterIndex.value;
    _openingChapterIndex = widget.book.chapterIndex.value;
    _openingCharOffset = widget.book.charOffset.value;
    if (_chapterIndex < 0 || _chapterIndex >= _chapters.length) {
      _chapterIndex = 0;
    }
    _pageIndex = widget.book.pageIndex.value;
    _lastRecordedChar = _absoluteChar(_openingChapterIndex, _openingCharOffset);
    widget.book.chapterCount = _chapters.length;
    final LibraryStore store = LibraryStore.instance;
    _style = ReaderStyle(
      fontSize: store.fontSize,
      lineHeight: store.lineHeight,
      backgroundIndex: kEink ? 0 : store.backgroundIndex,
    );
    unawaited(_loadStyle());
    _loadBookmarks();
    _loadChapterRule();
  }

  @override
  void dispose() {
    _activeReading.stop();
    WidgetsBinding.instance.removeObserver(this);
    _recordSession();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background time should never inflate reading statistics.
    if (state == AppLifecycleState.resumed) {
      _activeReading.start();
    } else {
      _activeReading.stop();
      _recordSession();
    }
  }

  int _absoluteChar(int chapterIndex, int charOffset) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return 0;
    return _chapters[chapterIndex].start + (charOffset < 0 ? 0 : charOffset);
  }

  /// Checkpoint on background as well as close. A killed background process
  /// should not lose an entire session, and a later dispose must not double
  /// count seconds or pages already checkpointed.
  void _recordSession() {
    final elapsed = _activeReading.elapsed.inSeconds;
    final deltaSeconds = elapsed - _accountedReadingSeconds;
    if (deltaSeconds < 10) return;
    final currentChar =
        _absoluteChar(_chapterIndex, widget.book.charOffset.value);
    final chars = currentChar > _lastRecordedChar
        ? currentChar - _lastRecordedChar
        : 0;
    _accountedReadingSeconds = elapsed;
    _lastRecordedChar = currentChar;
    ReadingStatsStore.instance.record(
      bookId: widget.book.id,
      seconds: deltaSeconds,
      chars: chars,
    );
    LibraryStore.instance.noteChapterCount(widget.book, _chapters.length);
  }

  _Palette get _palette {
    if (kEink) return const _Palette(Colors.white, Colors.black);
    switch (_style.backgroundIndex) {
      case 1:
        return const _Palette(Color(0xFFF5EFE1), Color(0xFF41382B));
      case 2:
        return const _Palette(Color(0xFF121212), Color(0xFFDBDBDB));
      case 3:
        return const _Palette(Color(0xFFE9E9E9), Color(0xFF252525));
      case 4:
        return const _Palette(Color(0xFFEAF0E5), Color(0xFF2D3A30));
      case 5:
        return const _Palette(Colors.black, Colors.white);
      default:
        return const _Palette(Color(0xFFFCFCF8), Color(0xFF24332F));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_styleLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final _Palette palette = _palette;
    final Chapter chapter = _chapters[_chapterIndex];
    final String chapterText = chapter.slice(widget.book.content);
    final int bookmarkOffset = chapter.start +
        (_pageSlices.isNotEmpty && _pageIndex < _pageSlices.length
            ? _pageSlices[_pageIndex].start
            : widget.book.charOffset.value.clamp(0, chapter.length));
    final bool bookmarked = _bookmarks.contains(bookmarkOffset);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: (_showChrome || _style.showHeader) ? AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.foreground,
        title: Text(
          widget.book.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.foreground,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: bookmarked ? '移除本页书签' : '添加本页书签',
            icon: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: palette.foreground,
            ),
            onPressed: _toggleCurrentBookmark,
          ),
          PopupMenuButton<String>(
            tooltip: '阅读工具',
            icon: Icon(Icons.more_vert_rounded, color: palette.foreground),
            onSelected: (value) {
              switch (value) {
                case 'search':
                  _searchInBook();
                case 'bookmarks':
                  _showBookmarks();
                case 'chapters':
                  _showChapters();
                case 'rules':
                  _showChapterRules();
                case 'settings':
                  _showSettings();
              }
            },
            itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'search',
                child: ListTile(
                  leading: Icon(Icons.search_rounded),
                  title: Text('书内搜索'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'chapters',
                child: ListTile(
                  leading: Icon(Icons.list_rounded),
                  title: Text('章节目录'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'bookmarks',
                child: ListTile(
                  leading: Icon(Icons.collections_bookmark_outlined),
                  title: Text('我的书签'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'rules',
                child: ListTile(
                  leading: Icon(Icons.tune_rounded),
                  title: Text('分章规则'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.text_fields_rounded),
                  title: Text('阅读设置'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ) : null,
      bottomNavigationBar: _showChrome ? SafeArea(
        top: false,
        child: Container(
          color: palette.background,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: '上一页',
                onPressed: () => _turnPage(-1),
                icon: Icon(Icons.chevron_left_rounded, color: palette.foreground),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: (_pageSlices.length - 1).clamp(1, 1000000).toDouble(),
                  value: _pageIndex.clamp(0, (_pageSlices.length - 1).clamp(1, 1000000)).toDouble(),
                  onChanged: _pageSlices.length <= 1 ? null : (value) {
                    if (_controller?.hasClients ?? false) {
                      _controller!.jumpToPage(value.round());
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: '下一页',
                onPressed: () => _turnPage(1),
                icon: Icon(Icons.chevron_right_rounded, color: palette.foreground),
              ),
              IconButton(
                tooltip: '目录',
                onPressed: _showChapters,
                icon: Icon(Icons.list_rounded, color: palette.foreground),
              ),
              IconButton(
                tooltip: '排版设置',
                onPressed: _showSettings,
                icon: Icon(Icons.tune_rounded, color: palette.foreground),
              ),
            ],
          ),
        ),
      ) : null,
      body: SafeArea(child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _maybeMeasure(constraints.biggest, chapter);
          if (_pageSlices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    final width = constraints.maxWidth;
                    if (width <= 0) return;
                    if (details.localPosition.dx < width * _style.tapZone) {
                      _turnPage(-1);
                    } else if (details.localPosition.dx > width * (1 - _style.tapZone)) {
                      _turnPage(1);
                    } else {
                      setState(() => _showChrome = !_showChrome);
                    }
                  },
                  child: PageView.builder(
                  controller: _controller,
                  itemCount: _pageSlices.length,
                  onPageChanged: (int index) {
                    _pageIndex = index;
                    widget.book.chapterIndex.value = _chapterIndex;
                    widget.book.pageIndex.value = index;
                    if (index < _pageSlices.length) {
                      widget.book.charOffset.value = _pageSlices[index].start;
                    }
                    _persistProgress();
                    setState(() {});
                  },
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _style.horizontalMargin,
                      vertical: _style.verticalMargin,
                    ),
                    child: Text(
                      ReaderTextFormatter.format(chapterText,
                          _pageSlices[index].start, _pageSlices[index].end, _style),
                      textAlign: _style.textAlign,
                      style: _style.textStyle(color: palette.foreground),
                    ),
                  ),
                ),
                ),
              ),
              if (_style.showFooter)
                SizedBox(
                  height: 38,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.foreground.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          (_pageIndex + 1).toString() + ' / ' +
                              _pageSlices.length.toString() + ' · ' +
                              (widget.book.content.isEmpty ? '0.0' :
                                (_absoluteReadingOffset() * 100 /
                                    widget.book.content.length).clamp(0, 100).toStringAsFixed(1)) + '%',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.foreground.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      )),
    );
  }

  void _maybeMeasure(Size size, Chapter chapter) {
    // The page renderer and measurement must use identical text geometry.
    // System text scaling also changes page breaks on accessibility devices.
    final scaler = MediaQuery.textScalerOf(context);
    final String key = size.toString() + '/' + _style.layoutKey +
        '/' + scaler.scale(_style.fontSize).toString() + '/' + _chapterIndex.toString();
    if (key == _measureKey) return;
    _measureKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _measureKey != key) return;
      final double width = size.width - _style.horizontalMargin * 2;
      final double height = size.height - _style.verticalMargin * 2 -
          (_style.showFooter ? 38 : 0);
      if (width <= 0 || height <= 0) return;
      final String chapterText = chapter.slice(widget.book.content);
      final List<PageSlice> slices = paginateSlices(
        chapterText,
        _style.textStyle(),
        width,
        height,
        textScaler: scaler,
        formatPage: (text, start, end) =>
            ReaderTextFormatter.format(text, start, end, _style),
      );
      // An exact source range is more reliable than indexOf(pageText), which
      // becomes ambiguous when the same paragraph or whitespace repeats.
      int targetPage = _pageIndex;
      final int savedOffset = widget.book.charOffset.value;
      if (savedOffset >= 0) {
        targetPage = 0;
        for (int i = 0; i < slices.length; i++) {
          if (slices[i].start > savedOffset) break;
          targetPage = i;
        }
      }
      // A rapid chapter change, font change, or rotation can supersede
      // this layout calculation. Never apply stale page slices to the new
      // chapter, or the stored character anchor may jump unexpectedly.
      if (!mounted || _measureKey != key ||
          !identical(_chapters[_chapterIndex], chapter)) return;
      final oldController = _controller;
      setState(() {
        _pageSlices = slices;
        _pageIndex = targetPage.clamp(0, slices.length - 1);
        _controller = PageController(initialPage: _pageIndex);
        widget.book.chapterIndex.value = _chapterIndex;
        widget.book.pageIndex.value = _pageIndex;
        widget.book.charOffset.value = slices[_pageIndex].start;
      });
      // Dispose the detached controller after the new PageView is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController?.dispose();
      });
      _persistProgress();
    });
  }

  bool _progressErrorShown = false;

  Future<void> _persistProgress() async {
    try {
      await LibraryStore.instance.saveProgress(widget.book);
      _progressErrorShown = false;
    } catch (_) {
      if (!mounted || _progressErrorShown) return;
      _progressErrorShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('阅读位置保存失败，请确认设备存储空间后重试'),
        ),
      );
    }
  }

  /// Unlike PageView, this navigates past chapter edges.
  void _turnPage(int direction) {
    if (direction == 0 || _pageSlices.isEmpty || _controller == null) return;
    final target = _pageIndex + direction;
    if (target >= 0 && target < _pageSlices.length) {
      if (kEink || _style.turnDurationMs == 0) {
        _controller!.jumpToPage(target);
      } else {
        _controller!.animateToPage(
          target,
          duration: Duration(milliseconds: _style.turnDurationMs),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    final nextChapter = _chapterIndex + direction;
    if (nextChapter < 0 || nextChapter >= _chapters.length) return;
    setState(() {
      _chapterIndex = nextChapter;
      _pageIndex = 0;
      _pageSlices = const <PageSlice>[];
      _measureKey = null;
      widget.book.chapterIndex.value = nextChapter;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value = direction < 0
          ? _chapters[nextChapter].length
          : 0;
    });
    _persistProgress();
  }

  int _absoluteReadingOffset() {
    final Chapter chapter = _chapters[_chapterIndex];
    final int local = (_pageSlices.isNotEmpty &&
            _pageIndex >= 0 &&
            _pageIndex < _pageSlices.length)
        ? _pageSlices[_pageIndex].start
        : widget.book.charOffset.value.clamp(0, chapter.length);
    return chapter.start + local;
  }

  void _applyChapterRule(ChapterRule rule, {int? absoluteOverride}) {
    final int absolute = absoluteOverride ?? _absoluteReadingOffset();
    final List<Chapter> next =
        splitChapters(widget.book.content, rule: rule);
    int index = next.length - 1;
    for (int i = 0; i < next.length; i++) {
      if (absolute < next[i].end) {
        index = i;
        break;
      }
    }
    final Chapter selected = next[index];
    setState(() {
      _chapterRule = rule;
      _chapters = next;
      _chapterIndex = index;
      _pageIndex = 0;
      _pageSlices = const <PageSlice>[];
      _measureKey = null;
      widget.book.chapterIndex.value = index;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value =
          (absolute - selected.start).clamp(0, selected.length);
    });
    _persistProgress();
  }

  Future<void> _loadChapterRule() async {
    final rule = await ChapterRuleStore.load(widget.book.id);
    if (!mounted || rule.mode == ChapterRuleMode.automatic) return;
    try {
      // Saved chapter-relative progress belongs to the saved rule, not to
      // the automatic rule temporarily shown during initialization.
      final restoredChapters =
          splitChapters(widget.book.content, rule: rule);
      final savedChapter = _openingChapterIndex
          .clamp(0, restoredChapters.length - 1);
      final restored = restoredChapters[savedChapter];
      final int savedLocal = _openingCharOffset;
      final int absolute = restored.start +
          (savedLocal < 0 ? 0 : savedLocal.clamp(0, restored.length));
      _applyChapterRule(rule, absoluteOverride: absolute);
    } on FormatException {
      // Keep the original setting and original file untouched.
    }
  }

  Future<void> _showChapterRules() async {
    ChapterRuleMode mode = _chapterRule.mode;
    final controller = TextEditingController(text: _chapterRule.pattern);
    String? validationError;
    final ChapterRule? selected = await showModalBottomSheet<ChapterRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: !kEink,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('章节识别', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('仅改变目录，不修改电子书原文。'),
                RadioListTile<ChapterRuleMode>(
                  title: const Text('自动识别（推荐）'),
                  value: ChapterRuleMode.automatic,
                  groupValue: mode,
                  onChanged: (value) => setSheetState(() {
                    mode = value!;
                    validationError = null;
                  }),
                ),
                RadioListTile<ChapterRuleMode>(
                  title: const Text('整本作为一章'),
                  value: ChapterRuleMode.none,
                  groupValue: mode,
                  onChanged: (value) => setSheetState(() {
                    mode = value!;
                    validationError = null;
                  }),
                ),
                RadioListTile<ChapterRuleMode>(
                  title: const Text('自定义章节标题正则'),
                  value: ChapterRuleMode.custom,
                  groupValue: mode,
                  onChanged: (value) => setSheetState(() {
                    mode = value!;
                    validationError = null;
                  }),
                ),
                if (mode == ChapterRuleMode.custom) ...<Widget>[
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: '行首匹配规则',
                      hintText: r'^第[0-9]+章',
                      errorText: validationError,
                    ),
                    onChanged: (_) => setSheetState(() {
                      validationError = null;
                    }),
                  ),
                  const Text('仅支持简单的单行规则，暂不支持括号分组及分支。'),
                ],
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      final ChapterRule next;
                      if (mode == ChapterRuleMode.automatic) {
                        next = const ChapterRule.automatic();
                      } else if (mode == ChapterRuleMode.none) {
                        next = const ChapterRule.none();
                      } else {
                        try {
                          validateChapterPattern(controller.text.trim());
                        } on FormatException catch (e) {
                          setSheetState(() => validationError = e.message);
                          return;
                        }
                        next = ChapterRule.custom(controller.text.trim());
                      }
                      Navigator.pop(ctx, next);
                    },
                    child: const Text('应用'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The bottom sheet is closed before disposing the field controller.
    controller.dispose();
    if (!mounted || selected == null) return;
    try {
      // Validate against the actual book before saving; large numbers of
      // matches are rejected without changing the existing preference.
      splitChapters(widget.book.content, rule: selected);
      await ChapterRuleStore.save(widget.book.id, selected);
      if (!mounted) return;
      _applyChapterRule(selected);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分章设置保存失败，请重试')),
      );
    }
  }

  Future<void> _loadBookmarks() async {
    final saved = await BookmarkStore.load(widget.book.id);
    if (mounted) setState(() => _bookmarks = saved);
  }

  Future<void> _toggleCurrentBookmark() async {
    if (_pageSlices.isEmpty || _pageIndex >= _pageSlices.length) return;
    final int absolute = _chapters[_chapterIndex].start +
        _pageSlices[_pageIndex].start;
    try {
      final saved = await BookmarkStore.toggle(widget.book.id, absolute);
      if (!mounted) return;
      setState(() => _bookmarks = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved.contains(absolute) ? '已添加书签' : '已移除书签'),
        duration: const Duration(seconds: 1),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书签保存失败，请重试')),
      );
    }
  }

  Future<void> _showBookmarks() async {
    final int? position = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: !kEink,
      builder: (BuildContext ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.65,
          child: Column(
            children: <Widget>[
              const ListTile(
                title: Text('我的书签',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                subtitle: Text('按书籍中的位置排列'),
              ),
              Expanded(
                child: _bookmarks.isEmpty
                    ? const Center(child: Text('还没有书签，阅读时点右上角即可添加'))
                    : ListView.builder(
                        itemCount: _bookmarks.length,
                        itemBuilder: (BuildContext context, int index) {
                          final int offset = _bookmarks[index];
                          final String source = widget.book.content;
                          int begin = offset.clamp(0, source.length);
                          int end = (begin + 45).clamp(0, source.length);
                          // Do not split an emoji's UTF-16 surrogate pair.
                          if (begin > 0 && begin < source.length &&
                              source.codeUnitAt(begin) >= 0xDC00 &&
                              source.codeUnitAt(begin) <= 0xDFFF) {
                            begin++;
                          }
                          if (end > begin && end < source.length &&
                              source.codeUnitAt(end) >= 0xDC00 &&
                              source.codeUnitAt(end) <= 0xDFFF) {
                            end--;
                          }
                          final preview = source.substring(begin, end)
                              .replaceAll(RegExp(r'[\r\n]+'), ' ')
                              .trim();
                          return ListTile(
                            leading: const Icon(Icons.bookmark_rounded),
                            title: Text(preview.isEmpty ? '书签位置' : preview,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('位置 ${offset + 1}'),
                            onTap: () => Navigator.pop(ctx, offset),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || position == null) return;
    _jumpToAbsoluteOffset(position);
  }

  void _jumpToAbsoluteOffset(int absoluteOffset) {
    int chapterIndex = _chapters.length - 1;
    for (int i = 0; i < _chapters.length; i++) {
      if (absoluteOffset < _chapters[i].end) {
        chapterIndex = i;
        break;
      }
    }
    final chapter = _chapters[chapterIndex];
    setState(() {
      _chapterIndex = chapterIndex;
      _pageIndex = 0;
      _pageSlices = const <PageSlice>[];
      _measureKey = null;
      widget.book.chapterIndex.value = chapterIndex;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value =
          (absoluteOffset - chapter.start).clamp(0, chapter.length);
    });
    _persistProgress();
  }

  Future<void> _searchInBook() async {
    final BookSearchMatch? hit = await showSearch<BookSearchMatch?>(
      context: context,
      delegate: _BookSearchDelegate(widget.book.content, _chapters),
    );
    if (!mounted || hit == null) return;
    final Chapter target = _chapters[hit.chapterIndex];
    final int localOffset = hit.start - target.start;
    setState(() {
      _chapterIndex = hit.chapterIndex;
      _pageIndex = 0;
      widget.book.chapterIndex.value = hit.chapterIndex;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value = localOffset;
      _pageSlices = const <PageSlice>[];
      _measureKey = null;
    });
    await _persistProgress();
  }

  Future<void> _showChapters() async {
    final int? selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (BuildContext ctx, ScrollController scroll) => ListView.builder(
          controller: scroll,
          itemCount: _chapters.length,
          itemBuilder: (BuildContext c, int index) => ListTile(
            selected: index == _chapterIndex,
            title: Text(_chapters[index].title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(ctx, index),
          ),
        ),
      ),
    );
    if (selected != null && selected != _chapterIndex) {
      setState(() {
        _chapterIndex = selected;
        _pageIndex = 0;
        widget.book.chapterIndex.value = selected;
        widget.book.pageIndex.value = 0;
        widget.book.charOffset.value = 0;
        _pageSlices = const <PageSlice>[];
        _measureKey = null;
      });
      await _persistProgress();
    }
  }


  Future<void> _loadStyle() async {
    try {
      var selection = await ReaderStyleStore.instance.load(widget.book.id, _style);
      if (!mounted) return;
      if (selection.style.fontFamily.isNotEmpty) {
        final loaded = await ReaderFontStore.instance.load(selection.style.fontFamily);
        if (!mounted) return;
        if (!loaded) {
          // Missing font must not block a previously imported book.
          selection = ReaderStyleSelection(
            selection.style.copyWith(fontFamily: ''), selection.bookSpecific);
        }
      }
      setState(() {
        _style = kEink
            ? selection.style.copyWith(backgroundIndex: 0)
            : selection.style;
        _bookSpecificStyle = selection.bookSpecific;
        _styleLoaded = true;
        _measureKey = null;
      });
    } catch (_) {
      // Never strand the reader on a loading screen when a preference fails.
      if (mounted) setState(() => _styleLoaded = true);
    }
  }

  void _updateStyle(ReaderStyle next) {
    if (kEink) next = next.copyWith(backgroundIndex: 0, turnDurationMs: 0);
    final oldLayout = _style.layoutKey;
    setState(() {
      _style = next;
      if (oldLayout != next.layoutKey) {
        _pageSlices = const <PageSlice>[];
        _measureKey = null;
      }
    });
    final future = _bookSpecificStyle
        ? ReaderStyleStore.instance.saveForBook(widget.book.id, next)
        : ReaderStyleStore.instance.saveGlobal(next);
    unawaited(future.catchError((Object _) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('阅读样式保存失败，请检查设备空间')),
      );
    }));
  }

  Future<void> _setBookScope(bool enabled) async {
    if (enabled == _bookSpecificStyle) return;
    if (enabled) {
      await ReaderStyleStore.instance.saveForBook(widget.book.id, _style);
      if (mounted) setState(() => _bookSpecificStyle = true);
    } else {
      await ReaderStyleStore.instance.clearForBook(widget.book.id);
      final store = LibraryStore.instance;
      final global = await ReaderStyleStore.instance.loadGlobal(ReaderStyle(
        fontSize: store.fontSize,
        lineHeight: store.lineHeight,
        backgroundIndex: store.backgroundIndex,
      ));
      if (global.fontFamily.isNotEmpty) {
        await ReaderFontStore.instance.load(global.fontFamily);
      }
      if (!mounted) return;
      setState(() {
        _bookSpecificStyle = false;
        _style = kEink ? global.copyWith(backgroundIndex: 0) : global;
        _pageSlices = const <PageSlice>[];
        _measureKey = null;
      });
    }
  }

  Future<String?> _selectFont() async {
    try {
      final fonts = await ReaderFontStore.instance.list();
      if (!mounted) return null;
      return await showModalBottomSheet<String>(
        context: context,
        showDragHandle: !kEink,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(title: Text('阅读字体')),
              ListTile(
                leading: const Icon(Icons.text_fields_outlined),
                title: const Text('使用系统默认字体'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final font in fonts)
                ListTile(
                  title: Text(font.displayName),
                  trailing: _style.fontFamily == font.family
                      ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(ctx, font.family),
                ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const Text('导入字体文件'),
                subtitle: const Text('TTF / OTF，大小不超过 12MB'),
                onTap: () async {
                  try {
                    final imported = await ReaderFontStore.instance.importFromPicker();
                    if (!ctx.mounted || imported == null) return;
                    Navigator.pop(ctx, imported.family);
                  } catch (error) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('字体导入失败：$error')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取自定义字体，请检查存储权限')),
        );
      }
      return null;
    }
  }

  Widget _styleSlider(String label, double value, double min, double max,
      int divisions, ValueChanged<double> onChanged, {int digits = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(label + '  ' + value.toStringAsFixed(digits),
              style: const TextStyle(fontSize: 13)),
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          value: value.clamp(min, max),
          label: value.toStringAsFixed(digits),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: !kEink,
      builder: (BuildContext sheetContext) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter refresh) {
          void change(ReaderStyle next) {
            refresh(() => _updateStyle(next));
          }
          Widget section(String label) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
            child: Text(label, style: Theme.of(ctx).textTheme.titleMedium),
          );
          Widget option(String label, bool chosen, VoidCallback select) =>
            ChoiceChip(
              label: Text(label),
              selected: chosen,
              onSelected: (_) => refresh(select),
            );
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.80,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text('阅读排版',
                          style: Theme.of(ctx).textTheme.titleLarge)),
                      TextButton(
                        onPressed: () => change(const ReaderStyle()),
                        child: const Text('恢复默认'),
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('仅本书使用此排版'),
                    subtitle: Text(_bookSpecificStyle
                      ? '本书独立设置，不影响其他书籍'
                      : '使用全局设置，所有未单独配置的书籍共享'),
                    value: _bookSpecificStyle,
                    onChanged: (enabled) async {
                      try {
                        await _setBookScope(enabled);
                        if (ctx.mounted) refresh(() {});
                      } catch (_) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('排版范围更改失败')),
                        );
                      }
                    },
                  ),
                  section('文字'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.font_download_outlined),
                    title: Text(_style.fontFamily.isEmpty
                        ? '系统默认字体' : '已选择自定义字体'),
                    subtitle: const Text('支持导入本地 TTF / OTF 文件'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final chosen = await _selectFont();
                      if (!mounted || !ctx.mounted || chosen == null) return;
                      refresh(() => _updateStyle(
                        _style.copyWith(fontFamily: chosen)));
                    },
                  ),
                  _styleSlider('字号', _style.fontSize, 12, 42, 30,
                      (v) => change(_style.copyWith(fontSize: v)), digits: 0),
                  _styleSlider('行高', _style.lineHeight, 1, 2.8, 18,
                      (v) => change(_style.copyWith(lineHeight: v))),
                  _styleSlider('字间距', _style.letterSpacing, -1, 5, 24,
                      (v) => change(_style.copyWith(letterSpacing: v))),
                  _styleSlider('字体粗细', _style.fontWeightIndex.toDouble(), 0, 8, 8,
                      (v) => change(_style.copyWith(fontWeightIndex: v.round())),
                      digits: 0),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      option('左对齐', _style.textAlignIndex == 0,
                          () => _updateStyle(_style.copyWith(textAlignIndex: 0))),
                      option('两端对齐', _style.textAlignIndex == 1,
                          () => _updateStyle(_style.copyWith(textAlignIndex: 1))),
                      option('居中', _style.textAlignIndex == 2,
                          () => _updateStyle(_style.copyWith(textAlignIndex: 2))),
                      option('右对齐', _style.textAlignIndex == 3,
                          () => _updateStyle(_style.copyWith(textAlignIndex: 3))),
                    ],
                  ),
                  section('段落'),
                  _styleSlider('首行缩进（全角字符）', _style.indentCharacters.toDouble(),
                      0, 4, 4, (v) =>
                          change(_style.copyWith(indentCharacters: v.round())),
                      digits: 0),
                  _styleSlider('段落间距（额外空行）', _style.paragraphBlankLines.toDouble(),
                      0, 2, 2, (v) =>
                          change(_style.copyWith(paragraphBlankLines: v.round())),
                      digits: 0),
                  section('页面留白'),
                  _styleSlider('左右边距', _style.horizontalMargin, 8, 80, 36,
                      (v) => change(_style.copyWith(horizontalMargin: v)), digits: 0),
                  _styleSlider('上下边距', _style.verticalMargin, 4, 80, 38,
                      (v) => change(_style.copyWith(verticalMargin: v)), digits: 0),
                  if (!kEink) ...<Widget>[
                    section('阅读主题'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        for (int i = 0; i < 6; i++)
                          option(const <String>['纸白', '米黄', '夜间', '浅灰', '护眼绿', '纯黑'][i],
                              _style.backgroundIndex == i,
                              () => _updateStyle(_style.copyWith(backgroundIndex: i))),
                      ],
                    ),
                  ],
                  section('显示内容'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('固定显示顶部书名'),
                    value: _style.showHeader,
                    onChanged: (v) => change(_style.copyWith(showHeader: v)),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示章节、页数与全书百分比'),
                    value: _style.showFooter,
                    onChanged: (v) => change(_style.copyWith(showFooter: v)),
                  ),
                  section('翻页交互'),
                  _styleSlider('点击翻页区域比例', _style.tapZone, 0.15, 0.42, 27,
                      (v) => change(_style.copyWith(tapZone: v)), digits: 2),
                  if (!kEink)
                    _styleSlider('翻页动画（毫秒）', _style.turnDurationMs.toDouble(),
                        0, 400, 20,
                        (v) => change(_style.copyWith(turnDurationMs: v.round())),
                        digits: 0),
                  const SizedBox(height: 10),
                  const Text('点击屏幕中部可收起或呼出顶部工具栏；左右边缘点击翻页。'
                      '当前 EPUB 为文本提取模式，尚不支持完整 CSS 富文本还原。',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

class _Palette {
  const _Palette(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class _BookSearchDelegate extends SearchDelegate<BookSearchMatch?> {
  _BookSearchDelegate(this.content, this.chapters);

  final String content;
  final List<Chapter> chapters;

  @override
  String get searchFieldLabel => '搜索本书内容';

  @override
  List<Widget> buildActions(BuildContext context) => <Widget>[
    if (query.isNotEmpty)
      IconButton(
        tooltip: '清空',
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: '返回',
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  @override
  Widget buildResults(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('输入关键词搜索当前书籍'));
    }
    final matches = searchBookText(content, chapters, query);
    if (matches.isEmpty) {
      return const Center(child: Text('未找到匹配内容'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (BuildContext context, int index) {
        final match = matches[index];
        return ListTile(
          title: Text(
            chapters[match.chapterIndex].title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            match.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => close(context, match),
        );
      },
    );
  }
}
