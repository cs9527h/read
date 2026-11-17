import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:read/src/database/core_store.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/services/appearance_store.dart';
import 'package:read/src/services/collection_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/services/search_history_store.dart';
import 'package:read/src/sync/auto_sync_service.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/shell/home_shell.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';

/// 启动分两段：
/// 1. 只初始化首帧真正需要的四项（界面模式、外观、阅读设置、书架元数据）；
/// 2. 其余服务（统计、搜索历史、字体、分类、云配置、自动同步、SQLite）
///    在首帧之后并行预热，避免启动时长时间白屏。
///
/// 每个服务独立 try/catch：任何一项失败都只影响对应功能，不能让应用打不开。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 书架封面是网络/文件图片的混合列表，限制缓存避免长时间浏览后内存膨胀。
  PaintingBinding.instance.imageCache
    ..maximumSize = 120
    ..maximumSizeBytes = 64 << 20;
  await _safe('ui', ReadUi.instance.init);
  await _safe('appearance', AppearanceStore.instance.init);
  await _safe('readerSettings', ReaderSettingsStore.instance.init);
  await _safe('library', LibraryStore.instance.init);
  runApp(const ReadApp());
  unawaited(_warmUp());
}

Future<void> _warmUp() async {
  await Future.wait<void>(<Future<void>>[
    _safe('stats', ReadingStatsStore.instance.init),
    _safe('searchHistory', SearchHistoryStore.instance.init),
    _safe('fonts', UserFontStore.instance.init),
    _safe('collections', CollectionStore.instance.init),
    _safe('syncConfig', SyncConfig.instance.init),
  ]);
  await _safe('database', _initDatabase);
  await _safe('autoSync', AutoSyncService.instance.init);
}

/// 打开 SQLite 并把旧版 SharedPreferences 数据增量导入。
/// 旧键一个都不删除，因此关闭 [CoreStore] 即可回滚到旧路径。
Future<void> _initDatabase() async {
  final Directory docs = await getApplicationDocumentsDirectory();
  final File file = File('${docs.path}/read-core.sqlite');
  final CoreStore store = await CoreStore.open(file);
  final prefs = await SharedPreferences.getInstance();
  final MigrationReport report = await store.migrateLegacy(
    prefs: prefs,
    books: LibraryStore.instance.books,
  );
  await store.saveBooks(LibraryStore.instance.books);
  if (!report.isEmpty) {
    debugPrint('SQLite 迁移完成：$report');
  }
}

Future<void> _safe(String name, Future<void> Function() action) async {
  try {
    await action();
  } catch (error, stack) {
    // 启动阶段任何单项失败都要被记录并隔离。
    debugPrint('启动初始化失败[$name]：$error');
    debugPrintStack(stackTrace: stack);
  }
}

class ReadApp extends StatelessWidget {
  const ReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        AppearanceStore.instance,
        ReadUi.instance,
      ]),
      builder: (BuildContext context, Widget? child) {
        final AppearanceStore appearance = AppearanceStore.instance;
        return MaterialApp(
          title: 'read',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, fontScale: appearance.fontScale),
          darkTheme: buildTheme(Brightness.dark, fontScale: appearance.fontScale),
          themeMode: appearance.themeMode,
          home: const HomeShell(),
        );
      },
    );
  }
}
