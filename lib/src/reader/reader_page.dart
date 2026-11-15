import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/chapter_rule_store.dart';
import 'package:read/src/services/book_search.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/paginator.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';

/// 阅读页：按章节分页，支持目录跳转、字号/行距/背景调整，进度自动保存。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
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

  double _fontSize = 18;
  double _lineHeight = 1.7;
  int _bgIndex = 0;

  @override
  void initState() {
    super.initState();
    _chapters = splitChapters(widget.book.content);
    _chapterIndex = widget.book.chapterIndex.value;
    _openingChapterIndex = widget.book.chapterIndex.value;
    _openingCharOffset = widget.book.charOffset.value;
    if (_chapterIndex < 0 || _chapterIndex >= _chapters.length) {
      _chapterIndex = 0;
    }
    _pageIndex = widget.book.pageIndex.value;
    final LibraryStore store = LibraryStore.instance;
    _fontSize = store.fontSize;
    _lineHeight = store.lineHeight;
    _bgIndex = kEink ? 0 : store.backgroundIndex;
    _loadBookmarks();
    _loadChapterRule();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  _Palette get _palette {
    if (kEink) return const _Palette(Colors.white, Colors.black);
    switch (_bgIndex) {
      case 1:
        return const _Palette(Color(0xFFF5EFE1), Color(0xFF41382B));
      case 2:
        return const _Palette(Color(0xFF121212), Color(0xFFBDBDBD));
      default:
        return const _Palette(Color(0xFFFCFCF8), Color(0xFF24332F));
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
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
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _maybeMeasure(constraints.biggest, chapter);
          if (_pageSlices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: <Widget>[
              Expanded(
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
                    LibraryStore.instance.saveProgress(widget.book);
                    setState(() {});
                  },
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth > 720 ? 64 : 24,
                      vertical: 12,
                    ),
                    child: Text(
                      _pageSlices[index].textOf(chapterText),
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: _lineHeight,
                        color: palette.foreground,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        chapter.title,
                        style: TextStyle(fontSize: 12, color: palette.foreground.withValues(alpha: 0.65)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_pageIndex + 1} / ${_pageSlices.length}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.foreground.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _maybeMeasure(Size size, Chapter chapter) {
    final String key =
        '${size.width}x${size.height}-$_fontSize-$_lineHeight-$_chapterIndex';
    if (key == _measureKey) return;
    _measureKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final double width = size.width - (size.width > 720 ? 128 : 48);
      final double height = size.height - 56;
      if (width <= 0 || height <= 0) return;
      final String chapterText = chapter.slice(widget.book.content);
      final List<PageSlice> slices = paginateSlices(
        chapterText,
        TextStyle(fontSize: _fontSize, height: _lineHeight),
        width,
        height,
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
      if (!mounted) return;
      setState(() {
        _pageSlices = slices;
        _pageIndex = targetPage.clamp(0, slices.length - 1);
        _controller?.dispose();
        _controller = PageController(initialPage: _pageIndex);
        widget.book.chapterIndex.value = _chapterIndex;
        widget.book.pageIndex.value = _pageIndex;
        widget.book.charOffset.value = slices[_pageIndex].start;
      });
      LibraryStore.instance.saveProgress(widget.book);
    });
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
    LibraryStore.instance.saveProgress(widget.book);
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
    LibraryStore.instance.saveProgress(widget.book);
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
    await LibraryStore.instance.saveProgress(widget.book);
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
      await LibraryStore.instance.saveProgress(widget.book);
    }
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext c, void Function(void Function()) setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('字号 ${_fontSize.toStringAsFixed(0)}'),
                  TextButton(
                    onPressed: () {
                      setSheet(() {});
                      setState(() {
                        _fontSize = 18;
                        _pageSlices = const <PageSlice>[];
                        _measureKey = null;
                      });
                      LibraryStore.instance.setFontSize(18);
                    },
                    child: const Text('重置'),
                  ),
                ],
              ),
              Slider(
                min: 12,
                max: 32,
                divisions: 20,
                value: _fontSize,
                label: _fontSize.toStringAsFixed(0),
                onChanged: (double v) {
                  setSheet(() {});
                  setState(() {
                    _fontSize = v;
                    _pageSlices = const <PageSlice>[];
                    _measureKey = null;
                  });
                  LibraryStore.instance.setFontSize(v);
                },
              ),
              Text('行距 ${_lineHeight.toStringAsFixed(1)}'),
              Slider(
                min: 1.2,
                max: 2.2,
                divisions: 10,
                value: _lineHeight,
                label: _lineHeight.toStringAsFixed(1),
                onChanged: (double v) {
                  setSheet(() {});
                  setState(() {
                    _lineHeight = v;
                    _pageSlices = const <PageSlice>[];
                    _measureKey = null;
                  });
                  LibraryStore.instance.setLineHeight(v);
                },
              ),
              if (!kEink) ...<Widget>[
                const Text('背景'),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _bgButton(setSheet, 0, '白'),
                    _bgButton(setSheet, 1, '米黄'),
                    _bgButton(setSheet, 2, '夜间'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bgButton(void Function(void Function()) setSheet, int index, String label) {
    final bool active = _bgIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: OutlinedButton(
        onPressed: () {
          setSheet(() {});
          setState(() {
            _bgIndex = index;
          });
          LibraryStore.instance.setBackgroundIndex(index);
        },
        child: Text(
          active ? '· $label' : label,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.black : null,
          ),
        ),
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
