import 'package:flutter/material.dart';

import 'package:read/src/profile/about_page.dart';
import 'package:read/src/profile/appearance_page.dart';
import 'package:read/src/profile/reading_history_page.dart';
import 'package:read/src/profile/storage_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/version.dart';

/// 设置：阅读历史、外观、存储、关于。同步独立为底部 Tab。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ),
                _SectionTitle(text: '数据管理'),
                _Section(
                  children: <Widget>[
                    _Row(
                      icon: Icons.menu_book_outlined,
                      title: '阅读历史',
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
        borderRadius: BorderRadius.circular(kEink ? 0 : 12),
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
