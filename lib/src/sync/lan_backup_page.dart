import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/theme.dart';
import 'package:read/src/sync/backup_service.dart';
import 'package:read/src/sync/lan_backup_client.dart';
import 'package:read/src/sync/lan_backup_service.dart';

/// 局域网备份直传：同一 WiFi 下两台设备之间直接传全量备份，无需密码、无需云。
/// - 「共享本机」：开一个仅私有网段可访问的服务，把本机备份暴露给对端下载；
/// - 「从对端恢复」：输入对端显示的地址，选一个备份，预览逐本书后勾选恢复。
class LanBackupPage extends StatefulWidget {
  const LanBackupPage({super.key});

  @override
  State<LanBackupPage> createState() => _LanBackupPageState();
}

class _LanBackupPageState extends State<LanBackupPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final LanBackupService _service;
  final BackupService _backup = BackupService();
  final LanBackupClient _client = LanBackupClient();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 2, vsync: this);
    _service = LanBackupService(deviceName: 'Read 设备');
    _service.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _service.onAppPaused();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('局域网备份'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: palette.ink,
          unselectedLabelColor: palette.muted,
          indicatorColor: palette.accent,
          tabs: const <Widget>[
            Tab(text: '共享本机备份'),
            Tab(text: '从对端恢复'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _ShareTab(service: _service, backup: _backup),
          _RestoreTab(client: _client, backup: _backup),
        ],
      ),
    );
  }
}

/// 共享本机备份：启动服务并把地址展示给对端。
class _ShareTab extends StatefulWidget {
  const _ShareTab({required this.service, required this.backup});
  final LanBackupService service;
  final BackupService backup;

  @override
  State<_ShareTab> createState() => _ShareTabState();
}

class _ShareTabState extends State<_ShareTab> {
  List<BackupInfo> _backups = <BackupInfo>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.service.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    try {
      final list = await widget.backup.listLocal();
      if (mounted) setState(() => _backups = list);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    setState(() => _error = null);
    try {
      if (widget.service.isRunning) {
        await widget.service.stop();
      } else {
        await widget.service.start();
        await _refresh();
        if (widget.service.lastError.isNotEmpty) {
          setState(() => _error = widget.service.lastError);
        }
      }
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final running = widget.service.isRunning;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          '开启后，同一 WiFi 下的另一台设备可在「从对端恢复」里输入下面的地址，'
          '直接下载你的备份。无需密码，仅局域网内可访问，退回后台自动停止。',
          style: TextStyle(color: palette.muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _toggle,
          icon: Icon(running ? Icons.stop_rounded : Icons.wifi_tethering_rounded),
          label: Text(running ? '停止共享' : '开启共享'),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ],
        if (running) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(palette, '在对端输入这些地址'),
          for (final address in widget.service.addresses)
            _AddressRow(palette: palette, address: 'http://$address:${widget.service.port}'),
          const SizedBox(height: 8),
          Text(
            '若列表为空，请确认两台设备连的是同一个 WiFi；也可在对端直接输入本机局域网 IP。',
            style: TextStyle(color: palette.muted, fontSize: 11, height: 1.5),
          ),
        ],
        const SizedBox(height: 20),
        _SectionTitle(palette, '本机可共享的备份（${_backups.length}）'),
        if (_backups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('还没有备份，请先在「备份」页创建。',
                style: TextStyle(color: palette.muted, fontSize: 12)),
          ),
        for (final item in _backups)
          ListTile(
            dense: true,
            leading: Icon(Icons.archive_outlined, color: palette.muted, size: 20),
            title: Text(item.name, style: TextStyle(color: palette.ink, fontSize: 13)),
            subtitle: Text(
              '${(item.bytes / 1024 / 1024).toStringAsFixed(1)} MB · '
              '${item.createdAt.toLocal().toString().substring(0, 16)}',
              style: TextStyle(color: palette.muted, fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.palette, required this.address});
  final ReadPalette palette;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(address,
                style: TextStyle(color: palette.ink, fontSize: 13, fontFamily: 'monospace')),
          ),
          IconButton(
            tooltip: '复制',
            icon: Icon(Icons.copy_all_outlined, color: palette.muted, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: address));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('地址已复制')));
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 从对端恢复：输入地址 → 选备份 → 预览逐本书 → 勾选恢复。
class _RestoreTab extends StatefulWidget {
  const _RestoreTab({required this.client, required this.backup});
  final LanBackupClient client;
  final BackupService backup;

  @override
  State<_RestoreTab> createState() => _RestoreTabState();
}

class _RestoreTabState extends State<_RestoreTab> {
  final TextEditingController _address = TextEditingController();
  Uri? _base;
  List<Map<String, Object?>> _backups = <Map<String, Object?>>[];
  String? _device;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final Uri? base = LanBackupClient.normalizeBase(_address.text);
    if (base == null) {
      setState(() => _error = '地址格式不正确，例如 192.168.1.5:8769');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await widget.client.info(base);
      final backups = await widget.client.listBackups(base);
      if (!mounted) return;
      setState(() {
        _base = base;
        _device = info['device'] as String?;
        _backups = backups;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickBackup(Map<String, Object?> item) async {
    final String name = item['name'] as String;
    final Uri? base = _base;
    if (base == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? downloaded;
    try {
      downloaded = await widget.client.downloadBackup(base, name);
      final preview = await widget.backup.previewRestore(downloaded);
      if (!mounted) return;
      final bool? go = await showDialog<bool>(
        context: context,
        builder: (ctx) => _PreviewDialog(
          preview: preview,
          fileName: name,
          onRestore: (Set<String>? hashes) async {
            final report = await widget.backup.restore(
              downloaded!,
              selection: RestoreSelection(hashes: hashes),
            );
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              _toast('已恢复 ${report.booksRestored} 本'
                  '${report.complete ? '' : '（部分未成功）'}');
            }
          },
        ),
      );
      if (go == false) {}
    } catch (e) {
      if (mounted) setState(() => _error = '恢复失败：$e');
    } finally {
      if (downloaded != null) {
        try {
          final file = File(downloaded);
          if (await file.exists()) await file.parent.delete(recursive: true);
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          '在对端「共享本机备份」页复制地址，粘贴到下方连接。'
          '连接后选择备份，可只勾选需要的书恢复，不会删除本机现有数据。',
          style: TextStyle(color: palette.muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _address,
                decoration: InputDecoration(
                  hintText: '192.168.1.5:8769',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixIcon: Icon(Icons.link_rounded, color: palette.muted, size: 18),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _connect(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: const Text('连接'),
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ],
        if (_device != null) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(palette, '已连接：$_device · 选择备份'),
          for (final item in _backups)
            ListTile(
              dense: true,
              leading: Icon(Icons.archive_outlined, color: palette.accent, size: 20),
              title: Text(item['name'] as String,
                  style: TextStyle(color: palette.ink, fontSize: 13)),
              subtitle: Text(
                '${((item['size'] as num) / 1024 / 1024).toStringAsFixed(1)} MB',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
              trailing: Icon(Icons.restore_rounded, color: palette.muted, size: 18),
              onTap: _busy ? null : () => _pickBackup(item),
            ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.palette, this.text);
  final ReadPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(color: palette.ink, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

/// 逐本书预览 + 勾选恢复。默认全选；明确告知只增不删。
class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({
    required this.preview,
    required this.fileName,
    required this.onRestore,
  });
  final BackupPreview preview;
  final String fileName;
  final Future<void> Function(Set<String>? hashes) onRestore;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <String>{
      for (final book in widget.preview.manifest.books)
        if (book.complete) book.hash,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final books = widget.preview.manifest.books;
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text('恢复 ${widget.fileName}',
          style: TextStyle(color: palette.ink, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('只勾选的书会被恢复，不会删除本机现有书籍。',
                style: TextStyle(color: palette.muted, fontSize: 12, height: 1.5)),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: books.length,
                itemBuilder: (BuildContext context, int index) {
                  final book = books[index];
                  return CheckboxListTile(
                    dense: true,
                    value: _selected.contains(book.hash),
                    onChanged: book.complete
                        ? (bool? v) => setState(() {
                              if (v == true) {
                                _selected.add(book.hash);
                              } else {
                                _selected.remove(book.hash);
                              }
                            })
                        : null,
                    title: Text(book.title.isEmpty ? book.fileName : book.title,
                        style: TextStyle(color: palette.ink, fontSize: 13)),
                    subtitle: book.complete
                        ? null
                        : Text('仅元数据：${book.reason}',
                            style: TextStyle(color: palette.muted, fontSize: 11)),
                    activeColor: palette.accent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () async => widget.onRestore(Set<String>.from(_selected)),
          child: Text('恢复 ${_selected.length} 本'),
        ),
      ],
    );
  }
}
