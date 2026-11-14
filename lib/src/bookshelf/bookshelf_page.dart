import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';
import 'package:read/src/services/library_store.dart';

class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LibraryStore.instance,
      builder: (BuildContext context, _) {
        final store = LibraryStore.instance;
        return Scaffold(
          appBar: AppBar(title: const Text('书架')),
          body: store.books.isEmpty
              ? const Center(child: Text('还没有书，点右下角导入'))
              : ListView.separated(
                  itemCount: store.books.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final Book book = store.books[index];
                    return ListTile(
                      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${book.author} · ${book.format} · 第 ${book.chapterIndex.value + 1} 章',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReaderPage(book: book),
                          ),
                        );
                        await store.touch(book);
                      },
                      onLongPress: () => _confirmDelete(context, store, book),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final Book? book = await LibraryStore.instance.importBook();
              if (!context.mounted) return;
              if (book == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('没有选到可读的文本文件')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已导入《${book.title}》')),
              );
            },
            icon: const Icon(Icons.file_open),
            label: const Text('导入'),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LibraryStore store,
    Book book,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除这本书'),
        content: Text('会同时删除本地副本与阅读进度：${book.title}'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteBook(book);
    }
  }
}
