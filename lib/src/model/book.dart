import 'package:flutter/foundation.dart';

/// 一本书的最小模型。
/// 注意：当前为内存模型，持久化与格式解析在后续阶段接入。
class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.content,
    this.format = 'TXT',
  });

  final String id;
  final String title;
  final String author;
  final String content;
  final String format;

  /// 阅读进度：页索引（0 起）。同步功能落地后改为带 rev 的实体。
  ValueNotifier<int> progress = ValueNotifier<int>(0);
}
