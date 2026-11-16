import 'package:flutter/material.dart';

import 'package:read/src/profile/about_page.dart';
import 'package:read/src/profile/appearance_page.dart';
import 'package:read/src/profile/reading_history_page.dart';
import 'package:read/src/profile/storage_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/sync/sync_page.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/version.dart';
import 'package:read/src/theme/ui_mode.dart';

/// 我的：头像 + 同步状态 + 分区列表。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        LibraryStore.instance,
        ReadingStatsStore.instance,
      ]),
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.ink,
                        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: palette.brightness == Brightness.dark ? Colors.black : Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '我的书房',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '读万卷书，行万里路。',
                            style: TextStyle(fontSize: 12, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: palette.muted, size: 20),
                  ],
                ),
                const SizedBox(height: 20),
                _Section(
                  children: <Widget>[
                    _Row(
                      icon: Icons.sync_rounded,
                      title: '同步',
                      subtitle: SyncConfig.instance.lastSyncAt.isEmpty
                          ? '全量同步 / 备份 / 历史'
                          : '上次同步 ${SyncConfig.instance.lastSyncStatus}',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const SyncPage()),
                      ),
                    ),
                  ],
                ),
                _SectionTitle(text: '数据管理'),
                _Section(
                  children: <Widget>[
                    _Row(
                      icon: Icons.menu_book_outlined,
                      title: '我的阅读',
                      subtitle: '${LibraryStore.instance.books.length} 本 · 全部/在读/读完',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const ReadingHistoryPage()),
                      ),
                    ),
                  ],
                ),
                _SectionTitle(text: '外观'),
                _Section(
                  children: <Widget>[
                    _Row(
                      icon: Icons.palette_outlined,
                      title: '应用外观',
                      subtitle: '主题 / 字体 / 缩放',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AppearancePage()),
                      ),
                    ),
                  ],
                ),
                _SectionTitle(text: '资源'),
                _Section(
                  children: <Widget>[
                    _Row(
                      icon: Icons.sd_storage_outlined,
                      title: '存储管理',
                      subtitle: '书籍文件与缓存占用',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const StoragePage()),
                      ),
                    ),
                  ],
                ),
                _SectionTitle(text: '其他'),
                _Section(
                  children: <Widget>[
                    _Row(
                      icon: Icons.info_outline_rounded,
                      title: '关于',
                      subtitle: 'read $appVersionLabel',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: palette.muted, letterSpacing: 0.5),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
        border: Border.all(color: palette.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: palette.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: palette.ink, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: palette.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
