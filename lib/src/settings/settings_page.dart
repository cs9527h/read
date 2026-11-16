import 'package:flutter/material.dart';

import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/services/appearance_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/shelf_settings.dart';
import 'package:read/src/stats/stats_page.dart';
import 'package:read/src/sync/data_tools_page.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/version.dart';

/// 设置：外观、阅读排版、书架显示、数据入口。
///
/// 这里的每一项都直接写进对应的 Store，没有只改 UI 不落盘的假开关。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        AppearanceStore.instance,
        ReadUi.instance,
        ShelfSettings.instance,
        LibraryStore.instance,
        ReaderSettingsStore.instance,
      ]),
      builder: (BuildContext context, Widget? _) {
        final ReaderSettings global = ReaderSettingsStore.instance.globalSettings();
        final bool eink = ReadUi.instance.isEink;
        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text('设置',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: palette.ink)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(ReadUi.instance.label,
                            style: TextStyle(fontSize: 11.5, color: palette.muted)),
                      ),
                    ],
                  ),
                ),

                _label(palette, '界面'),
                _group(palette, <Widget>[
                  _segmentedRow(
                    palette,
                    title: '界面风格',
                    subtitle: eink
                        ? '细线单色图标、无阴影、直角；适合低刷新率与黑白屏'
                        : '圆角、暖白纸感、更精致的多色图标层次',
                    options: const <String, String>{'classic': '原版', 'eink': '墨水屏'},
                    value: ReadUi.instance.mode.name,
                    onChanged: (String value) => ReadUi.instance.setMode(
                      value == 'eink' ? ReadUiMode.eink : ReadUiMode.classic,
                    ),
                  ),
                  _segmentedRow(
                    palette,
                    title: '明暗',
                    subtitle: '墨水屏版固定为黑白高对比',
                    options: const <String, String>{
                      'system': '跟随系统',
                      'light': '浅色',
                      'dark': '深色',
                    },
                    value: AppearanceStore.instance.themeMode.name,
                    enabled: !eink,
                    onChanged: (String value) => AppearanceStore.instance.setThemeMode(
                      value == 'light'
                          ? ThemeMode.light
                          : value == 'dark'
                              ? ThemeMode.dark
                              : ThemeMode.system,
                    ),
                  ),
                  _sliderRow(
                    context,
                    palette,
                    title: '全局字号缩放',
                    value: AppearanceStore.instance.fontScale,
                    min: 0.85,
                    max: 1.4,
                    divisions: 11,
                    label: '${(AppearanceStore.instance.fontScale * 100).round()}%',
                    onChanged: AppearanceStore.instance.setFontScale,
                  ),
                ]),

                _label(palette, '阅读排版（默认值）'),
                _group(palette, <Widget>[
                  _sliderRow(
                    context,
                    palette,
                    title: '正文字号',
                    value: global.fontSize,
                    min: 12,
                    max: 32,
                    divisions: 40,
                    label: '${global.fontSize.toStringAsFixed(1)} px',
                    onChanged: (double value) => _patch(
                      <String, Object?>{'fontSize': value},
                    ),
                  ),
                  _sliderRow(
                    context,
                    palette,
                    title: '行距',
                    value: global.lineHeight,
                    min: 1.1,
                    max: 2.6,
                    divisions: 30,
                    label: global.lineHeight.toStringAsFixed(2),
                    onChanged: (double value) => _patch(
                      <String, Object?>{'lineHeight': value},
                    ),
                  ),
                  _segmentedRow(
                    palette,
                    title: '翻页方式',
                    subtitle: '阅读器内也可单独覆盖',
                    options: const <String, String>{
                      'cover': '覆盖',
                      'slide': '平移',
                      'none': '无动画',
                      'scroll': '滚动',
                    },
                    value: global.pageTurnMode,
                    onChanged: (String value) => _patch(
                      <String, Object?>{'pageTurnMode': value},
                    ),
                  ),
                  _segmentedRow(
                    palette,
                    title: '分栏',
                    subtitle: '自动：宽屏且横向时双栏',
                    options: const <String, String>{'auto': '自动', 'one': '单栏', 'two': '双栏'},
                    value: global.columns,
                    onChanged: (String value) => _patch(
                      <String, Object?>{'columns': value},
                    ),
                  ),
                ]),

                _label(palette, '书架'),
                _group(palette, <Widget>[
                  _switchRow(
                    palette,
                    title: '显示阅读进度',
                    value: ShelfSettings.instance.showProgress,
                    onChanged: ShelfSettings.instance.setShowProgress,
                  ),
                  _switchRow(
                    palette,
                    title: '显示云端标识',
                    subtitle: '只给云端确实存在文件的书籍显示云朵',
                    value: ShelfSettings.instance.showCloud,
                    onChanged: ShelfSettings.instance.setShowCloud,
                  ),
                  _switchRow(
                    palette,
                    title: '显示私密书籍',
                    subtitle: '关闭后，设为私密的书不出现在书架',
                    value: ShelfSettings.instance.showPrivate,
                    onChanged: ShelfSettings.instance.setShowPrivate,
                  ),
                  _switchRow(
                    palette,
                    title: '紧凑封面',
                    subtitle: '更小的卡片间距，一屏看更多书',
                    value: ShelfSettings.instance.compact,
                    onChanged: ShelfSettings.instance.setCompact,
                  ),
                  _segmentedRow(
                    palette,
                    title: '每行本数',
                    options: const <String, String>{
                      '0': '自适应',
                      '3': '3',
                      '4': '4',
                      '5': '5',
                    },
                    value: '${ShelfSettings.instance.columns}',
                    onChanged: (String value) =>
                        ShelfSettings.instance.setColumns(int.parse(value)),
                  ),
                ]),

                _label(palette, '数据与工具'),
                _group(palette, <Widget>[
                  _navRow(
                    palette,
                    glyph: ReadGlyph.device,
                    title: '设备与数据',
                    subtitle: '导出 / 导入本机设置、跨设备恢复、云端对比',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const DataToolsPage()),
                    ),
                  ),
                  _navRow(
                    palette,
                    glyph: ReadGlyph.clock,
                    title: '阅读统计',
                    subtitle: '阅读时长、字数、连续天数',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const StatsPage()),
                    ),
                  ),
                ]),

                _label(palette, '关于'),
                _group(palette, <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: <Widget>[
                        ReadIcon(ReadGlyph.book, size: 20, color: palette.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Read',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: palette.ink)),
                              const SizedBox(height: 2),
                              Text('版本 $appVersion · 本地优先，无账号体系',
                                  style: TextStyle(fontSize: 11.5, color: palette.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _patch(Map<String, Object?> values) {
    final ReaderSettingsStore store = ReaderSettingsStore.instance;
    final ReaderSettings next = store.globalSettings().patch(values);
    store.save('', next, ReaderScope.global);
  }

  Widget _label(ReadPalette palette, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
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
              Divider(height: 1, indent: 14, color: palette.outline),
          ],
        ],
      ),
    );
  }

  Widget _switchRow(
    ReadPalette palette, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: TextStyle(fontSize: 14.5, color: palette.ink)),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, height: 1.45, color: palette.muted)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: palette.ink,
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context,
    ReadPalette palette, {
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 14.5, color: palette.ink)),
              ),
              Text(label, style: TextStyle(fontSize: 12, color: palette.muted)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentedRow(
    ReadPalette palette, {
    required String title,
    String? subtitle,
    required Map<String, String> options,
    required String value,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: TextStyle(
                  fontSize: 14.5,
                  color: enabled ? palette.ink : palette.muted)),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 11, height: 1.45, color: palette.muted)),
          ],
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final MapEntry<String, String> entry in options.entries)
                GestureDetector(
                  onTap: enabled ? () => onChanged(entry.key) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: entry.key == value ? palette.ink : Colors.transparent,
                      border: Border.all(
                        color: entry.key == value ? palette.ink : palette.outline,
                      ),
                      borderRadius: BorderRadius.circular(
                          ReadUi.instance.isEink ? 0 : 16),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: entry.key == value
                            ? (palette.brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white)
                            : palette.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navRow(
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
            ReadIcon(glyph, size: 19, color: palette.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: TextStyle(fontSize: 14.5, color: palette.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
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
