import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:read/src/reader/engine/reader_engine.dart';
import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/reader/settings/reader_theme.dart';
import 'package:read/src/reader/settings/user_font_store.dart';

/// 阅读设置面板：所有开关都接入真实排版引擎，没有装饰性假开关。
class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.bookId,
    required this.onRepaginate,
  });

  final String bookId;
  final VoidCallback onRepaginate;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  final ReaderSettingsStore _store = ReaderSettingsStore.instance;
  late ReaderSettings _settings;
  late ReaderSettings _initial;
  ReaderScope _scope = ReaderScope.book;

  @override
  void initState() {
    super.initState();
    _settings = _store.resolve(widget.bookId);
    _initial = _settings;
  }

  void _update(Map<String, Object?> patch) {
    setState(() => _settings = _settings.patch(patch));
    _store.save(widget.bookId, _settings, _scope);
    widget.onRepaginate();
  }

  void _resetScope() {
    _store.clearScope(widget.bookId, _scope);
    setState(() {
      _settings = _store.resolve(widget.bookId);
      _initial = _settings;
    });
    widget.onRepaginate();
  }

  void _undo() {
    setState(() => _settings = _initial);
    _store.save(widget.bookId, _settings, _scope);
    widget.onRepaginate();
  }

  @override
  Widget build(BuildContext context) {
    final ReaderTheme theme = _store.effectiveTheme(
      _settings,
      MediaQuery.platformBrightnessOf(context),
    );
    final Color background = Color(_settings.backgroundColor ?? theme.background);
    final Color foreground = Color(_settings.textColor ?? theme.foreground);
    final Color secondary = Color(theme.secondary);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.9,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: secondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
            child: Row(
              children: <Widget>[
                Text(
                  '阅读设置',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _undo,
                  child: const Text('撤销'),
                ),
                TextButton(
                  onPressed: () => _confirmReset(context),
                  child: const Text('恢复默认'),
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: Icon(Icons.close_rounded, color: foreground),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: <Widget>[
                SegmentedButton<ReaderScope>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: const WidgetStatePropertyAll<TextStyle>(
                      TextStyle(fontSize: 12),
                    ),
                  ),
                  segments: const <ButtonSegment<ReaderScope>>[
                    ButtonSegment<ReaderScope>(
                      value: ReaderScope.global,
                      label: Text('全局'),
                    ),
                    ButtonSegment<ReaderScope>(
                      value: ReaderScope.theme,
                      label: Text('主题'),
                    ),
                    ButtonSegment<ReaderScope>(
                      value: ReaderScope.book,
                      label: Text('本书'),
                    ),
                  ],
                  selected: <ReaderScope>{_scope},
                  onSelectionChanged: (Set<ReaderScope> value) {
                    setState(() => _scope = value.first);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _scope.hint,
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _preview(background, foreground, secondary),
          const SizedBox(height: 4),
          Expanded(
            child: DefaultTabController(
              length: 7,
              child: Column(
                children: <Widget>[
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: secondary.withValues(alpha: 0.15),
                    labelColor: foreground,
                    unselectedLabelColor: secondary,
                    tabs: const <Widget>[
                      Tab(text: '字体'),
                      Tab(text: '段落'),
                      Tab(text: '主题'),
                      Tab(text: '页眉页脚'),
                      Tab(text: '翻页'),
                      Tab(text: '布局'),
                      Tab(text: '高级'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _fontTab(secondary),
                        _paragraphTab(secondary),
                        _themeTab(secondary),
                        _headerFooterTab(secondary),
                        _turnTab(secondary),
                        _layoutTab(secondary),
                        _advancedTab(secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(Color background, Color foreground, Color secondary) {
    final ReaderTheme theme = _store.effectiveTheme(
      _settings,
      MediaQuery.platformBrightnessOf(context),
    );
    final Color bg = Color(_settings.backgroundColor ?? theme.background);
    final Color fg = Color(_settings.textColor ?? theme.foreground);
    return Container(
      height: 112,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondary.withValues(alpha: 0.18)),
      ),
      padding: EdgeInsets.fromLTRB(
        _settings.marginLeft.clamp(12, 28),
        8,
        _settings.marginRight.clamp(12, 28),
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '第一章 风起',
            style: TextStyle(
              fontSize: _settings.titleFontSize * 0.8,
              fontWeight: FontWeight.values[(_settings.titleWeight ~/ 100) - 1],
              color: fg,
              fontFamily: _settings.titleFontFamily ?? _settings.fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              '　　山雨欲来的时候，整座城都安静下来。预览会随字号、行距、缩进与配色实时变化，'
              '设置保存后立即作用于正文。',
              overflow: TextOverflow.fade,
              style: ReaderEngine.bodyStyle(_settings,
                  color: fg, textScale: 1.0),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 字体
  // ---------------------------------------------------------------------------

  Widget _fontTab(Color secondary) {
    final List<UserFont> fonts = UserFontStore.instance.fonts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('字体', secondary),
        _choiceTile(
          title: '系统默认字体',
          selected: _settings.fontFamily == null,
          onTap: () => _update(<String, Object?>{'fontFamily': null}),
        ),
        ...fonts.map((UserFont font) => _choiceTile(
              title: font.name,
              subtitle: '已导入 · ${p.basename(font.path)}',
              selected: _settings.fontFamily == font.family,
              onTap: () => _update(<String, Object?>{'fontFamily': font.family}),
              trailing: IconButton(
                tooltip: '删除字体',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => UserFontStore.instance.deleteFont(font),
              ),
            )),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final UserFont? font = await UserFontStore.instance.importFont();
              if (font == null) return;
              _update(<String, Object?>{'fontFamily': font.family});
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('导入 TTF / OTF 字体'),
          ),
        ),
        _slider(
          '字号',
          _settings.fontSize,
          12,
          34,
          divisions: 22,
          label: '${_settings.fontSize.toStringAsFixed(0)} pt',
          onChanged: (double v) => _update(<String, Object?>{'fontSize': v}),
        ),
        _slider(
          '行距',
          _settings.lineHeight,
          1.0,
          2.8,
          divisions: 18,
          label: _settings.lineHeight.toStringAsFixed(2),
          onChanged: (double v) => _update(<String, Object?>{'lineHeight': v}),
        ),
        _slider(
          '字重',
          _settings.fontWeight.toDouble(),
          300,
          700,
          divisions: 4,
          label: 'w${_settings.fontWeight}',
          onChanged: (double v) =>
              _update(<String, Object?>{'fontWeight': v.round()}),
        ),
        _slider(
          '字间距',
          _settings.letterSpacing,
          -1,
          4,
          divisions: 50,
          label: _settings.letterSpacing.toStringAsFixed(2),
          onChanged: (double v) =>
              _update(<String, Object?>{'letterSpacing': v}),
        ),
        _slider(
          '词间距',
          _settings.wordSpacing,
          0,
          8,
          divisions: 32,
          label: _settings.wordSpacing.toStringAsFixed(1),
          onChanged: (double v) => _update(<String, Object?>{'wordSpacing': v}),
        ),
        _slider(
          '横向缩放（近似）',
          _settings.textScaleX,
          0.85,
          1.15,
          divisions: 12,
          label: '${(_settings.textScaleX * 100).toStringAsFixed(0)}%',
          onChanged: (double v) => _update(<String, Object?>{'textScaleX': v}),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 段落
  // ---------------------------------------------------------------------------

  Widget _paragraphTab(Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('缩进与对齐', secondary),
        _segment<String>(
          label: '首行缩进',
          value: _settings.indentMode,
          options: const <String, String>{
            'none': '不缩进',
            'fixed': '固定缩进',
            'em': '按字号缩进',
          },
          onChanged: (String v) => _update(<String, Object?>{'indentMode': v}),
        ),
        if (_settings.indentMode != 'none')
          _slider(
            '缩进量',
            _settings.indentChars,
            1,
            4,
            divisions: 6,
            label: _settings.indentChars.toStringAsFixed(0),
            onChanged: (double v) =>
                _update(<String, Object?>{'indentChars': v}),
          ),
        _segment<String>(
          label: '对齐方式',
          value: _settings.align,
          options: const <String, String>{
            'left': '左对齐',
            'justify': '两端',
            'center': '居中',
            'right': '右对齐',
          },
          onChanged: (String v) => _update(<String, Object?>{'align': v}),
        ),
        _slider(
          '段前留白',
          _settings.paragraphSpacingBefore,
          0,
          30,
          divisions: 30,
          label: '${_settings.paragraphSpacingBefore.toStringAsFixed(0)} px',
          onChanged: (double v) =>
              _update(<String, Object?>{'paragraphSpacingBefore': v}),
        ),
        _slider(
          '段后留白',
          _settings.paragraphSpacingAfter,
          0,
          30,
          divisions: 30,
          label: '${_settings.paragraphSpacingAfter.toStringAsFixed(0)} px',
          onChanged: (double v) =>
              _update(<String, Object?>{'paragraphSpacingAfter': v}),
        ),
        _switch(
          '保留原文空行',
          _settings.preserveBlankLines,
          (bool v) => _update(<String, Object?>{'preserveBlankLines': v}),
        ),
        _switch(
          '忽略多余空行',
          _settings.ignoreExtraBlankLines,
          (bool v) => _update(<String, Object?>{'ignoreExtraBlankLines': v}),
        ),
        _switch(
          '文字底部对齐',
          _settings.bottomAlign,
          (bool v) => _update(<String, Object?>{'bottomAlign': v}),
        ),
        _section('行内强调', secondary),
        TextField(
          controller: TextEditingController(text: _settings.boldPattern)
            ..selection = TextSelection.collapsed(
                offset: _settings.boldPattern.length),
          decoration: const InputDecoration(
            labelText: '加粗行匹配规则（正则，留空关闭）',
            hintText: r'^【.*】',
            helperText: '匹配到的整行加粗；无效正则会自动忽略。',
          ),
          onSubmitted: (String v) =>
              _update(<String, Object?>{'boldPattern': v}),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 主题
  // ---------------------------------------------------------------------------

  Widget _themeTab(Color secondary) {
    final ReaderTheme currentTheme = _store.themeById(_settings.themeId);
    final List<ReaderTheme> themes = _store.allThemes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('配色主题', secondary),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: themes.map((ReaderTheme theme) {
            final bool selected = _settings.themeId == theme.id;
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _update(<String, Object?>{
                'themeId': theme.id,
                'backgroundColor': null,
                'textColor': null,
              }),
              child: Container(
                width: 104,
                height: 64,
                decoration: BoxDecoration(
                  color: Color(theme.background),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Color(theme.foreground)
                        : secondary.withValues(alpha: 0.2),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      theme.name,
                      style: TextStyle(
                        color: Color(theme.foreground),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!theme.builtIn)
                      Text(
                        '自定义',
                        style: TextStyle(
                          color: Color(theme.foreground).withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: () => _createTheme(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建主题'),
            ),
            if (!_store.themeById(_settings.themeId).builtIn) ...<Widget>[
              TextButton(
                onPressed: () => _renameTheme(context),
                child: const Text('重命名'),
              ),
              TextButton(
                onPressed: () => _editThemeColors(context),
                child: const Text('编辑颜色'),
              ),
              TextButton(
                onPressed: () async {
                  await _store.duplicateTheme(_settings.themeId);
                  setState(() {});
                },
                child: const Text('复制'),
              ),
              TextButton(
                onPressed: () async {
                  await _store.deleteTheme(_settings.themeId);
                  _update(<String, Object?>{'themeId': 'paper'});
                },
                child: const Text('删除'),
              ),
            ],
          ],
        ),
        _section('跟随系统', secondary),
        _switch(
          '自动切换日间/夜间主题',
          _settings.followSystemTheme,
          (bool v) => _update(<String, Object?>{'followSystemTheme': v}),
        ),
        if (_settings.followSystemTheme) ...<Widget>[
          _themeDropdown('日间主题', _settings.dayThemeId,
              (String id) => _update(<String, Object?>{'dayThemeId': id})),
          _themeDropdown('夜间主题', _settings.nightThemeId,
              (String id) => _update(<String, Object?>{'nightThemeId': id})),
        ],
        _section('自定义颜色', secondary),
        _colorRow('正文颜色', _settings.textColor, currentTheme.foreground,
            (int? value) => _update(<String, Object?>{'textColor': value})),
        _colorRow('背景颜色', _settings.backgroundColor, currentTheme.background,
            (int? value) => _update(<String, Object?>{'backgroundColor': value})),
        _section('背景图片', secondary),
        _choiceTile(
          title: _settings.bgImagePath == null ? '未设置背景图片' : '已设置背景图片',
          subtitle: _settings.bgImagePath ?? '支持 JPG / PNG / WebP',
          selected: false,
          onTap: _pickBackgroundImage,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                onPressed: () => _pickBackgroundImage(),
                child: const Text('选择'),
              ),
              if (_settings.bgImagePath != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => _update(<String, Object?>{'bgImagePath': null}),
                ),
            ],
          ),
        ),
        if (_settings.bgImagePath != null) ...<Widget>[
          _segment<String>(
            label: '填充方式',
            value: _settings.bgImageFit,
            options: const <String, String>{
              'cover': '裁切填充',
              'contain': '完整显示',
              'fill': '拉伸',
              'center': '居中',
            },
            onChanged: (String v) => _update(<String, Object?>{'bgImageFit': v}),
          ),
          _slider(
            '图片不透明度',
            _settings.bgImageOpacity,
            0.1,
            1.0,
            divisions: 18,
            label: '${(_settings.bgImageOpacity * 100).toStringAsFixed(0)}%',
            onChanged: (double v) =>
                _update(<String, Object?>{'bgImageOpacity': v}),
          ),
          _slider(
            '图片压暗',
            _settings.bgImageDim,
            0,
            0.8,
            divisions: 16,
            label: '${(_settings.bgImageDim * 100).toStringAsFixed(0)}%',
            onChanged: (double v) =>
                _update(<String, Object?>{'bgImageDim': v}),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 页眉页脚
  // ---------------------------------------------------------------------------

  Widget _headerFooterTab(Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('页眉', secondary),
        _switch('显示页眉', _settings.headerShow,
            (bool v) => _update(<String, Object?>{'headerShow': v})),
        if (_settings.headerShow) ...<Widget>[
          _templateField('左侧', _settings.headerLeft,
              (String v) => _update(<String, Object?>{'headerLeft': v})),
          _templateField('中间', _settings.headerCenter,
              (String v) => _update(<String, Object?>{'headerCenter': v})),
          _templateField('右侧', _settings.headerRight,
              (String v) => _update(<String, Object?>{'headerRight': v})),
          _slider(
            '页眉字号',
            _settings.headerFontSize,
            9,
            16,
            divisions: 14,
            label: '${_settings.headerFontSize.toStringAsFixed(0)}',
            onChanged: (double v) =>
                _update(<String, Object?>{'headerFontSize': v}),
          ),
          _slider(
            '页眉透明度',
            _settings.headerOpacity,
            0.2,
            1,
            divisions: 16,
            label: '${(_settings.headerOpacity * 100).toStringAsFixed(0)}%',
            onChanged: (double v) =>
                _update(<String, Object?>{'headerOpacity': v}),
          ),
          _colorRow('页眉颜色', _settings.headerColor, 0xFF888888,
              (int? value) => _update(<String, Object?>{'headerColor': value})),
        ],
        _section('页脚', secondary),
        _switch('显示页脚', _settings.footerShow,
            (bool v) => _update(<String, Object?>{'footerShow': v})),
        if (_settings.footerShow) ...<Widget>[
          _templateField('左侧', _settings.footerLeft,
              (String v) => _update(<String, Object?>{'footerLeft': v})),
          _templateField('中间', _settings.footerCenter,
              (String v) => _update(<String, Object?>{'footerCenter': v})),
          _templateField('右侧', _settings.footerRight,
              (String v) => _update(<String, Object?>{'footerRight': v})),
          _slider(
            '页脚字号',
            _settings.footerFontSize,
            9,
            16,
            divisions: 14,
            label: '${_settings.footerFontSize.toStringAsFixed(0)}',
            onChanged: (double v) =>
                _update(<String, Object?>{'footerFontSize': v}),
          ),
          _slider(
            '页脚透明度',
            _settings.footerOpacity,
            0.2,
            1,
            divisions: 16,
            label: '${(_settings.footerOpacity * 100).toStringAsFixed(0)}%',
            onChanged: (double v) =>
                _update(<String, Object?>{'footerOpacity': v}),
          ),
          _colorRow('页脚颜色', _settings.footerColor, 0xFF888888,
              (int? value) => _update(<String, Object?>{'footerColor': value})),
          _switch('页脚进度条', _settings.footerProgressBar,
              (bool v) => _update(<String, Object?>{'footerProgressBar': v})),
        ],
        const SizedBox(height: 6),
        Text(
          '可用变量：{book} 书名，{author} 作者，{chapter} 章节名，{page} 当前页，'
          '{pages} 本章总页，{percent} 全书进度，{time} 当前时间。',
          style: TextStyle(fontSize: 11, color: secondary),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 翻页
  // ---------------------------------------------------------------------------

  Widget _turnTab(Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('翻页方式', secondary),
        _segment<String>(
          label: '效果',
          value: _settings.pageTurnMode,
          options: const <String, String>{
            'cover': '覆盖',
            'slide': '平移',
            'none': '无动画',
            'scroll': '滚动',
          },
          onChanged: (String v) => _update(<String, Object?>{'pageTurnMode': v}),
        ),
        _slider(
          '动画时长',
          _settings.animationMs.toDouble(),
          100,
          600,
          divisions: 10,
          label: '${_settings.animationMs} ms',
          onChanged: (double v) =>
              _update(<String, Object?>{'animationMs': v.round()}),
        ),
        _section('点击分区', secondary),
        _tapActionTile('左侧 30%', _settings.tapLeft,
            (String v) => _update(<String, Object?>{'tapLeft': v})),
        _tapActionTile('中间 40%', _settings.tapCenter,
            (String v) => _update(<String, Object?>{'tapCenter': v})),
        _tapActionTile('右侧 30%', _settings.tapRight,
            (String v) => _update(<String, Object?>{'tapRight': v})),
        _switch('反向翻页（从右到左）', _settings.reverseDirection,
            (bool v) => _update(<String, Object?>{'reverseDirection': v})),
        _section('自动翻页', secondary),
        _switch('自动翻页', _settings.autoTurn,
            (bool v) => _update(<String, Object?>{'autoTurn': v})),
        if (_settings.autoTurn)
          _slider(
            '自动翻页间隔',
            _settings.autoTurnSeconds.toDouble(),
            5,
            120,
            divisions: 23,
            label: '${_settings.autoTurnSeconds} 秒',
            onChanged: (double v) =>
                _update(<String, Object?>{'autoTurnSeconds': v.round()}),
          ),
        _section('音量键', secondary),
        _switch('音量键翻页（当前版本不可用）', false, (bool v) {}),
        Text(
          '音量键需要 Android 原生通道；当前 APK 的 Android 壳由 CI 生成，尚未接入，'
          '因此这一项没有做成开关，避免出现“能点但无效”的假功能。',
          style: TextStyle(fontSize: 11, color: secondary),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 布局
  // ---------------------------------------------------------------------------

  Widget _layoutTab(Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('边距预设', secondary),
        Wrap(
          spacing: 8,
          children: <Widget>[
            _presetButton('窄', <String, Object?>{
              'marginPreset': 'narrow',
              'marginLeft': 14,
              'marginRight': 14,
              'marginTop': 8,
              'marginBottom': 4,
            }),
            _presetButton('标准', <String, Object?>{
              'marginPreset': 'standard',
              'marginLeft': 20,
              'marginRight': 20,
              'marginTop': 10,
              'marginBottom': 6,
            }),
            _presetButton('宽', <String, Object?>{
              'marginPreset': 'wide',
              'marginLeft': 30,
              'marginRight': 30,
              'marginTop': 16,
              'marginBottom': 12,
            }),
          ],
        ),
        _slider(
          '上边距',
          _settings.marginTop,
          0,
          60,
          divisions: 60,
          label: '${_settings.marginTop.toStringAsFixed(0)}',
          onChanged: (double v) =>
              _update(<String, Object?>{'marginTop': v, 'marginPreset': 'custom'}),
        ),
        _slider(
          '下边距',
          _settings.marginBottom,
          0,
          60,
          divisions: 60,
          label: '${_settings.marginBottom.toStringAsFixed(0)}',
          onChanged: (double v) => _update(
              <String, Object?>{'marginBottom': v, 'marginPreset': 'custom'}),
        ),
        _slider(
          '左边距',
          _settings.marginLeft,
          0,
          60,
          divisions: 60,
          label: '${_settings.marginLeft.toStringAsFixed(0)}',
          onChanged: (double v) => _update(
              <String, Object?>{'marginLeft': v, 'marginPreset': 'custom'}),
        ),
        _slider(
          '右边距',
          _settings.marginRight,
          0,
          60,
          divisions: 60,
          label: '${_settings.marginRight.toStringAsFixed(0)}',
          onChanged: (double v) => _update(
              <String, Object?>{'marginRight': v, 'marginPreset': 'custom'}),
        ),
        _section('屏幕', secondary),
        _switch('沉浸式阅读', _settings.immersive,
            (bool v) => _update(<String, Object?>{'immersive': v})),
        _switch('显示系统状态栏', _settings.showSystemBars,
            (bool v) => _update(<String, Object?>{'showSystemBars': v})),
        _segment<String>(
          label: '屏幕方向',
          value: _settings.orientation,
          options: const <String, String>{
            'system': '跟随系统',
            'portrait': '竖屏',
            'landscape': '横屏',
          },
          onChanged: (String v) => _update(<String, Object?>{'orientation': v}),
        ),
        _section('分栏', secondary),
        _segment<String>(
          label: '横屏分栏',
          value: _settings.columns,
          options: const <String, String>{
            'auto': '自动',
            'one': '单栏',
            'two': '双栏',
          },
          onChanged: (String v) => _update(<String, Object?>{'columns': v}),
        ),
        _slider(
          '分栏间距',
          _settings.columnGap,
          8,
          60,
          divisions: 26,
          label: '${_settings.columnGap.toStringAsFixed(0)}',
          onChanged: (double v) => _update(<String, Object?>{'columnGap': v}),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 高级
  // ---------------------------------------------------------------------------

  Widget _advancedTab(Color secondary) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: <Widget>[
        _section('亮度', secondary),
        _slider(
          '应用内亮度',
          _settings.brightness,
          0.2,
          1.0,
          divisions: 16,
          label: '${(_settings.brightness * 100).toStringAsFixed(0)}%',
          onChanged: (double v) => _update(<String, Object?>{'brightness': v}),
        ),
        Text(
          '这是叠加在页面上的调暗遮罩，不改系统亮度；系统亮度控制需要原生权限。',
          style: TextStyle(fontSize: 11, color: secondary),
        ),
        _section('辅助线', secondary),
        _switch('显示辅助线', _settings.guideShow,
            (bool v) => _update(<String, Object?>{'guideShow': v})),
        if (_settings.guideShow) ...<Widget>[
          _segment<String>(
            label: '线型',
            value: _settings.guideStyle,
            options: const <String, String>{
              'solid': '实线',
              'dashed': '虚线',
            },
            onChanged: (String v) =>
                _update(<String, Object?>{'guideStyle': v}),
          ),
          _slider(
            '线宽',
            _settings.guideThickness,
            0.2,
            2,
            divisions: 18,
            label: _settings.guideThickness.toStringAsFixed(1),
            onChanged: (double v) =>
                _update(<String, Object?>{'guideThickness': v}),
          ),
          _slider(
            '透明度',
            _settings.guideOpacity,
            0.03,
            0.4,
            divisions: 37,
            label: '${(_settings.guideOpacity * 100).toStringAsFixed(0)}%',
            onChanged: (double v) =>
                _update(<String, Object?>{'guideOpacity': v}),
          ),
          _colorRow('辅助线颜色', _settings.guideColor, 0xFF888888,
              (int? value) => _update(<String, Object?>{'guideColor': value})),
        ],
        _section('章节标题', secondary),
        _slider(
          '标题字号',
          _settings.titleFontSize,
          14,
          30,
          divisions: 16,
          label: '${_settings.titleFontSize.toStringAsFixed(0)}',
          onChanged: (double v) =>
              _update(<String, Object?>{'titleFontSize': v}),
        ),
        _slider(
          '标题字重',
          _settings.titleWeight.toDouble(),
          300,
          700,
          divisions: 4,
          label: 'w${_settings.titleWeight}',
          onChanged: (double v) =>
              _update(<String, Object?>{'titleWeight': v.round()}),
        ),
        _fontDropdown(
          '标题字体',
          _settings.titleFontFamily,
          (String? family) =>
              _update(<String, Object?>{'titleFontFamily': family}),
        ),
        _colorRow('标题颜色', _settings.titleColor,
            _store.themeById(_settings.themeId).foreground,
            (int? value) => _update(<String, Object?>{'titleColor': value})),
        _segment<String>(
          label: '标题样式',
          value: _settings.titleTemplate,
          options: const <String, String>{
            'plain': '普通',
            'centered': '居中',
            'divider': '带分隔线',
            'none': '不显示',
          },
          onChanged: (String v) =>
              _update(<String, Object?>{'titleTemplate': v}),
        ),
        _segment<String>(
          label: '标题对齐',
          value: _settings.titleAlign,
          options: const <String, String>{
            'left': '左',
            'center': '中',
            'right': '右',
          },
          onChanged: (String v) =>
              _update(<String, Object?>{'titleAlign': v}),
        ),
        _slider(
          '标题上方留白',
          _settings.titleGapTop,
          0,
          40,
          divisions: 40,
          label: _settings.titleGapTop.toStringAsFixed(0),
          onChanged: (double v) =>
              _update(<String, Object?>{'titleGapTop': v}),
        ),
        _slider(
          '标题下方留白',
          _settings.titleGapBottom,
          0,
          50,
          divisions: 50,
          label: _settings.titleGapBottom.toStringAsFixed(0),
          onChanged: (double v) =>
              _update(<String, Object?>{'titleGapBottom': v}),
        ),
        _switch('章节序号与标题分行', _settings.titleNumberNewLine,
            (bool v) => _update(<String, Object?>{'titleNumberNewLine': v})),
        _slider(
          '章节起始留白',
          _settings.chapterStartBlank,
          0,
          80,
          divisions: 40,
          label: _settings.chapterStartBlank.toStringAsFixed(0),
          onChanged: (double v) =>
              _update(<String, Object?>{'chapterStartBlank': v}),
        ),
        _switch('极简模式（关闭翻页动画）', _settings.minimalMode,
            (bool v) => _update(<String, Object?>{'minimalMode': v})),
        _section('方案与配置', secondary),
        Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: () => _savePresetDialog(context),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('存为方案'),
            ),
            TextButton.icon(
              onPressed: () => _exportDialog(context),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('导出配置'),
            ),
            TextButton.icon(
              onPressed: () => _importDialog(context),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('导入配置'),
            ),
          ],
        ),
        ..._store.presets.entries.map(
          (MapEntry<String, ReaderSettings> entry) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            subtitle: const Text('点击应用此方案'),
            onTap: () => _update(entry.value.toJson()),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await _store.deletePreset(entry.key);
                setState(() {});
              },
            ),
          ),
        ),
        const Divider(),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '配置按「本书 > 当前主题 > 全局」合并；当前编辑范围：${_scope.label}。',
            style: TextStyle(fontSize: 11, color: secondary),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 通用组件
  // ---------------------------------------------------------------------------

  Widget _section(String title, Color secondary) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: secondary,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _slider(
    String title,
    double value,
    double min,
    double max, {
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) =>
      _sliderRaw(title, value, min, max, divisions, label, onChanged);

  Widget _sliderRaw(String label, double value, double min, double max,
      int divisions, String labelText, ValueChanged<double> onChanged) {
    final double safe = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Text(labelText, style: const TextStyle(fontSize: 12)),
          ],
        ),
        Slider(
          value: safe,
          min: min,
          max: max,
          divisions: divisions,
          label: labelText,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged,
      {bool enabled = true}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _segment<T>({
    required String label,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.entries.map((MapEntry<T, String> entry) {
              final bool selected = entry.key == value;
              return ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (_) => onChanged(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _choiceTile({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      selected: selected,
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (trailing != null) trailing,
          if (selected) const Icon(Icons.check_rounded, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _presetButton(String label, Map<String, Object?> patch) {
    return OutlinedButton(
      onPressed: () => _update(patch),
      child: Text(label),
    );
  }

  Widget _templateField(String label, String value, ValueChanged<String> onChanged) {
    final TextEditingController controller = TextEditingController(text: value);
    controller.selection = TextSelection.collapsed(offset: value.length);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: '{chapter}',
          isDense: true,
        ),
        onSubmitted: onChanged,
      ),
    );
  }

  Widget _colorRow(
      String label, int? current, int fallback, ValueChanged<int?> onChanged) {
    final int shown = current ?? fallback;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Color(shown),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF888888)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final int? picked = await _pickColor(context, shown);
              if (picked != null) onChanged(picked);
            },
            child: const Text('选择'),
          ),
          if (current != null)
            IconButton(
              tooltip: '跟随主题',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }

  Widget _themeDropdown(String label, String value, ValueChanged<String> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: DropdownButton<String>(
        value: _store.allThemes.any((ReaderTheme t) => t.id == value) ? value : null,
        underline: const SizedBox.shrink(),
        items: _store.allThemes
            .map((ReaderTheme t) => DropdownMenuItem<String>(
                  value: t.id,
                  child: Text(t.name),
                ))
            .toList(),
        onChanged: (String? id) {
          if (id != null) onChanged(id);
        },
      ),
    );
  }

  Widget _tapActionTile(String label, String value, ValueChanged<String> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: const <DropdownMenuItem<String>>[
          DropdownMenuItem<String>(value: 'prev', child: Text('上一页')),
          DropdownMenuItem<String>(value: 'next', child: Text('下一页')),
          DropdownMenuItem<String>(value: 'menu', child: Text('显示菜单')),
          DropdownMenuItem<String>(value: 'none', child: Text('无动作')),
          DropdownMenuItem<String>(value: 'chapters', child: Text('打开目录')),
          DropdownMenuItem<String>(value: 'bookmark', child: Text('加书签')),
        ],
        onChanged: (String? v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _fontDropdown(
      String label, String? family, ValueChanged<String?> onChanged) {
    final List<UserFont> fonts = UserFontStore.instance.fonts;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: DropdownButton<String?>(
        value: fonts.any((UserFont f) => f.family == family) ? family : null,
        underline: const SizedBox.shrink(),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(value: null, child: Text('跟随正文')),
          ...fonts.map((UserFont f) => DropdownMenuItem<String?>(
                value: f.family,
                child: Text(f.name),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _editThemeColors(BuildContext context) async {
    final ReaderTheme theme = _store.themeById(_settings.themeId);
    final int? background = await _pickColor(context, theme.background);
    if (background == null || !context.mounted) return;
    final int? foreground = await _pickColor(context, theme.foreground);
    if (foreground == null || !context.mounted) return;
    await _store.updateTheme(
      theme.copyWith(background: background, foreground: foreground),
    );
    _update(<String, Object?>{
      'themeId': theme.id,
      'backgroundColor': null,
      'textColor': null,
    });
    setState(() {});
  }

  Future<void> _confirmReset(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('恢复默认'),
        content: Text('将清空「${_scope.label}」里的阅读设置，确定吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok == true) _resetScope();
  }

  Future<void> _pickBackgroundImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null || result.files.length != 1) return;
    final PlatformFile file = result.files.first;
    if (file.path == null) return;
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/backgrounds');
    if (!await dir.exists()) await dir.create(recursive: true);
    final String target =
        '${dir.path}/bg-${DateTime.now().millisecondsSinceEpoch}${p.extension(file.name).toLowerCase()}';
    await File(file.path!).copy(target);
    _update(<String, Object?>{'bgImagePath': target});
  }

  Future<int?> _pickColor(BuildContext context, int initial) async {
    final TextEditingController hex = TextEditingController(
      text: '#${initial.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );
    String? error;
    return showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) => AlertDialog(
          title: const Text('选择颜色'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <int>[
                  0xFF000000,
                  0xFF1A1A1A,
                  0xFF41382B,
                  0xFF22301F,
                  0xFF7A7A7A,
                  0xFFB4B6B9,
                  0xFFF5EFE1,
                  0xFFE3EFE3,
                  0xFFF1F2F3,
                  0xFFFDFDFC,
                ].map((int color) {
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF999999)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hex,
                decoration: InputDecoration(
                  labelText: '十六进制（#RRGGBB 或 #AARRGGBB）',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                String value = hex.text.trim().replaceFirst('#', '');
                if (value.length == 6) value = 'FF$value';
                if (value.length != 8 ||
                    int.tryParse(value, radix: 16) == null) {
                  setDialogState(() => error = '格式不正确');
                  return;
                }
                Navigator.pop(ctx, int.parse(value, radix: 16));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTheme(BuildContext context) async {
    final TextEditingController name = TextEditingController(text: '自定义主题');
    bool dark = false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) => AlertDialog(
          title: const Text('新建主题'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '主题名称'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('深色主题'),
                value: dark,
                onChanged: (bool v) => setDialogState(() => dark = v),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final ReaderTheme theme = await _store.createTheme(
      name: name.text,
      isDark: dark,
      background: dark ? 0xFF181A1B : 0xFFFAF9F6,
      foreground: dark ? 0xFFC9CBCE : 0xFF202124,
    );
    _update(<String, Object?>{'themeId': theme.id});
    setState(() {});
  }

  Future<void> _renameTheme(BuildContext context) async {
    final ReaderTheme theme = _store.themeById(_settings.themeId);
    final TextEditingController name = TextEditingController(text: theme.name);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('重命名主题'),
        content: TextField(controller: name, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, name.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await _store.renameTheme(theme.id, value);
    setState(() {});
  }

  Future<void> _savePresetDialog(BuildContext context) async {
    final TextEditingController name = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('存为阅读方案'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: '方案名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, name.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    await _store.savePreset(value, _settings);
    setState(() {});
  }

  Future<void> _exportDialog(BuildContext context) async {
    final String json = _store.exportJson(bookId: widget.bookId);
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('导出阅读配置'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _importDialog(BuildContext context) async {
    final TextEditingController input = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) => AlertDialog(
          title: const Text('导入阅读配置'),
          content: TextField(
            controller: input,
            maxLines: 8,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              hintText: '粘贴之前导出的 JSON',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final int count = await _store.importJson(input.text);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  setState(() => _settings = _store.resolve(widget.bookId));
                  widget.onRepaginate();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已导入配置（$count 项）')),
                  );
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: const Text('导入'),
            ),
          ],
        ),
      ),
    );
  }
}
