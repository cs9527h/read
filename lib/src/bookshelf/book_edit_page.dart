import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';

/// 编辑信息：封面、书名、作者、分类、评分、置顶/私密、阅读状态与标签。
/// 所有字段一次提交，保存成功后才返回书架。
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
  late final List<String> _tags = List<String>.from(widget.book.tags);
  late int _rating = widget.book.rating;
  late bool _pinned = widget.book.pinned;
  late bool _private = widget.book.isPrivate;
  late String _status = widget.book.readingStatus;
  String? _coverPath;
  bool _saving = false;

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

  static const Map<String, String> _statusLabels = <String, String>{
    'unread': '未读',
    'reading': '在读',
    'shelved': '搁置',
    'finished': '读完',
    'dropped': '弃读',
  };

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('编辑信息'),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: _showCoverMenu,
                child: _CoverPreview(book: widget.book, path: _coverPath),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('封面',
                        style: TextStyle(fontSize: 12, color: palette.muted)),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _showCoverMenu,
                      icon: const Icon(Icons.image_outlined, size: 17),
                      label: const Text('更换封面'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持本机图片、网络图片与预置模板；AI 生图/搜图尚未接入。',
                      style: TextStyle(
                          fontSize: 11, color: palette.muted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _field(_title, '书名'),
          _field(_author, '作者'),
          _field(_category, '分类', hint: '例如：科幻、历史、待读'),
          const SizedBox(height: 6),
          Text('评分', style: TextStyle(fontSize: 12, color: palette.muted)),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              for (int i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _rating = i == _rating ? 0 : i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 24,
                    color: palette.ink,
                  ),
                ),
              const Spacer(),
              Text(_rating == 0 ? '未评分' : '$_rating / 5',
                  style: TextStyle(fontSize: 12, color: palette.muted)),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pinned,
            onChanged: (bool v) => setState(() => _pinned = v),
            title: const Text('置顶'),
            subtitle: const Text('置顶书籍始终排在书架最前'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _private,
            onChanged: (bool v) => setState(() => _private = v),
            title: const Text('设为私密'),
            subtitle: const Text('仅在书架隐藏标题，不影响本地阅读与同步'),
          ),
          const SizedBox(height: 6),
          Text('阅读状态', style: TextStyle(fontSize: 12, color: palette.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final entry in _statusLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _status == entry.key,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _status = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Text('标签', style: TextStyle(fontSize: 12, color: palette.muted)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addTag,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (_tags.isEmpty)
                Text('暂无标签',
                    style: TextStyle(fontSize: 12, color: palette.muted)),
              for (final String tag in _tags)
                InputChip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {String? hint}) {
    final palette = ReadPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kEink ? 0 : 10),
          ),
          filled: true,
          fillColor: palette.surface,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _toast('书名不能为空');
      return;
    }
    setState(() => _saving = true);
    try {
      await LibraryStore.instance.updateBookInfo(
        widget.book,
        title: _title.text,
        author: _author.text,
        category: _category.text,
        rating: _rating,
        pinned: _pinned,
        isPrivate: _private,
        readingStatus: _status,
        tags: _tags,
        coverPath: _coverPath,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _toast('保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '标签名'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return;
    if (!_tags.contains(clean)) setState(() => _tags.add(clean));
  }

  Future<void> _showCoverMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('预置封面 / 模板封面'),
              subtitle: const Text('本地生成黑白模板，不上传网络'),
              onTap: () => Navigator.pop(ctx, 'template'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('本机图片'),
              onTap: () => Navigator.pop(ctx, 'local'),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('网络图片'),
              subtitle: const Text('填写 https 图片地址并下载到本机'),
              onTap: () => Navigator.pop(ctx, 'network'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('AI 生成封面（未接入）'),
              subtitle: const Text('尚未接入生图服务，不会伪装成功'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.image_search_outlined),
              title: const Text('搜图设置封面（未接入）'),
              subtitle: const Text('尚未接入图片搜索接口'),
            ),
            if (_coverPath != null && File(_coverPath!).existsSync())
              ListTile(
                leading: const Icon(Icons.zoom_in_rounded),
                title: const Text('查看大图'),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
            if (_coverPath != null && File(_coverPath!).existsSync())
              ListTile(
                leading: const Icon(Icons.save_alt_rounded),
                title: const Text('保存封面'),
                onTap: () => Navigator.pop(ctx, 'save'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'template':
        await _chooseTemplate();
      case 'local':
        await _pickLocalCover();
      case 'network':
        await _pickNetworkCover();
      case 'view':
        await _viewCover();
      case 'save':
        await _exportCover();
    }
  }

  Future<void> _chooseTemplate() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
            children: <Widget>[
              for (int i = 0; i < 6; i++)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, i),
                  child: _TemplatePreview(index: i, title: _title.text),
                ),
            ],
          ),
        ),
      ),
    );
    if (index == null) return;
    final bytes = await _renderTemplate(index, _title.text);
    await _storeCover(bytes, 'png');
  }

  Future<void> _pickLocalCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null || !File(path).existsSync()) {
      _toast('无法读取所选图片');
      return;
    }
    final bytes = await File(path).readAsBytes();
    final ext = path.split('.').last.toLowerCase();
    await _storeCover(bytes, ext == 'jpeg' ? 'jpg' : ext);
  }

  Future<void> _pickNetworkCover() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('网络图片'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration:
              const InputDecoration(hintText: 'https://example.com/cover.jpg'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('下载')),
        ],
      ),
    );
    controller.dispose();
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _toast('图片地址必须以 http(s) 开头');
      return;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200)
        throw StateError('HTTP ${response.statusCode}');
      final chunks = <List<int>>[];
      int total = 0;
      await for (final chunk in response) {
        total += chunk.length;
        if (total > 10 * 1024 * 1024) throw StateError('图片超过 10MB');
        chunks.add(chunk);
      }
      final bytes = <int>[
        for (final chunk in chunks) ...chunk,
      ];
      final ext = uri.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      await _storeCover(Uint8List.fromList(bytes), ext);
    } catch (error) {
      _toast('下载失败：$error');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _storeCover(Uint8List bytes, String ext) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/covers');
      await dir.create(recursive: true);
      final file = File(
          '${dir.path}/${widget.book.id}-${DateTime.now().microsecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) setState(() => _coverPath = file.path);
    } catch (error) {
      _toast('封面保存失败：$error');
    }
  }

  Future<Uint8List> _renderTemplate(int index, String title) async {
    const double w = 600;
    const double h = 840;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
    const backgrounds = <Color>[
      Color(0xFF111111),
      Color(0xFFF5F5F2),
      Color(0xFFE8E8E5),
      Color(0xFF1E1E1E),
      Color(0xFFFAFAF8),
      Color(0xFF2B2B2B),
    ];
    final bg = backgrounds[index % backgrounds.length];
    final fg = bg.computeLuminance() < 0.4 ? Colors.white : Colors.black;
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);
    final border = Paint()
      ..color = fg.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(const Rect.fromLTWH(28, 28, w - 56, h - 56), border);
    if (index.isEven) {
      final path = ui.Path()
        ..moveTo(w * 0.34, h * 0.68)
        ..quadraticBezierTo(w * 0.30, h * 0.34, w * 0.62, h * 0.22)
        ..quadraticBezierTo(w * 0.74, h * 0.52, w * 0.34, h * 0.68);
      canvas.drawPath(
        path,
        Paint()
          ..color = fg.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawLine(
        Offset(w * 0.34, h * 0.68),
        Offset(w * 0.68, h * 0.84),
        Paint()
          ..color = fg.withValues(alpha: 0.8)
          ..strokeWidth = 5,
      );
    }
    final text = TextPainter(
      text: TextSpan(
        text: title.trim().isEmpty ? '未命名' : title.trim(),
        style: TextStyle(
          color: fg,
          fontSize: 46,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: w - 96);
    text.paint(canvas, Offset(48, h * 0.76));
    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('模板封面生成失败');
    return data.buffer.asUint8List();
  }

  Future<void> _viewCover() async {
    if (_coverPath == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.file(File(_coverPath!), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _exportCover() async {
    if (_coverPath == null) return;
    try {
      final bytes = await File(_coverPath!).readAsBytes();
      final name =
          '${_title.text.trim().isEmpty ? widget.book.id : _title.text.trim()}-cover.png';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '保存封面',
        fileName: name,
        bytes: bytes,
      );
      if (path == null) return;
      final file = File(path);
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      _toast('封面已保存：$path');
    } catch (error) {
      _toast('保存失败：$error');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.book, required this.path});

  final Book book;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(kEink ? 0 : 8),
      child: Container(
        width: 96,
        height: 136,
        color: palette.surface,
        child: path != null && File(path!).existsSync()
            ? Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _textCover(palette),
              )
            : _textCover(palette),
      ),
    );
  }

  Widget _textCover(ReadPalette palette) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: palette.outline)),
        child: Center(
          child: Text(
            book.title,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.35, color: palette.ink),
          ),
        ),
      );
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = index.isEven;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B1B1B) : const Color(0xFFF3F3F0),
        border: Border.all(color: dark ? Colors.white24 : Colors.black26),
        borderRadius: BorderRadius.circular(kEink ? 0 : 8),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title.trim().isEmpty ? '未命名' : title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dark ? Colors.white : Colors.black,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
