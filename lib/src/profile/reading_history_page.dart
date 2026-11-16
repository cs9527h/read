import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/pdf_reader_page.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// 我的阅读：按阅读状态筛选的书单。
/// 「搁置」目前没有独立状态字段，因此只提供有真实依据的三档。
class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: LibraryStore.instance,
      builder: (BuildContext context, Widget? child) {
        final LibraryStore store = LibraryStore.instance;
        final List<Book> filtered = store.books.where((Book book) {
          if (_filter == 0) return true;
          final bool finished = ReadingStatsStore.instance.isFinished(book.id);
          if (_filter == 1) return book.lastReadAt != null && !finished;
          return finished;
        }).toList(growable: false);

        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            title: Text('我的阅读', style: TextStyle(fontSize: 18, color: palette.ink)),
            leading: IconButton(
              icon: ReadIcon(ReadGlyph.arrowLeft, size: 20, color: palette.icon),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(<String>['全部', '在读', '读完'][i]),
                          selected: _filter == i,
                          onSelected: (_) => setState(() => _filter = i),
                          showCheckmark: false,
                          side: BorderSide(color: palette.outline),
                          backgroundColor: palette.surface,
                          selectedColor: palette.ink,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: _filter == i
                                ? (palette.brightness == Brightness.dark
                                    ? Colors.black
                                    : Colors.white)
                                : palette.muted,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _filter == 2 ? '还没有读完的书' : '还没有阅读记录',
                          style: TextStyle(fontSize: 13, color: palette.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final Book book = filtered[index];
                          return _HistoryRow(
                            book: book,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => book.format.toUpperCase() == 'PDF'
                                      ? PdfReaderPage(book: book)
                                      : ReaderPage(book: book),
                                ),
                              );
                              if (!context.mounted) return;
                              await LibraryStore.instance.touch(book);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final int chapters = book.chapterCount;
    final bool finished = ReadingStatsStore.instance.isFinished(book.id);
    final String progress = finished
        ? '已读完'
        : book.lastReadAt == null
            ? '未读过'
            : chapters > 0
                ? '读到 ${((book.chapterIndex.value + 1) / chapters * 100).clamp(0, 100).toStringAsFixed(1)}%'
                : '第 ${book.chapterIndex.value + 1} 章';
    final DateTime? at = book.lastReadAt;
    final String when = at == null
        ? '尚未打开'
        : '${at.year}年${at.month}月${at.day}日 ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
          border: Border.all(color: palette.outline),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 5),
              ),
              child: Text(
                book.title.characters.take(1).toString(),
                style: TextStyle(
                  color: palette.brightness == Brightness.dark ? Colors.black : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.author} · ${book.format.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$progress · $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                ],
              ),
            ),
            ReadIcon(ReadGlyph.chevronRight, size: 18, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
