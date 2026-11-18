import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/bookshelf/book_detail_page.dart';
import 'package:read/src/bookshelf/book_edit_page.dart';
import 'package:read/src/bookshelf/cover_art.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/more/import_tools.dart';
import 'package:read/src/more/taxonomy_page.dart';
import 'package:read/src/sync/data_tools_page.dart';
import 'package:read/src/more/wifi_transfer_page.dart';
import 'package:read/src/reader/pdf_reader_page.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/cloud_presence.dart';
import 'package:read/src/services/collection_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/services/shelf_settings.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/ui/sheet.dart';

/// 书架：点封面直接进阅读器，长按进选择模式，右上角是完整书架菜单。
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

enum _ShelfFilter { all, reading, finished, unread, pinned }

class _BookshelfPageState extends State<BookshelfPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _term = '';
  bool _grid = true;
  _ShelfFilter _filter = _ShelfFilter.all;
  String? _collection;
  String? _tag;
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    // 云端状态只用于显示云朵，失败也不影响书架本身。
    if (LibraryStore.instance.books.isNotEmpty) {
      CloudPresence.instance.refresh();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        LibraryStore.instance,
        ShelfSettings.instance,
        CloudPresence.instance,
        CollectionStore.instance,
        ReadingStatsStore.instance,
      ]),
      builder: (BuildContext context, Widget? _) {
        final LibraryStore store = LibraryStore.instance;
        final List<Book> visible = _visibleBooks(store);
        final int total = store.books.length;

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _header(palette, total),
                _searchBar(palette, total),
                _filterRow(palette, store),
                if (store.allCollections.isNotEmpty) _collectionRow(palette, store),
                Expanded(
                  child: visible.isEmpty
                      ? _empty(palette)
                      : LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints bounds) {
                            return _grid
                                ? _gridView(palette, visible, bounds.maxWidth)
                                : _listView(palette, visible);
                          },
                        ),
                ),
                if (_selecting)
                  _selectionBar(palette, store)
                else
                  _countLine(palette, total, visible.length),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 顶部
  // ---------------------------------------------------------------------------

  Widget _header(ReadPalette palette, int total) {
    if (_selecting) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: '退出选择',
              icon: ReadIcon(ReadGlyph.close, size: 20, color: palette.ink),
              onPressed: _exitSelection,
            ),
            Expanded(
              child: Text(
                '已选 ${_selected.length} 本',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: palette.ink),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                final List<Book> visible = _visibleBooks(LibraryStore.instance);
                if (_selected.length == visible.length) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(visible.map((Book b) => b.id));
                }
              }),
              child: Text(
                _selected.length == _visibleBooks(LibraryStore.instance).length
                    ? '取消全选'
                    : '全选',
                style: TextStyle(color: palette.ink),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 2),
      child: Row(
        children: <Widget>[
          Text(
            '书架',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: palette.ink,
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$total 本',
              style: TextStyle(fontSize: 11.5, color: palette.muted),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '选择',
            icon: ReadIcon(ReadGlyph.check, size: 20, color: palette.ink),
            onPressed: () => setState(() => _selecting = true),
          ),
          IconButton(
            tooltip: '书架菜单',
            icon: ReadIcon(ReadGlyph.ellipsis, size: 21, color: palette.ink),
            onPressed: _openShelfMenu,
          ),
        ],
      ),
    );
  }

  Widget _searchBar(ReadPalette palette, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.outline),
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 20),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 12),
            ReadIcon(ReadGlyph.search, size: 17, color: palette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                focusNode: _searchFocus,
                onChanged: (String value) => setState(() => _term = value),
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 14, color: palette.ink),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: '搜索书名、作者、标签',
                  hintStyle: TextStyle(fontSize: 13.5, color: palette.muted),
                ),
              ),
            ),
            if (_term.isNotEmpty)
              IconButton(
                tooltip: '清空',
                icon: ReadIcon(ReadGlyph.close, size: 16, color: palette.muted),
                onPressed: () {
                  _search.clear();
                  setState(() => _term = '');
                },
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(ReadPalette palette, LibraryStore store) {
    final List<String> tags = store.allTags;
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          for (final MapEntry<_ShelfFilter, String> entry
              in const <_ShelfFilter, String>{
            _ShelfFilter.all: '全部',
            _ShelfFilter.reading: '在读',
            _ShelfFilter.finished: '读完',
            _ShelfFilter.unread: '未读',
            _ShelfFilter.pinned: '置顶',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                palette,
                entry.value,
                selected: _filter == entry.key && _tag == null,
                onTap: () => setState(() {
                  _filter = entry.key;
                  _tag = null;
                }),
              ),
            ),
          if (_collection != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                palette,
                '书箱：$_collection',
                selected: true,
                onTap: () => setState(() => _collection = null),
              ),
            ),
          if (tags.isNotEmpty) ...<Widget>[
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              color: palette.outline,
            ),
            for (final String tag in tags.take(12))
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chip(
                  palette,
                  '#$tag',
                  selected: _tag == tag,
                  onTap: () => setState(() => _tag = _tag == tag ? null : tag),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _collectionRow(ReadPalette palette, LibraryStore store) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
        children: <Widget>[
          ReadIcon(ReadGlyph.folder, size: 14, color: palette.muted),
          const SizedBox(width: 8),
          for (final String name in store.allCollections)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(
                    () => _collection = _collection == name ? null : name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _collection == name ? palette.ink : Colors.transparent,
                    border: Border.all(
                      color: _collection == name ? palette.ink : palette.outline,
                    ),
                    borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 14),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      color: _collection == name
                          ? (palette.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white)
                          : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _countLine(ReadPalette palette, int total, int visible) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        children: <Widget>[
          Text(
            _term.isEmpty && _tag == null && _collection == null
                ? '$total 本书'
                : '找到 $visible 本',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
          const Spacer(),
          Text(
            LibraryStore.sortLabels[LibraryStore.instance.sortMode] ?? '',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 网格 / 列表
  // ---------------------------------------------------------------------------

  Widget _gridView(ReadPalette palette, List<Book> books, double maxWidth) {
    final int configured = ShelfSettings.instance.columns;
    final int columns = configured > 0
        ? configured
        : maxWidth >= 900
            ? 6
            : maxWidth >= 680
                ? 5
                : maxWidth >= 520
                    ? 4
                    : 3;
    final double gap = ShelfSettings.instance.compact ? 9 : 13;
    final double horizontal = 16;
    final double cellWidth =
        (maxWidth - horizontal * 2 - gap * (columns - 1)) / columns;
    final double coverHeight = cellWidth * (ShelfSettings.instance.compact ? 1.42 : 1.5);
    // 书名（最多两行）+ 作者（一行）+ 进度条，按实际行高预留，避免裁切。
    final double cellHeight =
        coverHeight + (ShelfSettings.instance.showProgress ? 74 : 56);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: gap + 6,
        crossAxisSpacing: gap,
        childAspectRatio: cellWidth / cellHeight,
      ),
      itemCount: books.length,
      itemBuilder: (BuildContext context, int index) {
        final Book book = books[index];
        return _BookCell(
          book: book,
          selected: _selected.contains(book.id),
          selecting: _selecting,
          onTap: () => _onTapBook(book),
          onLongPress: () => _enterSelection(book),
          onMenu: () => _openBookMenu(book),
        );
      },
    );
  }

  Widget _listView(ReadPalette palette, List<Book> books) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      physics: const BouncingScrollPhysics(),
      itemCount: books.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: palette.outline),
      itemBuilder: (BuildContext context, int index) {
        final Book book = books[index];
        return _BookRow(
          book: book,
          selected: _selected.contains(book.id),
          onTap: () => _onTapBook(book),
          onLongPress: () => _enterSelection(book),
          onMenu: () => _openBookMenu(book),
        );
      },
    );
  }

  void _onTapBook(Book book) {
    if (_selecting) {
      setState(() {
        if (!_selected.remove(book.id)) _selected.add(book.id);
        if (_selected.isEmpty) _selecting = false;
      });
      return;
    }
    // 点封面即读：不经过详情页，也不经过"继续阅读"中转页。
    _openReader(book);
  }

  void _enterSelection(Book book) {
    setState(() {
      _selecting = true;
      _selected.add(book.id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  List<Book> _visibleBooks(LibraryStore store) {
    final String term = _term.trim().toLowerCase();
    final bool showPrivate = ShelfSettings.instance.showPrivate;
    return store.books.where((Book book) {
      if (!showPrivate && book.isPrivate) return false;
      if (term.isNotEmpty) {
        final bool hit = book.title.toLowerCase().contains(term) ||
            book.author.toLowerCase().contains(term) ||
            book.tags.any((String t) => t.toLowerCase().contains(term)) ||
            book.category.toLowerCase().contains(term);
        if (!hit) return false;
      }
      if (_collection != null && !book.collections.contains(_collection)) {
        return false;
      }
      if (_tag != null && !book.tags.contains(_tag)) return false;
      final bool finished = ReadingStatsStore.instance.isFinished(book.id) ||
          book.status == ReadingStatus.finished;
      return switch (_filter) {
        _ShelfFilter.reading =>
          book.lastReadAt != null && !finished,
        _ShelfFilter.finished => finished,
        _ShelfFilter.unread => book.lastReadAt == null,
        _ShelfFilter.pinned => book.pinned,
        _ShelfFilter.all => true,
      };
    }).toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // 菜单
  // ---------------------------------------------------------------------------

  Future<void> _openShelfMenu() async {
    final String? action = await showReadSheet<String>(
      context,
      title: '书架',
      subtitle: '${LibraryStore.instance.books.length} 本书 · '
          '排序：${LibraryStore.sortLabels[LibraryStore.instance.sortMode]}',
      maxHeightFactor: 0.86,
      children: <Widget>[
        const SheetLabel('常用'),
        SheetMenuItem(
          glyph: ReadGlyph.check,
          title: '选择',
          subtitle: '批量置顶、分类、移动或移除',
          onTap: () => Navigator.pop(context, 'select'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.wifi,
          title: 'WiFi 传书',
          subtitle: '同一局域网用浏览器上传',
          onTap: () => Navigator.pop(context, 'wifi'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.importFile,
          title: '从本机导入',
          subtitle: '多选文件，重复内容自动跳过',
          onTap: () => Navigator.pop(context, 'import'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.sparkle,
          title: '智能导入',
          subtitle: '去重 + 补作者 + 按文件夹归类',
          onTap: () => Navigator.pop(context, 'smart'),
        ),
        const SheetLabel('管理'),
        SheetMenuItem(
          glyph: ReadGlyph.scan,
          title: '扫描文件夹',
          subtitle: '递归导入目录里的电子书',
          onTap: () => Navigator.pop(context, 'scan'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.folder,
          title: '创建书箱',
          subtitle: '可多选的集合，例如「待读」「技术」',
          onTap: () => Navigator.pop(context, 'collection'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.tag,
          title: '标签管理',
          onTap: () => Navigator.pop(context, 'taxonomy'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.layers,
          title: '分类管理',
          subtitle: '单值分类，一本书只属于一个',
          onTap: () => Navigator.pop(context, 'taxonomy'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.sort,
          title: '书籍排序',
          subtitle: '当前：${LibraryStore.sortLabels[LibraryStore.instance.sortMode]}',
          onTap: () => Navigator.pop(context, 'sort'),
        ),
        const SheetLabel('设置'),
        SheetMenuItem(
          glyph: ReadGlyph.settings,
          title: '书架设置',
          subtitle: '进度、云标、私密书、每行本数',
          onTap: () => Navigator.pop(context, 'shelfSettings'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.more,
          title: '更多',
          subtitle: '切换列表视图、导入历史',
          onTap: () => Navigator.pop(context, 'more'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'select':
        setState(() => _selecting = true);
      case 'wifi':
        await _push(const WifiTransferPage());
      case 'import':
        await _runImport(ImportTools.pickAndImport);
      case 'smart':
        await _runImport(ImportTools.smartImport);
      case 'scan':
        await _runImport(ImportTools.scanFolder);
      case 'collection':
        await _createCollection();
      case 'taxonomy':
        await _push(const TaxonomyPage());
      case 'sort':
        await _openSortSheet();
      case 'shelfSettings':
        await _openShelfSettings();
      case 'more':
        await _openMoreSheet();
    }
  }

  Future<void> _openBookMenu(Book book) async {
    final String? action = await showReadSheet<String>(
      context,
      title: book.title,
      subtitle: '${book.author} · ${book.format.toUpperCase()}'
          '${book.sourcePath == null ? '' : ' · ${_fileSize(book)}'}',
      children: <Widget>[
        SheetMenuItem(
          glyph: ReadGlyph.book,
          title: '阅读',
          subtitle: '直接打开阅读器',
          onTap: () => Navigator.pop(context, 'read'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.info,
          title: '信息',
          subtitle: '文件、进度、书签概览',
          onTap: () => Navigator.pop(context, 'detail'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.edit,
          title: '编辑信息',
          subtitle: '封面、书名、作者、分类、评分、状态',
          onTap: () => Navigator.pop(context, 'edit'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.pin,
          title: book.pinned ? '取消置顶' : '置顶',
          onTap: () => Navigator.pop(context, 'pin'),
        ),
        const SheetSeparator(),
        SheetMenuItem(
          glyph: ReadGlyph.export,
          title: '导出',
          subtitle: '把原始文件另存到本机',
          onTap: () => Navigator.pop(context, 'export'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.share,
          title: '分享',
          subtitle: '复制书籍信息（当前无系统分享依赖）',
          onTap: () => Navigator.pop(context, 'share'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.tag,
          title: '分类',
          subtitle: book.category.isEmpty ? '未分类' : book.category,
          onTap: () => Navigator.pop(context, 'category'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.folder,
          title: '加入书箱',
          subtitle: book.collections.isEmpty
              ? '未加入'
              : book.collections.join('、'),
          onTap: () => Navigator.pop(context, 'collection'),
        ),
        const SheetSeparator(),
        SheetMenuItem(
          glyph: ReadGlyph.trash,
          title: '移除',
          subtitle: '删除本地副本与进度，不可撤销',
          danger: true,
          onTap: () => Navigator.pop(context, 'remove'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.more,
          title: '更多',
          subtitle: '私密、阅读状态、封面、清除封面',
          onTap: () => Navigator.pop(context, 'more'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'read':
        await _openReader(book);
      case 'detail':
        await _push(BookDetailPage(book: book));
      case 'edit':
        await _push(BookEditPage(book: book));
      case 'pin':
        await LibraryStore.instance.setPinned(book, !book.pinned);
      case 'export':
        await _exportBook(book);
      case 'share':
        setState(() {});
        _copyShareText(book);
      case 'category':
        await _pickCategory(book);
      case 'collection':
        await _pickCollections(book);
      case 'remove':
        await _removeBook(book);
      case 'more':
        await _openBookMore(book);
    }
  }

  Future<void> _openBookMore(Book book) async {
    final String? action = await showReadSheet<String>(
      context,
      title: '更多',
      children: <Widget>[
        SheetMenuItem(
          glyph: ReadGlyph.lock,
          title: book.isPrivate ? '取消私密' : '设为私密',
          subtitle: '私密书默认不显示在书架',
          onTap: () => Navigator.pop(context, 'private'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.check,
          title: '阅读状态',
          subtitle: book.status.label,
          onTap: () => Navigator.pop(context, 'status'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.image,
          title: '更换封面',
          onTap: () => Navigator.pop(context, 'cover'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.eye,
          title: '查看封面大图',
          onTap: () => Navigator.pop(context, 'viewCover'),
        ),
        if (book.coverPath != null)
          SheetMenuItem(
            glyph: ReadGlyph.trash,
            title: '清除封面',
            subtitle: '恢复为内置模板封面',
            onTap: () => Navigator.pop(context, 'clearCover'),
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'private':
        await LibraryStore.instance
            .updateBook(book.copyWith(isPrivate: !book.isPrivate));
      case 'status':
        await _pickStatus(book);
      case 'cover':
        await _push(BookEditPage(book: book));
      case 'viewCover':
        await _push(CoverViewerPage(book: book, templateId: book.coverTemplate));
      case 'clearCover':
        await deleteCoverFile(book.coverPath);
        final Book updated = book.copyWith(clearCover: true);
        await LibraryStore.instance.updateBook(updated);
    }
  }

  Future<void> _openSortSheet() async {
    final String? mode = await showReadSheet<String>(
      context,
      title: '书籍排序',
      subtitle: '置顶的书始终排在前面',
      children: <Widget>[
        for (final MapEntry<String, String> entry
            in LibraryStore.sortLabels.entries)
          SheetMenuItem(
            glyph: ReadGlyph.sort,
            title: entry.value,
            trailing: LibraryStore.instance.sortMode == entry.key
                ? ReadIcon(ReadGlyph.check, size: 18, color: ReadPalette.of(context).ink)
                : null,
            onTap: () => Navigator.pop(context, entry.key),
          ),
      ],
    );
    if (mode != null) await LibraryStore.instance.setSortMode(mode);
  }

  Future<void> _openShelfSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final ReadPalette palette = ReadPalette.of(ctx);
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setLocal) {
            final ShelfSettings s = ShelfSettings.instance;
            Widget sw(String title, String subtitle, bool value,
                ValueChanged<bool> onChanged) {
              return SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                title: Text(title, style: TextStyle(fontSize: 14.5, color: palette.ink)),
                subtitle: Text(subtitle,
                    style: TextStyle(fontSize: 11, color: palette.muted)),
                value: value,
                activeTrackColor: palette.ink,
                onChanged: (bool v) {
                  onChanged(v);
                  setLocal(() {});
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: Text('书架设置',
                          style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                              color: palette.ink)),
                    ),
                    sw('显示阅读进度', '标题下方显示百分比', s.showProgress,
                        s.setShowProgress),
                    sw('显示云端标识', '只在云端确有文件时显示云朵', s.showCloud,
                        s.setShowCloud),
                    sw('显示私密书籍', '关闭后私密书不出现在书架', s.showPrivate,
                        s.setShowPrivate),
                    sw('紧凑封面', '更小间距，一屏放更多书', s.compact, s.setCompact),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: <Widget>[
                          Text('每行本数',
                              style: TextStyle(fontSize: 13.5, color: palette.ink)),
                          const Spacer(),
                          for (final int n in <int>[0, 3, 4, 5])
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: GestureDetector(
                                onTap: () {
                                  s.setColumns(n);
                                  setLocal(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: s.columns == n
                                        ? palette.ink
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: s.columns == n
                                          ? palette.ink
                                          : palette.outline,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                        ReadUi.instance.isEink ? 0 : 12),
                                  ),
                                  child: Text(
                                    n == 0 ? '自适应' : '$n',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: s.columns == n
                                          ? (palette.brightness == Brightness.dark
                                              ? Colors.black
                                              : Colors.white)
                                          : palette.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openMoreSheet() async {
    final String? action = await showReadSheet<String>(
      context,
      title: '更多',
      children: <Widget>[
        SheetMenuItem(
          glyph: _grid ? ReadGlyph.list : ReadGlyph.grid,
          title: _grid ? '切换为列表' : '切换为网格',
          onTap: () => Navigator.pop(context, 'toggleView'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.refresh,
          title: '刷新书架',
          subtitle: '重新读取本地索引与云端状态',
          onTap: () => Navigator.pop(context, 'refresh'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.device,
          title: '设备与数据',
          subtitle: '导出 / 导入设置、云端对比',
          onTap: () => Navigator.pop(context, 'device'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'toggleView':
        setState(() => _grid = !_grid);
      case 'refresh':
        await LibraryStore.instance.init();
        await CloudPresence.instance.refresh(force: true);
      case 'device':
        await _push(const DataToolsPage());
    }
  }

  // ---------------------------------------------------------------------------
  // 选择模式批量操作
  // ---------------------------------------------------------------------------

  Widget _selectionBar(ReadPalette palette, LibraryStore store) {
    final List<Book> books = store.books
        .where((Book b) => _selected.contains(b.id))
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            _batchAction(palette, ReadGlyph.pin, '置顶', () async {
              for (final Book b in books) {
                await store.setPinned(b, true);
              }
              _exitSelection();
            }),
            _batchAction(palette, ReadGlyph.tag, '分类', () async {
              final String? value = await promptText(
                context,
                title: '设置分类',
                hint: '分类名称，留空表示清除',
                confirm: '应用',
              );
              if (value == null) return;
              for (final Book b in books) {
                await store.updateBook(b.copyWith(category: value.trim()));
              }
              _exitSelection();
            }),
            _batchAction(palette, ReadGlyph.folder, '书箱', () async {
              final String? value = await _chooseCollection();
              if (value == null) return;
              for (final Book b in books) {
                if (b.collections.contains(value)) continue;
                await store.updateBook(b.copyWith(
                  collections: <String>[...b.collections, value],
                ));
              }
              _exitSelection();
            }),
            _batchAction(palette, ReadGlyph.lock, '私密', () async {
              final bool target = books.any((Book b) => !b.isPrivate);
              for (final Book b in books) {
                await store.updateBook(b.copyWith(isPrivate: target));
              }
              _exitSelection();
            }),
            _batchAction(palette, ReadGlyph.trash, '移除', () async {
              final bool ok = await confirmAction(
                context,
                title: '移除 ${books.length} 本书？',
                message: '删除本地副本与阅读进度，无法撤销。',
                confirm: '移除',
                danger: true,
              );
              if (!ok) return;
              for (final Book b in books) {
                await store.deleteBook(b);
              }
              _exitSelection();
            }),
          ],
        ),
      ),
    );
  }

  Widget _batchAction(
    ReadPalette palette,
    ReadGlyph glyph,
    String label,
    Future<void> Function() action,
  ) {
    return Expanded(
      child: InkWell(
        onTap: _selected.isEmpty ? null : () => action(),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            children: <Widget>[
              ReadIcon(glyph,
                  size: 19,
                  color: _selected.isEmpty ? palette.outline : palette.ink),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: _selected.isEmpty ? palette.outline : palette.ink)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------------

  Future<void> _openReader(Book book) async {
    if (book.format.toUpperCase() == 'PDF') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PdfReaderPage(book: book)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReaderPage(book: book)),
      );
    }
    if (!mounted) return;
    await LibraryStore.instance.touch(book);
    if (mounted) setState(() {});
  }

  Future<void> _runImport(Future<ImportSummary> Function() action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('正在导入…')));
    try {
      final ImportSummary summary = await action();
      await LibraryStore.instance.init();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(summary.message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  Future<void> _createCollection() async {
    final String? name = await promptText(
      context,
      title: '创建书箱',
      hint: '例如：待读、技术、今年重读',
      confirm: '创建',
    );
    if (name == null || name.trim().isEmpty) return;
    await CollectionStore.instance.add(name.trim());
    setState(() => _collection = name.trim());
  }

  Future<String?> _chooseCollection() async {
    final List<String> names = LibraryStore.instance.allCollections;
    if (names.isEmpty) {
      await _createCollection();
      return _collection;
    }
    return showReadSheet<String>(
      context,
      title: '选择书箱',
      children: <Widget>[
        for (final String name in names)
          SheetMenuItem(
            glyph: ReadGlyph.folder,
            title: name,
            onTap: () => Navigator.pop(context, name),
          ),
        SheetSeparator(),
        SheetMenuItem(
          glyph: ReadGlyph.plus,
          title: '新建书箱',
          onTap: () => Navigator.pop(context, '__new__'),
        ),
      ],
    );
  }

  Future<void> _pickCollections(Book book) async {
    final String? name = await _chooseCollection();
    if (name == null) return;
    String target = name;
    if (name == '__new__') {
      final String? created = await promptText(
        context,
        title: '新建书箱',
        hint: '书箱名称',
        confirm: '创建',
      );
      if (created == null || created.trim().isEmpty) return;
      target = created.trim();
      await CollectionStore.instance.add(target);
    }
    final List<String> next = List<String>.from(book.collections);
    if (!next.remove(target)) next.add(target);
    await LibraryStore.instance.updateBook(book.copyWith(collections: next));
  }

  Future<void> _pickCategory(Book book) async {
    final String? value = await promptText(
      context,
      title: '设置分类',
      hint: '分类名称，留空清除',
      initial: book.category,
      confirm: '应用',
    );
    if (value == null) return;
    await LibraryStore.instance.updateBook(book.copyWith(category: value.trim()));
  }

  Future<void> _pickStatus(Book book) async {
    final ReadingStatus? status = await showReadSheet<ReadingStatus>(
      context,
      title: '阅读状态',
      children: <Widget>[
        for (final ReadingStatus value in ReadingStatus.values)
          SheetMenuItem(
            glyph: ReadGlyph.check,
            title: value.label,
            trailing: book.status == value
                ? ReadIcon(ReadGlyph.check, size: 18, color: ReadPalette.of(context).ink)
                : null,
            onTap: () => Navigator.pop(context, value),
          ),
      ],
    );
    if (status != null) {
      await LibraryStore.instance.setStatus(book, status);
    }
  }

  Future<void> _removeBook(Book book) async {
    final bool ok = await confirmAction(
      context,
      title: '移除《${book.title}》？',
      message: '删除本地副本与阅读进度，无法撤销。云端的书不会被删除。',
      confirm: '移除',
      danger: true,
    );
    if (ok) await LibraryStore.instance.deleteBook(book);
  }

  Future<void> _exportBook(Book book) async {
    final String? path = book.sourcePath;
    if (path == null || !File(path).existsSync()) {
      _toast('这本书没有本地文件可导出');
      return;
    }
    try {
      final File file = File(path);
      final List<int> bytes = await file.readAsBytes();
      final String name = book.fileName ??
          '${book.title}.${book.format.toLowerCase()}';
      final String? target = await FilePicker.platform.saveFile(
        dialogTitle: '导出书籍',
        fileName: name,
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      );
      if (target == null) return;
      if (!File(target).existsSync()) {
        await File(target).writeAsBytes(bytes, flush: true);
      }
      _toast('已导出到 $target');
    } catch (error) {
      _toast('导出失败：$error');
    }
  }

  void _copyShareText(Book book) {
    final String text = '《${book.title}》 ${book.author}\n'
        '进度：第 ${book.chapterIndex.value + 1} 章 · '
        '${(book.progressRatio * 100).toStringAsFixed(0)}%';
    Clipboard.setData(ClipboardData(text: text));
    _toast('书籍信息已复制到剪贴板');
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    setState(() {});
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _empty(ReadPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ReadIcon(
              _term.isEmpty ? ReadGlyph.book : ReadGlyph.search,
              size: 40,
              color: palette.outline,
            ),
            const SizedBox(height: 14),
            Text(
              _term.isEmpty ? '书架还空着' : '没有符合条件的书',
              style: TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w600, color: palette.ink),
            ),
            const SizedBox(height: 6),
            Text(
              _term.isEmpty ? '从本机导入，或用 WiFi 传书' : '换个关键词、标签或书箱试试',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: palette.muted),
            ),
            if (_term.isEmpty) ...<Widget>[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => _runImport(ImportTools.pickAndImport),
                icon: ReadIcon(ReadGlyph.plus, size: 16, color: palette.ink),
                label: const Text('导入书籍'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.ink,
                  side: BorderSide(color: palette.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
    ReadPalette palette,
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          border: Border.all(color: selected ? accent : palette.outline),
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: selected ? theme.colorScheme.onPrimary : palette.muted,
          ),
        ),
      ),
    );
  }

  String _fileSize(Book book) {
    if (book.fileSize <= 0) return '大小未知';
    if (book.fileSize > 1024 * 1024) {
      return '${(book.fileSize / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(book.fileSize / 1024).toStringAsFixed(0)} KB';
  }
}

// -----------------------------------------------------------------------------
// 卡片
// -----------------------------------------------------------------------------

class _BookCell extends StatelessWidget {
  const _BookCell({
    required this.book,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final Book book;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final bool eink = ReadUi.instance.isEink;
    final CloudState cloud = CloudPresence.instance.stateFor(book);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BookCover(book: book, templateId: book.coverTemplate),
                ),
                if (selected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: (eink ? Colors.white : Colors.black)
                            .withValues(alpha: eink ? 0.0 : 0.22),
                        border: Border.all(
                          color: eink ? Colors.black : palette.ink,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(eink ? 0 : 5),
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: eink ? Colors.black : palette.ink,
                              shape: eink ? BoxShape.rectangle : BoxShape.circle,
                            ),
                            child: Center(
                              child: ReadIcon(ReadGlyph.check,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (book.pinned)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _badge(
                      eink,
                      palette,
                      ReadGlyph.pin,
                    ),
                  ),
                if (book.isPrivate)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _badge(eink, palette, ReadGlyph.lock),
                  ),
                if (ShelfSettings.instance.showCloud &&
                    cloud != CloudState.localOnly &&
                    CloudPresence.instance.available)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _cloudBadge(eink, palette, cloud),
                  ),
                if (!selecting)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: onMenu,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: eink
                                ? Colors.white
                                : Colors.black.withValues(alpha: 0.32),
                            shape: eink ? BoxShape.rectangle : BoxShape.circle,
                            border: eink ? Border.all(color: Colors.black) : null,
                          ),
                          child: Center(
                            child: ReadIcon(
                              ReadGlyph.ellipsis,
                              size: 13,
                              color: eink ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 2),
          // 作者与书名分开显示，绝不拼进标题（任务：书名作者必须分开）。
          Text(
            book.author.trim().isEmpty ? '未知作者' : book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: palette.muted,
            ),
          ),
          if (ShelfSettings.instance.showProgress) ...<Widget>[
            const SizedBox(height: 5),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(eink ? 0 : 2),
                    child: LinearProgressIndicator(
                      value: book.progressRatio.clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: palette.outline,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _progressLabel(book),
                  style: TextStyle(fontSize: 10, color: palette.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _progressLabel(Book book) {
    if (book.lastReadAt == null) return '';
    if (book.status == ReadingStatus.finished ||
        ReadingStatsStore.instance.isFinished(book.id)) {
      return '读完';
    }
    return '${(book.progressRatio * 100).toStringAsFixed(0)}%';
  }

  Widget _badge(bool eink, ReadPalette palette, ReadGlyph glyph) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: eink ? Colors.white : Colors.black.withValues(alpha: 0.42),
        shape: eink ? BoxShape.rectangle : BoxShape.circle,
        border: eink ? Border.all(color: Colors.black) : null,
      ),
      child: Center(
        child: ReadIcon(glyph, size: 12, color: eink ? Colors.black : Colors.white),
      ),
    );
  }

  Widget _cloudBadge(bool eink, ReadPalette palette, CloudState state) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: eink ? Colors.white : palette.surface,
        shape: eink ? BoxShape.rectangle : BoxShape.circle,
        border: Border.all(color: eink ? Colors.black : palette.outline),
      ),
      child: Center(
        child: ReadIcon(
          state == CloudState.cloudOnly ? ReadGlyph.cloudDownload : ReadGlyph.cloudCheck,
          size: 13,
          color: palette.ink,
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final Book book;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? palette.outline.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 40,
              height: 58,
              child: BookCover(book: book, templateId: book.coverTemplate),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: palette.ink)),
                  const SizedBox(height: 4),
                  Text(
                    '${book.author} · ${book.format.toUpperCase()}'
                    ' · ${book.status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: palette.muted),
                  ),
                ],
              ),
            ),
            if (book.pinned) ReadIcon(ReadGlyph.pin, size: 14, color: palette.muted),
            if (CloudPresence.instance.stateFor(book) != CloudState.localOnly &&
                CloudPresence.instance.available)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ReadIcon(ReadGlyph.cloudCheck, size: 15, color: palette.muted),
              ),
            IconButton(
              tooltip: '更多',
              icon: ReadIcon(ReadGlyph.ellipsis, size: 17, color: palette.muted),
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}
