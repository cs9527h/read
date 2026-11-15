import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/book_search.dart';
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
  late final List<Chapter> _chapters;
  late int _chapterIndex;
  int _pageIndex = 0;

  List<PageSlice> _pageSlices = const <PageSlice>[];
  String? _measureKey;
  PageController? _controller;

  double _fontSize = 18;
  double _lineHeight = 1.7;
  int _bgIndex = 0;

  @override
  void initState() {
    super.initState();
    _chapters = splitChapters(widget.book.content);
    _chapterIndex = widget.book.chapterIndex.value;
    if (_chapterIndex < 0 || _chapterIndex >= _chapters.length) {
      _chapterIndex = 0;
    }
    _pageIndex = widget.book.pageIndex.value;
    final LibraryStore store = LibraryStore.instance;
    _fontSize = store.fontSize;
    _lineHeight = store.lineHeight;
    _bgIndex = kEink ? 0 : store.backgroundIndex;
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
        return const _Palette(Color(0xFFF6EFE0), Color(0xFF3A3226));
      case 2:
        return const _Palette(Color(0xFF121212), Color(0xFFBDBDBD));
      default:
        return const _Palette(Colors.white, Color(0xFF1F1F1F));
    }
  }

  @override
  Widget build(BuildContext context) {
    final _Palette palette = _palette;
    final Chapter chapter = _chapters[_chapterIndex];
    final String chapterText = chapter.slice(widget.book.content);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        foregroundColor: palette.foreground,
        title: Text(
          widget.book.title,
          style: TextStyle(fontSize: 14, color: palette.foreground),
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '书内搜索',
            icon: Icon(Icons.search, color: palette.foreground),
            onPressed: _searchInBook,
          ),
          IconButton(
            tooltip: '目录',
            icon: Icon(Icons.list, color: palette.foreground),
            onPressed: _showChapters,
          ),
          IconButton(
            tooltip: '阅读设置',
            icon: Icon(Icons.text_fields, color: palette.foreground),
            onPressed: _showSettings,
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Text(
                      _pageSlices[index].textOf(chapterText),
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: _lineHeight,
                        color: palette.foreground,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        chapter.title,
                        style: TextStyle(fontSize: 12, color: palette.foreground.withOpacity(0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_pageIndex + 1} / ${_pageSlices.length}',
                      style: TextStyle(fontSize: 12, color: palette.foreground.withOpacity(0.6)),
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
      final double width = size.width - 40;
      final double height = size.height - 50;
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
        widget.book.charOffset.value = 0;
        _pageSlices = const <PageSlice>[];
        _measureKey = null;
      });
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
