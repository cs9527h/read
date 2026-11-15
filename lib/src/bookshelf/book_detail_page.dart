import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/pdf_reader_page.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/reader/widgets/reader_settings_sheet.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/theme.dart';

/// 现代书籍详情页：封面、元数据、进度、继续阅读、本书排版与删除。
class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key, required this.book});

  final Book book;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late Book book = widget.book;
  int _bookmarks = 0;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final values = await BookmarkStore.load(book.id);
    if (mounted) setState(() => _bookmarks = values.length);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final double ratio = _progress;
    final bool finished = ReadingStatsStore.instance.isFinished(book.id);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            tooltip: '本书排版',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openBookSettings,
          ),
          PopupMenuButton<String>(
            onSelected: (String action) {
              if (action == 'delete') _confirmDelete();
            },
            itemBuilder: (BuildContext ctx) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'delete', child: Text('删除本地书籍')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LargeCover(book: book),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      book.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(book.author,
                        style: TextStyle(fontSize: 13, color: palette.muted)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _tag(book.format.toUpperCase()),
                        if (book.fileSize > 0)
                          _tag(_formatBytes(book.fileSize)),
                        if (book.chapterCount > 0)
                          _tag('${book.chapterCount} 章'),
                        if (finished) _tag('已读完'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Text(
                          '${(ratio * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(kEink ? 0 : 3),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 3,
                              backgroundColor: palette.outline,
                              valueColor: AlwaysStoppedAnimation<Color>(palette.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.ink,
                          foregroundColor: palette.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kEink ? 0 : 10),
                          ),
                        ),
                        onPressed: _openBook,
                        child: Text(
                          book.lastReadAt == null ? '开始阅读' : '继续阅读',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: palette.outline),
          const SizedBox(height: 16),
          _row(palette, '阅读进度',
              book.lastReadAt == null ? '尚未开始' : '第 ${book.chapterIndex.value + 1} 章'),
          _row(palette, '书签', '$_bookmarks 条'),
          _row(palette, '最近阅读',
              book.lastReadAt == null ? '—' : _formatTime(book.lastReadAt!)),
          _row(palette, '文件大小',
              book.fileSize > 0 ? _formatBytes(book.fileSize) : '未记录'),
          _row(palette, '内容哈希',
              book.contentHash == null
                  ? '下次同步时计算'
                  : '${book.contentHash!.substring(0, 16)}…'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(kEink ? 0 : 12),
              border: Border.all(color: palette.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('本地优先', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.ink)),
                const SizedBox(height: 6),
                Text(
                  '阅读不依赖网络。同步只上传加密后的元数据、进度与可选文件；删除本书会同时删除本机文件。',
                  style: TextStyle(fontSize: 12, color: palette.muted, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double get _progress {
    if (book.lastReadAt == null) return 0;
    if (ReadingStatsStore.instance.isFinished(book.id)) return 1;
    if (book.chapterCount > 0) {
      return ((book.chapterIndex.value + 1) / book.chapterCount).clamp(0, 1);
    }
    return book.chapterIndex.value > 0 ? 0.05 : 0;
  }

  Widget _tag(String text) {
    final palette = ReadPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(kEink ? 0 : 4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: palette.muted)),
    );
  }

  Widget _row(ReadPalette palette, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 13, color: palette.muted)),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: palette.ink),
              ),
            ),
          ],
        ),
      );

  Future<void> _openBook() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => book.format.toUpperCase() == 'PDF'
            ? PdfReaderPage(book: book)
            : ReaderPage(book: book),
      ),
    );
    if (!mounted) return;
    await LibraryStore.instance.touch(book);
    setState(() => book = LibraryStore.instance.bookByHash(book.contentHash ?? '') ?? book);
    await _loadBookmarks();
  }

  Future<void> _openBookSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ReaderSettingsSheet(
        bookId: book.id,
        onRepaginate: () {},
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除这本书？'),
        content: Text('《${book.title}》的本地文件和阅读进度将被删除。删除会作为同步墓碑传播，但不会自动删除其他设备上的文件。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await LibraryStore.instance.deleteBook(book);
    if (mounted) Navigator.of(context).pop();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime at) {
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _LargeCover extends StatelessWidget {
  const _LargeCover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final bool dark = palette.brightness == Brightness.dark;
    return Container(
      width: 116,
      height: 166,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF191919) : const Color(0xFFF1F1F1),
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(kEink ? 0 : 8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 24, height: 2, color: palette.ink),
          const Spacer(),
          Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(book.format.toUpperCase(),
              style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: palette.muted)),
        ],
      ),
    );
  }
}
