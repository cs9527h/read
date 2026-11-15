import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/pdf_reader_page.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/sync/progress_sync_page.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/version.dart';

/// A calm, responsive bookshelf: no account, decorations store or fake data.
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LibraryStore.instance,
      builder: (BuildContext context, Widget? child) {
        final LibraryStore store = LibraryStore.instance;
        final String term = _searchTerm.trim().toLowerCase();
        final List<Book> visibleBooks = store.books.where((Book book) {
          return term.isEmpty ||
              book.title.toLowerCase().contains(term) ||
              book.author.toLowerCase().contains(term);
        }).toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            titleSpacing: 24,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.auto_stories_rounded,
                  color: kEink ? Colors.black : ReadColors.accent,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'read.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: kEink ? Colors.black : ReadColors.ink,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'WebDAV 阅读进度同步',
                icon: Icon(
                  Icons.cloud_sync_outlined,
                  color: kEink ? Colors.black : ReadColors.ink,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProgressSyncPage(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 22),
                child: Center(
                  child: Text(
                    '我的书房',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: kEink ? Colors.black : ReadColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 112),
                  children: <Widget>[
                    Text(
                      'READ AT YOUR OWN PACE · $appVersionLabel',
                      style: TextStyle(
                        color: kEink ? Colors.black : ReadColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '把时间，留给阅读。',
                      style: Theme.of(context).textTheme.headlineLarge ??
                          const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '安静读书，慢慢积累。已收藏 ' +
                          store.books.length.toString() + ' 本书。',
                      style: TextStyle(
                        fontSize: 14,
                        color: kEink ? Colors.black : ReadColors.muted,
                      ),
                    ),
                    if (store.books.isNotEmpty && term.isEmpty) ...<Widget>[
                      const SizedBox(height: 28),
                      _ContinueReadingCard(
                        book: store.books.first,
                        onOpen: () => _openBook(store.books.first),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '我的书架',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          visibleBooks.length.toString() + ' 本',
                          style: TextStyle(
                            fontSize: 13,
                            color: kEink ? Colors.black : ReadColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (String value) => setState(() {
                        _searchTerm = value;
                      }),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '搜索书名或作者',
                        prefixIcon: const Icon(Icons.search_rounded, size: 21),
                        suffixIcon: _searchTerm.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清空搜索',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchTerm = '';
                                  });
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (visibleBooks.isEmpty)
                      _EmptyLibrary(
                        isSearching: term.isNotEmpty,
                        onImport: _importBook,
                      )
                    else
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints bounds) {
                          final bool twoColumns = bounds.maxWidth >= 690;
                          final double cardWidth = twoColumns
                              ? (bounds.maxWidth - 16) / 2
                              : bounds.maxWidth;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: <Widget>[
                              for (final Book book in visibleBooks)
                                SizedBox(
                                  width: cardWidth,
                                  child: _BookTile(
                                    book: book,
                                    onOpen: () => _openBook(book),
                                    onDelete: () => _confirmDelete(store, book),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _importBook,
            icon: const Icon(Icons.add_rounded),
            label: const Text('导入书籍'),
          ),
        );
      },
    );
  }

  Future<void> _openBook(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => book.format.toUpperCase() == 'PDF'
            ? PdfReaderPage(book: book)
            : ReaderPage(book: book),
      ),
    );
    if (!mounted) return;
    await LibraryStore.instance.touch(book);
  }

  Future<void> _importBook() async {
    try {
      final Book? book = await LibraryStore.instance.importBook();
      if (!mounted || book == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入《' + book.title + '》')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
        content: Text('《' + book.title + '》的本地副本和阅读进度将被删除，无法撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (approved == true) {
      await store.deleteBook(book);
    }
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({
    required this.book,
    required this.onOpen,
  });

  final Book book;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final Color background = kEink ? Colors.white : ReadColors.softGreen;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kEink ? 0 : 24),
        side: BorderSide(color: kEink ? Colors.black : ReadColors.outline),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(kEink ? 0 : 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _BookCover(book: book, width: 104, height: 148),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '继续阅读',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kEink ? Colors.black : ReadColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
                        height: 1.25,
                        color: kEink ? Colors.black : ReadColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.author + ' · 第 ' +
                          (book.chapterIndex.value + 1).toString() + ' 章',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: kEink ? Colors.black : ReadColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '接着读',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: kEink ? Colors.black : ReadColors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onOpen,
    required this.onDelete,
  });

  final Book book;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kEink ? 0 : 20),
        side: BorderSide(color: kEink ? Colors.black : ReadColors.outline),
      ),
      child: InkWell(
        onTap: onOpen,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(kEink ? 0 : 20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              _BookCover(book: book, width: 70, height: 99),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: kEink ? Colors.black : ReadColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      book.format.toUpperCase() + '  ·  第 ' +
                          (book.chapterIndex.value + 1).toString() + ' 章',
                      style: TextStyle(
                        fontSize: 11,
                        color: kEink ? Colors.black : ReadColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (String value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('删除本地书籍'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.book,
    required this.width,
    required this.height,
  });

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    const List<Color> covers = <Color>[
      Color(0xFF355A50),
      Color(0xFF536C83),
      Color(0xFF8B5C55),
      Color(0xFF68637F),
      Color(0xFF987B46),
    ];
    final int tint = book.title.runes.fold<int>(0, (int a, int b) => a + b);
    final Color color = covers[tint % covers.length];

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kEink ? Colors.white : color,
        borderRadius: BorderRadius.circular(kEink ? 0 : 8),
        border: kEink ? Border.all(color: Colors.black, width: 1) : null,
        gradient: kEink
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[color, Color.lerp(color, Colors.black, 0.24)!],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.auto_stories_outlined,
            size: width > 90 ? 22 : 16,
            color: kEink ? Colors.black : Colors.white70,
          ),
          const Spacer(),
          Text(
            book.title,
            maxLines: width > 90 ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: kEink ? Colors.black : Colors.white,
              fontSize: width > 90 ? 14 : 11,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            book.format.toUpperCase(),
            style: TextStyle(
              color: kEink ? Colors.black : Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.isSearching,
    required this.onImport,
  });

  final bool isSearching;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kEink ? 0 : 20),
        border: Border.all(color: kEink ? Colors.black : ReadColors.outline),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.menu_book_rounded,
            color: kEink ? Colors.black : ReadColors.accent,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            isSearching ? '没有找到这本书' : '你的书架还空着',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            isSearching ? '试试其他书名或作者' : '从本地文件开始收藏第一本书',
            textAlign: TextAlign.center,
          ),
          if (!isSearching) ...<Widget>[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded),
              label: const Text('导入书籍'),
            ),
          ],
        ],
      ),
    );
  }
}
