import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/more/import_tools.dart';
import 'package:read/src/more/taxonomy_page.dart';
import 'package:read/src/more/wifi_transfer_page.dart';
import 'package:read/src/profile/about_page.dart';
import 'package:read/src/profile/reading_history_page.dart';
import 'package:read/src/profile/storage_page.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/stats/stats_page.dart';
import 'package:read/src/sync/lan_backup_page.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// 更多：把原来「我的」页里不属于账号的东西重新归类到工具区。
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: LibraryStore.instance,
      builder: (BuildContext context, Widget? _) {
        final LibraryStore store = LibraryStore.instance;
        final int total = store.books.length;
        final int reading = store.books
            .where((Book b) => b.lastReadAt != null)
            .length;
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  child: Text('更多',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: palette.ink)),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border.all(color: palette.outline),
                    borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 14),
                  ),
                  child: Row(
                    children: <Widget>[
                      _metric(palette, '$total', '本书'),
                      Container(width: 1, height: 26, color: palette.outline),
                      _metric(palette, '$reading', '在读'),
                      Container(width: 1, height: 26, color: palette.outline),
                      _metric(
                        palette,
                        '${ReadingStatsStore.instance.daysCount}',
                        '阅读天数',
                      ),
                    ],
                  ),
                ),
                _label(palette, '导入'),
                _group(palette, <Widget>[
                  _row(
                    palette,
                    glyph: ReadGlyph.wifi,
                    title: 'WiFi 传书',
                    subtitle: '同一局域网用浏览器上传，真正开了 HTTP 服务',
                    onTap: () => _push(context, const WifiTransferPage()),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.importFile,
                    title: '局域网备份互传',
                    subtitle: '同一 WiFi 下两台设备直传全量备份，可选书恢复',
                    onTap: () => _push(context, const LanBackupPage()),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.importFile,
                    title: '从本机导入',
                    subtitle: '多选 TXT / EPUB / PDF / Markdown',
                    onTap: () => _runImport(context, ImportTools.pickAndImport),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.scan,
                    title: '扫描文件夹',
                    subtitle: '递归扫描目录，导入其中所有电子书',
                    onTap: () => _runImport(context, ImportTools.scanFolder),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.sparkle,
                    title: '智能导入',
                    subtitle: '自动去重、从文件名补作者、按文件夹归分类',
                    onTap: () => _runImport(context, ImportTools.smartImport),
                  ),
                ]),
                _label(palette, '整理'),
                _group(palette, <Widget>[
                  _row(
                    palette,
                    glyph: ReadGlyph.tag,
                    title: '标签与分类',
                    subtitle: '重命名、删除；书箱分组也在这里',
                    onTap: () => _push(context, const TaxonomyPage()),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.clock,
                    title: '阅读统计',
                    subtitle: '时长、字数、每日分布',
                    onTap: () => _push(context, const StatsPage()),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.restore,
                    title: '阅读历史',
                    subtitle: '最近读过的书与进度轨迹',
                    onTap: () => _push(context, const ReadingHistoryPage()),
                  ),
                ]),
                _label(palette, '存储与关于'),
                _group(palette, <Widget>[
                  _row(
                    palette,
                    glyph: ReadGlyph.folder,
                    title: '存储管理',
                    subtitle: '查看书籍文件占用，清理不再需要的副本',
                    onTap: () => _push(context, const StoragePage()),
                  ),
                  _row(
                    palette,
                    glyph: ReadGlyph.info,
                    title: '关于 Read',
                    subtitle: '版本、开源许可、隐私说明',
                    onTap: () => _push(context, const AboutPage()),
                  ),
                ]),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '没有账号体系：所有数据默认只在本机。跨设备靠你自己配置的 WebDAV / S3，'
                    '不经过任何第三方服务器。',
                    style: TextStyle(fontSize: 11, height: 1.7, color: palette.muted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runImport(
    BuildContext context,
    Future<ImportSummary> Function() action,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('正在导入…')));
    try {
      final ImportSummary summary = await action();
      await LibraryStore.instance.init();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(summary.message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('导入失败：$error')));
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _metric(ReadPalette palette, String value, String label) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value,
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: palette.ink)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: palette.muted)),
        ],
      ),
    );
  }

  Widget _label(ReadPalette palette, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: palette.muted,
          ),
        ),
      );

  Widget _group(ReadPalette palette, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 14),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 52, color: palette.outline),
          ],
        ],
      ),
    );
  }

  Widget _row(
    ReadPalette palette, {
    required ReadGlyph glyph,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 20,
              child: ReadIcon(glyph, size: 19, color: palette.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 14.5, color: palette.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      style: TextStyle(fontSize: 11, height: 1.45, color: palette.muted)),
                ],
              ),
            ),
            ReadIcon(ReadGlyph.chevronRight, size: 16, color: palette.outline),
          ],
        ),
      ),
    );
  }
}
