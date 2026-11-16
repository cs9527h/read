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
    this.chapterCount = 0,
    this.contentHash,
    this.fileName,
    this.fileSize = 0,
    List<String>? tags,
    this.category = '',
    this.rating = 0,
    this.pinned = false,
    this.isPrivate = false,
    this.readingStatus = 'unread',
    this.coverPath,
  }) : tags = tags ?? <String>[];

  final String id;
  final String title;
  final String author;
  final String content;
  final String format;

  /// 导入文件的绝对路径（内置样章为 null）。
  final String? sourcePath;
  final DateTime? lastReadAt;

  /// 章节总数缓存（由阅读页写入，用于书架显示粗略进度）。
  int chapterCount;

  /// SHA-256 of the original imported bytes. This is the cross-device
  /// identity used by sync; local numeric ids are intentionally device-local.
  String? contentHash;
  String? fileName;
  int fileSize;

  /// User-defined tags/categories. Stored locally and synced by content hash.
  List<String> tags;

  /// 书架编辑信息：分类、评分、置顶、私密、阅读状态与本地封面。
  String category;
  int rating;
  bool pinned;
  bool isPrivate;
  String readingStatus;
  String? coverPath;

  Book copyWith({
    String? title,
    String? author,
    DateTime? lastReadAt,
    int? chapterCount,
    List<String>? tags,
    String? category,
    int? rating,
    bool? pinned,
    bool? isPrivate,
    String? readingStatus,
    String? coverPath,
    int? fileSize,
    String? fileName,
  }) {
    final Book next = Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      content: content,
      format: format,
      sourcePath: sourcePath,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      chapterCount: chapterCount ?? this.chapterCount,
      contentHash: contentHash,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      tags: List<String>.from(tags ?? this.tags),
      category: category ?? this.category,
      rating: rating ?? this.rating,
      pinned: pinned ?? this.pinned,
      isPrivate: isPrivate ?? this.isPrivate,
      readingStatus: readingStatus ?? this.readingStatus,
      coverPath: coverPath ?? this.coverPath,
    );
    next.chapterIndex.value = chapterIndex.value;
    next.pageIndex.value = pageIndex.value;
    next.charOffset.value = charOffset.value;
    return next;
  }

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
        'chapterCount': chapterCount,
        'contentHash': contentHash,
        'fileName': fileName,
        'fileSize': fileSize,
        'tags': tags,
        'category': category,
        'rating': rating,
        'pinned': pinned,
        'isPrivate': isPrivate,
        'readingStatus': readingStatus,
        'coverPath': coverPath,
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
        chapterCount: (m['chapterCount'] as int?) ?? 0,
        contentHash: m['contentHash'] as String?,
        fileName: m['fileName'] as String?,
        fileSize: (m['fileSize'] as num?)?.toInt() ?? 0,
        tags: (m['tags'] as List<dynamic>?)
            ?.whereType<String>()
            .where((String t) => t.trim().isNotEmpty)
            .map((String t) => t.trim())
            .toSet()
            .toList(),
        category: (m['category'] as String?) ?? '',
        rating: ((m['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
        pinned: m['pinned'] == true,
        isPrivate: m['isPrivate'] == true,
        readingStatus: (m['readingStatus'] as String?) ??
            (m['lastReadAt'] == null ? 'unread' : 'reading'),
        coverPath: m['coverPath'] as String?,
      );
}
