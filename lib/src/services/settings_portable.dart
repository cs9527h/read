import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;

import 'package:read/src/model/book.dart';
import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/services/appearance_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/shelf_settings.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/theme/ui_mode.dart';

/// 本机设置的可移植快照。
///
/// 只导出"真正能恢复"的东西：外观、阅读排版、书架偏好、同步的非密钥配置，
/// 以及（可选）书架元数据。**绝不导出密码、密钥、access key**——导出文件
/// 会被随手分享出去，密钥不该出现在里面。
class SettingsPortable {
  const SettingsPortable._();

  static const int formatVersion = 1;

  static Future<Map<String, Object?>> collect({bool includeBooks = false}) async {
    final Map<String, Object?> reader = <String, Object?>{};
    try {
      reader.addAll(
        jsonDecode(ReaderSettingsStore.instance.globalSettings().toJsonString())
            as Map<String, dynamic>,
      );
    } catch (_) {}

    final Map<String, Object?> shelf = <String, Object?>{
      'sortMode': LibraryStore.instance.sortMode,
      'showProgress': ShelfSettings.instance.showProgress,
      'showCloud': ShelfSettings.instance.showCloud,
      'showPrivate': ShelfSettings.instance.showPrivate,
      'columns': ShelfSettings.instance.columns,
      'compact': ShelfSettings.instance.compact,
    };

    final SyncConfig sync = SyncConfig.instance;
    final Map<String, Object?> syncData = <String, Object?>{
      'provider': sync.provider,
      'webdavUrl': sync.webdavUrl,
      'webdavDirectory': sync.webdavDirectory,
      'webdavUsername': sync.webdavUsername,
      's3Endpoint': sync.s3Endpoint,
      's3Region': sync.s3Region,
      's3Bucket': sync.s3Bucket,
      's3Prefix': sync.s3Prefix,
      's3AccessKey': sync.s3AccessKey,
      'syncBooks': sync.syncBooks,
      'syncBookmarks': sync.syncBookmarks,
      'syncReaderSettings': sync.syncReaderSettings,
      'syncStats': sync.syncStats,
      'syncFiles': sync.syncFiles,
      'encryptFiles': sync.encryptFiles,
      'autoJumpProgress': sync.autoJumpProgress,
      'promptCloudProgress': sync.promptCloudProgress,
      'conflictPolicy': sync.conflictPolicy,
      'progressAuto': sync.progressAuto,
      'fullAuto': sync.fullAuto,
      'wifiOnly': sync.wifiOnly,
    };

    return <String, Object?>{
      'app': 'read',
      'kind': 'settings',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appearance': <String, Object?>{
        'themeMode': AppearanceStore.instance.themeMode.name,
        'fontScale': AppearanceStore.instance.fontScale,
        'bigTitle': AppearanceStore.instance.bigTitle,
        'uiMode': ReadUi.instance.mode.name,
      },
      'reader': reader,
      'shelf': shelf,
      'sync': syncData,
      if (includeBooks)
        'books': LibraryStore.instance.books
            .map((Book b) => <String, Object?>{
                  'hash': b.contentHash,
                  'title': b.title,
                  'author': b.author,
                  'tags': b.tags,
                  'category': b.category,
                  'collections': b.collections,
                  'pinned': b.pinned,
                  'rating': b.rating,
                  'readingStatus': b.readingStatus,
                  'coverTemplate': b.coverTemplate,
                })
            .toList(),
    };
  }

  static Future<String> exportJson({bool includeBooks = true}) async {
    final Map<String, Object?> data = await collect(includeBooks: includeBooks);
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 解析并校验导入文件，返回可展示的覆盖范围说明。
  static PortablePreview inspect(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('文件不是有效的 JSON 对象');
    }
    if (decoded['app'] != 'read' || decoded['kind'] != 'settings') {
      throw const FormatException('这不是 Read 的设置导出文件');
    }
    final int version = (decoded['formatVersion'] as num?)?.toInt() ?? 0;
    if (version <= 0 || version > formatVersion) {
      throw FormatException('不支持的设置文件版本：$version');
    }
    final List<String> parts = <String>[];
    if (decoded['appearance'] is Map) parts.add('外观与界面风格');
    if (decoded['reader'] is Map) parts.add('阅读排版');
    if (decoded['shelf'] is Map) parts.add('书架偏好与排序');
    if (decoded['sync'] is Map) parts.add('同步配置（不含密码）');
    if (decoded['books'] is List) {
      parts.add('书架元数据 ${(decoded['books'] as List<dynamic>).length} 本');
    }
    return PortablePreview(
      raw: decoded,
      parts: parts,
      exportedAt: decoded['exportedAt'] as String?,
    );
  }

  /// 应用设置。[scopes] 可限制只恢复其中几类。
  static Future<void> apply(
    Map<String, dynamic> data, {
    Set<PortableScope> scopes = const <PortableScope>{
      PortableScope.appearance,
      PortableScope.reader,
      PortableScope.shelf,
      PortableScope.sync,
      PortableScope.books,
    },
  }) async {
    if (scopes.contains(PortableScope.appearance) && data['appearance'] is Map) {
      final Map<String, dynamic> a = data['appearance'] as Map<String, dynamic>;
      final String? mode = a['themeMode'] as String?;
      final ThemeMode themeMode = switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      await AppearanceStore.instance.setThemeMode(themeMode);
      final Object? scale = a['fontScale'];
      if (scale is num) await AppearanceStore.instance.setFontScale(scale.toDouble());
      final Object? bigTitle = a['bigTitle'];
      if (bigTitle is bool) await AppearanceStore.instance.setBigTitle(bigTitle);
      final String? ui = a['uiMode'] as String?;
      if (ui == 'eink') {
        await ReadUi.instance.setMode(ReadUiMode.eink);
      } else if (ui == 'classic') {
        await ReadUi.instance.setMode(ReadUiMode.classic);
      }
    }

    if (scopes.contains(PortableScope.reader) && data['reader'] is Map) {
      final Map<String, dynamic> reader = data['reader'] as Map<String, dynamic>;
      await ReaderSettingsStore.instance.save(
        '',
        ReaderSettings(reader),
        ReaderScope.global,
      );
    }

    if (scopes.contains(PortableScope.shelf) && data['shelf'] is Map) {
      final Map<String, dynamic> shelf = data['shelf'] as Map<String, dynamic>;
      final String? sort = shelf['sortMode'] as String?;
      if (sort != null) await LibraryStore.instance.setSortMode(sort);
      final ShelfSettings s = ShelfSettings.instance;
      if (shelf['showProgress'] is bool) {
        await s.setShowProgress(shelf['showProgress'] as bool);
      }
      if (shelf['showCloud'] is bool) await s.setShowCloud(shelf['showCloud'] as bool);
      if (shelf['showPrivate'] is bool) {
        await s.setShowPrivate(shelf['showPrivate'] as bool);
      }
      if (shelf['columns'] is num) {
        await s.setColumns((shelf['columns'] as num).toInt());
      }
      if (shelf['compact'] is bool) await s.setCompact(shelf['compact'] as bool);
    }

    if (scopes.contains(PortableScope.sync) && data['sync'] is Map) {
      final Map<String, dynamic> sync = data['sync'] as Map<String, dynamic>;
      final SyncConfig config = SyncConfig.instance;
      String str(String key, String fallback) =>
          sync[key] is String ? sync[key] as String : fallback;
      bool flag(String key, bool fallback) =>
          sync[key] is bool ? sync[key] as bool : fallback;
      config
        ..provider = str('provider', config.provider)
        ..webdavUrl = str('webdavUrl', config.webdavUrl)
        ..webdavDirectory = str('webdavDirectory', config.webdavDirectory)
        ..webdavUsername = str('webdavUsername', config.webdavUsername)
        ..s3Endpoint = str('s3Endpoint', config.s3Endpoint)
        ..s3Region = str('s3Region', config.s3Region)
        ..s3Bucket = str('s3Bucket', config.s3Bucket)
        ..s3Prefix = str('s3Prefix', config.s3Prefix)
        ..s3AccessKey = str('s3AccessKey', config.s3AccessKey)
        ..syncBooks = flag('syncBooks', config.syncBooks)
        ..syncBookmarks = flag('syncBookmarks', config.syncBookmarks)
        ..syncReaderSettings = flag('syncReaderSettings', config.syncReaderSettings)
        ..syncStats = flag('syncStats', config.syncStats)
        ..syncFiles = flag('syncFiles', config.syncFiles)
        ..encryptFiles = flag('encryptFiles', config.encryptFiles)
        ..autoJumpProgress = flag('autoJumpProgress', config.autoJumpProgress)
        ..promptCloudProgress = flag('promptCloudProgress', config.promptCloudProgress)
        ..conflictPolicy = str('conflictPolicy', config.conflictPolicy)
        ..progressAuto = flag('progressAuto', config.progressAuto)
        ..fullAuto = flag('fullAuto', config.fullAuto)
        ..wifiOnly = flag('wifiOnly', config.wifiOnly);
      await config.save();
    }

    if (scopes.contains(PortableScope.books) && data['books'] is List) {
      final List<dynamic> books = data['books'] as List<dynamic>;
      for (final dynamic raw in books) {
        if (raw is! Map) continue;
        final String? hash = raw['hash'] as String?;
        if (hash == null) continue;
        final Book? book = LibraryStore.instance.bookByHash(hash);
        if (book == null) continue;
        final List<String> tags = (raw['tags'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList();
        final List<String> collections =
            (raw['collections'] as List<dynamic>? ?? <dynamic>[])
                .whereType<String>()
                .toList();
        final Book updated = book.copyWith(
          title: raw['title'] as String? ?? book.title,
          author: raw['author'] as String? ?? book.author,
          tags: tags,
          category: raw['category'] as String? ?? book.category,
          collections: collections,
          pinned: raw['pinned'] == true,
          rating: (raw['rating'] as num?)?.toInt() ?? book.rating,
          readingStatus: raw['readingStatus'] as String? ?? book.readingStatus,
          coverTemplate: raw['coverTemplate'] as String? ?? book.coverTemplate,
        );
        await LibraryStore.instance.updateBook(updated);
      }
    }
  }
}

enum PortableScope { appearance, reader, shelf, sync, books }

class PortablePreview {
  const PortablePreview({
    required this.raw,
    required this.parts,
    required this.exportedAt,
  });

  final Map<String, dynamic> raw;
  final List<String> parts;
  final String? exportedAt;

  String get summary => parts.isEmpty ? '文件里没有可恢复的内容' : parts.join('、');
}
