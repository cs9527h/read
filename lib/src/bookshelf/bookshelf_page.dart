import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/bookshelf/book_detail_page.dart';
import 'package:read/src/reader/pdf_reader_page.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
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
          if (_tagFilter != null && !book.tags.contains(_tagFilter)) return false;
          final bool finished = ReadingStatsStore.instance.isFinished(book.id);
          return switch (_filter) {
            'reading' => book.lastReadAt != null && !finished,
            'finished' => finished,
            'unread' => book.lastReadAt == null,
            _ => true,
          };
        }).toList(growable: false);
        final List<Book> continueCandidates = store.books
            .where((Book b) =>
                b.lastReadAt != null &&
                !ReadingStatsStore.instance.isFinished(b.id))
            .toList(growable: false);
        final Book? continueBook =
            continueCandidates.isEmpty ? null : continueCandidates.first;
        final int total = store.books.length;
        final List<String> allTags = <String>{
          for (final Book b in store.books) ...b.tags,
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
                        '书架',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: palette.ink),
                      const Spacer(),
                      IconButton(
                        tooltip: _grid ? '切换列表' : '切换网格',
                        onPressed: () => setState(() => _grid = !_grid),
                        icon: Icon(
                          _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          color: palette.icon,
                        ),
                      ),
                      IconButton(
                        tooltip: '刷新书架',
                        onPressed: () async {
                          await LibraryStore.instance.init();
                        },
                        icon: Icon(Icons.refresh_rounded, color: palette.icon),
                      ),
                      IconButton(
                        tooltip: '更多',
                        onPressed: _showMoreMenu,
                        icon: Icon(Icons.more_horiz_rounded, color: palette.icon),
                      ),
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
                        Icon(Icons.search_rounded, size: 18, color: palette.muted),
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              hintText: '搜索 $total 本书',
                              hintStyle: TextStyle(fontSize: 14, color: palette.muted),
                            ),
                          ),
                        ),
                        if (_searchTerm.isNotEmpty)
                          IconButton(
                            tooltip: '清空搜索',
                            icon: Icon(Icons.close_rounded, size: 18, color: palette.muted),
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
                            onSelected: (_) => setState(() => _filter = entry.key),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(kEink ? 0 : 16),
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
                if (continueBook != null && term.isEmpty && _filter == 'all')
                  _ContinueCard(
                    book: continueBook,
                    onTap: () => _openReader(continueBook),
                  ),
                Expanded(
                  child: visibleBooks.isEmpty
                      ? _EmptyLibrary(
                          isSearching: term.isNotEmpty,
                          onImport: _importBook,
                        )
                      : LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints bounds) {
                            final int columns = bounds.maxWidth >= 900
                                ? 6
                                : bounds.maxWidth >= 640
                                    ? 4
                                    : 3;
                            if (!_grid) {
                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                                    onOpen: () => _openBook(book),
                                    onMenu: () => _showBookMenu(store, book),
                                  );
                                },
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                                  onOpen: () => _openBook(book),
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
                      term.isEmpty ? '共 $total 本书籍' : '找到 ${visibleBooks.length} 本',
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

  Future<void> _showMoreMenu() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('导入书籍'),
              onTap: () => Navigator.pop(sheetContext, 'import'),
            ),
            ListTile(
              leading: const Icon(Icons.sort_rounded),
              title: const Text('按最近阅读排序'),
              subtitle: const Text('当前排序规则'),
              enabled: false,
              onTap: null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'import') await _importBook();
  }

  Future<void> _showBookMenu(LibraryStore store, Book book) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${book.author} · ${book.format.toUpperCase()}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('书籍详情'),
              onTap: () => Navigator.pop(sheetContext, 'detail'),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('开始阅读'),
              onTap: () => Navigator.pop(sheetContext, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除本地书籍'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'detail') await _openBook(book);
    if (action == 'open') await _openReader(book);
    if (action == 'delete') await _confirmDelete(store, book);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('删除')),
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
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final String progress = _progressLabel(book);
    final bool read = book.lastReadAt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            onTap: onOpen,
            onLongPress: onMenu,
            child: _Cover(book: book),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.title,
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
                progress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
            ),
            if (read)
              Icon(Icons.cloud_done_outlined, size: 13, color: palette.muted),
            InkWell(
              onTap: onMenu,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.more_horiz_rounded, size: 16, color: palette.muted),
              ),
            ),
          ],
        ),
      ],
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
        boxShadow: kEink || ReadPalette.of(context).brightness == Brightness.dark
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
              book.title,
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.ink),
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


class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.book, required this.onTap});
  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final int chapters = book.chapterCount;
    final double ratio = chapters > 0
        ? ((book.chapterIndex.value + 1) / chapters).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kEink ? 0 : 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.outline),
            borderRadius: BorderRadius.circular(kEink ? 0 : 12),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 54,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.background,
                  border: Border.all(color: palette.outline),
                  borderRadius: BorderRadius.circular(kEink ? 0 : 4),
                ),
                child: Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, height: 1.25, color: palette.ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('继续阅读',
                        style: TextStyle(fontSize: 11, color: palette.muted)),
                    const SizedBox(height: 3),
                    Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: palette.ink)),
                    const SizedBox(height: 4),
                    Text(
                      chapters > 0
                          ? '第 ${book.chapterIndex.value + 1}/$chapters 章 · ${(ratio * 100).toStringAsFixed(0)}%'
                          : '第 ${book.chapterIndex.value + 1} 章',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 19, color: palette.ink),
            ],
          ),
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
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

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
            Container(
              width: 42,
              height: 60,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.outline),
                borderRadius: BorderRadius.circular(kEink ? 0 : 4),
              ),
              child: Text(
                book.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, height: 1.25, color: palette.ink),
              ),
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
                          fontSize: 15, fontWeight: FontWeight.w600, color: palette.ink)),
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
              icon: Icon(Icons.more_horiz_rounded, size: 18, color: palette.muted),
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}
