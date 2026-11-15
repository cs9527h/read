import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/reader_theme.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/reader/widgets/reader_settings_sheet.dart';
import 'package:read/src/services/book_search.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/chapter_rule_store.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';

/// 阅读页：真实排版分页、翻页、菜单、书签、目录与全部阅读设置都从这里生效。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  final ReaderSettingsStore _store = ReaderSettingsStore.instance;
  ReaderSettings _settings = ReaderSettings();

  List<Chapter> _chapters = const <Chapter>[];
  ChapterRule _rule = const ChapterRule.automatic();
  int _chapterIndex = 0;
  int _pageIndex = 0;

  PaginatedChapter? _pagination;
  PageController? _pageController;
  ScrollController? _scrollController;
  List<int> _bookmarks = const <int>[];

  bool _menuVisible = false;
  bool _loading = true;
  String _layoutKey = '';
  double _pageWidth = 520;
  double _pageHeight = 800;
  int? _anchorOffset;
  double? _scrubPreview;

  Timer? _autoTurnTimer;
  Timer? _clockTimer;
  Timer? _statsTimer;
  int _sessionSeconds = 0;
  int _sessionChars = 0;
  int _lastSavedOffset = 0;
  bool _isReadingActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = _store.resolve(widget.book.id);
    _store.addListener(_onStoreChanged);
    UserFontStore.instance.addListener(_onStoreChanged);
    _initChapters();
    _initBookmarks();
    _applySystemUi();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _loading || !_isReadingActive) return;
      _sessionSeconds += 10;
      _flushStats();
    });
    _startAutoTurn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    UserFontStore.instance.removeListener(_onStoreChanged);
    _autoTurnTimer?.cancel();
    _clockTimer?.cancel();
    _statsTimer?.cancel();
    _flushStats();
    _pageController?.dispose();
    _scrollController?.dispose();
    _restoreSystemUi();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_isReadingActive == active) return;
    _isReadingActive = active;
    if (active) {
      _startAutoTurn();
    } else {
      _autoTurnTimer?.cancel();
      _autoTurnTimer = null;
      _flushStats();
      _saveProgress();
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final ReaderSettings next = _store.resolve(widget.book.id);
    if (next != _settings) {
      final int anchor = _currentAbsoluteOffset;
      setState(() {
        _settings = next;
        _anchorOffset = anchor;
        _layoutKey = '';
        _pagination = null;
      });
      _startAutoTurn();
      _applySystemUi();
    } else {
      setState(() {});
    }
  }

  Future<void> _initChapters() async {
    final ChapterRule rule = await ChapterRuleStore.load(widget.book.id);
    if (!mounted) return;
    final List<Chapter> chapters =
        splitChapters(widget.book.content, rule: rule);
    final int savedChapter =
        widget.book.chapterIndex.value.clamp(0, chapters.length - 1);
    final int savedOffset = widget.book.charOffset.value;
    setState(() {
      _rule = rule;
      _chapters = chapters;
      _chapterIndex = savedChapter;
      _anchorOffset = savedOffset >= 0 ? savedOffset : 0;
      _loading = false;
    });
    LibraryStore.instance.noteChapterCount(widget.book, chapters.length);
  }

  Future<void> _initBookmarks() async {
    final List<int> saved = await BookmarkStore.load(widget.book.id);
    if (mounted) setState(() => _bookmarks = saved);
  }

  // ---------------------------------------------------------------------------
  // 系统 UI / 方向
  // ---------------------------------------------------------------------------

  void _applySystemUi() {
    final bool hideBars =
        _settings.immersive && !_settings.showSystemBars;
    SystemChrome.setEnabledSystemUIMode(
      hideBars ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    _applyOrientation();
  }

  void _applyOrientation() {
    switch (_settings.orientation) {
      case 'portrait':
        SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ]);
      case 'landscape':
        SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      default:
        SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
    }
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // ---------------------------------------------------------------------------
  // 排版 / 分页
  // ---------------------------------------------------------------------------

  bool get _twoColumns {
    if (_settings.columns == 'one') return false;
    if (_settings.columns == 'two') return true;
    return _pageWidth > 620 && _pageWidth > _pageHeight * 1.05;
  }

  double get _headerHeight => _settings.minimalMode || !_settings.headerShow
      ? 0 : _settings.headerFontSize * 2 + 8;
  double get _footerHeight => _settings.minimalMode || !_settings.footerShow
      ? 0
      : _settings.footerFontSize * 2 +
          (_settings.footerProgressBar ? 8 : 0) + 6;

  double get _textScale {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return scaler.scale(100) / 100;
  }

  void _scheduleLayout(double contentWidth, double contentHeight) {
    if (contentWidth <= 0 || contentHeight <= 0) return;
    final double bodyHeight = contentHeight - _headerHeight - _footerHeight;
    final double measureWidth = _twoColumns
        ? (contentWidth - _settings.columnGap) / 2
        : contentWidth;
    final String key = <String>[
      contentWidth.toStringAsFixed(1),
      bodyHeight.toStringAsFixed(1),
      _twoColumns.toString(),
      _textScale.toStringAsFixed(2),
      _settings.toJsonString(),
      _chapterIndex.toString(),
      _chapterIndex < _chapters.length ? _chapters[_chapterIndex].length.toString() : '0',
    ].join('|');
    if (key == _layoutKey) return;
    if (measureWidth <= 0 || bodyHeight <= 0) return;
    _layoutKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _relayout(measureWidth, bodyHeight);
    });
  }

  void _relayout(double width, double height) {
    if (_chapterIndex < 0 || _chapterIndex >= _chapters.length) return;
    final Chapter chapter = _chapters[_chapterIndex];
    final int savedOffset = (_anchorOffset ?? widget.book.charOffset.value)
        .clamp(0, chapter.length);
    _anchorOffset = null;
    final PaginatedChapter pagination = ReaderEngine.paginate(
      chapterText: chapter.slice(widget.book.content),
      chapterTitle: chapter.title,
      settings: _settings,
      width: width,
      height: height,
      textScale: _textScale,
    );
    final int page = pagination.pageForSourceOffset(savedOffset);
    _pageWidth = width;
    _pageHeight = height;
    setState(() {
      _pagination = pagination;
      _pageIndex = page;
    });
    _resetControllers(page);
    widget.book.chapterIndex.value = _chapterIndex;
    widget.book.pageIndex.value = _renderPageIndex(page);
    if (pagination.pages.isNotEmpty) {
      widget.book.charOffset.value =
          pagination.pages[page.clamp(0, pagination.pages.length - 1)].sourceStart;
    }
    _lastSavedOffset = widget.book.charOffset.value;
    LibraryStore.instance.saveProgress(widget.book);
  }

  void _resetControllers(int page) {
    _pageController?.dispose();
    _pageController = PageController(initialPage: _renderPageIndex(page));
    _scrollController?.dispose();
    _scrollController = ScrollController();
  }

  int get _renderPageCount {
    final PaginatedChapter? p = _pagination;
    if (p == null) return 0;
    return _twoColumns ? (p.pages.length + 1) ~/ 2 : p.pages.length;
  }

  int _renderPageIndex(int columnPage) =>
      _twoColumns ? columnPage ~/ 2 : columnPage;

  int get _currentAbsoluteOffset {
    final PaginatedChapter? p = _pagination;
    if (_chapters.isEmpty || _chapterIndex >= _chapters.length) return 0;
    if (p == null || p.pages.isEmpty) {
      final chapter = _chapters[_chapterIndex];
      final saved = _anchorOffset ?? widget.book.charOffset.value;
      return chapter.start + saved.clamp(0, chapter.length);
    }
    final int column = _pageIndex.clamp(0, p.pages.length - 1);
    return _chapters[_chapterIndex].start + p.pages[column].sourceStart;
  }

  void _saveProgress() {
    final PaginatedChapter? p = _pagination;
    if (p == null || p.pages.isEmpty) return;
    final int column = _pageIndex.clamp(0, p.pages.length - 1);
    final int offset = p.pages[column].sourceStart;
    final int delta = (offset - _lastSavedOffset).abs();
    if (delta > 0) {
      _sessionChars += delta;
      _lastSavedOffset = offset;
    }
    widget.book.chapterIndex.value = _chapterIndex;
    widget.book.pageIndex.value = _renderPageIndex(column);
    widget.book.charOffset.value = offset;
    LibraryStore.instance.saveProgress(widget.book);
    if (_chapters.isNotEmpty) {
      final double percent =
          (_chapterIndex + (column / math.max(1, p.pages.length))) /
              _chapters.length;
      if (percent >= 0.995) {
        ReadingStatsStore.instance.markFinished(widget.book.id);
      }
    }
  }

  void _flushStats() {
    final int seconds = _sessionSeconds;
    final int chars = _sessionChars;
    if (seconds <= 0 && chars <= 0) return;
    _sessionSeconds = 0;
    _sessionChars = 0;
    ReadingStatsStore.instance.record(
      bookId: widget.book.id,
      seconds: seconds,
      chars: chars,
    );
  }

  void _startAutoTurn() {
    _autoTurnTimer?.cancel();
    if (!_settings.autoTurn || _settings.minimalMode || !_isReadingActive) return;
    _autoTurnTimer = Timer.periodic(
      Duration(seconds: _settings.autoTurnSeconds.clamp(3, 600)),
      (_) {
        if (!mounted || !_isReadingActive || _menuVisible) return;
        _turnPage(1);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 翻页
  // ---------------------------------------------------------------------------

  bool get _showScroll => _settings.pageTurnMode == 'scroll';

  void _turnPage(int direction) {
    final int d = _settings.reverseDirection ? -direction : direction;
    final PaginatedChapter? p = _pagination;
    if (p == null) return;
    if (_showScroll) {
      if (_scrollController?.hasClients != true) return;
      final ScrollPosition pos = _scrollController!.position;
      final double target = d > 0
          ? pos.pixels + pos.viewportDimension * 0.86
          : pos.pixels - pos.viewportDimension * 0.86;
      _scrollController!.animateTo(
        target.clamp(pos.minScrollExtent, pos.maxScrollExtent),
        duration: Duration(milliseconds: _settings.animationMs),
        curve: Curves.easeOut,
      );
      return;
    }
    final int targetColumn = _pageIndex + d;
    if (targetColumn < 0) {
      if (_chapterIndex > 0) _gotoChapter(_chapterIndex - 1, atEnd: true);
      return;
    }
    if (targetColumn >= p.pages.length) {
      if (_chapterIndex < _chapters.length - 1) {
        _gotoChapter(_chapterIndex + 1);
      } else {
        ReadingStatsStore.instance.markFinished(widget.book.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一页')),
        );
      }
      return;
    }
    final int renderIndex = _renderPageIndex(targetColumn);
    final PageController? controller = _pageController;
    if (controller != null && controller.hasClients) {
      if (_settings.pageTurnMode == 'none') {
        controller.jumpToPage(renderIndex);
      } else {
        controller.animateToPage(
          renderIndex,
          duration: Duration(
            milliseconds: _settings.minimalMode ? 0 : _settings.animationMs,
          ),
          curve: Curves.easeOutCubic,
        );
      }
    }
    setState(() => _pageIndex = targetColumn);
    _saveProgress();
  }

  void _onPageChanged(int renderIndex) {
    final int column = _twoColumns ? renderIndex * 2 : renderIndex;
    setState(() => _pageIndex = column);
    _saveProgress();
  }

  Future<void> _gotoChapter(int index, {bool atEnd = false}) async {
    if (index < 0 || index >= _chapters.length) return;
    final Chapter chapter = _chapters[index];
    setState(() {
      _chapterIndex = index;
      _pageIndex = 0;
      _anchorOffset = atEnd ? math.max(0, chapter.length - 1) : 0;
      _pagination = null;
      _layoutKey = '';
      widget.book.chapterIndex.value = index;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value = _anchorOffset!;
    });
    _lastSavedOffset = _anchorOffset!;
    await LibraryStore.instance.saveProgress(widget.book);
  }

  void _jumpToAbsolute(int absoluteOffset) {
    int chapterIndex = _chapters.length - 1;
    for (int i = 0; i < _chapters.length; i++) {
      if (absoluteOffset < _chapters[i].end) {
        chapterIndex = i;
        break;
      }
    }
    final Chapter chapter = _chapters[chapterIndex];
    setState(() {
      _chapterIndex = chapterIndex;
      _pageIndex = 0;
      _anchorOffset = (absoluteOffset - chapter.start).clamp(0, chapter.length);
      _pagination = null;
      _layoutKey = '';
      widget.book.chapterIndex.value = chapterIndex;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value = _anchorOffset!;
    });
    _lastSavedOffset = _anchorOffset!;
    LibraryStore.instance.saveProgress(widget.book);
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.platformBrightnessOf(context);
    final ReaderTheme theme = _store.effectiveTheme(_settings, brightness);
    final Color background = Color(_settings.backgroundColor ?? theme.background);
    final Color foreground = Color(_settings.textColor ?? theme.foreground);
    final Color secondary = Color(theme.secondary);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: <Widget>[
          _buildBackground(background),
          SafeArea(
            top: _settings.showSystemBars,
            bottom: _settings.showSystemBars,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints outer) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    _settings.marginLeft,
                    _settings.marginTop,
                    _settings.marginRight,
                    _settings.marginBottom,
                  ),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints inner) {
                      _scheduleLayout(inner.maxWidth, inner.maxHeight);
                      return Column(
                        children: <Widget>[
                          _buildHeader(secondary),
                          Expanded(
                            child: _buildPageArea(foreground, secondary),
                          ),
                          _buildFooter(secondary),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _buildTapLayer(),
          _buildMenu(background, foreground, secondary),
          _buildBrightnessOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground(Color background) {
    final String? path = _settings.bgImagePath;
    final File? file = path == null || path.isEmpty ? null : File(path);
    if (file == null || !file.existsSync()) {
      return Positioned.fill(child: ColoredBox(color: background));
    }
    BoxFit fit = BoxFit.cover;
    switch (_settings.bgImageFit) {
      case 'contain':
        fit = BoxFit.contain;
      case 'fill':
        fit = BoxFit.fill;
      case 'center':
        fit = BoxFit.none;
    }
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(color: background),
          Opacity(
            opacity: _settings.bgImageOpacity.clamp(0, 1),
            child: Image.file(file, fit: fit),
          ),
          if (_settings.bgImageDim > 0)
            ColoredBox(
              color: Colors.black.withValues(alpha: _settings.bgImageDim),
            ),
        ],
      ),
    );
  }

  Widget _buildBrightnessOverlay() {
    final double reduce = _settings.followSystemBrightness
        ? 0
        : (1 - _settings.brightness).clamp(0, 0.8);
    if (reduce <= 0) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(color: Colors.black.withValues(alpha: reduce)),
      ),
    );
  }

  Widget _buildHeader(Color secondary) {
    if (_settings.minimalMode || !_settings.headerShow) return const SizedBox.shrink();
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: _templateText(
              _settings.headerLeft,
              secondary,
              _settings.headerFontSize,
              _settings.headerColor,
              _settings.headerOpacity,
              TextAlign.left,
              _settings.headerFontFamily,
            ),
          ),
          Expanded(
            flex: 2,
            child: _templateText(
              _settings.headerCenter,
              secondary,
              _settings.headerFontSize,
              _settings.headerColor,
              _settings.headerOpacity,
              TextAlign.center,
              _settings.headerFontFamily,
            ),
          ),
          Expanded(
            flex: 2,
            child: _templateText(
              _settings.headerRight,
              secondary,
              _settings.headerFontSize,
              _settings.headerColor,
              _settings.headerOpacity,
              TextAlign.right,
              _settings.headerFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color secondary) {
    if (_settings.minimalMode || !_settings.footerShow) return const SizedBox.shrink();
    return SizedBox(
      height: _footerHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _templateText(
                  _settings.footerLeft,
                  secondary,
                  _settings.footerFontSize,
                  _settings.footerColor,
                  _settings.footerOpacity,
                  TextAlign.left,
                  _settings.footerFontFamily,
                ),
              ),
              Expanded(
                flex: 3,
                child: _templateText(
                  _settings.footerCenter,
                  secondary,
                  _settings.footerFontSize,
                  _settings.footerColor,
                  _settings.footerOpacity,
                  TextAlign.center,
                  _settings.footerFontFamily,
                ),
              ),
              Expanded(
                flex: 2,
                child: _templateText(
                  _settings.footerRight,
                  secondary,
                  _settings.footerFontSize,
                  _settings.footerColor,
                  _settings.footerOpacity,
                  TextAlign.right,
                  _settings.footerFontFamily,
                ),
              ),
            ],
          ),
          if (_settings.footerProgressBar)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: _overallProgress,
                minHeight: 2,
                backgroundColor: secondary.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  secondary.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double get _overallProgress {
    if (_scrubPreview != null) return _scrubPreview!.clamp(0, 1);
    final total = widget.book.content.length;
    if (total == 0) return 0;
    return (_currentAbsoluteOffset / total).clamp(0, 1);
  }

  Widget _templateText(
    String template,
    Color fallback,
    double size,
    int? color,
    double opacity,
    TextAlign align,
    String? fontFamily,
  ) {
    if (template.trim().isEmpty) return const SizedBox.shrink();
    final String text = _renderTemplate(template);
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: switch (align) {
        TextAlign.center => Alignment.center,
        TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      },
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          fontSize: size,
          fontFamily: fontFamily ?? _settings.fontFamily,
          color: Color(color ?? fallback.toARGB32())
              .withValues(alpha: opacity.clamp(0, 1)),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  String _renderTemplate(String template) {
    final PaginatedChapter? p = _pagination;
    final String chapter =
        _chapterIndex < _chapters.length ? _chapters[_chapterIndex].title : '';
    final int totalPages = p?.pages.length ?? 1;
    final int page = _pageIndex + 1;
    final double percent = _overallProgress * 100;
    final DateTime now = DateTime.now();
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return template
        .replaceAll('{book}', widget.book.title)
        .replaceAll('{author}', widget.book.author)
        .replaceAll('{chapter}', chapter)
        .replaceAll('{page}', '$page')
        .replaceAll('{pages}', '$totalPages')
        .replaceAll('{percent}', '${percent.toStringAsFixed(1)}%')
        .replaceAll('{time}', time);
  }

  Widget _buildPageArea(Color foreground, Color secondary) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final PaginatedChapter? p = _pagination;
    if (p == null || p.pages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _chapterIndex < _chapters.length &&
                    _chapters[_chapterIndex]
                        .slice(widget.book.content)
                        .trim()
                        .isEmpty
                ? '这一章没有正文内容'
                : '正在排版…',
            style: TextStyle(color: secondary),
          ),
        ),
      );
    }
    if (_showScroll) return _buildScrollArea(p, foreground);
    final PageController? controller = _pageController;
    return PageView.builder(
      controller: controller,
      itemCount: _renderPageCount,
      physics: _settings.pageTurnMode == 'none'
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (BuildContext context, int renderIndex) {
        final Widget page = _twoColumns
            ? _buildTwoColumnPage(p, renderIndex, foreground)
            : _buildSinglePage(p, renderIndex, foreground);
        final Widget guided = _withGuides(page, secondary);
        if (_settings.pageTurnMode != 'cover' || controller == null) {
          return guided;
        }
        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            double delta = 0;
            if (controller.hasClients && controller.position.haveDimensions) {
              delta = (controller.page ?? renderIndex.toDouble()) - renderIndex;
            }
            final double direction = _settings.reverseDirection ? -1 : 1;
            return Transform.translate(
              offset: Offset(delta * direction * -_pageWidth * 0.22, 0),
              child: Transform.scale(
                scale: 1 - delta.abs() * 0.04,
                child: Opacity(
                  opacity: (1 - delta.abs() * 0.25).clamp(0, 1),
                  child: child,
                ),
              ),
            );
          },
          child: guided,
        );
      },
    );
  }

  Widget _withGuides(Widget child, Color secondary) {
    if (_settings.minimalMode || !_settings.guideShow) return child;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GuidePainter(
                settings: _settings,
                color: Color(_settings.guideColor ?? secondary.toARGB32()),
                titleHeight: _pagination?.titleHeight ?? 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _pageSpan(String text, TextStyle style) {
    final String pattern = _settings.boldPattern.trim();
    if (pattern.isEmpty) return TextSpan(text: text, style: style);
    RegExp regex;
    try {
      regex = RegExp(pattern);
    } catch (_) {
      return TextSpan(text: text, style: style);
    }
    final List<String> lines = text.split('\n');
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int i = 0; i < lines.length; i++) {
      final bool bold = lines[i].trim().isNotEmpty && regex.hasMatch(lines[i]);
      spans.add(TextSpan(
        text: lines[i],
        style: bold ? style.copyWith(fontWeight: FontWeight.w700) : style,
      ));
      if (i != lines.length - 1) spans.add(TextSpan(text: '\n', style: style));
    }
    return TextSpan(children: spans);
  }

  Widget _scaledText(Widget child) {
    if ((_settings.textScaleX - 1).abs() < 0.001) return child;
    return Transform.scale(
      scaleX: _settings.textScaleX,
      alignment: Alignment.topLeft,
      child: child,
    );
  }

  Widget _buildSinglePage(PaginatedChapter p, int index, Color foreground) {
    if (index < 0 || index >= p.pages.length) return const SizedBox.shrink();
    final EnginePage page = p.pages[index];
    final List<Widget> children = <Widget>[];
    if (index == 0 && p.showTitle) children.add(_buildChapterTitle());
    final TextStyle style = ReaderEngine.bodyStyle(
      _settings,
      color: foreground,
      textScale: _textScale,
    );
    final Widget body = _scaledText(SelectionArea(
      child: Text.rich(
        _pageSpan(page.textOf(p.display), style),
        textAlign: ReaderEngine.textAlignOf(_settings.align),
      ),
    ));
    children.add(
      Expanded(
        child: Align(
          alignment:
              _settings.bottomAlign ? Alignment.bottomLeft : Alignment.topLeft,
          child: body,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildTwoColumnPage(
      PaginatedChapter p, int renderIndex, Color foreground) {
    final int leftIndex = renderIndex * 2;
    final int rightIndex = leftIndex + 1;
    Widget column(int index) {
      if (index >= p.pages.length) return const SizedBox.shrink();
      final EnginePage page = p.pages[index];
      final List<Widget> children = <Widget>[];
      if (index == 0 && p.showTitle) children.add(_buildChapterTitle());
      final TextStyle style = ReaderEngine.bodyStyle(
        _settings,
        color: foreground,
        textScale: _textScale,
      );
      children.add(
        Expanded(
          child: Align(
            alignment: _settings.bottomAlign
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            child: _scaledText(SelectionArea(
              child: Text.rich(
                _pageSpan(page.textOf(p.display), style),
                textAlign: ReaderEngine.textAlignOf(_settings.align),
              ),
            )),
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: column(leftIndex)),
        SizedBox(width: _settings.columnGap),
        Expanded(child: column(rightIndex)),
      ],
    );
  }

  Widget _buildChapterTitle() {
    final String title =
        _chapterIndex < _chapters.length ? _chapters[_chapterIndex].title : '';
    final Color color = Color(
      _settings.titleColor ?? _settings.textColor ?? 0xFF1A1A1A,
    );
    final TextAlign align = switch (_settings.titleAlign) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    final double titleHeight = _pagination?.titleHeight ?? 0;
    final TextStyle style = TextStyle(
      fontFamily: _settings.titleFontFamily ?? _settings.fontFamily,
      fontSize: _settings.titleFontSize * _textScale,
      fontWeight: FontWeight.values[(_settings.titleWeight ~/ 100) - 1],
      height: 1.3,
      color: color,
    );
    Widget inner;
    final List<String> parts = _settings.titleNumberNewLine
        ? ReaderEngine.splitChapterTitle(title)
        : <String>[title];
    if (parts.length > 1) {
      inner = Column(
        crossAxisAlignment: switch (align) {
          TextAlign.center => CrossAxisAlignment.center,
          TextAlign.right => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        },
        children: <Widget>[
          Text(parts[0], textAlign: align, style: style),
          Text(parts[1], textAlign: align, style: style),
        ],
      );
    } else {
      inner = Text(title, textAlign: align, style: style);
    }
    if (_settings.titleTemplate == 'centered') {
      inner = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[inner],
      );
    } else if (_settings.titleTemplate == 'divider') {
      inner = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          inner,
          const SizedBox(height: 6),
          Container(height: 0.6, color: color.withValues(alpha: 0.25)),
        ],
      );
    }
    return SizedBox(
      height: titleHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          _settings.chapterStartBlank + _settings.titleGapTop,
          0,
          _settings.titleGapBottom,
        ),
        child: Align(
          alignment: switch (align) {
            TextAlign.center => Alignment.topCenter,
            TextAlign.right => Alignment.topRight,
            _ => Alignment.topLeft,
          },
          child: inner,
        ),
      ),
    );
  }

  Widget _buildScrollArea(PaginatedChapter p, Color foreground) {
    final ScrollController controller =
        _scrollController ??= ScrollController();
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollEndNotification) {
          _onScrollProgress(p, controller);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildChapterTitle(),
            _scaledText(SelectionArea(
              child: Text.rich(
                _pageSpan(
                  p.display.text,
                  ReaderEngine.bodyStyle(
                    _settings,
                    color: foreground,
                    textScale: _textScale,
                  ),
                ),
                textAlign: ReaderEngine.textAlignOf(_settings.align),
              ),
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _onScrollProgress(PaginatedChapter p, ScrollController controller) {
    if (!controller.hasClients) return;
    final double max = controller.position.maxScrollExtent;
    final double fraction = max <= 0 ? 1 : (controller.offset / max).clamp(0, 1);
    final int displayIndex =
        (fraction * p.display.text.length).clamp(0, p.display.text.length).toInt();
    final int source = p.display.sourceOffset(displayIndex);
    final int delta = (source - _lastSavedOffset).abs();
    if (delta > 0) {
      _sessionChars += delta;
      _lastSavedOffset = source;
    }
    widget.book.chapterIndex.value = _chapterIndex;
    widget.book.pageIndex.value = 0;
    widget.book.charOffset.value = source;
    LibraryStore.instance.saveProgress(widget.book);
  }

  // ---------------------------------------------------------------------------
  // 点击、菜单与手势
  // ---------------------------------------------------------------------------

  Widget _buildTapLayer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (TapUpDetails details) {
          final double width = MediaQuery.sizeOf(context).width;
          final double x = details.localPosition.dx;
          final String action;
          if (x < width * 0.3) {
            action = _settings.tapLeft;
          } else if (x < width * 0.7) {
            action = _settings.tapCenter;
          } else {
            action = _settings.tapRight;
          }
          _performTapAction(action);
        },
        // Long press now belongs to SelectionArea for range selection.
      ),
    );
  }

  void _performTapAction(String action) {
    switch (action) {
      case 'prev':
        if (_menuVisible) {
          setState(() => _menuVisible = false);
        } else {
          _turnPage(-1);
        }
      case 'next':
        if (_menuVisible) {
          setState(() => _menuVisible = false);
        } else {
          _turnPage(1);
        }
      case 'menu':
        setState(() => _menuVisible = !_menuVisible);
      case 'chapters':
        _showChapters();
      case 'settings':
        _openSettings();
      case 'bookmark':
        _toggleBookmark();
      case 'read':
      case 'none':
        break;
    }
  }

  Widget _buildMenu(Color background, Color foreground, Color secondary) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_menuVisible,
        child: Stack(
          children: <Widget>[
            AnimatedOpacity(
              opacity: _menuVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: GestureDetector(
                onTap: () => setState(() => _menuVisible = false),
                child: ColoredBox(
                  color: foreground.withValues(alpha: 0.16),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: _menuVisible ? 0 : -110,
              left: 0,
              right: 0,
              child: _topBar(background, foreground),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              bottom: _menuVisible ? 0 : -190,
              left: 0,
              right: 0,
              child: _bottomBar(background, foreground, secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(Color background, Color foreground) {
    return Container(
      color: background.withValues(alpha: 0.96),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '返回',
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: foreground),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showChapters,
              child: Text(
                _chapterIndex < _chapters.length
                    ? _chapters[_chapterIndex].title
                    : widget.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: foreground),
              ),
            ),
          ),
          IconButton(
            tooltip: '书内搜索',
            icon: Icon(Icons.search_rounded, size: 21, color: foreground),
            onPressed: _searchInBook,
          ),
          IconButton(
            tooltip: '添加书签',
            icon: Icon(
              _bookmarks.contains(_currentAbsoluteOffset)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 21,
              color: foreground,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            tooltip: '阅读设置',
            icon: Icon(Icons.tune_rounded, size: 21, color: foreground),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(Color background, Color foreground, Color secondary) {
    return Container(
      color: background.withValues(alpha: 0.96),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Text(
              '${(_overallProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Slider(
                value: _overallProgress.clamp(0, 1),
                onChanged: widget.book.content.isEmpty
                    ? null
                    : (value) => setState(() => _scrubPreview = value),
                onChangeEnd: widget.book.content.isEmpty ? null : (value) {
                  setState(() => _scrubPreview = null);
                  _seekProgress(value);
                },
              ),
            ),
            for (final action in _settings.bottomActions)
              IconButton(
                tooltip: switch (action) {
                  'toc' => '目录',
                  'bookmark' => '书签',
                  'search' => '书内搜索',
                  _ => '阅读设置',
                },
                icon: Icon(
                  switch (action) {
                    'toc' => Icons.list_rounded,
                    'bookmark' => Icons.collections_bookmark_outlined,
                    'search' => Icons.search_rounded,
                    _ => Icons.text_fields_rounded,
                  },
                  color: foreground,
                ),
                onPressed: () {
                  switch (action) {
                    case 'toc':
                      _showChapters();
                    case 'bookmark':
                      _showBookmarks();
                    case 'search':
                      _searchInBook();
                    default:
                      _openSettings();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _seekProgress(double fraction) {
    if (_chapters.isEmpty || widget.book.content.isEmpty) return;
    final absolute = (fraction.clamp(0, 1) * widget.book.content.length).round();
    _jumpToAbsolute(absolute);
  }

  Future<void> _openSettings() async {
    setState(() => _menuVisible = false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ReaderSettingsSheet(
        bookId: widget.book.id,
        onRepaginate: () => setState(() {
          _layoutKey = '';
          _pagination = null;
        }),
      ),
    );
  }

  Future<void> _showSelectionActions() async {
    final PaginatedChapter? p = _pagination;
    if (p == null || p.pages.isEmpty) return;
    final String pageText = p.pages[_pageIndex.clamp(0, p.pages.length - 1)]
        .textOf(p.display)
        .trim();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制本页文字'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: pageText));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制本页文字')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.search_rounded),
              title: const Text('搜索本页文字'),
              onTap: () {
                Navigator.pop(ctx);
                _searchInBook(
                  initialQuery:
                      pageText.length > 24 ? pageText.substring(0, 24) : pageText,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('在当前位置添加书签'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleBookmark();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 章节调整 / 书签 / 搜索
  // ---------------------------------------------------------------------------

  Future<void> _showChapters() async {
    final int? selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        builder: (BuildContext ctx, ScrollController scroll) => ListView.builder(
          controller: scroll,
          itemCount: _chapters.length + 1,
          itemBuilder: (BuildContext c, int index) {
            if (index == _chapters.length) {
              return ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('章节识别规则'),
                subtitle: const Text('自动 / 整本一章 / 自定义正则'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChapterRules();
                },
              );
            }
            return ListTile(
              selected: index == _chapterIndex,
              title: Text(_chapters[index].title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, index),
            );
          },
        ),
      ),
    );
    if (selected != null && selected != _chapterIndex) {
      await _gotoChapter(selected);
    }
  }

  Future<void> _showChapterRules() async {
    ChapterRuleMode mode = _rule.mode;
    final TextEditingController controller =
        TextEditingController(text: _rule.pattern);
    String? validationError;
    final ChapterRule? selected = await showModalBottomSheet<ChapterRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
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
                  onChanged: (ChapterRuleMode? value) => setSheetState(() {
                    mode = value!;
                    validationError = null;
                  }),
                ),
                RadioListTile<ChapterRuleMode>(
                  title: const Text('整本作为一章'),
                  value: ChapterRuleMode.none,
                  groupValue: mode,
                  onChanged: (ChapterRuleMode? value) => setSheetState(() {
                    mode = value!;
                    validationError = null;
                  }),
                ),
                RadioListTile<ChapterRuleMode>(
                  title: const Text('自定义章节标题正则'),
                  value: ChapterRuleMode.custom,
                  groupValue: mode,
                  onChanged: (ChapterRuleMode? value) => setSheetState(() {
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
    controller.dispose();
    if (!mounted || selected == null) return;
    try {
      splitChapters(widget.book.content, rule: selected);
      await ChapterRuleStore.save(widget.book.id, selected);
      if (!mounted) return;
      final int absolute = _currentAbsoluteOffset;
      final List<Chapter> next =
          splitChapters(widget.book.content, rule: selected);
      int index = next.length - 1;
      for (int i = 0; i < next.length; i++) {
        if (absolute < next[i].end) {
          index = i;
          break;
        }
      }
      setState(() {
        _rule = selected;
        _chapters = next;
        _chapterIndex = index;
        _pageIndex = 0;
        _anchorOffset =
            (absolute - next[index].start).clamp(0, next[index].length);
        _pagination = null;
        _layoutKey = '';
        widget.book.chapterIndex.value = index;
        widget.book.pageIndex.value = 0;
        widget.book.charOffset.value = _anchorOffset!;
      });
      _lastSavedOffset = _anchorOffset!;
      LibraryStore.instance.saveProgress(widget.book);
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

  Future<void> _toggleBookmark() async {
    try {
      final List<int> saved = await BookmarkStore.toggle(
        widget.book.id,
        _currentAbsoluteOffset,
      );
      if (!mounted) return;
      setState(() => _bookmarks = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(saved.contains(_currentAbsoluteOffset) ? '已添加书签' : '已移除书签'),
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
      showDragHandle: true,
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
                          if (begin > 0 &&
                              begin < source.length &&
                              source.codeUnitAt(begin) >= 0xDC00 &&
                              source.codeUnitAt(begin) <= 0xDFFF) {
                            begin++;
                          }
                          if (end > begin &&
                              end < source.length &&
                              source.codeUnitAt(end) >= 0xDC00 &&
                              source.codeUnitAt(end) <= 0xDFFF) {
                            end--;
                          }
                          final String preview = source
                              .substring(begin, end)
                              .replaceAll(RegExp(r'[\r\n]+'), ' ')
                              .trim();
                          return ListTile(
                            leading: const Icon(Icons.bookmark_rounded),
                            title: Text(
                              preview.isEmpty ? '书签位置' : preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
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
    _jumpToAbsolute(position);
  }

  Future<void> _searchInBook({String? initialQuery}) async {
    final BookSearchMatch? hit = await showSearch<BookSearchMatch?>(
      context: context,
      delegate: _BookSearchDelegate(
        widget.book.content,
        _chapters,
        initialQuery: initialQuery,
      ),
    );
    if (!mounted || hit == null) return;
    _jumpToAbsolute(hit.start);
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.settings,
    required this.color,
    required this.titleHeight,
  });

  final ReaderSettings settings;
  final Color color;
  final double titleHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final double line = settings.fontSize * settings.lineHeight;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: settings.guideOpacity.clamp(0, 1))
      ..strokeWidth = settings.guideThickness;
    double y = titleHeight;
    while (y < size.height) {
      if (settings.guideStyle == 'dashed') {
        for (double x = 0; x < size.width; x += 8) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + 4, size.width), y),
            paint,
          );
        }
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      y += line;
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) =>
      old.settings != settings || old.titleHeight != titleHeight;
}

class _BookSearchDelegate extends SearchDelegate<BookSearchMatch?> {
  _BookSearchDelegate(this.content, this.chapters, {String? initialQuery})
      : super(searchFieldLabel: '搜索本书内容') {
    if (initialQuery != null) query = initialQuery;
  }

  final String content;
  final List<Chapter> chapters;

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
    final List<BookSearchMatch> matches =
        searchBookText(content, chapters, query);
    if (matches.isEmpty) {
      return const Center(child: Text('未找到匹配内容'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (BuildContext context, int index) {
        final BookSearchMatch match = matches[index];
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
