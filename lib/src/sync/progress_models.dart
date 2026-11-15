import 'dart:convert';

class ProgressRecord {
  const ProgressRecord({
    required this.hash,
    required this.format,
    required this.offset,
    required this.page,
    required this.revision,
    required this.device,
    required this.updatedAt,
  });

  final String hash;
  final String format;
  final int offset; // Absolute UTF-16 source text offset, -1 for a PDF.
  final int page; // PDF zero-based page number, 0 for text.
  final int revision;
  final String device;
  final int updatedAt;

  bool samePosition(ProgressRecord other) =>
      format == other.format && offset == other.offset && page == other.page;

  ProgressRecord withRevision(int newRevision, String newDevice, int now) =>
      ProgressRecord(
        hash: hash,
        format: format,
        offset: offset,
        page: page,
        revision: newRevision,
        device: newDevice,
        updatedAt: now,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hash': hash, 'format': format, 'offset': offset, 'page': page,
    'rev': revision, 'device': device, 'modified': updatedAt,
  };

  factory ProgressRecord.fromJson(Map<String, dynamic> data) {
    final hash = data['hash'];
    final format = data['format'];
    final offset = data['offset'];
    final page = data['page'];
    final revision = data['rev'];
    final device = data['device'];
    final modified = data['modified'];
    if (hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        format is! String ||
        !<String>['TXT', 'EPUB', 'PDF', 'MD', 'MARKDOWN', 'HTML', 'HTM'].contains(format) ||
        offset is! int || offset < -1 ||
        page is! int || page < 0 ||
        revision is! int || revision < 0 ||
        device is! String || device.isEmpty ||
        modified is! int || modified < 0) {
      throw const FormatException('阅读进度同步记录损坏');
    }
    return ProgressRecord(
      hash: hash, format: format, offset: offset, page: page,
      revision: revision, device: device, updatedAt: modified,
    );
  }
}

class ProgressManifest {
  const ProgressManifest(this.entries);
  static const format = 'read-progress-v1';
  final Map<String, ProgressRecord> entries;

  String encode() => jsonEncode(<String, dynamic>{
    'format': format,
    'entries': entries.values.map((value) => value.toJson()).toList(),
  });

  factory ProgressManifest.decode(String value) {
    final dynamic parsed;
    try {
      parsed = jsonDecode(value);
    } catch (_) {
      throw const FormatException('云端进度文件不是有效的 JSON');
    }
    if (parsed is! Map<String, dynamic> ||
        parsed['format'] != format || parsed['entries'] is! List) {
      throw const FormatException('云端进度格式不受支持');
    }
    final entries = <String, ProgressRecord>{};
    for (final item in parsed['entries'] as List) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('云端进度记录类型错误');
      }
      final record = ProgressRecord.fromJson(item);
      if (entries.containsKey(record.hash)) {
        throw const FormatException('云端存在重复的书籍内容指纹');
      }
      entries[record.hash] = record;
    }
    return ProgressManifest(entries);
  }
}

enum ProgressChoice { local, cloud }
enum ProgressDecision { local, cloud, conflict }

class ProgressMerger {
  static ProgressDecision decide({
    required ProgressRecord local,
    required ProgressRecord remote,
    required bool locallyChanged,
    required int baseRevision,
  }) {
    if (local.format != remote.format) return ProgressDecision.conflict;
    if (local.samePosition(remote)) {
      return local.revision >= remote.revision
          ? ProgressDecision.local
          : ProgressDecision.cloud;
    }
    if (!locallyChanged) return ProgressDecision.cloud;
    if (remote.revision <= baseRevision) return ProgressDecision.local;
    return ProgressDecision.conflict;
  }

  static ProgressRecord resolved(
    ProgressRecord chosen, ProgressRecord other, String device, int now,
  ) => chosen.withRevision(
    (chosen.revision > other.revision ? chosen.revision : other.revision) + 1,
    device,
    now,
  );
}
