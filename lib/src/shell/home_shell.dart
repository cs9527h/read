import 'package:flutter/material.dart';

import 'package:read/src/bookshelf/bookshelf_page.dart';
import 'package:read/src/profile/profile_page.dart';
import 'package:read/src/sync/sync_page.dart';
import 'package:read/src/stats/stats_page.dart';
import 'package:read/src/theme.dart';

/// 应用主壳：底部四栏 书架 / 统计 / 同步 / 设置。无账号体系，不再保留“我的”。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          BookshelfPage(),
          StatsPage(),
          SyncPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.outline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                _NavItem(
                  icon: ReadIcons.shelf,
                  label: '书架',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: ReadIcons.stats,
                  label: '统计',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _NavItem(
                  icon: ReadIcons.sync,
                  label: '同步',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  icon: ReadIcons.settings,
                  label: '设置',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final Color color = selected ? palette.ink : palette.muted;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
