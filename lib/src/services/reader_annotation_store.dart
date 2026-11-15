import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Durable text annotation in absolute UTF-16 source offsets.
/// Typography changes and EPUB/TXT reflow do not alter these anchors.
class ReaderAnnotation {
  const ReaderAnnotation({
    required this.id,
    required this.start,
    required this.end,
    required this.quote,
    required this.note,
    required this.colorArgb,
    required this.createdAt,
  });

  final String id;
  final int start;
  final int end;
  final String quote;
  final String note;
  final int colorArgb;
  final int createdAt;

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'start': start,
        'end': end,
        'quote': quote,
        'note': note,
        'colorArgb': colorArgb,
        'createdAt': createdAt,
      };

  factory ReaderAnnotation.fromJson(Map<String, dynamic> raw) {
    final id = raw['id'];
    final start = raw['start'];
    final end = raw['end'];
    final quote = raw['quote'];
    final note = raw['note'];
    final color = raw['colorArgb'];
    final created = raw['createdAt'];
    if (id is! String || id.isEmpty || id.length > 64 ||
        start is! int || end is! int || start < 0 || end <= start ||
        quote is! String || quote.length > 2000 ||
        note is! String || note.length > 4000 ||
        color is! int || color < 0 || color > 0xFFFFFFFF ||
        created is! int || created < 0) {
      throw const FormatException('阅读批注数据无效');
    }
    return ReaderAnnotation(
      id: id,
      start: start,
      end: end,
      quote: quote,
      note: note,
      colorArgb: color,
      createdAt: created,
    );
  }

  ReaderAnnotation copyWith({String? note, int? colorArgb}) =>
      ReaderAnnotation(
        id: id,
        start: start,
        end: end,
        quote: quote,
        note: note ?? this.note,
        colorArgb: colorArgb ?? this.colorArgb,
        createdAt: createdAt,
      );
}

class ReaderAnnotationStore {
  ReaderAnnotationStore._();
  static final ReaderAnnotationStore instance = ReaderAnnotationStore._();
  static const _prefix = 'read.reader.annotations.v1.';
  Future<void> _pendingWrites = Future<void>.value();

  String _key(String id) => _prefix + Uri.encodeComponent(id);

  List<ReaderAnnotation> _decode(String? raw) {
    if (raw == null) return <ReaderAnnotation>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List || list.length > 5000) {
        throw const FormatException('批注数量超出上限');
      }
      final annotations = <ReaderAnnotation>[
        for (final item in list)
          ReaderAnnotation.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
      annotations.sort((a, b) => a.start.compareTo(b.start));
      return annotations;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('阅读批注记录损坏，已保留原始数据');
    }
  }

  Future<List<ReaderAnnotation>> load(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key(bookId)));
  }

  Future<List<ReaderAnnotation>> _edit(
    String bookId,
    List<ReaderAnnotation> Function(List<ReaderAnnotation>) modify,
  ) {
    final result = _pendingWrites.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final current = _decode(prefs.getString(_key(bookId)));
      final next = modify(current);
      if (!await prefs.setString(
        _key(bookId),
        jsonEncode(next.map((a) => a.toJson()).toList(growable: false)),
      )) {
        throw StateError('阅读批注保存失败');
      }
      return next;
    });
    _pendingWrites = result.then<void>((_) {});
    return result;
  }

  Future<List<ReaderAnnotation>> add({
    required String bookId,
    required String content,
    required int start,
    required int end,
    required int colorArgb,
    String note = '',
  }) {
    if (start < 0 || end <= start || end > content.length ||
        colorArgb < 0 || colorArgb > 0xFFFFFFFF || note.length > 4000) {
      throw const FormatException('批注范围超出正文');
    }
    final quote = content.substring(start, end);
    if (quote.trim().isEmpty) {
      throw const FormatException('不能对空白文本添加划线');
    }
    return _edit(bookId, (items) {
      final existing = items.indexWhere((a) => a.start == start && a.end == end);
      if (existing >= 0) {
        items[existing] = items[existing].copyWith(
          colorArgb: colorArgb,
          note: note,
        );
      } else {
        items.add(ReaderAnnotation(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          start: start,
          end: end,
          quote: quote.length > 2000 ? quote.substring(0, 2000) : quote,
          note: note,
          colorArgb: colorArgb,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      items.sort((a, b) => a.start.compareTo(b.start));
      return items;
    });
  }

  Future<List<ReaderAnnotation>> update(
    String bookId,
    String id, {
    String? note,
    int? colorArgb,
  }) {
    if ((note?.length ?? 0) > 4000) {
      throw const FormatException('笔记内容不能超过 4000 字');
    }
    return _edit(bookId, (items) {
      final index = items.indexWhere((a) => a.id == id);
      if (index < 0) throw StateError('批注不存在');
      items[index] = items[index].copyWith(note: note, colorArgb: colorArgb);
      return items;
    });
  }

  Future<List<ReaderAnnotation>> delete(String bookId, String id) =>
      _edit(bookId, (items) {
        items.removeWhere((a) => a.id == id);
        return items;
      });
}
