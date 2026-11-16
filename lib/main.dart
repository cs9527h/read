import 'package:flutter/material.dart';

import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/services/appearance_store.dart';
import 'package:read/src/services/collection_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/sync/auto_sync_service.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/shell/home_shell.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LibraryStore.instance.init();
  await AppearanceStore.instance.init();
  await ReadingStatsStore.instance.init();
  await ReaderSettingsStore.instance.init();
  await UserFontStore.instance.init();
  await CollectionStore.instance.init();
  await SyncConfig.instance.init();
  await ReadUi.instance.init();
  await AutoSyncService.instance.init();
  runApp(const ReadApp());
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
