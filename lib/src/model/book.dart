import 'package:flutter/foundation.dart';

/// 一本书的最小模型。
class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.content,
    this.format = 'TXT',
    this.sourcePath,
    this.lastReadAt,
  });

  final String id;
  final String title;
  final String author;
  final String content;
  final String format;

  /// 导入文件的绝对路径（内置样章为 null）。
  final String? sourcePath;
  final DateTime? lastReadAt;

  /// 阅读进度：章节索引与页索引。
  final ValueNotifier<int> chapterIndex = ValueNotifier<int>(0);
  final ValueNotifier<int> pageIndex = ValueNotifier<int>(0);

  /// Layout-independent progress within the current chapter; -1 = legacy page-only.
  final ValueNotifier<int> charOffset = ValueNotifier<int>(-1);

  Map<String, dynamic> toMeta() => <String, dynamic>{
        'id': id,
        'title': title,
        'author': author,
        'format': format,
        'sourcePath': sourcePath,
        'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
      };

  static Book fromMeta(Map<String, dynamic> m, String content) => Book(
        id: m['id'] as String,
        title: m['title'] as String,
        author: (m['author'] as String?) ?? '未知作者',
        format: (m['format'] as String?) ?? 'TXT',
        sourcePath: m['sourcePath'] as String?,
        lastReadAt: m['lastReadAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['lastReadAt'] as int),
        content: content,
      );
}
