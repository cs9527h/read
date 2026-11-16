import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/bookshelf/book_detail_page.dart';
import 'package:read/src/bookshelf/book_edit_page.dart';
import 'package:read/src/reader/pdf_reader_page.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/profile/profile_page.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/services/wifi_transfer_service.dart';
import 'package:read/src/sync/cloud_library_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:read/src/theme.dart';

/// 书架：三列封面网格，黑白图标，无示例书。
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchTerm = '';
  bool _grid = true;
  String _filter = 'all';
  String? _tagFilter;
  String? _categoryFilter;
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  String _sortMode = 'recent';
  int _columns = 0;
  bool _showProgress = true;
  List<String> _customCategories = <String>[];

  @override
  void initState() {
    super.initState();
    _loadShelfPrefs();
  }

  Future<void> _loadShelfPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _grid = prefs.getBool('read.shelf.grid') ?? true;
      _columns = prefs.getInt('read.shelf.columns') ?? 0;
      _showProgress = prefs.getBool('read.shelf.showProgress') ?? true;
      _sortMode = prefs.getString('read.shelf.sort') ?? 'recent';
      _customCategories =
          prefs.getStringList('read.shelf.categories') ?? <String>[];
    });
  }

  Future<void> _setShelfPref(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is List<String>) await prefs.setStringList(key, value);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: LibraryStore.instance,
      builder: (BuildContext context, Widget? child) {
        final LibraryStore store = LibraryStore.instance;
        final String term = _searchTerm.trim().toLowerCase();
        final List<Book> visibleBooks = store.books.where((Book book) {
          final bool matchesSearch = term.isEmpty ||
              book.title.toLowerCase().contains(term) ||
              book.author.toLowerCase().contains(term) ||
              book.tags.any((String tag) => tag.toLowerCase().contains(term));
          if (!matchesSearch) return false;
          if (_tagFilter != null && !book.tags.contains(_tagFilter))
            return false;
          if (_categoryFilter != null && book.category != _categoryFilter) {
            return false;
          }
          final bool finished = ReadingStatsStore.instance.isFinished(book.id);
          return switch (_filter) {
            'reading' => book.lastReadAt != null && !finished,
            'finished' => finished,
            'unread' => book.lastReadAt == null,
            _ => true,
          };
        }).toList();
        _sortVisible(visibleBooks);
        final int total = store.books.length;
        final List<String> allTags = <String>{
          for (final Book b in store.books) ...b.tags,
        }.toList()
          ..sort();
        final List<String> allCategories = <String>{
          ..._customCategories,
          for (final Book b in store.books)
            if (b.category.trim().isNotEmpty) b.category,
        }.toList()
          ..sort();

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                  child: Row(
                    children: <Widget>[
                      Text(
                        _selectionMode ? '已选 ${_selectedIds.length} 本' : '书架',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (!_selectionMode) ...<Widget>[
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 22, color: palette.ink),
                        const Spacer(),
                        IconButton(
                          tooltip: '选择',
                          onPressed: () =>
                              setState(() => _selectionMode = true),
                          icon: Icon(Icons.checklist_rounded,
                              color: palette.icon),
                        ),
                        IconButton(
                          tooltip: _grid ? '切换列表' : '切换网格',
                          onPressed: () async {
                            setState(() => _grid = !_grid);
                            await _setShelfPref('read.shelf.grid', _grid);
                          },
                          icon: Icon(
                            _grid
                                ? Icons.view_list_rounded
                                : Icons.grid_view_rounded,
                            color: palette.icon,
                          ),
                        ),
                        IconButton(
                          tooltip: '书架菜单',
                          onPressed: _showMoreMenu,
                          icon: Icon(ReadIcons.more, color: palette.icon),
                        ),
                      ] else ...<Widget>[
                        const Spacer(),
                        IconButton(
                          tooltip: '退出选择',
                          onPressed: () => setState(() {
                            _selectionMode = false;
                            _selectedIds.clear();
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        IconButton(
                          tooltip: '删除所选',
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _deleteSelected(store),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(kEink ? 0 : 20),
                      border: Border.all(color: palette.outline),
                    ),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 12),
                        Icon(Icons.search_rounded,
                            size: 18, color: palette.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: (String value) => setState(() {
                              _searchTerm = value;
                            }),
                            textInputAction: TextInputAction.search,
                            style: TextStyle(fontSize: 14, color: palette.ink),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              hintText: '搜索 $total 本书',
                              hintStyle:
                                  TextStyle(fontSize: 14, color: palette.muted),
                            ),
                          ),
                        ),
                        if (_searchTerm.isNotEmpty)
                          IconButton(
                            tooltip: '清空搜索',
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: palette.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchTerm = '';
                              });
                            },
                          )
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    children: <Widget>[
                      for (final entry in const <String, String>{
                        'all': '全部',
                        'reading': '在读',
                        'finished': '读完',
                        'unread': '未读',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kEink ? 0 : 16),
                              side: BorderSide(color: palette.outline),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (allTags.isNotEmpty)
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: const Text('全部标签',
                                style: TextStyle(fontSize: 10)),
                            selected: _tagFilter == null,
                            onSelected: (_) =>
                                setState(() => _tagFilter = null),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kEink ? 0 : 14),
                              side: BorderSide(color: palette.outline),
                            ),
                          ),
                        ),
                        for (final tag in allTags)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('#$tag',
                                  style: const TextStyle(fontSize: 10)),
                              selected: _tagFilter == tag,
                              onSelected: (_) =>
                                  setState(() => _tagFilter = tag),
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(kEink ? 0 : 14),
                                side: BorderSide(color: palette.outline),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (allCategories.isNotEmpty)
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: const Text('全部分类',
                                style: TextStyle(fontSize: 10)),
                            selected: _categoryFilter == null,
                            onSelected: (_) =>
                                setState(() => _categoryFilter = null),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kEink ? 0 : 14),
                              side: BorderSide(color: palette.outline),
                            ),
                          ),
                        ),
                        for (final category in allCategories)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(category,
                                  style: const TextStyle(fontSize: 10)),
                              selected: _categoryFilter == category,
                              onSelected: (_) =>
                                  setState(() => _categoryFilter = category),
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(kEink ? 0 : 14),
                                side: BorderSide(color: palette.outline),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: visibleBooks.isEmpty
                      ? _EmptyLibrary(
                          isSearching: term.isNotEmpty,
                          onImport: _importBook,
                        )
                      : LayoutBuilder(
                          builder:
                              (BuildContext context, BoxConstraints bounds) {
                            final int columns = _columns > 0
                                ? _columns
                                : bounds.maxWidth >= 900
                                    ? 6
                                    : bounds.maxWidth >= 640
                                        ? 4
                                        : 3;
                            if (!_grid) {
                              return ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                physics: const BouncingScrollPhysics(),
                                itemCount: visibleBooks.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: palette.outline,
                                ),
                                itemBuilder: (BuildContext context, int index) {
                                  final Book book = visibleBooks[index];
                                  return _BookRow(
                                    book: book,
                                    selectionMode: _selectionMode,
                                    selected: _selectedIds.contains(book.id),
                                    showProgress: _showProgress,
                                    onOpen: () => _handleBookTap(book),
                                    onMenu: () => _showBookMenu(store, book),
                                  );
                                },
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              physics: const BouncingScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.47,
                              ),
                              itemCount: visibleBooks.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Book book = visibleBooks[index];
                                return _BookCell(
                                  book: book,
                                  selectionMode: _selectionMode,
                                  selected: _selectedIds.contains(book.id),
                                  showProgress: _showProgress,
                                  onOpen: () => _handleBookTap(book),
                                  onMenu: () => _showBookMenu(store, book),
                                );
                              },
                            );
                          },
                        ),
                ),
                if (visibleBooks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Text(
                      term.isEmpty
                          ? '共 $total 本书籍'
                          : '找到 ${visibleBooks.length} 本',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMoreMenu() async {
    final palette = ReadPalette.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: <Widget>[
                      const Text('书架',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        '${_grid ? '网格' : '列表'} · ${_sortLabel()}',
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.checklist_rounded),
                  title: const Text('选择'),
                  subtitle: const Text('批量选择并删除本机书籍'),
                  onTap: () => Navigator.pop(sheetContext, 'select'),
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering_rounded),
                  title: const Text('WiFi 传书'),
                  subtitle: Text(WifiTransferService.instance.running
                      ? '接收中：${WifiTransferService.instance.url}'
                      : '局域网接收，电脑浏览器上传'),
                  onTap: () => Navigator.pop(sheetContext, 'wifi'),
                ),
                ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: const Text('从本机导入'),
                  subtitle: const Text('选择一个 EPUB/TXT/PDF 文件'),
                  onTap: () => Navigator.pop(sheetContext, 'import'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('扫描文件夹'),
                  subtitle: const Text('递归导入文件夹内支持的格式'),
                  onTap: () => Navigator.pop(sheetContext, 'folder'),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_motion_outlined),
                  title: const Text('智能导入'),
                  subtitle: const Text('自动识别选中文件夹里的书籍并跳过重复格式'),
                  onTap: () => Navigator.pop(sheetContext, 'smart'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text('创建书箱 / 分组'),
                  subtitle: const Text('新建分类，编辑书籍时可归入'),
                  onTap: () => Navigator.pop(sheetContext, 'createCategory'),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: const Text('书架设置'),
                  subtitle: const Text('网格/列表、列数、是否显示进度'),
                  onTap: () => Navigator.pop(sheetContext, 'shelfSettings'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: const Text('标签管理'),
                  subtitle: const Text('查看、重命名或清理全部标签'),
                  onTap: () => Navigator.pop(sheetContext, 'tags'),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_shared_outlined),
                  title: const Text('分类管理'),
                  subtitle: const Text('重命名或移除书箱分类'),
                  onTap: () => Navigator.pop(sheetContext, 'categories'),
                ),
                ListTile(
                  leading: const Icon(Icons.sort_rounded),
                  title: const Text('书籍排序'),
                  subtitle: Text(_sortLabel()),
                  onTap: () => Navigator.pop(sheetContext, 'sort'),
                ),
                ListTile(
                  leading: const Icon(Icons.more_horiz_rounded),
                  title: const Text('更多'),
                  subtitle: const Text('刷新云端状态、设置与关于'),
                  onTap: () => Navigator.pop(sheetContext, 'more'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'select':
        setState(() {
          _selectionMode = true;
          _selectedIds.clear();
        });
      case 'wifi':
        await _showWifiTransfer();
      case 'import':
        await _importBook();
      case 'folder':
        await _scanFolder(smart: false);
      case 'smart':
        await _scanFolder(smart: true);
      case 'createCategory':
        await _createCategory();
      case 'shelfSettings':
        await _showShelfSettings();
      case 'tags':
        await _manageTags();
      case 'categories':
        await _manageCategories();
      case 'sort':
        await _chooseSort();
      case 'more':
        await _showSecondaryMenu();
    }
    if (mounted) setState(() {});
  }

  String _sortLabel() => switch (_sortMode) {
        'title' => '按书名',
        'author' => '按作者',
        'imported' => '按导入时间',
        _ => '按最近阅读',
      };

  Future<void> _showWifiTransfer() async {
    final service = WifiTransferService.instance;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setLocal) {
            final palette = ReadPalette.of(ctx);
            return AlertDialog(
              title: const Text('WiFi 传书'),
              content: SizedBox(
                width: 360,
                child: service.running
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('接收已开启。电脑和手机连同一个 WiFi，在浏览器打开：'),
                          const SizedBox(height: 8),
                          SelectableText(
                            service.url ?? '没有可用地址',
                            style: TextStyle(
                                fontSize: 13,
                                color: palette.ink,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '端口 ${service.port} · 只接收 EPUB/TXT/MD/HTML/PDF，单文件上限 64MB。关闭开关后地址立即失效。',
                            style: TextStyle(
                                fontSize: 11,
                                color: palette.muted,
                                height: 1.45),
                          ),
                          if (service.lastMessage.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(service.lastMessage,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const <Widget>[
                          Text('在手机上开启局域网接收，电脑浏览器上传后直接进入书架。'),
                          SizedBox(height: 8),
                          Text('不会开放目录浏览；地址带随机令牌，停止即关闭端口。',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('关闭'),
                ),
                if (service.running)
                  TextButton(
                    onPressed: () async {
                      await service.stop();
                      setLocal(() {});
                    },
                    child: const Text('停止接收'),
                  )
                else
                  FilledButton(
                    onPressed: () async {
                      try {
                        await service.start();
                        setLocal(() {});
                      } catch (error) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                                SnackBar(content: Text('启动失败：$error')));
                        }
                      }
                    },
                    child: const Text('开启接收'),
                  ),
              ],
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _scanFolder({required bool smart}) async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: smart ? '选择要智能导入的文件夹' : '选择要扫描的文件夹',
    );
    if (directory == null || !mounted) return;
    final root = Directory(directory);
    if (!await root.exists()) {
      _toast('文件夹不存在');
      return;
    }
    final supported = <String>{'epub', 'txt', 'md', 'html', 'htm', 'pdf'};
    int imported = 0;
    int skipped = 0;
    try {
      final files = <File>[];
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final ext = entity.path.split('.').last.toLowerCase();
        if (!supported.contains(ext)) continue;
        files.add(entity);
        if (files.length >= 200) break;
      }
      for (final file in files) {
        final book = await LibraryStore.instance.importFileAtPath(file.path);
        if (book == null) {
          skipped++;
        } else {
          imported++;
        }
      }
    } catch (error) {
      _toast('扫描失败：$error');
      return;
    }
    _toast(smart
        ? '智能导入完成：新增 $imported 本，跳过 $skipped 个'
        : '扫描完成：新增 $imported 本，跳过 $skipped 个');
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建书箱 / 分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：技术书、待读'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('创建')),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim() ?? '';
    if (clean.isEmpty) return;
    if (!_customCategories.contains(clean)) {
      _customCategories.add(clean);
      await _setShelfPref('read.shelf.categories', _customCategories);
    }
    if (mounted) {
      setState(() => _categoryFilter = clean);
      _toast('已创建“$clean”，编辑书籍时可归入该分类');
    }
  }

  Future<void> _showShelfSettings() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('书架设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('网格模式'),
                value: _grid,
                onChanged: (v) async {
                  setLocal(() => _grid = v);
                  setState(() => _grid = v);
                  await _setShelfPref('read.shelf.grid', v);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('显示阅读进度'),
                value: _showProgress,
                onChanged: (v) async {
                  setLocal(() => _showProgress = v);
                  setState(() => _showProgress = v);
                  await _setShelfPref('read.shelf.showProgress', v);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Text('列数'),
                  const Spacer(),
                  for (final option in <int>[0, 3, 4, 5])
                    ChoiceChip(
                      label: Text(option == 0 ? '自动' : '$option'),
                      selected: _columns == option,
                      showCheckmark: false,
                      onSelected: (_) async {
                        setLocal(() => _columns = option);
                        setState(() => _columns = option);
                        await _setShelfPref('read.shelf.columns', option);
                      },
                    ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('完成')),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseSort() async {
    final labels = <String, String>{
      'recent': '按最近阅读',
      'title': '按书名',
      'author': '按作者',
      'imported': '按导入时间',
    };
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final entry in labels.entries)
              ListTile(
                leading: Icon(_sortMode == entry.key
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(entry.value),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (value == null) return;
    setState(() => _sortMode = value);
    await _setShelfPref('read.shelf.sort', value);
  }

  Future<void> _manageTags() async {
    final store = LibraryStore.instance;
    final counts = <String, int>{};
    for (final book in store.books) {
      for (final tag in book.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      _toast('还没有标签');
      return;
    }
    final tag = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final entry in counts.entries)
              ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: Text(entry.key),
                subtitle: Text('${entry.value} 本书'),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (tag == null || !mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('管理标签“$tag”'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'rename'),
              child: const Text('重命名')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('删除')),
        ],
      ),
    );
    if (action == null) return;
    if (action == 'delete') {
      for (final book in store.books.where((b) => b.tags.contains(tag))) {
        final tags = List<String>.from(book.tags)..remove(tag);
        await _updateBook(store, book, tags: tags);
      }
      _toast('已删除标签“$tag”');
      return;
    }
    final controller = TextEditingController(text: tag);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名标签'),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    final clean = newName?.trim() ?? '';
    if (clean.isEmpty || clean == tag) return;
    for (final book in store.books.where((b) => b.tags.contains(tag))) {
      final tags = book.tags.map((t) => t == tag ? clean : t).toList();
      await _updateBook(store, book, tags: tags);
    }
    _toast('标签已重命名');
  }

  Future<void> _manageCategories() async {
    final store = LibraryStore.instance;
    final categories = <String>{
      ..._customCategories,
      for (final book in store.books)
        if (book.category.trim().isNotEmpty) book.category,
    }.toList()
      ..sort();
    if (categories.isEmpty) {
      _toast('还没有分类');
      return;
    }
    final category = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final item in categories)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(item),
                subtitle: Text(
                    '${store.books.where((b) => b.category == item).length} 本书'),
                onTap: () => Navigator.pop(ctx, item),
              ),
          ],
        ),
      ),
    );
    if (category == null || !mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('管理分类“$category”'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'rename'),
              child: const Text('重命名')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('清空分类')),
        ],
      ),
    );
    if (action == null) return;
    if (action == 'delete') {
      for (final book in store.books.where((b) => b.category == category)) {
        await _updateBook(store, book, category: '');
      }
      _customCategories.remove(category);
      await _setShelfPref('read.shelf.categories', _customCategories);
      _toast('分类“$category”已清空');
      return;
    }
    final controller = TextEditingController(text: category);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分类'),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    final clean = newName?.trim() ?? '';
    if (clean.isEmpty || clean == category) return;
    for (final book in store.books.where((b) => b.category == category)) {
      await _updateBook(store, book, category: clean);
    }
    final index = _customCategories.indexOf(category);
    if (index >= 0) _customCategories[index] = clean;
    await _setShelfPref('read.shelf.categories', _customCategories);
    _toast('分类已重命名');
  }

  Future<void> _showSecondaryMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('刷新云端书库状态'),
              subtitle: const Text('只读云端索引，不上传、不覆盖'),
              onTap: () => Navigator.pop(ctx, 'refreshCloud'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('打开设置'),
              onTap: () => Navigator.pop(ctx, 'settings'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'refreshCloud') {
      await CloudLibraryIndex.instance.refresh(force: true);
      if (!mounted) return;
      final error = CloudLibraryIndex.instance.lastError;
      _toast(error.isEmpty
          ? '云端索引已刷新：${CloudLibraryIndex.instance.lastRefresh ?? ''}'
          : '刷新失败：$error');
    } else if (action == 'settings') {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
    }
  }

  Future<void> _showBookMenu(LibraryStore store, Book book) async {
    final cloud = CloudLibraryIndex.instance.stateFor(book.contentHash);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final palette = ReadPalette.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(book.isPrivate ? '私密书籍' : book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            '${book.author} · ${book.format.toUpperCase()}'
                            '${cloud == null ? '' : cloud.file ? ' · 云端有文件' : cloud.metadata ? ' · 云端有元数据' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 11, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    if (book.pinned)
                      Icon(Icons.push_pin_rounded,
                          size: 17, color: palette.icon),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('阅读'),
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('信息'),
                onTap: () => Navigator.pop(sheetContext, 'detail'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑信息'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: Icon(book.pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined),
                title: Text(book.pinned ? '取消置顶' : '置顶'),
                onTap: () => Navigator.pop(sheetContext, 'pin'),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('分享'),
                subtitle: const Text('当前复制书籍信息与文件路径'),
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导出原文件'),
                onTap: () => Navigator.pop(sheetContext, 'export'),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('分类'),
                subtitle: Text(book.category.isEmpty ? '未分类' : book.category),
                onTap: () => Navigator.pop(sheetContext, 'category'),
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz_rounded),
                title: const Text('更多'),
                onTap: () => Navigator.pop(sheetContext, 'more'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('移除'),
                subtitle: const Text('删除本机副本与进度，云端对象不受影响'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _openReader(book);
      case 'detail':
        await _openBook(book);
      case 'edit':
        await _openEdit(book);
      case 'pin':
        await _updateBook(store, book, pinned: !book.pinned);
      case 'share':
        await _shareBook(book);
      case 'export':
        await _exportBook(book);
      case 'category':
        await _editCategory(store, book);
      case 'more':
        await _showBookMore(store, book);
      case 'delete':
        await _confirmDelete(store, book);
    }
    if (mounted) setState(() {});
  }

  Future<void> _showBookMore(LibraryStore store, Book book) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: const Text('标签'),
              subtitle: Text(book.tags.isEmpty ? '未设置' : book.tags.join('、')),
              onTap: () => Navigator.pop(ctx, 'tags'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('阅读状态'),
              subtitle: Text(_statusLabel(book.readingStatus)),
              onTap: () => Navigator.pop(ctx, 'status'),
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: const Text('复制文件路径'),
              onTap: () => Navigator.pop(ctx, 'path'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'tags') {
      await _editTags(store, book);
    } else if (action == 'status') {
      await _editReadingStatus(store, book);
    } else if (action == 'path') {
      await Clipboard.setData(
          ClipboardData(text: book.sourcePath ?? '该书没有本机文件'));
      _toast('文件路径已复制');
    }
  }

  Future<void> _openEdit(Book book) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => BookEditPage(book: book)),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _updateBook(LibraryStore store, Book book,
      {bool? pinned,
      String? category,
      String? status,
      List<String>? tags}) async {
    try {
      await store.updateBookInfo(
        book,
        title: book.title,
        author: book.author,
        category: category ?? book.category,
        rating: book.rating,
        pinned: pinned ?? book.pinned,
        isPrivate: book.isPrivate,
        readingStatus: status ?? book.readingStatus,
        tags: tags ?? book.tags,
        coverPath: book.coverPath,
      );
    } catch (error) {
      _toast('保存失败：$error');
    }
  }

  Future<void> _editCategory(LibraryStore store, Book book) async {
    final controller = TextEditingController(text: book.category);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：科幻、历史、工作'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _updateBook(store, book, category: value.trim());
  }

  Future<void> _editTags(LibraryStore store, Book book) async {
    final tags = List<String>.from(book.tags);
    final controller = TextEditingController();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final tag in tags)
                    InputChip(
                      label: Text(tag),
                      onDeleted: () => setLocal(() => tags.remove(tag)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: '输入后点添加'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty && !tags.contains(value)) tags.add(value);
                controller.clear();
                setLocal(() {});
              },
              child: const Text('添加'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx, tags),
                child: const Text('保存')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    await _updateBook(store, book, tags: result);
  }

  Future<void> _editReadingStatus(LibraryStore store, Book book) async {
    final status = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final entry in _readingStatuses.entries)
              ListTile(
                leading: Icon(book.readingStatus == entry.key
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(entry.value),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (status == null) return;
    await _updateBook(store, book, status: status);
  }

  static const Map<String, String> _readingStatuses = <String, String>{
    'unread': '未读',
    'reading': '在读',
    'shelved': '搁置',
    'finished': '读完',
    'dropped': '弃读',
  };

  String _statusLabel(String status) => _readingStatuses[status] ?? '未读';

  Future<void> _shareBook(Book book) async {
    final path = book.sourcePath;
    final buffer = StringBuffer()
      ..writeln('《${book.title}》')
      ..write('作者：${book.author}');
    if (path != null) buffer.write('\n文件：$path');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _toast('已复制书籍信息；系统分享面板尚未接入');
  }

  Future<void> _exportBook(Book book) async {
    final path = book.sourcePath;
    if (path == null || !File(path).existsSync()) {
      _toast('该书没有可导出的本机文件');
      return;
    }
    try {
      final bytes = await File(path).readAsBytes();
      final name =
          book.fileName ?? '${book.title}.${book.format.toLowerCase()}';
      final target = await FilePicker.platform.saveFile(
        dialogTitle: '导出书籍',
        fileName: name,
        bytes: bytes,
      );
      if (target == null) return;
      final targetFile = File(target);
      if (!await targetFile.exists() ||
          await targetFile.length() != bytes.length) {
        await targetFile.writeAsBytes(bytes, flush: true);
      }
      _toast('已导出：$target');
    } catch (error) {
      _toast('导出失败：$error');
    }
  }

  void _sortVisible(List<Book> books) {
    int pinnedThen(Book a, Book b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return 0;
    }

    switch (_sortMode) {
      case 'title':
        books.sort((a, b) {
          final p = pinnedThen(a, b);
          if (p != 0) return p;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      case 'author':
        books.sort((a, b) {
          final p = pinnedThen(a, b);
          if (p != 0) return p;
          return a.author.toLowerCase().compareTo(b.author.toLowerCase());
        });
      case 'imported':
        books.sort((a, b) {
          final p = pinnedThen(a, b);
          if (p != 0) return p;
          return b.id.compareTo(a.id);
        });
      default:
        books.sort((a, b) {
          final p = pinnedThen(a, b);
          if (p != 0) return p;
          final at = a.lastReadAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.lastReadAt?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
    }
  }

  void _handleBookTap(Book book) {
    if (_selectionMode) {
      setState(() {
        if (!_selectedIds.remove(book.id)) _selectedIds.add(book.id);
      });
      return;
    }
    _openReader(book);
  }

  Future<void> _deleteSelected(LibraryStore store) async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除所选 $count 本书？'),
        content: const Text('只删除本机副本与进度，云端对象不会自动删除。'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final selected =
        store.books.where((b) => _selectedIds.contains(b.id)).toList();
    for (final book in selected) {
      try {
        await store.deleteBook(book);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  Future<void> _openBook(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BookDetailPage(book: book),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openReader(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => book.format.toUpperCase() == 'PDF'
            ? PdfReaderPage(book: book)
            : ReaderPage(book: book),
      ),
    );
    if (!mounted) return;
    await LibraryStore.instance.touch(book);
    setState(() {});
  }

  Future<void> _importBook() async {
    try {
      final Book? book = await LibraryStore.instance.importBook();
      if (!mounted || book == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入《${book.title}》')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入失败，原始文件没有被修改')),
      );
    }
  }

  Future<void> _confirmDelete(LibraryStore store, Book book) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('删除这本书？'),
        content: Text('《${book.title}》的本地副本和阅读进度将被删除，无法撤销。'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (approved == true) await store.deleteBook(book);
  }
}

class _BookCell extends StatelessWidget {
  const _BookCell({
    required this.book,
    required this.onOpen,
    required this.onMenu,
    this.selectionMode = false,
    this.selected = false,
    this.showProgress = true,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final bool selectionMode;
  final bool selected;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final String progress = _progressLabel(book);
    final bool inCloud = CloudLibraryIndex.instance.hasCloud(book.contentHash);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      onLongPress: onMenu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: onOpen,
                    onLongPress: onMenu,
                    child: _Cover(book: book),
                  ),
                ),
                if (selectionMode)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected ? palette.ink : palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.outline),
                      ),
                      child: Icon(
                        selected ? Icons.check_rounded : Icons.circle_outlined,
                        size: 15,
                        color: selected
                            ? (palette.brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white)
                            : palette.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.isPrivate ? '私密书籍' : book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  showProgress ? progress : book.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ),
              if (inCloud)
                Tooltip(
                  message: CloudLibraryIndex.instance.hasFile(book.contentHash)
                      ? '云端存在该文件'
                      : '云端存在该书元数据',
                  child: Icon(Icons.cloud_outlined,
                      size: 13, color: palette.muted),
                ),
              if (!selectionMode)
                InkWell(
                  onTap: onMenu,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(ReadIcons.more, size: 16, color: palette.muted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _progressLabel(Book book) {
    if (book.lastReadAt == null) return '未读过';
    if (ReadingStatsStore.instance.isFinished(book.id)) return '已读完';
    final int chapters = book.chapterCount;
    if (chapters <= 0) return '第 ${book.chapterIndex.value + 1} 章';
    final double ratio =
        ((book.chapterIndex.value + 1) / chapters).clamp(0.0, 1.0).toDouble();
    return '${(ratio * 100).toStringAsFixed(2)}%';
  }
}

/// 黑白封面：书名决定灰度深浅，没有彩色、没有图片资源。
class _Cover extends StatelessWidget {
  const _Cover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final cover = book.coverPath;
    if (cover != null && File(cover).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(kEink ? 0 : 6),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: kEink ? Border.all(color: Colors.black) : null,
          ),
          child: Image.file(
            File(cover),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _textCover(context),
          ),
        ),
      );
    }
    return _textCover(context);
  }

  Widget _textCover(BuildContext context) {
    final int hash = book.title.runes.fold<int>(0, (int a, int b) => a + b);
    final List<double> shades = <double>[0.10, 0.18, 0.26, 0.34, 0.44];
    final double shade = shades[hash % shades.length];
    final Color base = Color.lerp(Colors.black, Colors.white, shade)!;
    final Color text = shade < 0.3 ? Colors.white : Colors.black;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kEink ? Colors.white : base,
        borderRadius: BorderRadius.circular(kEink ? 0 : 6),
        border: kEink ? Border.all(color: Colors.black) : null,
        boxShadow:
            kEink || ReadPalette.of(context).brightness == Brightness.dark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 18, height: 1.5, color: text.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              book.isPrivate ? '私密书籍' : book.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            book.format.toUpperCase(),
            style: TextStyle(
              color: text.withValues(alpha: 0.6),
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.isSearching, required this.onImport});

  final bool isSearching;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.menu_book_outlined,
              size: 40,
              color: palette.muted,
            ),
            const SizedBox(height: 14),
            Text(
              isSearching ? '没有找到这本书' : '书架还空着',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.ink),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching ? '换个书名或作者试试' : '导入本地 TXT / EPUB / PDF 开始阅读',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.muted),
            ),
            if (!isSearching) ...<Widget>[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('导入书籍'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.ink,
                  side: BorderSide(color: palette.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kEink ? 0 : 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.onOpen,
    required this.onMenu,
    this.selectionMode = false,
    this.selected = false,
    this.showProgress = true,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final bool selectionMode;
  final bool selected;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final bool finished = ReadingStatsStore.instance.isFinished(book.id);
    return InkWell(
      onTap: onOpen,
      onLongPress: onMenu,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            if (selectionMode) ...<Widget>[
              Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20, color: palette.icon),
              const SizedBox(width: 10),
            ],
            Container(
              width: 42,
              height: 60,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.outline),
                borderRadius: BorderRadius.circular(kEink ? 0 : 4),
              ),
              child:
                  book.coverPath != null && File(book.coverPath!).existsSync()
                      ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
                      : Text(
                          book.isPrivate ? '私密书籍' : book.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 9, height: 1.25, color: palette.ink),
                        ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(book.isPrivate ? '私密书籍' : book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.ink)),
                  const SizedBox(height: 4),
                  Text(
                    '${book.author} · ${book.format.toUpperCase()}'
                    '${finished ? ' · 已读完' : book.lastReadAt == null ? ' · 未读' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ],
              ),
            ),
            if (book.chapterCount > 0)
              Text(
                '${((book.chapterIndex.value + 1) / book.chapterCount * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            IconButton(
              tooltip: '更多',
              icon: Icon(Icons.more_horiz_rounded,
                  size: 18, color: palette.muted),
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}
