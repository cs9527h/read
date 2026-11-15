import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/chapter_splitter.dart';
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

  List<String> _pages = const <String>[];
  List<int> _pageOffsets = const <int>[];
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
          if (_pages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (int index) {
                    _pageIndex = index;
                    widget.book.chapterIndex.value = _chapterIndex;
                    widget.book.pageIndex.value = index;
                    if (index < _pageOffsets.length) {
                      widget.book.charOffset.value = _pageOffsets[index];
                    }
                    LibraryStore.instance.saveProgress(widget.book);
                    setState(() {});
                  },
                  itemBuilder: (BuildContext context, int index) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Text(
                      _pages[index],
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
                      '${_pageIndex + 1} / ${_pages.length}',
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
      final List<String> pages = paginate(
        chapterText,
        TextStyle(fontSize: _fontSize, height: _lineHeight),
        width,
        height,
      );
      // Record chapter-local offsets independent from font size and viewport.
      final List<int> offsets = <int>[];
      int cursor = 0;
      for (final String page in pages) {
        final int found = chapterText.indexOf(page, cursor);
        final int start = found < 0 ? cursor : found;
        offsets.add(start);
        cursor = start + page.length;
      }
      int targetPage = _pageIndex;
      final int savedOffset = widget.book.charOffset.value;
      if (savedOffset >= 0) {
        targetPage = 0;
        for (int i = 0; i < offsets.length; i++) {
          if (offsets[i] > savedOffset) break;
          targetPage = i;
        }
      }
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _pageOffsets = offsets;
        _pageIndex = targetPage.clamp(0, pages.length - 1);
        _controller?.dispose();
        _controller = PageController(initialPage: _pageIndex);
        widget.book.chapterIndex.value = _chapterIndex;
        widget.book.pageIndex.value = _pageIndex;
        widget.book.charOffset.value = offsets[_pageIndex];
      });
      LibraryStore.instance.saveProgress(widget.book);
    });
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
        _pages = const <String>[];
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
                        _pages = const <String>[];
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
                    _pages = const <String>[];
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
                    _pages = const <String>[];
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
