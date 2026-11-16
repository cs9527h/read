import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/reader/platform/reader_device_bridge.dart';
import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/reader_theme.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/reader/widgets/reader_settings_sheet.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/services/book_search.dart';
import 'package:read/src/services/bookmark_meta_store.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/chapter_rule_store.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/highlight_store.dart';
import 'package:read/src/services/manual_chapter_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/sync/auto_sync_service.dart';
import 'package:read/src/sync/progress_models.dart';
import 'package:read/src/sync/metadata_sync_service.dart';
import 'package:read/src/sync/progress_sync_service.dart';
import 'package:read/src/sync/sync_page.dart';
import 'package:read/src/sync/sync_config.dart';

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
  List<int> _bookmarks = <int>[];
  List<HighlightRecord> _highlights = <HighlightRecord>[];

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
  StreamSubscription<String>? _volumeKeysSubscription;
  int? _batteryLevel;
  ProgressRecord? _cloudRecord;
  bool _cloudBusy = false;
  bool _chapterTransition = false;

  // 点击翻页用原始指针层处理，避免被 SelectableText 的文本选择手势
  // 抢走 tap，导致点右侧/左侧不翻页（任务 16/45/47）。
  Offset? _tapDownPosition;
  DateTime? _tapDownTime;

  /// 只用于刷新页眉页脚，避免每次翻页 setState 重建整页。
  final ValueNotifier<int> _pageTick = ValueNotifier<int>(0);
  // Chapter transitions replace the PageView and must invalidate its subtree.
  final ValueNotifier<int> _chapterTick = ValueNotifier<int>(0);

  /// 进度落盘防抖：翻页先走内存，400ms 内的连续翻页只写一次磁盘。
  Timer? _progressTimer;
  Timer? _relayoutTimer;

  /// 分页缓存：key = 版式签名|章节索引。命中时切章零计算。
  final Map<String, PaginatedChapter> _paginationCache = <String, PaginatedChapter>{};
  PaginatedChapter? _prevPagination;
  PaginatedChapter? _nextPagination;
  int _controllerEpoch = 0;
  String _signature = '';

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _ttsContinuous = false;
  bool _ttsPaused = false;
  double _ttsSpeed = 0.5;
  final List<int> _positionHistory = <int>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings = _store.resolve(widget.book.id);
    _store.addListener(_onStoreChanged);
    UserFontStore.instance.addListener(_onStoreChanged);
    _initChapters();
    _initBookmarks();
    unawaited(_refreshCloudProgress());
    _applySystemUi();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
      unawaited(_refreshDeviceControls());
    });
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _loading || !_isReadingActive) return;
      _sessionSeconds += 10;
      _flushStats();
    });
    _startAutoTurn();
    _initTts();
    unawaited(AutoSyncService.instance.onBookOpened(widget.book).then(_afterOpenSync));
  }

  void _initTts() {
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _ttsPaused = false;
      });
      if (_ttsContinuous && _isReadingActive) {
        _turnPage(1);
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _ttsContinuous) unawaited(_speakCurrent());
        });
      }
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((dynamic message) {
      if (mounted) {
        setState(() => _speaking = false);
        _ttsContinuous = false;
      }
    });
  }

  void _afterOpenSync(ProgressSyncReport? report) {
    if (!mounted || report == null) return;
    final hash = widget.book.contentHash;
    if (hash == null || !report.downloadedHashes.contains(hash)) {
      unawaited(_refreshCloudProgress());
      return;
    }
    if (SyncConfig.instance.autoJumpProgress) _reloadAtSyncedPosition();
    unawaited(_refreshCloudProgress());
  }

  Future<void> _refreshCloudProgress() async {
    final hash = widget.book.contentHash;
    if (hash == null || !SyncConfig.instance.configured) {
      if (mounted) setState(() => _cloudRecord = null);
      return;
    }
    if (mounted) setState(() => _cloudBusy = true);
    try {
      final secrets = await SyncSecrets.load();
      final store = SyncBackendFactory.create(SyncConfig.instance, secrets);
      final record = await ProgressSyncService(LibraryStore.instance)
          .fetchRemoteStore(
        store,
        secrets.encryptionPassword,
        SyncBackendFactory.targetId(SyncConfig.instance),
        hash,
      );
      if (mounted) setState(() => _cloudRecord = record);
    } catch (_) {
      // A read-only cloud probe must never interrupt reading.
      if (mounted) setState(() => _cloudRecord = null);
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<void> _manualProgressSync({ProgressChoice? force}) async {
    if (!SyncConfig.instance.configured) {
      _showToast('请先在“我的 → 同步”配置云存储');
      return;
    }
    try {
      final report = await AutoSyncService.instance.runProgress(
        widget.book,
        resolver: force == null
            ? _resolveProgressConflict
            : (ProgressSyncConflict _) async => force,
      );
      if (!mounted) return;
      if (report == null) {
        _showToast('同步未执行');
        return;
      }
      final hash = widget.book.contentHash;
      if (hash != null && report.downloadedHashes.contains(hash)) {
        _reloadAtSyncedPosition();
        _showToast('已采用云端阅读进度');
      } else {
        _showToast('阅读进度已同步');
      }
    } catch (error) {
      if (mounted) _showToast('同步失败：$error');
    }
  }

  Future<ProgressChoice?> _resolveProgressConflict(ProgressSyncConflict conflict) async {
    if (!SyncConfig.instance.promptCloudProgress) {
      return SyncConfig.instance.conflictPolicy == 'cloud'
          ? ProgressChoice.cloud
          : ProgressChoice.local;
    }
    return showDialog<ProgressChoice>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('《${conflict.title}》进度冲突'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('本机位置：字符 ${conflict.local.offset}'),
            const SizedBox(height: 6),
            Text('云端位置：字符 ${conflict.remote.offset}'),
            const SizedBox(height: 6),
            Text('云端设备：${conflict.remote.device.substring(0, 6)}…'),
            const SizedBox(height: 10),
            const Text('选择后会作为一个新的同步版本上传，不会静默覆盖。'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, ProgressChoice.local),
            child: const Text('保留本机'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ProgressChoice.cloud),
            child: const Text('采用云端'),
          ),
        ],
      ),
    );
  }

  void _reloadAtSyncedPosition() {
    final chapter = widget.book.chapterIndex.value;
    if (chapter < 0 || chapter >= _chapters.length) return;
    setState(() {
      _chapterIndex = chapter;
      _pageIndex = 0;
      _anchorOffset = widget.book.charOffset.value;
      _layoutKey = '';
      _pagination = null;
    });
  }

  void _showToast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    if (Platform.isAndroid) {
      _volumeKeysSubscription = ReaderDeviceBridge.volumeKeys.listen(
        (String key) {
          if (!mounted || !_isReadingActive || !_settings.volumeKeys || _loading) {
            return;
          }
          final direction = key == 'up' ? -1 : 1;
          _turnPage(_settings.reverseDirection ? -direction : direction);
        },
        onError: (Object _) {},
      );
      unawaited(_refreshDeviceControls());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    UserFontStore.instance.removeListener(_onStoreChanged);
    _autoTurnTimer?.cancel();
    _clockTimer?.cancel();
    _statsTimer?.cancel();
    _progressTimer?.cancel();
    _relayoutTimer?.cancel();
    _prefetchTimer?.cancel();
    _pageTick.dispose();
    _chapterTick.dispose();
    if (Platform.isAndroid) {
      unawaited(_volumeKeysSubscription?.cancel() ?? Future<void>.value());
      unawaited(ReaderDeviceBridge.setVolumePaging(false).catchError((Object _) {}));
      unawaited(ReaderDeviceBridge.setWindowBrightness(null).catchError((Object _) {}));
    }
    _flushStats();
    _flushProgress();
    AutoSyncService.instance.onBookClosed();
    unawaited(_tts.stop());
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
      _flushProgress();
    }
    unawaited(_refreshDeviceControls());
  }

  Future<void> _refreshDeviceControls() async {
    if (!Platform.isAndroid) return;
    try {
      await ReaderDeviceBridge.setVolumePaging(
        _settings.volumeKeys && _isReadingActive,
      );
      await ReaderDeviceBridge.setWindowBrightness(
        _settings.followSystemBrightness || !_isReadingActive
            ? null
            : _settings.brightness,
      );
      final level = await ReaderDeviceBridge.batteryLevel();
      if (mounted && _batteryLevel != level) {
        setState(() => _batteryLevel = level);
      }
    } on MissingPluginException {
      // The desktop target and legacy host builds have no Android channel.
    } on PlatformException {
      // A failed battery query must not prevent reading.
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final ReaderSettings next = _store.resolve(widget.book.id);
    if (next != _settings) {
      // 重排用章节内相对偏移恢复位置。这里必须取当前页的 sourceStart
      // （相对偏移），不能用全书绝对偏移，否则改字号后会跳到错误页面。
      final PaginatedChapter? current = _pagination;
      int anchor;
      if (current != null && current.pages.isNotEmpty) {
        anchor = current.pages[_pageIndex.clamp(0, current.pages.length - 1)]
            .sourceStart;
      } else {
        anchor = widget.book.charOffset.value;
      }
      _anchorOffset = anchor;
      // 保留当前 PaginatedChapter，等新版式算完再替换：调字号时不会闪出
      // 「正在排版…」空白页。重排本身做 180ms 防抖，拖动滑块只算最后一次。
      _settings = next;
      _layoutKey = '';
      _paginationCache.clear();
      _relayoutTimer?.cancel();
      _relayoutTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        setState(() {
          _layoutKey = '';
        });
      });
      _startAutoTurn();
      _applySystemUi();
      unawaited(_refreshDeviceControls());
    } else {
      setState(() {});
    }
  }

  Future<void> _initChapters() async {
    final ChapterRule rule = await ChapterRuleStore.load(widget.book.id);
    final marks = await ManualChapterStore.load(widget.book.id);
    if (!mounted) return;
    final List<Chapter> chapters = applyManualChapters(
      widget.book.content,
      splitChapters(widget.book.content, rule: rule),
      marks,
    );
    final int savedChapter =
        widget.book.chapterIndex.value.clamp(0, chapters.length - 1);
    final int savedOffset = widget.book.charOffset.value;
    setState(() {
      _rule = rule;
      _chapters = chapters;
      _chapterIndex = savedChapter;
      _anchorOffset = savedOffset >= 0 ? savedOffset : 0;
      _loading = false;
      // 章节列表到位后必须让版式签名失效，否则首次 build 时算出的 key
      // 会挡住真正的分页。
      _layoutKey = '';
      _paginationCache.clear();
    });
    LibraryStore.instance.noteChapterCount(widget.book, chapters.length);
  }

  Future<void> _initBookmarks() async {
    final List<int> saved = await BookmarkStore.load(widget.book.id);
    final highlights = await HighlightStore.load(widget.book.id);
    if (mounted) {
      setState(() {
        _bookmarks
          ..clear()
          ..addAll(saved);
        _highlights = highlights;
      });
    }
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
    // _pageWidth is the previous measured column width, not viewport width.
    final Size viewport = MediaQuery.sizeOf(context);
    return viewport.width >= 860 && viewport.width > viewport.height * 1.05;
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

  // ---------------------------------------------------------------------------
  // 排版 / 分页（带缓存与相邻章预取）
  // ---------------------------------------------------------------------------

  String _buildSignature(double width, double bodyHeight) => <String>[
        width.toStringAsFixed(1),
        bodyHeight.toStringAsFixed(1),
        _twoColumns.toString(),
        _textScale.toStringAsFixed(2),
        _settings.toJsonString(),
      ].join('|');

  void _scheduleLayout(double contentWidth, double contentHeight) {
    if (contentWidth <= 0 || contentHeight <= 0) return;
    final double bodyHeight = contentHeight - _headerHeight - _footerHeight;
    final double measureWidth = _twoColumns
        ? (contentWidth - _settings.columnGap) / 2
        : contentWidth;
    if (measureWidth <= 0 || bodyHeight <= 0) return;
    final String signature = _buildSignature(measureWidth, bodyHeight);
    final String key = '$signature|$_chapterIndex';
    if (key == _layoutKey) return;
    _layoutKey = key;
    _signature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 过期回调防护：排队期间可能又发起了新的布局请求（改字号、旋转、
      // 窗口变化），旧尺寸的结果不能覆盖新状态（任务 35）。
      if (key != _layoutKey) return;
      _relayout(measureWidth, bodyHeight);
    });
  }

  // 分页缓存上限：按章节计，超出按 LRU 淘汰最久未命中的一章（任务 32/165）。
  static const int _kPaginationCacheMax = 9;

  void _rememberPagination(String key, PaginatedChapter pagination) {
    _paginationCache[key] = pagination;
    if (_paginationCache.length > _kPaginationCacheMax) {
      _paginationCache.remove(_paginationCache.keys.first);
    }
  }

  PaginatedChapter? _cachedFor(int index) {
    final String key = '$_signature|$index';
    final PaginatedChapter? pagination = _paginationCache[key];
    if (pagination != null) {
      // 命中即刷新 LRU 顺序，让 keys.first 始终是最久未使用的键。
      _paginationCache.remove(key);
      _paginationCache[key] = pagination;
    }
    return pagination;
  }

  PaginatedChapter _computeFor(int index, double width, double height) {
    final Chapter chapter = _chapters[index];
    final PaginatedChapter pagination = ReaderEngine.paginate(
      chapterText: chapter.slice(widget.book.content),
      chapterTitle: chapter.title,
      settings: _settings,
      width: width,
      height: height,
      textScale: _textScale,
    );
    _rememberPagination('$_signature|$index', pagination);
    return pagination;
  }

  void _relayout(double width, double height) {
    if (_chapterIndex < 0 || _chapterIndex >= _chapters.length) return;
    final Chapter chapter = _chapters[_chapterIndex];
    final int savedOffset = (_anchorOffset ?? widget.book.charOffset.value)
        .clamp(0, chapter.length);
    _anchorOffset = null;
    final PaginatedChapter pagination = _cachedFor(_chapterIndex) ??
        _computeFor(_chapterIndex, width, height);
    final int page = pagination.pageForSourceOffset(savedOffset);
    _pageWidth = width;
    _pageHeight = height;
    setState(() {
      _pagination = pagination;
      _pageIndex = page;
    });
    _recreateController(page);
    _syncProgressValues(page);
    _lastSavedOffset = widget.book.charOffset.value;
    unawaited(LibraryStore.instance.saveProgress(widget.book));
    _prefetchNeighbors(width, height);
  }

  /// 相邻章预分页：空闲时算，命中缓存后跨章翻页不再有「正在排版」。
  /// 用一次性延时而不是每帧回调，避免在测试/低端机上反复触发重建。
  Timer? _prefetchTimer;
  void _prefetchNeighbors([double? width, double? height]) {
    final double w = width ?? _pageWidth;
    final double h = height ?? _pageHeight;
    if (w <= 0 || h <= 0 || _signature.isEmpty || _prefetchTimer != null) return;
    _prefetchTimer = Timer(const Duration(milliseconds: 80), () {
      _prefetchTimer = null;
      if (!mounted) return;
      bool changed = false;
      final int next = _chapterIndex + 1;
      if (next < _chapters.length && _cachedFor(next) == null &&
          _chapters[next].length <= 60000) {
        _nextPagination = _computeFor(next, w, h);
        changed = true;
      } else if (next < _chapters.length) {
        _nextPagination = _cachedFor(next);
      }
      final int prev = _chapterIndex - 1;
      if (prev >= 0 && _cachedFor(prev) == null &&
          _chapters[prev].length <= 60000) {
        _prevPagination = _computeFor(prev, w, h);
        changed = true;
      } else if (prev >= 0) {
        _prevPagination = _cachedFor(prev);
      }
      if (changed && mounted && !_menuVisible) {
        // itemCount 里多出来的相邻章页需要立刻生效。
        setState(() {});
      }
    });
  }

  void _recreateController(int columnPage) {
    final PageController? old = _pageController;
    _pageController = PageController(
      initialPage: _virtualPrevCount + _renderPageIndex(columnPage),
      // Chapter changes reconstruct the controller with an explicitly saved
      // source anchor. PageStorage must never restore an older virtual page
      // (such as the previous chapter) over this initialPage.
      keepPage: false,
    );
    _controllerEpoch++;
    // 旧控制器可能还在本帧的 PageView 上，延后一帧再释放，避免
    // "A PageController was used after being disposed"。
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  void _syncProgressValues(int columnPage) {
    widget.book.chapterIndex.value = _chapterIndex;
    widget.book.pageIndex.value = _renderPageIndex(columnPage);
    if (_pagination != null && _pagination!.pages.isNotEmpty) {
      widget.book.charOffset.value = _pagination!.pages[
              columnPage.clamp(0, _pagination!.pages.length - 1)]
          .sourceStart;
    }
  }

  /// 页码只影响页眉页脚，用 ValueNotifier 精准刷新，不触发整页 rebuild。
  void _markProgress() {
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
    _pageTick.value++;

    if (_chapters.isNotEmpty) {
      final double percent =
          (_chapterIndex + (column / math.max(1, p.pages.length))) /
              _chapters.length;
      if (percent >= 0.995) {
        ReadingStatsStore.instance.markFinished(widget.book.id);
      }
    }

    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(milliseconds: 400), _flushProgress);
  }

  void _flushProgress() {
    _progressTimer?.cancel();
    if (!mounted) return;
    unawaited(LibraryStore.instance.saveProgress(widget.book));
    AutoSyncService.instance.scheduleProgress(widget.book);
  }

  /// 立即落盘的旧入口，供朗读、退出、生命周期切换使用。
  void _saveProgress() {
    final PaginatedChapter? p = _pagination;
    if (p == null || p.pages.isEmpty) return;
    _markProgress();
    _flushProgress();
  }

  int get _renderPageCount {
    final PaginatedChapter? p = _pagination;
    if (p == null) return 0;
    return _twoColumns ? (p.pages.length + 1) ~/ 2 : p.pages.length;
  }

  int _renderPageIndex(int columnPage) =>
      _twoColumns ? columnPage ~/ 2 : columnPage;

  int get _virtualPrevCount => _chapterIndex > 0 ? 1 : 0;

  int get _currentAbsoluteOffset {
    final PaginatedChapter? p = _pagination;
    if (_chapters.isEmpty || _chapterIndex >= _chapters.length) return 0;
    if (_showScroll) {
      final Chapter chapter = _chapters[_chapterIndex];
      return chapter.start +
          widget.book.charOffset.value.clamp(0, chapter.length);
    }
    if (p == null || p.pages.isEmpty) {
      final Chapter chapter = _chapters[_chapterIndex];
      final int saved = _anchorOffset ?? widget.book.charOffset.value;
      return chapter.start + saved.clamp(0, chapter.length);
    }
    final int column = _pageIndex.clamp(0, p.pages.length - 1);
    return _chapters[_chapterIndex].start + p.pages[column].sourceStart;
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
      if (d > 0 && pos.pixels >= pos.maxScrollExtent - 2) {
        _advanceChapter(1);
        return;
      }
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
      if (_chapterIndex > 0) _advanceChapter(-1, atEnd: true);
      return;
    }
    if (targetColumn >= p.pages.length) {
      if (_chapterIndex < _chapters.length - 1) {
        _advanceChapter(1);
      } else {
        ReadingStatsStore.instance.markFinished(widget.book.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已经是最后一页')),
        );
      }
      return;
    }
    final int renderIndex = _virtualPrevCount + _renderPageIndex(targetColumn);
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
    // 不调用 setState：正文内容没变，只有页码与进度变了。
    _pageIndex = targetColumn;
    _markProgress();
  }

  /// 跨章推进：先保证目标章有分页，再一次性替换状态，避免空白页。
  void _advanceChapter(int delta, {bool atEnd = false}) {
    if (_chapterTransition) return;
    final int target = _chapterIndex + delta;
    if (target < 0 || target >= _chapters.length) return;
    _chapterTransition = true;
    _gotoChapter(target, atEnd: atEnd).whenComplete(() {
      // 只锁一个短窗口，防止同一次手势连跳两章；不再固定卡 280ms。
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        _chapterTransition = false;
      });
    });
  }

  void _onPageChanged(int renderIndex) {
    if (_chapterTransition) return;
    final int prevCount = _virtualPrevCount;
    final int pageCount = _renderPageCount;
    if (renderIndex < prevCount) {
      _advanceChapter(-1, atEnd: true);
      return;
    }
    if (renderIndex >= prevCount + pageCount) {
      _advanceChapter(1);
      return;
    }
    final int column =
        _twoColumns ? (renderIndex - prevCount) * 2 : (renderIndex - prevCount);
    if (column == _pageIndex) return;
    _pageIndex = column;
    _markProgress();
  }

  Future<void> _gotoChapter(int index, {bool atEnd = false}) async {
    if (index < 0 || index >= _chapters.length) return;
    _rememberPosition();
    final PaginatedChapter pagination =
        _cachedFor(index) ?? _computeFor(index, _pageWidth, _pageHeight);
    if (pagination.pages.isEmpty) return;
    final int page = atEnd ? pagination.pages.length - 1 : 0;
    setState(() {
      _chapterIndex = index;
      _pagination = pagination;
      _pageIndex = page;
      _layoutKey = '$_signature|$index';
      _nextPagination = null;
      _prevPagination = null;
      // Swap controller and chapter in the same state transaction: PageView
      // must not rebuild with the new chapter and the old viewport index.
      _recreateController(page);
    });
    _syncProgressValues(page);
    widget.book.charOffset.value =
        pagination.pages[page.clamp(0, pagination.pages.length - 1)].sourceStart;
    _lastSavedOffset = widget.book.charOffset.value;
    _pageTick.value++;
    _chapterTick.value++;
    // A PageView can still be attached to the previous chapter's virtual
    // neighbor while it is being rebuilt from a swipe. Reaffirm the target
    // after the new PageView mounts, and guard against stale callbacks.
    final int chapterEpoch = _controllerEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _chapterIndex != index ||
          _controllerEpoch != chapterEpoch) return;
      final controller = _pageController;
      if (controller == null || !controller.hasClients) return;
      controller.jumpToPage(
        _virtualPrevCount + _renderPageIndex(_pageIndex),
      );
    });
    await LibraryStore.instance.saveProgress(widget.book);
    AutoSyncService.instance.scheduleProgress(widget.book);
    _prefetchNeighbors();
  }

  void _advanceToNextChapter() {
    if (_chapterIndex < _chapters.length - 1) {
      _advanceChapter(1);
    }
  }

  void _jumpToAbsolute(int absoluteOffset, {bool remember = true}) {
    if (remember) _rememberPosition();
    int chapterIndex = _chapters.length - 1;
    for (int i = 0; i < _chapters.length; i++) {
      if (absoluteOffset < _chapters[i].end) {
        chapterIndex = i;
        break;
      }
    }
    final Chapter chapter = _chapters[chapterIndex];
    final int anchor = (absoluteOffset - chapter.start).clamp(0, chapter.length);
    final PaginatedChapter pagination =
        _cachedFor(chapterIndex) ?? _computeFor(chapterIndex, _pageWidth, _pageHeight);
    final int page = pagination.pageForSourceOffset(anchor);
    setState(() {
      _chapterIndex = chapterIndex;
      _pagination = pagination;
      _pageIndex = page;
      _layoutKey = '$_signature|$chapterIndex';
      _nextPagination = null;
      _prevPagination = null;
      widget.book.chapterIndex.value = chapterIndex;
      widget.book.pageIndex.value = _renderPageIndex(page);
      widget.book.charOffset.value = anchor;
    });
    _recreateController(page);
    _chapterTick.value++;
    _lastSavedOffset = anchor;
    unawaited(LibraryStore.instance.saveProgress(widget.book));
    _prefetchNeighbors();
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _chapterTick,
      builder: (BuildContext context, int _, Widget? __) {
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
                          // 页码/进度只在这里刷新，翻页不再重建正文。
                          ValueListenableBuilder<int>(
                            valueListenable: _pageTick,
                            builder: (BuildContext context, int _, Widget? __) =>
                                _buildHeader(secondary),
                          ),
                          Expanded(
                            child: _buildTapLayer(
                              _buildPageArea(foreground, secondary),
                            ),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _pageTick,
                            builder: (BuildContext context, int _, Widget? __) =>
                                _buildFooter(secondary),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _buildMenu(background, foreground, secondary),
          _buildBrightnessOverlay(),
        ],
      ),
    );
      },
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
    // Android uses the actual window brightness, without a dark overlay.
    if (Platform.isAndroid) return const SizedBox.shrink();
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
        .replaceAll('{battery}', _batteryLevel == null ? '--' : '${_batteryLevel}%')
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
    final int pageCount = _renderPageCount;
    final int prevCount = _virtualPrevCount;
    final bool hasNextChapter = _chapterIndex < _chapters.length - 1;
    return PageView.builder(
      // 换 controller 时用新 key 重建，避免 PageView 内部页码与控制器不一致。
      key: ValueKey<int>(_controllerEpoch),
      controller: controller,
      reverse: _settings.reverseDirection,
      itemCount: prevCount + pageCount + (hasNextChapter ? 1 : 0),
      physics: _settings.pageTurnMode == 'none'
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      onPageChanged: _onPageChanged,
      itemBuilder: (BuildContext context, int renderIndex) {
        if (renderIndex < prevCount) {
          final PaginatedChapter? prev = _prevPagination;
          if (prev == null || prev.pages.isEmpty) {
            return const SizedBox.shrink();
          }
          final int lastRender =
              _twoColumns ? ((prev.pages.length + 1) ~/ 2) - 1 : prev.pages.length - 1;
          return _withGuides(
            _twoColumns
                ? _buildTwoColumnPage(prev, lastRender, foreground,
                    chapterIndex: _chapterIndex - 1)
                : _buildSinglePage(prev, lastRender, foreground,
                    chapterIndex: _chapterIndex - 1),
            secondary,
          );
        }
        if (renderIndex >= prevCount + pageCount) {
          final PaginatedChapter? next = _nextPagination;
          if (next == null || next.pages.isEmpty) {
            return _buildChapterTransitionPage(foreground, secondary);
          }
          return _withGuides(
            _twoColumns
                ? _buildTwoColumnPage(next, 0, foreground,
                    chapterIndex: _chapterIndex + 1)
                : _buildSinglePage(next, 0, foreground,
                    chapterIndex: _chapterIndex + 1),
            secondary,
          );
        }
        final int localIndex = renderIndex - prevCount;
        final Widget page = _twoColumns
            ? _buildTwoColumnPage(p, localIndex, foreground)
            : _buildSinglePage(p, localIndex, foreground);
        final Widget guided = _withGuides(page, secondary);
        if (_settings.pageTurnMode != 'cover' || controller == null) {
          return guided;
        }
        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            double delta = 0;
            if (controller.hasClients && controller.position.haveDimensions) {
              delta = (controller.page ?? renderIndex.toDouble()) -
                  renderIndex.toDouble();
            }
            // 翻页动画只用透明度过渡，不做任何缩放或额外平移：
            // Transform.scale 会把正文压成窄条，Transform.translate 会让
            // 正文向边缘漂移，二者都会破坏分页后的排版宽度。
            return Opacity(
              opacity: (1 - delta.abs() * 0.22).clamp(0, 1),
              child: child,
            );
          },
          child: guided,
        );
      },
    );
  }

  Widget _buildChapterTransitionPage(Color foreground, Color secondary) {
    if (_chapterIndex + 1 >= _chapters.length) {
      return const SizedBox.shrink();
    }
    final next = _chapters[_chapterIndex + 1];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ReadIcon(ReadGlyph.book, size: 34, color: secondary),
            const SizedBox(height: 12),
            Text('下一章',
                style: TextStyle(fontSize: 12, color: secondary)),
            const SizedBox(height: 4),
            Text(
              next.title.trim().isEmpty ? '第 ${_chapterIndex + 2} 章' : next.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
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

  Widget _selectablePage(
    PaginatedChapter chapter,
    EnginePage page,
    TextStyle style, {
    required int chapterIndex,
  }) {
    final displayText = page.textOf(chapter.display);
    return SelectableText.rich(
      _highlightedSpan(chapter, page, style, chapterIndex),
      textAlign: ReaderEngine.textAlignOf(_settings.align),
      contextMenuBuilder: (BuildContext ctx, EditableTextState editableState) {
        final selection = editableState.textEditingValue.selection;
        final canUse = selection.isValid && !selection.isCollapsed;
        return AdaptiveTextSelectionToolbar(
          anchors: editableState.contextMenuAnchors,
          children: <Widget>[
            TextSelectionToolbarTextButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () => editableState.copySelection(
                SelectionChangedCause.toolbar,
              ),
              child: const Text('复制'),
            ),
            if (canUse) ...<Widget>[
              TextSelectionToolbarTextButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () {
                  editableState.hideToolbar();
                  unawaited(_saveSelectionHighlight(
                    chapter,
                    page,
                    selection,
                    chapterIndex: chapterIndex,
                    note: '',
                  ));
                },
                child: const Text('高亮'),
              ),
              TextSelectionToolbarTextButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () async {
                  editableState.hideToolbar();
                  final note = await _askNote(displayText, selection, page);
                  if (note == null || !mounted) return;
                  await _saveSelectionHighlight(
                    chapter,
                    page,
                    selection,
                    chapterIndex: chapterIndex,
                    note: note,
                  );
                },
                child: const Text('笔记'),
              ),
            ],
            if (_highlights.isNotEmpty)
              TextSelectionToolbarTextButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () {
                  editableState.hideToolbar();
                  _manageHighlights();
                },
                child: const Text('高亮记录'),
              ),
          ],
        );
      },
    );
  }

  TextSpan _highlightedSpan(
    PaginatedChapter chapter,
    EnginePage page,
    TextStyle style,
    int chapterIndex,
  ) {
    final text = page.textOf(chapter.display);
    if (text.isEmpty) return TextSpan(text: text, style: style);
    final chapterStart = _chapters[chapterIndex].start;
    final chapterLength = _chapters[chapterIndex].length;
    // Each highlight is a *range*. The previous code appended identical
    // start/end points to two parallel lists, creating zero-length intervals
    // and silently rendering every highlight as normal text.
    final ranges = <({int start, int end, Color color})>[];
    final boundaries = <int>{0, text.length};
    for (final highlight in _highlights) {
      final sourceStart =
          (highlight.start - chapterStart).clamp(0, chapterLength);
      final sourceEnd =
          (highlight.end - chapterStart).clamp(0, chapterLength);
      if (sourceEnd <= sourceStart) continue;
      final displayStart = chapter.display.displayOffset(sourceStart);
      final displayEnd = chapter.display.displayOffset(sourceEnd);
      final localStart =
          (displayStart - page.displayStart).clamp(0, text.length);
      final localEnd =
          (displayEnd - page.displayStart).clamp(0, text.length);
      if (localEnd <= localStart) continue;
      ranges.add((
        start: localStart,
        end: localEnd,
        color: Color(highlight.color),
      ));
      boundaries.add(localStart);
      boundaries.add(localEnd);
    }
    final sorted = boundaries.toList()..sort();
    final spans = <InlineSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (end <= start) continue;
      Color? background;
      for (final range in ranges) {
        if (start >= range.start && end <= range.end) {
          background = range.color;
          break;
        }
      }
      final regex = _boldRegex();
      bool bold = false;
      if (regex != null) {
        final lineStart = text.lastIndexOf('\n', start > 0 ? start - 1 : 0);
        final lineEnd = text.indexOf('\n', end);
        final line = text.substring(
          lineStart < 0 ? 0 : lineStart + 1,
          lineEnd < 0 ? text.length : lineEnd,
        );
        bold = line.trim().isNotEmpty && regex.hasMatch(line);
      }
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: style.copyWith(
          fontWeight: bold ? FontWeight.w700 : null,
          backgroundColor: background?.withValues(alpha: 0.42),
        ),
      ));
    }
    return TextSpan(children: spans);
  }

  RegExp? _boldRegex() {
    final pattern = _settings.boldPattern.trim();
    if (pattern.isEmpty) return null;
    try {
      return RegExp(pattern);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _askNote(
    String displayText,
    TextSelection selection,
    EnginePage page,
  ) async {
    final selected = selection.isValid
        ? displayText.substring(
            selection.start.clamp(0, displayText.length),
            selection.end.clamp(0, displayText.length),
          )
        : '';
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('添加笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              selected.length > 160 ? '${selected.substring(0, 160)}…' : selected,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '写下想法（可留空，仅高亮）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return note;
  }

  Future<void> _saveSelectionHighlight(
    PaginatedChapter chapter,
    EnginePage page,
    TextSelection selection, {
    required int chapterIndex,
    required String note,
  }) async {
    if (!selection.isValid || selection.isCollapsed) return;
    final text = page.textOf(chapter.display);
    final localStart = selection.start.clamp(0, text.length);
    final localEnd = selection.end.clamp(0, text.length);
    if (localEnd <= localStart) return;
    final chapterStart = _chapters[chapterIndex].start;
    final sourceStart = chapter.display.sourceOffset(page.displayStart + localStart);
    final sourceEnd = chapter.display.sourceOffset(page.displayEnd - (text.length - localEnd));
    final record = HighlightRecord(
      start: chapterStart + sourceStart,
      end: chapterStart + math.max(sourceStart + 1, sourceEnd),
      color: 0xFFFFE082,
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final values = await HighlightStore.add(widget.book.id, record);
    if (mounted) {
      setState(() => _highlights = values);
      _showToast(note.isEmpty ? '已高亮' : '已保存笔记');
    }
  }

  Future<void> _manageHighlights() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) => ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: Text('高亮与笔记（${_highlights.length}）'),
              subtitle: const Text('按原文字符锚点保存，换字号后仍能定位'),
            ),
            for (final highlight in _highlights)
              ListTile(
                leading: const ReadIcon(ReadGlyph.quote, size: 20),
                title: Text(
                  highlight.note.isEmpty ? '高亮' : highlight.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '字符 ${highlight.start}–${highlight.end}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const ReadIcon(ReadGlyph.trash, size: 20),
                  onPressed: () async {
                    await HighlightStore.remove(widget.book.id, highlight);
                    final values = await HighlightStore.load(widget.book.id);
                    if (mounted) setState(() => _highlights = values);
                    setSheetState(() {});
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scaledText(Widget child) {
    if ((_settings.textScaleX - 1).abs() < 0.001) return child;
    return Transform.scale(
      scaleX: _settings.textScaleX,
      alignment: Alignment.topLeft,
      child: child,
    );
  }

  Widget _buildSinglePage(
    PaginatedChapter p,
    int index,
    Color foreground, {
    int? chapterIndex,
  }) {
    final int renderedChapter = chapterIndex ?? _chapterIndex;
    if (index < 0 || index >= p.pages.length) return const SizedBox.shrink();
    final EnginePage page = p.pages[index];
    final List<Widget> children = <Widget>[];
    if (index == 0 && p.showTitle) {
      children.add(_buildChapterTitle(renderedChapter, p.titleHeight));
    }
    final TextStyle style = ReaderEngine.bodyStyle(
      _settings,
      color: foreground,
      textScale: _textScale,
    );
    final Widget body = _scaledText(
      _selectablePage(p, page, style, chapterIndex: renderedChapter),
    );
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
    PaginatedChapter p,
    int renderIndex,
    Color foreground, {
    int? chapterIndex,
  }) {
    final int renderedChapter = chapterIndex ?? _chapterIndex;
    final int leftIndex = renderIndex * 2;
    final int rightIndex = leftIndex + 1;
    Widget column(int index) {
      if (index >= p.pages.length) return const SizedBox.shrink();
      final EnginePage page = p.pages[index];
      final List<Widget> children = <Widget>[];
      if (index == 0 && p.showTitle) {
        children.add(_buildChapterTitle(renderedChapter, p.titleHeight));
      }
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
            child: _scaledText(_selectablePage(p, page, style,
                chapterIndex: renderedChapter)),
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

  Widget _buildChapterTitle(int chapterIndex, double titleHeight) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length ||
        titleHeight <= 0) {
      return const SizedBox.shrink();
    }
    final String title = _chapters[chapterIndex].title;
    final ReaderTheme theme = _store.effectiveTheme(
      _settings,
      MediaQuery.platformBrightnessOf(context),
    );
    final Color color = Color(
      _settings.titleColor ?? _settings.textColor ?? theme.foreground,
    );
    final TextAlign align = switch (_settings.titleAlign) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
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
          if (controller.hasClients &&
              controller.position.maxScrollExtent > 0 &&
              controller.offset >= controller.position.maxScrollExtent - 2) {
            _advanceToNextChapter();
          }
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (p.showTitle)
              _buildChapterTitle(_chapterIndex, p.titleHeight),
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

  /// The tap recognizer must wrap the actual page rather than sit above it
  /// as a full-screen Stack overlay. Overlays intercept hit testing and make
  /// PageView swipes and long-press text selection impossible.
  Widget _buildTapLayer(Widget page) {
    // 用 Listener 而非 GestureDetector：SelectableText 内部的点击手势会在
    // 手势竞技场里抢走 tap，导致"点击翻页"失效。原始指针事件不参与竞技场，
    // 因此点击翻页始终可靠，同时拖动交给 PageView、长按交给文本选择。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent event) {
        _tapDownPosition = event.localPosition;
        _tapDownTime = DateTime.now();
      },
      onPointerUp: (PointerUpEvent event) {
        final Offset? down = _tapDownPosition;
        final DateTime? downTime = _tapDownTime;
        _tapDownPosition = null;
        _tapDownTime = null;
        if (down == null || downTime == null) return;
        // 位移超过阈值视为拖动（交给 PageView/滚动），不当作点击。
        if ((event.localPosition - down).distance > 12) return;
        // 按住过久视为长按（交给文本选择），不当作点击。
        if (DateTime.now().difference(downTime) >
            const Duration(milliseconds: 500)) {
          return;
        }
        // In dual-column mode _pageWidth measures a single column. Tap
        // zones must span the entire visible page rather than half of it.
        final double width = _pageWidth > 0
            ? (_twoColumns ? _pageWidth * 2 + _settings.columnGap : _pageWidth)
            : MediaQuery.sizeOf(context).width;
        final double x = down.dx;
        final String action = x < width * 0.3
            ? _settings.tapLeft
            : x > width * 0.7
                ? _settings.tapRight
                : _settings.tapCenter;
        _performTapAction(action);
      },
      child: page,
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

  ReadGlyph get _syncIcon {
    if (!SyncConfig.instance.configured) return ReadGlyph.cloudOff;
    if (_cloudRecord == null) return ReadGlyph.cloud;
    final cloud = _cloudRecord!;
    final bool same;
    if (cloud.format == 'PDF') {
      same = cloud.page == widget.book.pageIndex.value;
    } else {
      same = cloud.offset == _currentAbsoluteOffset;
    }
    return same ? ReadGlyph.cloudCheck : ReadGlyph.cloudDownload;
  }

  String get _syncTooltip {
    if (!SyncConfig.instance.configured) return '未配置云存储';
    if (_cloudBusy) return '正在读取云端进度';
    if (_cloudRecord == null) return '云端暂无本书进度';
    final cloud = _cloudRecord!;
    final bool same = cloud.format == 'PDF'
        ? cloud.page == widget.book.pageIndex.value
        : cloud.offset == _currentAbsoluteOffset;
    return same ? '本机与云端进度一致' : '云端有不同进度，点击查看';
  }

  Widget _topBar(Color background, Color foreground) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '返回',
            icon: ReadIcon(ReadGlyph.arrowLeft, size: 20, color: foreground),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: '章节：${_chapterIndex < _chapters.length ? _chapters[_chapterIndex].title : widget.book.title}，点击打开目录',
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
          ),
          IconButton(
            tooltip: '书内搜索',
            icon: ReadIcon(ReadGlyph.search, size: 20, color: foreground),
            onPressed: _searchInBook,
          ),
          // Keep the main toolbar narrow enough for a real phone. Secondary
          // actions stay available with labels and do not squeeze the title.
          IconButton(
            tooltip: '阅读设置',
            icon: ReadIcon(ReadGlyph.type, size: 20, color: foreground),
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            tooltip: '更多阅读操作',
            icon: ReadIcon(ReadGlyph.ellipsis, size: 20, color: foreground),
            onSelected: (String action) {
              switch (action) {
                case 'bookmark':
                  _toggleBookmark();
                case 'history':
                  _goBackPosition();
                case 'tts':
                  _openTtsSheet();
                case 'sync':
                  _openSyncMenu();
              }
            },
            itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'bookmark',
                child: Text('添加或移除书签'),
              ),
              if (_positionHistory.isNotEmpty)
                const PopupMenuItem<String>(
                  value: 'history',
                  child: Text('返回上一个位置'),
                ),
              const PopupMenuItem<String>(
                value: 'tts',
                child: Text('朗读设置'),
              ),
              if (SyncConfig.instance.showReaderSyncButton)
                PopupMenuItem<String>(
                  value: 'sync',
                  child: Row(
                    children: <Widget>[
                      ReadIcon(_syncIcon, size: 18, color: foreground),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_syncTooltip)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(Color background, Color foreground, Color secondary) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
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
              ],
            ),
            // Keep action buttons on a separate row to protect slider
            // accessibility and hit targets on compact phones.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                for (final action in _settings.bottomActions)
                  IconButton(
                    tooltip: switch (action) {
                      'toc' => '目录',
                      'bookmark' => '书签',
                      'search' => '书内搜索',
                      _ => '阅读设置',
                    },
                    icon: ReadIcon(
                      switch (action) {
                        'toc' => ReadGlyph.toc,
                        'bookmark' => ReadGlyph.bookmark,
                        'search' => ReadGlyph.search,
                        _ => ReadGlyph.type,
                      },
                      size: 20,
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
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
      builder: (BuildContext ctx) => ReaderSettingsSheet(
        bookId: widget.book.id,
        // 只让版式签名失效，不把分页清空：新结果算好后再替换，
        // 这样连续拖字号时不会闪白，也不会反复重建控制器。
        onRepaginate: () => setState(() {
          _layoutKey = '';
        }),
      ),
    );
  }

  void _rememberPosition() {
    if (_chapters.isEmpty || _pagination == null) return;
    final current = _currentAbsoluteOffset;
    if (_positionHistory.isNotEmpty && _positionHistory.last == current) return;
    _positionHistory.add(current);
    if (_positionHistory.length > 20) _positionHistory.removeAt(0);
  }

  Future<void> _goBackPosition() async {
    if (_positionHistory.isEmpty) return;
    final target = _positionHistory.removeLast();
    _jumpToAbsolute(target, remember: false);
    _showToast('已返回上一个阅读位置');
  }

  String _describePosition(int offset, int page, String format) {
    if (format.toUpperCase() == 'PDF') return '第 ${page + 1} 页';
    if (_chapters.isEmpty || widget.book.content.isEmpty) return '暂无位置';
    int index = _chapters.length - 1;
    for (int i = 0; i < _chapters.length; i++) {
      if (offset < _chapters[i].end) {
        index = i;
        break;
      }
    }
    final percent =
        (offset / widget.book.content.length * 100).clamp(0, 100);
    return '第 ${index + 1} 章 ${_chapters[index].title.trim()} · '
        '${percent.toStringAsFixed(2)}%';
  }

  Future<void> _openSyncMenu() async {
    setState(() => _menuVisible = false);
    await _refreshCloudProgress();
    if (!mounted) return;
    final configured = SyncConfig.instance.configured;
    final localText = _describePosition(
      _currentAbsoluteOffset,
      widget.book.pageIndex.value,
      widget.book.format,
    );
    final cloud = _cloudRecord;
    final cloudText = cloud == null
        ? (configured ? '云端暂无本书进度' : '尚未配置云存储')
        : _describePosition(cloud.offset, cloud.page, cloud.format);
    final cloudDevice = cloud == null
        ? ''
        : '${cloud.device.length > 10 ? '${cloud.device.substring(0, 10)}…' : cloud.device}'
            ' · ${DateTime.fromMillisecondsSinceEpoch(cloud.updatedAt).toString().substring(0, 16)}';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text('阅读进度同步',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                    if (_cloudBusy)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        tooltip: '刷新云端进度',
                        icon: const ReadIcon(ReadGlyph.refresh, size: 19),
                        onPressed: () => Navigator.pop(ctx, 'refresh'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('本机进度',
                          style: TextStyle(
                              fontSize: 11, color: theme.hintColor)),
                      const SizedBox(height: 3),
                      Text(localText,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 10),
                      Text('云端进度',
                          style: TextStyle(
                              fontSize: 11, color: theme.hintColor)),
                      const SizedBox(height: 3),
                      Text(cloudText, style: const TextStyle(fontSize: 13)),
                      if (cloudDevice.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(cloudDevice,
                            style: TextStyle(
                                fontSize: 11, color: theme.hintColor)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: configured
                            ? () => Navigator.pop(ctx, 'push')
                            : () => Navigator.pop(ctx, 'settings'),
                        icon: const ReadIcon(ReadGlyph.cloudUpload, size: 18),
                        label: const Text('同步本机'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: cloud == null
                            ? null
                            : () => Navigator.pop(ctx, 'pull'),
                        icon: const ReadIcon(ReadGlyph.cloudDownload, size: 18),
                        label: const Text('采用云端'),
                      ),
                    ),
                  ],
                ),
                if (!configured)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('尚未配置 WebDAV / S3；配置后才能读取云端进度。',
                        style:
                            TextStyle(fontSize: 11, color: theme.hintColor)),
                  ),
                const SizedBox(height: 6),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const ReadIcon(ReadGlyph.sync, size: 20),
                  title: const Text('完整同步书库'),
                  subtitle: Text(SyncConfig.instance.syncFiles
                      ? '数据 + 可选图书原文件（文件会加密上传）'
                      : '数据：书籍信息、书签、笔记、设置；不含图书文件'),
                  trailing: const ReadIcon(ReadGlyph.chevronRight, size: 18),
                  onTap: () => Navigator.pop(ctx, 'full'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const ReadIcon(ReadGlyph.settings, size: 20),
                  title: const Text('云存储与同步范围'),
                  subtitle: const Text('WebDAV / S3、自动同步、文件与数据分开控制'),
                  trailing: const ReadIcon(ReadGlyph.chevronRight, size: 18),
                  onTap: () => Navigator.pop(ctx, 'settings'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    if (action == 'refresh') {
      await _refreshCloudProgress();
    } else if (action == 'push') {
      await _manualProgressSync();
    } else if (action == 'pull') {
      await _manualProgressSync(force: ProgressChoice.cloud);
    } else if (action == 'full') {
      if (!SyncConfig.instance.configured) {
        _showToast('请先在“我的 → 同步”配置云存储');
        return;
      }
      _showToast('正在完整同步…');
      try {
        final report = await AutoSyncService.instance.runFull(
          downloadMissing: SyncConfig.instance.syncFiles,
        );
        if (mounted) _showToast(report?.message ?? '没有需要同步的变化');
        unawaited(_refreshCloudProgress());
      } catch (error) {
        if (mounted) _showToast('完整同步失败：$error');
      }
    } else if (action == 'settings') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SyncPage()),
      );
      unawaited(_refreshCloudProgress());
    }
  }

  // ---------------------------------------------------------------------------
  // 朗读（本页 / 连续）
  // ---------------------------------------------------------------------------

  Future<void> _openTtsSheet() async {
    setState(() => _menuVisible = false);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const ReadIcon(ReadGlyph.headphones, size: 20),
                  title: const Text('朗读本页'),
                  subtitle: const Text('使用系统 TTS 引擎，不读取书外内容'),
                  onTap: () => Navigator.pop(ctx, 'page'),
                ),
                ListTile(
                  leading: const ReadIcon(ReadGlyph.play, size: 20),
                  title: const Text('连续朗读'),
                  subtitle: const Text('读完后自动翻页，直到章节结尾'),
                  onTap: () => Navigator.pop(ctx, 'continuous'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: <Widget>[
                      const Text('语速'),
                      Expanded(
                        child: Slider(
                          value: _ttsSpeed,
                          min: 0.25,
                          max: 1.0,
                          divisions: 15,
                          onChanged: (double value) {
                            _ttsSpeed = value;
                            setSheetState(() {});
                          },
                        ),
                      ),
                      Text(_ttsSpeed.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (_speaking || _ttsPaused)
                  ListTile(
                    leading: ReadIcon(
                        _ttsPaused ? ReadGlyph.play : ReadGlyph.pause,
                        size: 20),
                    title: Text(_ttsPaused ? '继续朗读' : '暂停朗读'),
                    onTap: () => Navigator.pop(ctx, _ttsPaused ? 'resume' : 'pause'),
                  ),
                if (_speaking || _ttsPaused)
                  ListTile(
                    leading: const ReadIcon(ReadGlyph.stop, size: 20),
                    title: const Text('停止朗读'),
                    onTap: () => Navigator.pop(ctx, 'stop'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'page':
        _ttsContinuous = false;
        await _speakCurrent();
      case 'continuous':
        _ttsContinuous = true;
        await _speakCurrent();
      case 'pause':
        _saveProgress();
        await _tts.pause();
        if (mounted) {
          setState(() {
            _speaking = false;
            _ttsPaused = true;
          });
        }
      case 'resume':
        _ttsPaused = false;
        await _speakCurrent();
      case 'stop':
        _saveProgress();
        _ttsContinuous = false;
        _ttsPaused = false;
        await _tts.stop();
        if (mounted) setState(() => _speaking = false);
    }
  }

  String _currentPageText() {
    final pagination = _pagination;
    if (pagination == null || pagination.pages.isEmpty) {
      final chapter = _chapters[_chapterIndex];
      final start = (widget.book.charOffset.value >= 0
              ? widget.book.charOffset.value
              : 0)
          .clamp(0, chapter.length);
      final end = math.min(chapter.length, start + 1800);
      return chapter.slice(widget.book.content).substring(start, end).trim();
    }
    final page = pagination.pages[_pageIndex.clamp(0, pagination.pages.length - 1)];
    final chapter = _chapters[_chapterIndex];
    final start = page.sourceStart.clamp(0, chapter.length);
    final end = page.sourceEnd.clamp(start, chapter.length);
    return chapter.slice(widget.book.content).substring(start, end).trim();
  }

  Future<void> _speakCurrent() async {
    _saveProgress();
    final text = _currentPageText();
    if (text.isEmpty) {
      _showToast('当前页没有可朗读的文字');
      return;
    }
    try {
      await _tts.stop();
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(_ttsSpeed);
      await _tts.speak(text);
      if (mounted) {
        setState(() {
          _speaking = true;
          _ttsPaused = false;
        });
      }
    } catch (error) {
      _ttsContinuous = false;
      if (mounted) {
        setState(() => _speaking = false);
        _showToast('系统 TTS 不可用：$error');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 章节调整 / 书签 / 搜索
  // ---------------------------------------------------------------------------

  Future<void> _showChapters() async {
    final String? query = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _ChapterSheet(
        chapters: _chapters,
        currentIndex: _chapterIndex,
      ),
    );
    if (!mounted || query == null) return;
    final int? selected = int.tryParse(query);
    if (selected != null && selected >= 0 && selected < _chapters.length) {
      if (selected != _chapterIndex) await _gotoChapter(selected);
    } else if (query == 'rules') {
      await _showChapterRules();
    } else if (query == 'manual') {
      await _addManualChapter();
    } else if (query.startsWith('remove:')) {
      final offset = int.tryParse(query.substring('remove:'.length));
      if (offset != null) await _removeManualChapter(offset);
    }
  }

  Future<void> _addManualChapter() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('从当前位置新增章节'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '章节标题',
            hintText: '留空则使用“手动章节”',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('新增'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) return;
    final offset = _currentAbsoluteOffset;
    await ManualChapterStore.add(widget.book.id, offset, title);
    await _reloadChapters(anchor: offset);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已在当前位置新增章节'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _removeManualChapter(int offset) async {
    await ManualChapterStore.remove(widget.book.id, offset);
    final absolute = _currentAbsoluteOffset;
    await _reloadChapters(anchor: absolute);
  }

  Future<void> _reloadChapters({required int anchor}) async {
    final marks = await ManualChapterStore.load(widget.book.id);
    final next = applyManualChapters(
      widget.book.content,
      splitChapters(widget.book.content, rule: _rule),
      marks,
    );
    if (!mounted || next.isEmpty) return;
    int index = next.length - 1;
    for (int i = 0; i < next.length; i++) {
      if (anchor < next[i].end) {
        index = i;
        break;
      }
    }
    setState(() {
      _chapters = next;
      _chapterIndex = index;
      _pageIndex = 0;
      _anchorOffset = (anchor - next[index].start).clamp(0, next[index].length);
      _pagination = null;
      _layoutKey = '';
      widget.book.chapterIndex.value = index;
      widget.book.pageIndex.value = 0;
      widget.book.charOffset.value = _anchorOffset!;
    });
    _lastSavedOffset = _anchorOffset!;
    LibraryStore.instance.noteChapterCount(widget.book, next.length);
    LibraryStore.instance.saveProgress(widget.book);
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
      final marks = await ManualChapterStore.load(widget.book.id);
      final List<Chapter> next = applyManualChapters(
        widget.book.content,
        splitChapters(widget.book.content, rule: selected),
        marks,
      );
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
    final Map<int, BookmarkMeta> metas =
        await BookmarkMetaStore.load(widget.book.id);
    if (!mounted) return;
    final int? position = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.65,
          child: Column(
            children: <Widget>[
              const ListTile(
                title: Text('我的书签',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                subtitle: Text('按书籍中的位置排列，可添加备注'),
              ),
              Expanded(
                child: _bookmarks.isEmpty
                    ? const Center(child: Text('还没有书签，阅读时点右上角即可添加'))
                    : ListView.builder(
                        itemCount: _bookmarks.length,
                        itemBuilder: (BuildContext context, int index) {
                          final int offset = _bookmarks[index];
                          final BookmarkMeta? meta = metas[offset];
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
                            leading: const ReadIcon(ReadGlyph.bookmark, size: 20),
                            title: Text(
                              preview.isEmpty ? '书签位置' : preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              meta == null || meta.note.isEmpty
                                  ? '位置 ${offset + 1}'
                                  : '位置 ${offset + 1} · ${meta.note}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: '编辑备注',
                              icon: const ReadIcon(ReadGlyph.note, size: 20),
                              onPressed: () async {
                                final note = await _askBookmarkNote(meta?.note ?? '');
                                if (note == null || !mounted) return;
                                await BookmarkMetaStore.setNote(
                                    widget.book.id, offset, note);
                                metas[offset] = BookmarkMeta(
                                  offset: offset,
                                  createdAt: meta?.createdAt ??
                                      DateTime.now().millisecondsSinceEpoch,
                                  note: note,
                                );
                                setSheetState(() {});
                              },
                            ),
                            onTap: () => Navigator.pop(ctx, offset),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
    if (!mounted || position == null) return;
    _jumpToAbsolute(position);
  }

  Future<String?> _askBookmarkNote(String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('书签备注'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '写下这一处为什么值得记住',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
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
    final int origin = _currentAbsoluteOffset;
    _jumpToAbsolute(hit.start);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已跳到“${hit.snippet}”'),
          action: SnackBarAction(
            label: '返回原位置',
            onPressed: () => _jumpToAbsolute(origin),
          ),
        ),
      );
  }
}

class _ChapterSheet extends StatefulWidget {
  const _ChapterSheet({required this.chapters, required this.currentIndex});
  final List<Chapter> chapters;
  final int currentIndex;

  @override
  State<_ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends State<_ChapterSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = (widget.currentIndex * 56.0)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final term = _query.trim().toLowerCase();
    final indices = <int>[
      for (var i = 0; i < widget.chapters.length; i++)
        if (term.isEmpty || widget.chapters[i].title.toLowerCase().contains(term)) i,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      builder: (BuildContext ctx, ScrollController dragScroll) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: <Widget>[
                Text('目录', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(width: 8),
                Text('${widget.chapters.length} 章 · 当前第 ${widget.currentIndex + 1} 章',
                    style: TextStyle(fontSize: 11, color: palette.muted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '搜索章节标题',
                prefixIcon: const ReadIcon(ReadGlyph.search, size: 18),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const ReadIcon(ReadGlyph.close, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _query.isEmpty ? _scroll : dragScroll,
              itemCount: indices.length + 1,
              itemBuilder: (BuildContext c, int listIndex) {
                if (listIndex == indices.length) {
                  return Column(
                    children: <Widget>[
                      ListTile(
                        leading: const ReadIcon(ReadGlyph.plus, size: 20),
                        title: const Text('从当前位置新增章节'),
                        subtitle: const Text('手动修正目录边界，不改原文'),
                        onTap: () => Navigator.pop(ctx, 'manual'),
                      ),
                      ListTile(
                        leading: const ReadIcon(ReadGlyph.type, size: 20),
                        title: const Text('章节识别规则'),
                        subtitle: const Text('自动 / 整本一章 / 自定义正则'),
                        onTap: () => Navigator.pop(ctx, 'rules'),
                      ),
                    ],
                  );
                }
                final index = indices[listIndex];
                final chapter = widget.chapters[index];
                final selected = index == widget.currentIndex;
                return ListTile(
                  selected: selected,
                  selectedTileColor: palette.surface,
                  leading: SizedBox(
                    width: 34,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? palette.ink : palette.muted,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: chapter.manual
                      ? IconButton(
                          tooltip: '删除手动章节',
                          icon: const ReadIcon(ReadGlyph.trash, size: 18),
                          onPressed: () =>
                              Navigator.pop(ctx, 'remove:${chapter.start}'),
                        )
                      : selected
                          ? Text('阅读中',
                              style: TextStyle(fontSize: 10, color: palette.muted))
                          : null,
                  onTap: () => Navigator.pop(ctx, '$index'),
                );
              },
            ),
          ),
        ],
      ),
    );
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
            icon: const ReadIcon(ReadGlyph.close, size: 22),
            onPressed: () {
              query = '';
              showSuggestions(context);
            },
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        tooltip: '返回',
        icon: const ReadIcon(ReadGlyph.arrowLeft, size: 22),
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
          subtitle: Text.rich(
            _highlightSnippet(context, match.snippet),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => close(context, match),
        );
      },
    );
  }

  TextSpan _highlightSnippet(BuildContext context, String snippet) {
    final textStyle = Theme.of(context).textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return TextSpan(text: snippet, style: textStyle);
    }
    final lower = snippet.toLowerCase();
    final target = keyword.toLowerCase();
    final spans = <InlineSpan>[];
    int start = 0;
    while (true) {
      final hit = lower.indexOf(target, start);
      if (hit < 0) break;
      if (hit > start) {
        spans.add(TextSpan(text: snippet.substring(start, hit)));
      }
      spans.add(TextSpan(
        text: snippet.substring(hit, hit + keyword.length),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      start = hit + keyword.length;
    }
    if (start < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(start)));
    }
    return TextSpan(style: textStyle, children: spans);
  }
}
