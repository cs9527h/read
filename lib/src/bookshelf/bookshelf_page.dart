import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/reader_page.dart';

/// 内存书架。持久化与真实文件导入在 P1.2 接入。
class LibraryStore {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  final List<Book> books = <Book>[
    Book(
      id: 'sample-1',
      title: '示例长文',
      author: '内置样章',
      content: _sampleContent,
    ),
  ];
}

class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LibraryStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('书架'), centerTitle: false),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: store.books.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final book = store.books[index];
          return ListTile(
            title: Text(book.title, style: const TextStyle(fontSize: 17)),
            subtitle: Text('${book.author} · ${book.format}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReaderPage(book: book),
              ),
            ),
          );
        },
      ),
    );
  }
}

const String _sampleContent =
    '这是一段用于验证阅读与分页效果的内置样章。\n'
    '极简阅读器的第一阶段目标：把文本稳稳地排到屏幕上，翻页不跳行、不吞字，字号可调，进度能记住。\n'
    '下面重复若干段落，用来产生足够多的页面。\n'
    '段落一。阅读是一种慢速的输入，排版决定了它是否顺畅。行高、字距、页边距，三者共同决定一眼能读到多少内容。\n'
    '段落二。墨水屏设备的刷新代价高，因此翻页应尽量避免整页重绘以外的动画开销。\n'
    '段落三。多端同步的关键不是“同步文件”，而是“同步位置与标注”，并能在离线修改后合并。\n'
    '段落四。每一章都应记录内容哈希，避免不同设备上同一本书的内容不一致却共享进度。\n'
    '段落五。字体导入、双页、脚注气泡、简繁转换，都会在后续阶段逐项补齐，绝不以占位形式标为完成。\n'
    '段落六。TXT 的智能分章要同时支持正则表达式与内置规则，并提供预览，避免误伤正文。\n'
    '段落七。PDF 需要独立阅读体验：裁边、标注、页面转码，不能简单当作图片流处理。\n'
    '段落八。漫画与 PDF 共享缩放与裁白边能力，但跨页拆分与从右到左阅读顺序要单独实现。\n'
    '段落九。笔记系统以“标注锚点 + 颜色 + 备注”为核心，导出卡片只是表现形式之一。\n'
    '段落十。查词、翻译、AI 助手共用一层网关，便于未来替换服务商与本地模型。\n'
    '段落十一。听书需要与阅读位置联动，跟读高亮依赖时间戳对齐，不能只做后台播放。\n'
    '段落十二。统计只统计阅读行为本身：时长、字数、连续天数，不做社交排名。\n'
    '段落十三。同步后端计划支持 WebDAV、S3 兼容存储与本地目录；iCloud 仅在 Apple 平台可用。\n'
    '段落十四。所有同步数据默认端到端加密，密钥不落在服务端。\n'
    '段落十五。这一页之后还有几页，用来验证翻页边界与最后一页的处理。\n'
    '收尾段落。如果你看到这里，说明分页、翻页、字号调整都已正常工作。\n';
