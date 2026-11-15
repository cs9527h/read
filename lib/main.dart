import 'package:flutter/material.dart';

import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/user_font_store.dart';
import 'package:read/src/services/appearance_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/shell/home_shell.dart';
import 'package:read/src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LibraryStore.instance.init();
  await AppearanceStore.instance.init();
  await ReadingStatsStore.instance.init();
  await ReaderSettingsStore.instance.init();
  await UserFontStore.instance.init();
  runApp(const ReadApp());
}

class ReadApp extends StatelessWidget {
  const ReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppearanceStore.instance,
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
