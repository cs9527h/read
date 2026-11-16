import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// 存储管理：统计书籍目录与缓存目录的真实占用。
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  int _booksBytes = 0;
  int _booksCount = 0;
  int _cacheBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    setState(() => _loading = true);
    int books = 0;
    int count = 0;
    int cache = 0;
    try {
      final Directory base = await getApplicationDocumentsDirectory();
      final Directory booksDir = Directory('${base.path}/books');
      if (await booksDir.exists()) {
        await for (final FileSystemEntity entity in booksDir.list(recursive: true)) {
          if (entity is File) {
            books += await entity.length();
            count += 1;
          }
        }
      }
      final Directory? cacheDir = await getTemporaryDirectory();
      if (cacheDir != null && await cacheDir.exists()) {
        await for (final FileSystemEntity entity in cacheDir.list(recursive: true)) {
          if (entity is File) cache += await entity.length();
        }
      }
    } catch (_) {
      // 权限或平台差异：保留已统计到的数字。
    }
    if (!mounted) return;
    setState(() {
      _booksBytes = books;
      _booksCount = count;
      _cacheBytes = cache;
      _loading = false;
    });
  }

  Future<void> _clearCache() async {
    int removed = 0;
    try {
      final Directory? cacheDir = await getTemporaryDirectory();
      if (cacheDir != null && await cacheDir.exists()) {
        await for (final FileSystemEntity entity in cacheDir.list()) {
          try {
            if (entity is File) {
              removed += await entity.length();
              await entity.delete();
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清理缓存 ${_size(removed)}')),
    );
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text('存储管理', style: TextStyle(fontSize: 18, color: palette.ink)),
        leading: IconButton(
          icon: ReadIcon(ReadGlyph.arrowLeft, size: 20, color: palette.icon),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '重新统计',
            icon: ReadIcon(ReadGlyph.refresh, size: 20, color: palette.icon),
            onPressed: _measure,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: <Widget>[
          _Card(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('书籍文件', style: TextStyle(fontSize: 12, color: palette.muted)),
                const SizedBox(height: 6),
                Text(
                  _loading ? '统计中…' : _size(_booksBytes),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 $_booksCount 个文件 · ${LibraryStore.instance.books.length} 本书在书架',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('缓存', style: TextStyle(fontSize: 12, color: palette.muted)),
                const SizedBox(height: 6),
                Text(
                  _loading ? '统计中…' : _size(_cacheBytes),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _clearCache,
                    icon: const ReadIcon(ReadGlyph.trash, size: 18),
                    label: const Text('清理缓存'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '清理缓存不会删除书架里的书。删除书籍请在书架长按封面。',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
        ],
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.palette, required this.child});

  final ReadPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
          border: Border.all(color: palette.outline),
        ),
        child: child,
      );
}
