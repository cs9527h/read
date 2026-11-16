import 'package:flutter/material.dart';

import 'package:read/src/services/appearance_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';

/// 应用外观：只放真正生效的设置项。
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: AppearanceStore.instance,
      builder: (BuildContext context, Widget? child) {
        final AppearanceStore store = AppearanceStore.instance;
        return Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            title: Text('应用外观', style: TextStyle(fontSize: 18, color: palette.ink)),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: palette.icon),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              _Label(text: '主题模式', palette: palette),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _ModeButton(
                    label: '跟随系统',
                    selected: store.themeMode == ThemeMode.system,
                    onTap: () => store.setThemeMode(ThemeMode.system),
                  ),
                  const SizedBox(width: 8),
                  _ModeButton(
                    label: '浅色',
                    selected: store.themeMode == ThemeMode.light,
                    onTap: () => store.setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(width: 8),
                  _ModeButton(
                    label: '深色',
                    selected: store.themeMode == ThemeMode.dark,
                    onTap: () => store.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _Label(text: '全局字体缩放', palette: palette),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
                  border: Border.all(color: palette.outline),
                ),
                child: Row(
                  children: <Widget>[
                    Text('A', style: TextStyle(fontSize: 12, color: palette.muted)),
                    Expanded(
                      child: Slider(
                        value: store.fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        activeColor: palette.ink,
                        inactiveColor: palette.outline,
                        label: '${(store.fontScale * 100).round()}%',
                        onChanged: (double value) => store.setFontScale(value),
                      ),
                    ),
                    Text('A', style: TextStyle(fontSize: 20, color: palette.muted)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      child: Text(
                        '${(store.fontScale * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '只影响界面字号；书内阅读的字号仍由阅读页单独控制。',
                style: TextStyle(fontSize: 11, color: palette.muted),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
                  border: Border.all(color: palette.outline),
                ),
                child: SwitchListTile(
                  title: Text('书架显示大标题', style: TextStyle(fontSize: 14, color: palette.ink)),
                  subtitle: Text('关闭后首页更紧凑', style: TextStyle(fontSize: 11, color: palette.muted)),
                  value: store.bigTitle,
                  activeThumbColor: palette.ink,
                  onChanged: (bool value) => store.setBigTitle(value),
                ),
              ),
              const SizedBox(height: 22),
              _Label(text: '当前生效', palette: palette),
              const SizedBox(height: 8),
              Text(
                '主题：${store.themeModeLabel} · 字体缩放 ${(store.fontScale * 100).round()}%',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.palette});

  final String text;
  final ReadPalette palette;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 12, color: palette.muted, letterSpacing: 0.4),
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.ink : palette.surface,
            borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
            border: Border.all(color: selected ? palette.ink : palette.outline),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected
                  ? (palette.brightness == Brightness.dark ? Colors.black : Colors.white)
                  : palette.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
