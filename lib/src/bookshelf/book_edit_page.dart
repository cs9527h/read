import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:read/src/bookshelf/cover_art.dart';
import 'package:read/src/bookshelf/cover_search_page.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/ui/sheet.dart';

/// 编辑书籍信息。所有字段都真实写回 [LibraryStore]，保存后书架立即刷新。
class BookEditPage extends StatefulWidget {
  const BookEditPage({super.key, required this.book});

  final Book book;

  @override
  State<BookEditPage> createState() => _BookEditPageState();
}

class _BookEditPageState extends State<BookEditPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.book.title);
  late final TextEditingController _author =
      TextEditingController(text: widget.book.author);
  late final TextEditingController _category =
      TextEditingController(text: widget.book.category);

  late bool _pinned = widget.book.pinned;
  late bool _private = widget.book.isPrivate;
  late int _rating = widget.book.rating;
  late ReadingStatus _status = widget.book.status;
  late List<String> _tags = List<String>.from(widget.book.tags);
  late List<String> _collections = List<String>.from(widget.book.collections);
  late String _template = widget.book.coverTemplate;
  String? _coverPath;

  bool _saving = false;
  bool get _eink => ReadUi.instance.isEink;

  @override
  void initState() {
    super.initState();
    _coverPath = widget.book.coverPath;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _category.dispose();
    super.dispose();
  }

  Book get _draft => widget.book.copyWith(
        title: _title.text.trim(),
        author: _author.text.trim(),
        category: _category.text.trim(),
        pinned: _pinned,
        isPrivate: _private,
        rating: _rating,
        readingStatus: _status.code,
        tags: _tags,
        collections: _collections,
        coverPath: _coverPath,
        coverTemplate: _template,
      );

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('编辑信息'),
        leading: IconButton(
          tooltip: '返回',
          icon: ReadIcon(ReadGlyph.arrowLeft, size: 21, color: palette.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '保存中' : '保存',
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _coverBlock(palette),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _fieldLabel(palette, '书名'),
                    TextField(
                      controller: _title,
                      maxLength: 80,
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: palette.outline),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: palette.ink, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(palette, '作者'),
                    TextField(
                      controller: _author,
                      style: TextStyle(fontSize: 15, color: palette.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: palette.outline),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: palette.ink, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(palette, '评分'),
                    _ratingRow(palette),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _section(palette, '分类与状态'),
          _plainField(
            palette,
            label: '分类',
            controller: _category,
            hint: '例如：文学 / 技术 / 待读',
          ),
          if (LibraryStore.instance.allCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String c in LibraryStore.instance.allCategories.take(8))
                    _chip(
                      palette,
                      c,
                      selected: _category.text.trim() == c,
                      onTap: () => setState(() => _category.text = c),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _fieldLabel(palette, '阅读状态'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final ReadingStatus status in ReadingStatus.values)
                _chip(
                  palette,
                  status.label,
                  selected: _status == status,
                  onTap: () => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _section(palette, '书架行为'),
          _switchRow(
            palette,
            icon: ReadGlyph.pin,
            title: '置顶',
            subtitle: '始终排在书架最前，不受排序影响',
            value: _pinned,
            onChanged: (bool v) => setState(() => _pinned = v),
          ),
          _switchRow(
            palette,
            icon: ReadGlyph.lock,
            title: '设为私密',
            subtitle: '书架默认不显示，需在设置中打开「显示私密书籍」',
            value: _private,
            onChanged: (bool v) => setState(() => _private = v),
          ),
          const SizedBox(height: 22),
          _section(palette, '标签'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String tag in _tags)
                InputChip(
                  label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() => _tags.remove(tag)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_eink ? 0 : 14),
                    side: BorderSide(color: palette.outline),
                  ),
                ),
              ActionChip(
                avatar: ReadIcon(ReadGlyph.plus, size: 14, color: palette.muted),
                label: const Text('添加标签', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: _addTag,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_eink ? 0 : 14),
                  side: BorderSide(color: palette.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _section(palette, '书箱'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String name in LibraryStore.instance.allCollections)
                _chip(
                  palette,
                  name,
                  selected: _collections.contains(name),
                  onTap: () => setState(() {
                    if (!_collections.remove(name)) _collections.add(name);
                  }),
                ),
              _chip(palette, '新建书箱', selected: false, onTap: _createCollection),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.outline),
              borderRadius: BorderRadius.circular(_eink ? 0 : 12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ReadIcon(ReadGlyph.info, size: 18, color: palette.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '角色：本项目没有人物库数据结构，也没有解析人物关系的引擎，'
                    '所以这里不显示「角色」字段——留一个填了也不生效的输入框没有意义。'
                    '后续若加入人物索引，会在这一屏补充。',
                    style: TextStyle(fontSize: 12, height: 1.55, color: palette.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.ink,
                foregroundColor: palette.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_eink ? 0 : 10),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverBlock(ReadPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: _openCoverMenu,
          child: SizedBox(
            width: 108,
            height: 156,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: BookCover(
                    book: _draft,
                    templateId: _template,
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _eink ? Colors.white : Colors.black.withValues(alpha: 0.55),
                      border: _eink ? Border.all(color: Colors.black) : null,
                      shape: BoxShape.circle,
                    ),
                    child: ReadIcon(
                      ReadGlyph.image,
                      size: 14,
                      color: _eink ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: _openCoverMenu,
          child: Text('更换封面',
              style: TextStyle(fontSize: 12.5, color: palette.muted)),
        ),
      ],
    );
  }

  Widget _ratingRow(ReadPalette palette) {
    return Row(
      children: <Widget>[
        for (int i = 1; i <= 5; i++)
          GestureDetector(
            onTap: () => setState(() => _rating = _rating == i ? 0 : i),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ReadIcon(
                ReadGlyph.star,
                size: 21,
                color: i <= _rating ? palette.ink : palette.outline,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          _rating == 0 ? '未评分' : '$_rating/5',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
      ],
    );
  }

  Widget _plainField(
    ReadPalette palette, {
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 15, color: palette.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(fontSize: 13, color: palette.muted),
          hintStyle: TextStyle(fontSize: 13, color: palette.outline),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_eink ? 0 : 10),
            borderSide: BorderSide(color: palette.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_eink ? 0 : 10),
            borderSide: BorderSide(color: palette.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_eink ? 0 : 10),
            borderSide: BorderSide(color: palette.ink, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(ReadPalette palette, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: palette.muted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      );

  Widget _section(ReadPalette palette, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1, color: palette.outline)),
          ],
        ),
      );

  Widget _chip(ReadPalette palette, String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? palette.ink : Colors.transparent,
          border: Border.all(color: selected ? palette.ink : palette.outline),
          borderRadius: BorderRadius.circular(_eink ? 0 : 16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected
                ? (palette.brightness == Brightness.dark ? Colors.black : Colors.white)
                : palette.ink,
          ),
        ),
      ),
    );
  }

  Widget _switchRow(
    ReadPalette palette, {
    required ReadGlyph icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ReadIcon(icon, size: 18, color: palette.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: TextStyle(fontSize: 15, color: palette.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: palette.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _eink ? Colors.white : null,
            activeTrackColor: palette.ink,
          ),
        ],
      ),
    );
  }

  Future<void> _addTag() async {
    final String? value = await promptText(
      context,
      title: '添加标签',
      hint: '例如：科幻 / 待重读',
      confirm: '添加',
    );
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      if (!_tags.contains(value.trim())) _tags.add(value.trim());
    });
  }

  Future<void> _createCollection() async {
    final String? value = await promptText(
      context,
      title: '新建书箱',
      hint: '书箱名称',
      confirm: '创建',
    );
    if (value == null || value.trim().isEmpty) return;
    setState(() => _collections.add(value.trim()));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书名不能为空')),
      );
      return;
    }
    setState(() => _saving = true);
    final Book updated = _draft;
    final bool ok = await LibraryStore.instance.updateBook(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败：书已不在书架中')),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  // ---------------------------------------------------------------------------
  // 封面菜单
  // ---------------------------------------------------------------------------

  Future<void> _openCoverMenu() async {
    final String? action = await showReadSheet<String>(
      context,
      title: '封面',
      children: <Widget>[
        SheetMenuItem(
          glyph: ReadGlyph.layers,
          title: '模板封面',
          subtitle: '用内置版式实时排版，不占用存储',
          onTap: () => Navigator.pop(context, 'template'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.wand,
          title: 'AI 生成封面',
          subtitle: CoverAiService.statusLabel,
          onTap: () => Navigator.pop(context, 'ai'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.search,
          title: '搜图设置封面',
          subtitle: '内置浏览器搜索，点选图片自动裁切为封面',
          onTap: () => Navigator.pop(context, 'search'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.image,
          title: '网络图片',
          subtitle: '从 http/https 地址下载并保存到本机',
          onTap: () => Navigator.pop(context, 'network'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.importFile,
          title: '本机图片',
          subtitle: '从相册或文件中选择 PNG / JPG',
          onTap: () => Navigator.pop(context, 'local'),
        ),
        const SheetSeparator(),
        SheetMenuItem(
          glyph: ReadGlyph.eye,
          title: '查看大图',
          onTap: () => Navigator.pop(context, 'view'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.save,
          title: '保存封面',
          subtitle: '导出当前封面为 PNG 文件',
          onTap: () => Navigator.pop(context, 'export'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.grid,
          title: '预置封面',
          subtitle: '一键套用，立即写入书架',
          onTap: () => Navigator.pop(context, 'preset'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'template':
        await _pickTemplate();
      case 'ai':
        await _showAiNotice();
      case 'search':
        await _searchImage();
      case 'network':
        await _networkImage();
      case 'local':
        await _localImage();
      case 'view':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CoverViewerPage(book: _draft, templateId: _template),
          ),
        );
      case 'export':
        await _exportCover();
      case 'preset':
        await _presetCovers();
    }
  }

  Future<void> _pickTemplate() async {
    final String? id = await showReadSheet<String>(
      context,
      title: '模板封面',
      children: <Widget>[
        for (final CoverTemplate template in CoverTemplate.all)
          SheetMenuItem(
            glyph: ReadGlyph.layers,
            title: template.label,
            subtitle: template.description,
            trailing: _template == template.id
                ? ReadIcon(ReadGlyph.check, size: 18, color: ReadPalette.of(context).ink)
                : null,
            onTap: () => Navigator.pop(context, template.id),
          ),
      ],
    );
    if (id == null) return;
    setState(() {
      _template = id;
      // 模板封面与图片封面互斥：选了模板就清掉旧图，避免"选了没变"。
      _coverPath = null;
    });
    await deleteCoverFile(widget.book.coverPath);
  }

  Future<void> _presetCovers() async {
    final String? id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        final ReadPalette palette = ReadPalette.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('预置封面',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: palette.ink)),
              const SizedBox(height: 4),
              Text('选定后会立即生成图片并写入书架',
                  style: TextStyle(fontSize: 12, color: palette.muted)),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CoverTemplate.all.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (BuildContext c, int i) {
                    final CoverTemplate template = CoverTemplate.all[i];
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, template.id),
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            width: 96,
                            height: 138,
                            child: BookCover(
                              book: _draft.copyWith(title: _title.text, author: _author.text),
                              templateId: template.id,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(template.label,
                              style: TextStyle(fontSize: 11, color: palette.muted)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (id == null) return;
    setState(() => _template = id);
    await _applyTemplateAsImage(id);
  }

  Future<void> _applyTemplateAsImage(String templateId) async {
    final File file = await renderTemplateCover(
      book: _draft.copyWith(title: _title.text, author: _author.text),
      templateId: templateId,
      eink: _eink,
    );
    await deleteCoverFile(_coverPath);
    setState(() => _coverPath = file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('封面已生成：${file.path.split('/').last}')),
    );
  }

  Future<void> _showAiNotice() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('AI 封面未接入'),
        content: Text(CoverAiService.explanation),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  Future<void> _searchImage() async {
    final String query = _title.text.trim().isNotEmpty
        ? _title.text.trim()
        : widget.book.title;
    final File? picked = await Navigator.of(context).push<File>(
      MaterialPageRoute<File>(
        builder: (_) => CoverSearchPage(query: query),
      ),
    );
    if (picked == null || !picked.existsSync()) return;
    try {
      final File saved = await adoptCoverImage(picked, widget.book.id);
      await deleteCoverFile(_coverPath);
      setState(() => _coverPath = saved.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置封面失败：$error')),
      );
    } finally {
      if (picked.existsSync()) await picked.delete();
    }
  }

  Future<void> _networkImage() async {
    final String? url = await promptText(
      context,
      title: '网络图片',
      hint: 'https://example.com/cover.jpg',
      confirm: '下载',
    );
    if (url == null || url.trim().isEmpty) return;
    await _applyNetwork(url.trim());
  }

  Future<void> _applyNetwork(String url) async {
    try {
      final File tmp = await downloadCover(url);
      final File saved = await adoptCoverImage(tmp, widget.book.id);
      await deleteCoverFile(_coverPath);
      if (await tmp.exists()) await tmp.delete();
      setState(() => _coverPath = saved.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置封面失败：$error')),
      );
    }
  }

  Future<void> _localImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    final String? path = result?.files.firstOrNull?.path;
    if (path == null) return;
    final File saved = await adoptCoverImage(File(path), widget.book.id);
    await deleteCoverFile(_coverPath);
    setState(() => _coverPath = saved.path);
  }

  Future<void> _exportCover() async {
    try {
      final Uint8List bytes;
      final String? path = _coverPath;
      if (path != null && File(path).existsSync()) {
        bytes = await File(path).readAsBytes();
      } else {
        bytes = await renderCoverPng(
          title: _title.text,
          author: _author.text,
          templateId: _template,
          eink: _eink,
        );
      }
      final String? target = await FilePicker.platform.saveFile(
        dialogTitle: '保存封面',
        fileName: '${_title.text.trim().isEmpty ? 'cover' : _title.text.trim()}.png',
        bytes: bytes,
      );
      if (target == null) return;
      // 桌面平台由 saveFile 写入；移动端返回路径时自行落盘。
      if (!await File(target).exists()) {
        await File(target).writeAsBytes(bytes, flush: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('封面已保存到 $target')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存封面失败：$error')),
      );
    }
  }
}
