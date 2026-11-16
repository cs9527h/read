import 'package:flutter/material.dart';

import 'package:read/src/bookshelf/bookshelf_page.dart';
import 'package:read/src/more/more_page.dart';
import 'package:read/src/settings/settings_page.dart';
import 'package:read/src/sync/sync_page.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// 应用主壳：书架 / 同步 / 设置 / 更多。
///
/// 没有账号体系，所以不再保留「我的」——个人中心、登录、云盘绑定这些
/// 在无账号产品里是不成立的入口。原来的功能拆到「同步」（进度与数据）
/// 和「设置」（阅读与外观），统计、标签、导入等工具进「更多」。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(ReadGlyph.shelf, '书架'),
    _TabSpec(ReadGlyph.sync, '同步'),
    _TabSpec(ReadGlyph.settings, '设置'),
    _TabSpec(ReadGlyph.more, '更多'),
  ];

  /// 各页只在第一次被选中时构建：启动只书架，进阅读器更快，
  /// 也避免同步页在后台初始化网络/密钥。
  final Set<int> _built = <int>{0};

  Widget _page(int index) {
    switch (index) {
      case 0:
        return const BookshelfPage();
      case 1:
        return const SyncPage(embedded: true);
      case 2:
        return const SettingsPage();
      default:
        return const MorePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: <Widget>[
          for (int i = 0; i < _tabs.length; i++)
            if (_built.contains(i))
              Offstage(
                offstage: _index != i,
                child: TickerMode(
                  enabled: _index == i,
                  child: _page(i),
                ),
              ),
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
            height: ReadUi.instance.isEink ? 52 : 56,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      glyph: _tabs[i].glyph,
                      label: _tabs[i].label,
                      selected: _index == i,
                      onTap: () => setState(() {
                        _index = i;
                        _built.add(i);
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.glyph, this.label);

  final ReadGlyph glyph;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ReadGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final Color color = selected ? palette.ink : palette.muted;
    return InkResponse(
      onTap: onTap,
      radius: 42,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ReadIcon(glyph, size: 21, color: color, strokeScale: selected ? 1.08 : 1),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
