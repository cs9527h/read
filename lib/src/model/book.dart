import 'package:flutter/foundation.dart';

/// 阅读状态。与「读完」统计解耦：状态是用户显式声明，统计是行为推断。
enum ReadingStatus {
  unread('unread', '未读'),
  reading('reading', '在读'),
  paused('paused', '搁置'),
  finished('finished', '读完'),
  abandoned('abandoned', '弃读');

  const ReadingStatus(this.code, this.label);

  final String code;
  final String label;

  static ReadingStatus fromCode(String? code) {
    for (final ReadingStatus value in ReadingStatus.values) {
      if (value.code == code) return value;
    }
    return ReadingStatus.unread;
  }
}

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
    this.pinned = false,
    this.rating = 0,
    this.readingStatus = 'unread',
    this.category = '',
    List<String>? collections,
    this.coverPath,
    this.coverTemplate = 'ink',
    this.isPrivate = false,
    DateTime? addedAt,
  })  : tags = tags ?? <String>[],
        collections = collections ?? <String>[],
        addedAt = addedAt ?? DateTime.now();

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

  /// 置顶：书架排序时优先，且始终排在自动排序之前。
  bool pinned;
  int rating; // 0..5
  String readingStatus; // ReadingStatus.code
  String category;
  List<String> collections;
  String? coverPath;

  /// 无封面图时使用的内置模板 id。
  String coverTemplate;
  bool isPrivate;
  DateTime addedAt;

  ReadingStatus get status => ReadingStatus.fromCode(readingStatus);

  set status(ReadingStatus value) => readingStatus = value.code;

  /// 阅读进度：章节索引与页索引。
  final ValueNotifier<int> chapterIndex = ValueNotifier<int>(0);
  final ValueNotifier<int> pageIndex = ValueNotifier<int>(0);

  /// Layout-independent progress within the current chapter; -1 = legacy page-only.
  final ValueNotifier<int> charOffset = ValueNotifier<int>(-1);

  /// 粗略进度 0..1，用于书架展示。章节内偏移无法直接换算成全书比例，
  /// 这里按章节位置估算，与阅读器内的精确进度分工不同。
  double get progressRatio {
    if (chapterCount <= 0) return 0;
    final double chapter =
        (chapterIndex.value + 1).clamp(0, chapterCount).toDouble();
    return (chapter / chapterCount).clamp(0.0, 1.0);
  }

  Book copyWith({
    String? title,
    String? author,
    String? content,
    String? format,
    String? sourcePath,
    DateTime? lastReadAt,
    int? chapterCount,
    String? contentHash,
    String? fileName,
    int? fileSize,
    List<String>? tags,
    bool? pinned,
    int? rating,
    String? readingStatus,
    String? category,
    List<String>? collections,
    String? coverPath,
    String? coverTemplate,
    bool? isPrivate,
    DateTime? addedAt,
    bool clearCover = false,
  }) {
    final Book copy = Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      content: content ?? this.content,
      format: format ?? this.format,
      sourcePath: sourcePath ?? this.sourcePath,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      chapterCount: chapterCount ?? this.chapterCount,
      contentHash: contentHash ?? this.contentHash,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      tags: List<String>.from(tags ?? this.tags),
      pinned: pinned ?? this.pinned,
      rating: rating ?? this.rating,
      readingStatus: readingStatus ?? this.readingStatus,
      category: category ?? this.category,
      collections: List<String>.from(collections ?? this.collections),
      coverPath: clearCover ? null : (coverPath ?? this.coverPath),
      coverTemplate: coverTemplate ?? this.coverTemplate,
      isPrivate: isPrivate ?? this.isPrivate,
      addedAt: addedAt ?? this.addedAt,
    );
    copy.chapterIndex.value = chapterIndex.value;
    copy.pageIndex.value = pageIndex.value;
    copy.charOffset.value = charOffset.value;
    return copy;
  }

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
        'pinned': pinned,
        'rating': rating,
        'readingStatus': readingStatus,
        'category': category,
        'collections': collections,
        'coverPath': coverPath,
        'coverTemplate': coverTemplate,
        'isPrivate': isPrivate,
        'addedAt': addedAt.millisecondsSinceEpoch,
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
        pinned: m['pinned'] == true,
        rating: ((m['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
        readingStatus: (m['readingStatus'] as String?) ?? 'unread',
        category: (m['category'] as String?) ?? '',
        collections: (m['collections'] as List<dynamic>?)
                ?.whereType<String>()
                .where((String c) => c.trim().isNotEmpty)
                .toList() ??
            <String>[],
        coverPath: m['coverPath'] as String?,
        coverTemplate: (m['coverTemplate'] as String?) ?? 'ink',
        isPrivate: m['isPrivate'] == true,
        addedAt: m['addedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['addedAt'] as int),
      );
}
