import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/cloud_presence.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/settings_portable.dart';
import 'package:read/src/sync/auto_sync_service.dart';
import 'package:read/src/sync/metadata_sync_service.dart';
import 'package:read/src/sync/progress_models.dart';
import 'package:read/src/sync/progress_sync_service.dart';
import 'package:read/src/sync/remote_store.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/sync/sync_document.dart';
import 'package:read/src/sync/sync_record.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/ui/sheet.dart';

/// 设备与数据：导出 / 导入本机设置、从其他设备恢复、云端数据对比。
class DataToolsPage extends StatefulWidget {
  const DataToolsPage({super.key});

  @override
  State<DataToolsPage> createState() => _DataToolsPageState();
}

class _DataToolsPageState extends State<DataToolsPage> {
  bool _busy = false;
  String _busyLabel = '';

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final bool configured = SyncConfig.instance.configured;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('设备与数据'),
        leading: IconButton(
          tooltip: '返回',
          icon: ReadIcon(ReadGlyph.arrowLeft, size: 21, color: palette.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: <Widget>[
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: palette.ink),
                  ),
                  const SizedBox(width: 10),
                  Text(_busyLabel,
                      style: TextStyle(fontSize: 12.5, color: palette.muted)),
                ],
              ),
            ),
          _sectionLabel(palette, '本机设置'),
          _group(palette, <Widget>[
            _row(
              palette,
              glyph: ReadGlyph.export,
              title: '导出本机设置',
              subtitle: '阅读排版、书架偏好、同步配置、界面风格导出为 JSON',
              onTap: _busy ? null : _exportSettings,
            ),
            _row(
              palette,
              glyph: ReadGlyph.importFile,
              title: '导入本机设置',
              subtitle: '从 JSON 恢复；导入前会列出覆盖范围',
              onTap: _busy ? null : _importSettings,
            ),
          ]),
          _sectionLabel(palette, '跨设备'),
          _group(palette, <Widget>[
            _row(
              palette,
              glyph: ReadGlyph.restore,
              title: '从其他设备恢复',
              subtitle: configured
                  ? '选择恢复范围：仅设置 / 仅进度 / 仅书架 / 全部'
                  : '需要先在「同步 → 云存储」配置 WebDAV 或 S3',
              onTap: configured && !_busy ? _restoreFromOtherDevice : null,
            ),
            _row(
              palette,
              glyph: ReadGlyph.compare,
              title: '云端数据对比',
              subtitle: '阅读进度、书签笔记、书架元数据、设置、文件状态',
              onTap: _busy ? null : _openCompare,
            ),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.outline),
              borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ReadIcon(ReadGlyph.shield, size: 17, color: palette.muted),
                    const SizedBox(width: 8),
                    Text('安全说明',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: palette.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '导出的设置文件不包含 WebDAV 密码、S3 Secret Key、同步加密密码。'
                  '换设备后需要重新填写密钥；这是故意的——导出文件经常会被发到聊天窗口里。',
                  style: TextStyle(fontSize: 11.5, height: 1.6, color: palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 导出 / 导入
  // ---------------------------------------------------------------------------

  Future<void> _exportSettings() async {
    setState(() {
      _busy = true;
      _busyLabel = '正在打包本机设置…';
    });
    try {
      final String json = await SettingsPortable.exportJson();
      final Uint8List bytes = Uint8List.fromList(utf8.encode(json));
      final String stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .split('.')
          .first;
      final String? target = await FilePicker.platform.saveFile(
        dialogTitle: '导出本机设置',
        fileName: 'read-settings-$stamp.json',
        bytes: bytes,
      );
      if (target != null) {
        final File file = File(target);
        if (!await file.exists()) {
          await file.writeAsBytes(bytes, flush: true);
        }
      }
      if (!mounted) return;
      setState(() => _busy = false);
      if (target == null) return;
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('已导出'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SelectableText(target, style: const TextStyle(fontSize: 12.5, height: 1.5)),
              const SizedBox(height: 10),
              Text('${(bytes.length / 1024).toStringAsFixed(1)} KB · 不含任何密钥',
                  style: TextStyle(fontSize: 11.5, color: ReadPalette.of(ctx).muted)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _copy(json, '设置 JSON 已复制');
              },
              child: const Text('复制内容'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('完成')),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('导出失败：$error');
    }
  }

  Future<void> _importSettings() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    final PlatformFile? file = result?.files.firstOrNull;
    if (file == null) return;
    final Uint8List? bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      _toast('读不到文件内容');
      return;
    }
    final PortablePreview preview;
    try {
      preview = SettingsPortable.inspect(utf8.decode(bytes));
    } catch (error) {
      _toast('无法导入：$error');
      return;
    }
    if (!mounted) return;

    final Set<PortableScope> selected = <PortableScope>{
      PortableScope.appearance,
      PortableScope.reader,
      PortableScope.shelf,
      PortableScope.sync,
      PortableScope.books,
    };
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) {
          final ReadPalette palette = ReadPalette.of(ctx);
          Widget check(String label, PortableScope scope) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selected.contains(scope),
                onChanged: (bool? value) => setLocal(() {
                  if (value == true) {
                    selected.add(scope);
                  } else {
                    selected.remove(scope);
                  }
                }),
                title: Text(label, style: const TextStyle(fontSize: 14)),
              );
          return AlertDialog(
            title: const Text('导入本机设置'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '文件包含：${preview.summary}',
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.muted),
                  ),
                  if (preview.exportedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('导出于 ${preview.exportedAt}',
                          style: TextStyle(fontSize: 11, color: palette.muted)),
                    ),
                  const SizedBox(height: 8),
                  const Divider(height: 16),
                  Text('覆盖范围（取消勾选则保留本机原值）',
                      style: TextStyle(fontSize: 11.5, color: palette.muted)),
                  check('外观与界面风格', PortableScope.appearance),
                  check('阅读排版', PortableScope.reader),
                  check('书架偏好与排序', PortableScope.shelf),
                  check('同步配置（不含密码）', PortableScope.sync),
                  check('书架元数据（按内容哈希匹配）', PortableScope.books),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _busyLabel = '正在应用设置…';
    });
    try {
      await SettingsPortable.apply(preview.raw, scopes: selected);
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('设置已导入，界面会立即按新配置重排');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('导入失败：$error');
    }
  }

  // ---------------------------------------------------------------------------
  // 从其他设备恢复
  // ---------------------------------------------------------------------------

  Future<void> _restoreFromOtherDevice() async {
    setState(() {
      _busy = true;
      _busyLabel = '正在读取云端记录…';
    });
    await CloudPresence.instance.refresh(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    final SyncDocument? doc = CloudPresence.instance.document;
    if (doc == null) {
      _toast(CloudPresence.instance.error ?? '云端还没有可恢复的数据');
      return;
    }
    final Set<String> devices = doc.records.values
        .map((SyncRecord r) => r.deviceId)
        .where((String id) => id.isNotEmpty)
        .toSet();
    final String? scope = await showReadSheet<String>(
      context,
      title: '从其他设备恢复',
      subtitle: '已发现 ${devices.length} 台设备的云端记录。恢复是「合并」：不会删除本机书籍。',
      children: <Widget>[
        SheetMenuItem(
          glyph: ReadGlyph.type,
          title: '仅设置',
          subtitle: '阅读排版 + 界面偏好，云端覆盖本机',
          onTap: () => Navigator.pop(context, 'settings'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.bookmark,
          title: '仅进度',
          subtitle: '只同步各书阅读位置，冲突时以云端为准',
          onTap: () => Navigator.pop(context, 'progress'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.shelf,
          title: '仅书架',
          subtitle: '书籍元数据与标签，不传书文件',
          onTap: () => Navigator.pop(context, 'books'),
        ),
        const SheetSeparator(),
        SheetMenuItem(
          glyph: ReadGlyph.restore,
          title: '全部恢复',
          subtitle: '设置 + 进度 + 书架 + 书签笔记，可选下载书文件',
          onTap: () => Navigator.pop(context, 'all'),
        ),
      ],
    );
    if (scope == null || !mounted) return;
    await _runRestore(scope);
  }

  Future<void> _runRestore(String scope) async {
    setState(() {
      _busy = true;
      _busyLabel = '正在恢复…';
    });
    try {
      final SyncSecrets secrets = await SyncSecrets.load();
      if (secrets.encryptionPassword.length < 12) {
        throw const FormatException('同步加密密码不足 12 位，请先在同步设置里补齐');
      }
      final RemoteObjectStore store =
          SyncBackendFactory.create(SyncConfig.instance, secrets);
      final String targetId = SyncBackendFactory.targetId(SyncConfig.instance);

      String message = '';
      if (scope == 'progress') {
        final ProgressSyncReport report = await ProgressSyncService(LibraryStore.instance).syncStore(
          store,
          secrets.encryptionPassword,
          targetId: targetId,
          resolveConflict: (ProgressSyncConflict conflict) async => ProgressChoice.cloud,
        );
        message = '进度已按云端恢复：扫描 ${report.scanned} 本，'
            '下载 ${report.downloaded} 本，冲突 ${report.conflicts} 处';
      } else {
        final MetadataSyncReport report = await MetadataSyncService().sync(
          store: store,
          encryptionPassword: secrets.encryptionPassword,
          includeBookmarks: scope == 'all',
          includeSettings: scope == 'settings' || scope == 'all',
          includeStats: scope == 'all',
          includeBooks: scope == 'books' || scope == 'all',
          includeFiles: scope == 'all' && SyncConfig.instance.syncFiles,
          downloadMissingFiles: scope == 'all' && SyncConfig.instance.syncFiles,
          targetId: targetId,
          encryptFiles: SyncConfig.instance.encryptFiles,
          allowLegacyPlainFiles: SyncConfig.instance.allowLegacyPlainFiles,
        );
        message = '${report.message}（上传 ${report.uploaded} 条、'
            '下载 ${report.downloaded} 条、冲突 ${report.conflicts} 处）';
      }
      await LibraryStore.instance.init();
      await CloudPresence.instance.refresh(force: true);
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('恢复失败：$error');
    }
  }

  // ---------------------------------------------------------------------------
  // 云端数据对比
  // ---------------------------------------------------------------------------

  Future<void> _openCompare() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CloudComparePage()),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _sectionLabel(ReadPalette palette, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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
              Divider(height: 1, indent: 50, color: palette.outline),
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ReadIcon(glyph,
                  size: 19, color: onTap == null ? palette.outline : palette.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          color: onTap == null ? palette.muted : palette.ink)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11.5, height: 1.45, color: palette.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ReadIcon(ReadGlyph.chevronRight, size: 16, color: palette.outline),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _copy(String text, String message) {
    // 复制用系统剪贴板，不引入额外依赖。
    Clipboard.setData(ClipboardData(text: text));
    _toast(message);
  }
}

/// 本地 vs 云端的差异视图。
class CloudComparePage extends StatefulWidget {
  const CloudComparePage({super.key});

  @override
  State<CloudComparePage> createState() => _CloudComparePageState();
}

enum _Diff { onlyLocal, onlyRemote, differs, same }

class _DiffRow {
  const _DiffRow({
    required this.title,
    required this.localText,
    required this.remoteText,
    required this.state,
    this.book,
  });

  final String title;
  final String localText;
  final String remoteText;
  final _Diff state;
  final Book? book;
}

class _CloudComparePageState extends State<CloudComparePage> {
  bool _loading = true;
  String? _error;
  final Map<String, int> _localBookmarks = <String, int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await CloudPresence.instance.refresh(force: true);
    for (final Book book in LibraryStore.instance.books) {
      _localBookmarks[book.id] = (await BookmarkStore.load(book.id)).length;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = CloudPresence.instance.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final bool ready = SyncConfig.instance.configured;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('云端数据对比'),
        leading: IconButton(
          tooltip: '返回',
          icon: ReadIcon(ReadGlyph.arrowLeft, size: 21, color: palette.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '重新检查',
            icon: ReadIcon(ReadGlyph.refresh, size: 20, color: palette.ink),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: !ready
          ? _notice(palette, '尚未配置云存储，无法比对。请先在「同步 → 云存储」填写 WebDAV 或 S3。')
          : _loading
              ? Center(child: CircularProgressIndicator(color: palette.ink))
              : _buildBody(palette),
    );
  }

  Widget _buildBody(ReadPalette palette) {
    final List<_DiffRow> progress = <_DiffRow>[];
    final List<_DiffRow> bookmarks = <_DiffRow>[];
    final List<_DiffRow> meta = <_DiffRow>[];
    final List<_DiffRow> files = <_DiffRow>[];
    final List<_DiffRow> settings = <_DiffRow>[];

    final CloudPresence presence = CloudPresence.instance;
    final Map<String, String> remoteTitles = presence.remoteTitles;

    for (final Book book in LibraryStore.instance.books) {
      final String hash = book.contentHash ?? '';
      final bool inCloud = hash.isNotEmpty && presence.remoteMetaHashes.contains(hash);
      final int remoteChapter = presence.remoteChapters[hash] ?? 0;
      final int remotePage = presence.remotePages[hash] ?? 0;
      final int localChapter = book.chapterIndex.value;
      final int localPage = book.pageIndex.value;
      final bool samePos = remoteChapter == localChapter && remotePage == localPage;

      progress.add(_DiffRow(
        title: book.title,
        book: book,
        localText: '第 ${localChapter + 1} 章 · 第 ${localPage + 1} 页',
        remoteText: inCloud ? '第 ${remoteChapter + 1} 章 · 第 ${remotePage + 1} 页' : '—',
        state: !inCloud
            ? _Diff.onlyLocal
            : samePos
                ? _Diff.same
                : _Diff.differs,
      ));

      final int localMark = _localBookmarks[book.id] ?? 0;
      final int remoteMark = presence.remoteBookmarkCounts[hash] ?? 0;
      bookmarks.add(_DiffRow(
        title: book.title,
        book: book,
        localText: '$localMark 条',
        remoteText: inCloud ? '$remoteMark 条' : '—',
        state: !inCloud
            ? (localMark > 0 ? _Diff.onlyLocal : _Diff.same)
            : remoteMark == localMark
                ? _Diff.same
                : _Diff.differs,
      ));

      final bool localFile = book.sourcePath != null && File(book.sourcePath!).existsSync();
      final bool remoteFile = hash.isNotEmpty && presence.remoteFileHashes.contains(hash);
      files.add(_DiffRow(
        title: book.title,
        book: book,
        localText: localFile ? '本地有文件' : '本地无文件',
        remoteText: remoteFile ? '云端有文件' : '云端无文件',
        state: remoteFile && localFile
            ? _Diff.same
            : remoteFile
                ? _Diff.onlyRemote
                : localFile
                    ? _Diff.onlyLocal
                    : _Diff.same,
      ));

      meta.add(_DiffRow(
        title: book.title,
        book: book,
        localText: '${book.tags.length} 标签 · ${book.collections.length} 书箱',
        remoteText: inCloud
            ? (remoteTitles[hash] == book.title ? '标题一致' : '云端标题：${remoteTitles[hash]}')
            : '—',
        state: !inCloud
            ? _Diff.onlyLocal
            : remoteTitles[hash] == book.title
                ? _Diff.same
                : _Diff.differs,
      ));
    }

    for (final String hash in presence.remoteMetaHashes) {
      if (LibraryStore.instance.bookByHash(hash) != null) continue;
      final String title = remoteTitles[hash] ?? '云端书籍 ${hash.substring(0, 8)}';
      progress.add(_DiffRow(
        title: title,
        localText: '—',
        remoteText: '第 ${(presence.remoteChapters[hash] ?? 0) + 1} 章',
        state: _Diff.onlyRemote,
      ));
      meta.add(_DiffRow(
        title: title,
        localText: '—',
        remoteText: '云端有元数据，本机无此书',
        state: _Diff.onlyRemote,
      ));
      files.add(_DiffRow(
        title: title,
        localText: '—',
        remoteText: presence.remoteFileHashes.contains(hash) ? '云端有文件' : '云端无文件',
        state: presence.remoteFileHashes.contains(hash) ? _Diff.onlyRemote : _Diff.same,
      ));
    }

    final int localSettingsLen =
        jsonEncode(LibraryStore.instance.sortMode).length + 24;
    settings.add(_DiffRow(
      title: '阅读设置（全局）',
      localText: '本机已配置（$localSettingsLen 字符摘要）',
      remoteText: presence.remoteSettingsAt == null
          ? '—'
          : '云端更新于 ${presence.remoteSettingsAt!.toString().substring(0, 16)}',
      state: presence.remoteSettingsAt == null ? _Diff.onlyLocal : _Diff.same,
    ));

    final int localOnly = <_DiffRow>[...progress, ...bookmarks, ...meta, ...files, ...settings]
        .where((_DiffRow r) => r.state == _Diff.onlyLocal)
        .length;
    final int remoteOnly = <_DiffRow>[...progress, ...bookmarks, ...meta, ...files, ...settings]
        .where((_DiffRow r) => r.state == _Diff.onlyRemote)
        .length;
    final int differs = <_DiffRow>[...progress, ...bookmarks, ...meta, ...files, ...settings]
        .where((_DiffRow r) => r.state == _Diff.differs)
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
        children: <Widget>[
          Row(
            children: <Widget>[
              _stat(palette, '仅本地', localOnly),
              const SizedBox(width: 10),
              _stat(palette, '仅云端', remoteOnly),
              const SizedBox(width: 10),
              _stat(palette, '内容不同', differs),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('最近一次检查出错：$_error',
                  style: TextStyle(fontSize: 11.5, color: palette.muted)),
            ),
          _group(palette, '阅读进度', progress),
          _group(palette, '书签 / 笔记', bookmarks),
          _group(palette, '书架元数据', meta),
          _group(palette, '设置', settings),
          _group(palette, '文件状态', files),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _pushAll(palette),
              icon: ReadIcon(ReadGlyph.cloud, size: 18, color: palette.ink),
              label: const Text('把本机数据推到云端'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.ink,
                side: BorderSide(color: palette.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '对比结果来自云端 metadata.enc 与 files/ 的真实列表。'
            '「内容不同」只表示位置或元数据不一致，不代表哪边更新——恢复前会再确认一次。',
            style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }

  Widget _stat(ReadPalette palette, String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.outline),
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
        ),
        child: Column(
          children: <Widget>[
            Text('$value',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: palette.ink)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: palette.muted)),
          ],
        ),
      ),
    );
  }

  Widget _group(ReadPalette palette, String title, List<_DiffRow> rows) {
    final List<_DiffRow> visible =
        rows.where((_DiffRow r) => r.state != _Diff.same).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(title,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.ink)),
              const SizedBox(width: 8),
              if (visible.isEmpty)
                Text('完全一致',
                    style: TextStyle(fontSize: 11, color: palette.muted))
              else
                Text('${visible.length} 项差异',
                    style: TextStyle(fontSize: 11, color: palette.muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.outline),
                borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
              ),
              child: Text('没有差异',
                  style: TextStyle(fontSize: 12, color: palette.muted)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(color: palette.outline),
                borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < visible.length; i++) ...<Widget>[
                    _diffTile(palette, visible[i]),
                    if (i != visible.length - 1)
                      Divider(height: 1, indent: 14, color: palette.outline),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _diffTile(ReadPalette palette, _DiffRow row) {
    final (String label, Color color) = switch (row.state) {
      _Diff.onlyLocal => ('仅本地', palette.ink),
      _Diff.onlyRemote => ('仅云端', palette.ink),
      _Diff.differs => ('内容不同', palette.ink),
      _Diff.same => ('一致', palette.muted),
    };
    return InkWell(
      onTap: () => _openRow(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: palette.ink)),
                  const SizedBox(height: 3),
                  Text('本机：${row.localText}',
                      style: TextStyle(fontSize: 11.5, color: palette.muted)),
                  Text('云端：${row.remoteText}',
                      style: TextStyle(fontSize: 11.5, color: palette.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: palette.outline),
                borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 20),
              ),
              child: Text(label, style: TextStyle(fontSize: 10.5, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRow(_DiffRow row) async {
    final Book? book = row.book;
    if (book == null) {
      await showReadSheet<void>(
        context,
        title: row.title,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(
              '这本书只在云端存在，本机没有对应文件。'
              '可回到同步页执行「完整同步」并勾选下载书文件后恢复。',
              style: TextStyle(
                  fontSize: 12.5, height: 1.6, color: ReadPalette.of(context).muted),
            ),
          ),
        ],
      );
      return;
    }
    final String? action = await showReadSheet<String>(
      context,
      title: book.title,
      subtitle: '本机：${row.localText}　·　云端：${row.remoteText}',
      children: <Widget>[
        SheetMenuItem(
          glyph: ReadGlyph.download,
          title: '采用云端进度',
          subtitle: '把本机阅读位置改成云端位置',
          onTap: () => Navigator.pop(context, 'pull'),
        ),
        SheetMenuItem(
          glyph: ReadGlyph.cloud,
          title: '把这本书推到云端',
          subtitle: '执行一次完整同步（含元数据与进度）',
          onTap: () => Navigator.pop(context, 'push'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'pull') {
      final String hash = book.contentHash ?? '';
      final int chapter = CloudPresence.instance.remoteChapters[hash] ?? 0;
      final int page = CloudPresence.instance.remotePages[hash] ?? 0;
      await LibraryStore.instance.applySyncedProgress(
        book,
        chapterIndex: chapter,
        pageIndex: page,
        charOffset: -1,
      );
      if (!mounted) return;
      _toast('已采用云端位置：第 ${chapter + 1} 章');
    } else {
      try {
        final MetadataSyncReport? report =
            await AutoSyncService.instance.runFull(downloadMissing: false);
        if (!mounted) return;
        _toast(report?.message ?? '没有需要同步的变化');
        await _load();
      } catch (error) {
        if (!mounted) return;
        _toast('同步失败：$error');
      }
    }
  }

  Future<void> _pushAll(ReadPalette palette) async {
    final bool ok = await confirmAction(
      context,
      title: '推到云端',
      message: '会把本机设置、书架元数据、书签与进度合并到云端。不会删除云端已有的书。',
      confirm: '开始同步',
    );
    if (!ok) return;
    try {
      final MetadataSyncReport? report =
          await AutoSyncService.instance.runFull(downloadMissing: false);
      if (!mounted) return;
      _toast(report?.message ?? '没有需要同步的变化');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _toast('同步失败：$error');
    }
  }

  Widget _notice(ReadPalette palette, String text) => Padding(
        padding: const EdgeInsets.all(28),
        child: Text(text,
            style: TextStyle(fontSize: 13, height: 1.7, color: palette.muted)),
      );

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
