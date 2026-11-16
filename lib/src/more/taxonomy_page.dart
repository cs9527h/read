import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/ui/sheet.dart';

/// 标签 / 分类 / 书箱的统一管理页。
class TaxonomyPage extends StatefulWidget {
  const TaxonomyPage({super.key});

  @override
  State<TaxonomyPage> createState() => _TaxonomyPageState();
}

class _TaxonomyPageState extends State<TaxonomyPage> {
  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: LibraryStore.instance,
      builder: (BuildContext context, Widget? _) {
        final LibraryStore store = LibraryStore.instance;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: palette.background,
            appBar: AppBar(
              backgroundColor: palette.background,
              surfaceTintColor: Colors.transparent,
              title: const Text('标签与分类'),
              leading: IconButton(
                icon: ReadIcon(ReadGlyph.arrowLeft, size: 21, color: palette.ink),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              bottom: TabBar(
                labelColor: palette.ink,
                unselectedLabelColor: palette.muted,
                dividerColor: palette.outline,
                tabs: <Widget>[
                  Tab(text: '标签 ${store.allTags.length}'),
                  Tab(text: '分类 ${store.allCategories.length}'),
                  Tab(text: '书箱 ${store.allCollections.length}'),
                ],
              ),
            ),
            body: TabBarView(
              children: <Widget>[
                _list(
                  palette,
                  items: store.allTags,
                  hint: '标签挂在书上，用于跨分类筛选。重命名会同时改掉所有书上的旧标签。',
                  empty: '还没有标签。在书籍「编辑信息」里可以添加。',
                  onRename: store.renameTag,
                  onDelete: store.deleteTag,
                  countOf: (String tag) =>
                      store.books.where((Book b) => b.tags.contains(tag)).length,
                ),
                _list(
                  palette,
                  items: store.allCategories,
                  hint: '分类是单值字段，一本书只属于一个分类；书箱可以多选。',
                  empty: '还没有分类。在书籍「编辑信息 → 分类」里填写。',
                  onRename: (String from, String to) =>
                      store.renameCategory(from, to),
                  onDelete: store.deleteCategory,
                  countOf: (String category) => store.books
                      .where((Book b) => b.category == category)
                      .length,
                ),
                _list(
                  palette,
                  items: store.allCollections,
                  hint: '书箱是可多选的集合，适合「待读」「技术」「今年重读」这类分组。',
                  empty: '还没有书箱。在书架菜单或编辑信息里创建。',
                  onRename: (String from, String to) async {
                    for (final Book book in store.books) {
                      if (!book.collections.contains(from)) continue;
                      await store.updateBook(book.copyWith(
                        collections: book.collections
                            .map((String c) => c == from ? to.trim() : c)
                            .toList(),
                      ));
                    }
                  },
                  onDelete: (String name) async {
                    for (final Book book in store.books) {
                      if (!book.collections.contains(name)) continue;
                      await store.updateBook(book.copyWith(
                        collections:
                            book.collections.where((String c) => c != name).toList(),
                      ));
                    }
                  },
                  countOf: (String name) =>
                      store.books.where((Book b) => b.collections.contains(name)).length,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _list(
    ReadPalette palette, {
    required List<String> items,
    required String hint,
    required String empty,
    required Future<void> Function(String from, String to) onRename,
    required Future<void> Function(String) onDelete,
    required int Function(String) countOf,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: <Widget>[
        Text(hint,
            style: TextStyle(fontSize: 11.5, height: 1.6, color: palette.muted)),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Text(empty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: palette.muted)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.outline),
              borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 14),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  _tile(palette, items[i], countOf(items[i]), onRename, onDelete),
                  if (i != items.length - 1)
                    Divider(height: 1, indent: 14, color: palette.outline),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(
    ReadPalette palette,
    String name,
    int count,
    Future<void> Function(String, String) onRename,
    Future<void> Function(String) onDelete,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: TextStyle(fontSize: 14.5, color: palette.ink)),
                const SizedBox(height: 2),
                Text('$count 本书',
                    style: TextStyle(fontSize: 11, color: palette.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: '重命名',
            icon: ReadIcon(ReadGlyph.edit, size: 17, color: palette.muted),
            onPressed: () async {
              final String? value = await promptText(
                context,
                title: '重命名',
                hint: name,
                initial: name,
                confirm: '保存',
              );
              if (value == null || value.trim().isEmpty || value.trim() == name) {
                return;
              }
              await onRename(name, value.trim());
            },
          ),
          IconButton(
            tooltip: '删除',
            icon: ReadIcon(ReadGlyph.trash, size: 17, color: palette.muted),
            onPressed: () async {
              final bool ok = await confirmAction(
                context,
                title: '删除「$name」？',
                message: '只会从书上移除这个标记，不会删除任何书籍或文件。',
                confirm: '删除',
                danger: true,
              );
              if (ok) await onDelete(name);
            },
          ),
        ],
      ),
    );
  }
}
