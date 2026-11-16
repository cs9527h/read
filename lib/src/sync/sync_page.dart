import 'dart:async';

import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/sync/auto_sync_service.dart';
import 'package:read/src/sync/backup_service.dart';
import 'package:read/src/sync/metadata_sync_service.dart';
import 'package:read/src/sync/progress_conflict_store.dart';
import 'package:read/src/sync/progress_history.dart';
import 'package:read/src/sync/progress_models.dart';
import 'package:read/src/sync/progress_sync_service.dart';
import 'package:read/src/sync/remote_store.dart';
import 'package:read/src/sync/sync_config.dart';
import 'package:read/src/sync/sync_history.dart';
import 'package:read/src/theme.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('同步'),
          actions: <Widget>[
            IconButton(
              tooltip: '立即同步',
              onPressed: _busy ? null : _fullSync,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: palette.outline,
            labelColor: palette.ink,
            unselectedLabelColor: palette.muted,
            tabs: const <Widget>[
              Tab(text: '云存储'),
              Tab(text: '同步选项'),
              Tab(text: '备份'),
              Tab(text: '历史'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _StorageTab(onBusyChanged: _setBusy),
            _OptionsTab(onBusyChanged: _setBusy),
            _BackupTab(onBusyChanged: _setBusy),
            const _HistoryTab(),
          ],
        ),
      ),
    );
  }

  void _setBusy(bool value) => setState(() => _busy = value);

  Future<void> _fullSync() async {
    if (!SyncConfig.instance.configured) {
      _toast(context, '请先在“云存储”填写并保存凭据');
      return;
    }
    setState(() => _busy = true);
    try {
      final report = await AutoSyncService.instance.runFull(
        downloadMissing: SyncConfig.instance.syncFiles,
      );
      if (mounted) {
        _toast(context, report?.message ?? '没有需要同步的变化');
        setState(() {});
      }
    } catch (error) {
      if (mounted) _toast(context, '同步失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _StorageTab extends StatefulWidget {
  const _StorageTab({required this.onBusyChanged});
  final ValueChanged<bool> onBusyChanged;

  @override
  State<_StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<_StorageTab> {
  late final TextEditingController _url;
  late final TextEditingController _directory;
  late final TextEditingController _user;
  late final TextEditingController _webdavPassword;
  late final TextEditingController _encryption;
  late final TextEditingController _endpoint;
  late final TextEditingController _region;
  late final TextEditingController _bucket;
  late final TextEditingController _prefix;
  late final TextEditingController _accessKey;
  late final TextEditingController _secretKey;

  SyncConfig get _config => SyncConfig.instance;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: _config.webdavUrl);
    _directory = TextEditingController(text: _config.webdavDirectory);
    _user = TextEditingController(text: _config.webdavUsername);
    _webdavPassword = TextEditingController();
    _encryption = TextEditingController();
    _endpoint = TextEditingController(text: _config.s3Endpoint);
    _region = TextEditingController(text: _config.s3Region);
    _bucket = TextEditingController(text: _config.s3Bucket);
    _prefix = TextEditingController(text: _config.s3Prefix);
    _accessKey = TextEditingController(text: _config.s3AccessKey);
    _secretKey = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _url,
      _directory,
      _user,
      _webdavPassword,
      _encryption,
      _endpoint,
      _region,
      _bucket,
      _prefix,
      _accessKey,
      _secretKey,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _save({bool showMessage = true}) async {
    final webdav = _config.provider == 'webdav';
    if (webdav) {
      final uri = Uri.tryParse(_url.text.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        _toast(context, 'WebDAV 地址必须是 https:// 开头的服务器地址');
        return false;
      }
      if (_user.text.trim().isEmpty) {
        _toast(context, '请填写 WebDAV 用户名');
        return false;
      }
      if (_webdavPassword.text.isEmpty && !_config.configured) {
        _toast(context, '请填写 WebDAV 应用密码');
        return false;
      }
      _config.webdavUrl = _url.text.trim();
      _config.webdavDirectory = _directory.text.trim().isEmpty
          ? 'Read'
          : _directory.text.trim();
      _config.webdavUsername = _user.text.trim();
    } else {
      if (_endpoint.text.trim().isEmpty ||
          _bucket.text.trim().isEmpty ||
          _accessKey.text.trim().isEmpty) {
        _toast(context, '请完整填写 S3 Endpoint、Bucket、Access Key');
        return false;
      }
      if (_secretKey.text.isEmpty && !_config.configured) {
        _toast(context, '请填写 S3 Secret Key');
        return false;
      }
      _config.s3Endpoint = _endpoint.text.trim();
      _config.s3Region = _region.text.trim().isEmpty ? 'auto' : _region.text.trim();
      _config.s3Bucket = _bucket.text.trim();
      _config.s3Prefix = _prefix.text.trim().isEmpty ? 'Read' : _prefix.text.trim();
      _config.s3AccessKey = _accessKey.text.trim();
    }
    if (_encryption.text.isNotEmpty && _encryption.text.length < 12) {
      _toast(context, '同步密码至少 12 个字符');
      return false;
    }

    widget.onBusyChanged(true);
    try {
      await SyncSecrets().store(
        webdavPassword: _webdavPassword.text.isEmpty ? null : _webdavPassword.text,
        encryptionPassword: _encryption.text.isEmpty ? null : _encryption.text,
        s3SecretKey: _secretKey.text.isEmpty ? null : _secretKey.text,
      );
      await _config.save();
      final secrets = await SyncSecrets.load();
      if (secrets.encryptionPassword.isEmpty) {
        _toast(context, '云存储已保存；还请设置至少 12 位同步密码');
        return false;
      }
      if (showMessage) _toast(context, '云存储设置已保存到本机安全存储');
      return true;
    } catch (error) {
      _toast(context, '保存失败：$error');
      return false;
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _test() async {
    if (!await _save(showMessage: false)) return;
    widget.onBusyChanged(true);
    try {
      await AutoSyncService.instance.testConnection();
      if (mounted) {
        setState(() {});
        _toast(context, '连接成功：${_config.provider == 'webdav' ? _config.webdavUrl : _config.s3Endpoint}');
      }
    } catch (error) {
      if (mounted) _toast(context, '连接失败：$error');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final bool webdav = _config.provider == 'webdav';
    final bool hasWebdavSecret = _config.configured && webdav;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _StatusCard(configured: _config.configured),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'webdav', label: Text('WebDAV')),
            ButtonSegment<String>(value: 's3', label: Text('S3 兼容')),
          ],
          selected: <String>{_config.provider},
          onSelectionChanged: (Set<String> value) async {
            setState(() => _config.provider = value.first);
            await _config.save();
          },
        ),
        const SizedBox(height: 10),
        Text(
          webdav
              ? 'WebDAV 兼容：坚果云、Nextcloud、AList、群晖、Infobox 等；填各自 WebDAV 地址即可。'
              : 'S3 兼容：Cloudflare R2、MinIO、Backblaze B2、阿里云 OSS（S3 模式）等。',
          style: TextStyle(color: palette.muted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (webdav) ...<Widget>[
          _field(_url, '服务器地址', hint: 'https://dav.jianguoyun.com/dav/'),
          _field(_user, '账号'),
          _field(_webdavPassword, '应用密码', obscure: true,
              hint: hasWebdavSecret ? '已安全保存，留空不修改' : '不要填写网页登录密码'),
          _field(_directory, '同步目录', hint: 'Read'),
          const SizedBox(height: 8),
          Text('安全说明', style: TextStyle(color: palette.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text('密码保存在 Android Keystore/iOS Keychain；所有同步文件使用 AES-256-GCM 加密后再上传。',
              style: TextStyle(color: palette.muted, fontSize: 12, height: 1.5)),
        ] else ...<Widget>[
          _field(_endpoint, 'S3 Endpoint', hint: 'https://s3.example.com'),
          _field(_region, 'Region', hint: 'auto / us-east-1'),
          _field(_bucket, 'Bucket'),
          _field(_prefix, '前缀目录', hint: 'Read'),
          _field(_accessKey, 'Access Key ID'),
          _field(_secretKey, 'Secret Access Key', obscure: true,
              hint: _config.configured ? '已安全保存，留空不修改' : ''),
          Text('S3 使用 AWS Signature V4、路径式寻址与 If-Match/If-None-Match 条件写入；'
              '兼容 MinIO、R2、B2 等。未实测的厂商不会在界面标为“已验证”。',
              style: TextStyle(color: palette.muted, fontSize: 12, height: 1.5)),
        ],
        const SizedBox(height: 12),
        _field(_encryption, '同步密码（端到端加密）', obscure: true,
            hint: _config.configured ? '已安全保存，留空不修改' : '至少 12 个字符'),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: () => _save(),
                child: const Text('保存设置'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _test,
                child: const Text('测试连接'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('当前状态', style: TextStyle(color: palette.muted, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          _config.lastSyncAt.isEmpty
              ? '尚未同步'
              : '最近：${_formatTime(_config.lastSyncAt)} · ${_config.lastSyncStatus}',
          style: TextStyle(color: palette.ink, fontSize: 13),
        ),
        if (_config.lastError.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(_config.lastError,
              style: TextStyle(color: palette.muted, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

String _formatTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    final config = SyncConfig.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(kEink ? 0 : 12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            configured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: palette.ink,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  configured ? '云端已连接' : '尚未配置云存储',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  config.lastSyncAt.isEmpty
                      ? '所有同步均为真实请求，不会写入演示数据'
                      : '上次同步 ${_formatTime(config.lastSyncAt)} · ${config.lastSyncStatus}',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ],
            ),
          ),
          if (SyncTaskQueue.instance.tasks.isNotEmpty)
            Text(
                '${SyncTaskQueue.instance.tasks.length} 待处理'
                '${SyncTaskQueue.instance.failedTasks.isEmpty ? '' : ' · ${SyncTaskQueue.instance.failedTasks.length} 已失败'}',
                style: TextStyle(color: palette.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _OptionsTab extends StatefulWidget {
  const _OptionsTab({required this.onBusyChanged});
  final ValueChanged<bool> onBusyChanged;

  @override
  State<_OptionsTab> createState() => _OptionsTabState();
}

class _OptionsTabState extends State<_OptionsTab> {
  SyncConfig get _config => SyncConfig.instance;

  @override
  void initState() {
    super.initState();
    ProgressConflictStore.instance.addListener(_onConflictsChanged);
  }

  @override
  void dispose() {
    ProgressConflictStore.instance.removeListener(_onConflictsChanged);
    super.dispose();
  }

  void _onConflictsChanged() {
    if (mounted) setState(() {});
  }

  String _positionLine(PendingProgressConflict conflict, ProgressRecord record) {
    final book = LibraryStore.instance.bookByHash(conflict.bookHash);
    var chapter = '';
    var ratio = '';
    if (record.format == 'PDF') {
      ratio = '第 ${record.page + 1} 页';
    } else if (book != null && book.content.isNotEmpty) {
      final chapters = splitChapters(book.content);
      for (var i = 0; i < chapters.length; i++) {
        if (record.offset >= chapters[i].start && record.offset < chapters[i].end) {
          chapter = chapters[i].title.trim();
          ratio = '${(record.offset / book.content.length * 100).toStringAsFixed(1)}%';
          break;
        }
      }
      ratio = ratio.isEmpty ? '字符 ${record.offset}' : ratio;
    } else {
      ratio = '字符 ${record.offset}';
    }
    final device = record.device.length > 8
        ? '${record.device.substring(0, 8)}…'
        : record.device;
    final time = _formatTime(
      DateTime.fromMillisecondsSinceEpoch(record.updatedAt).toIso8601String(),
    );
    return <String>[if (chapter.isNotEmpty) chapter, ratio, device, time]
        .join(' · ');
  }

  Future<void> _resolveConflict(
    PendingProgressConflict conflict,
    ProgressChoice choice,
  ) async {
    final book = LibraryStore.instance.bookByHash(conflict.bookHash);
    if (book == null) {
      _toast(context, '本机没有这本书，无法合并该冲突；请先导入同一原文件');
      return;
    }
    try {
      await AutoSyncService.instance.runProgress(
        book,
        resolver: (ProgressSyncConflict _) async => choice,
        enqueueOnFailure: true,
      );
      await ProgressConflictStore.instance.remove(conflict.id);
      if (mounted) _toast(context, '冲突已解决并写入云端新修订');
    } catch (error) {
      if (mounted) _toast(context, '解决冲突失败：$error');
    }
  }

  int get _intervalValue {
    const standard = <int>[0, 5, 10, 15, 30, 60, 240, 720];
    if (standard.contains(_config.intervalMinutes)) {
      return _config.intervalMinutes;
    }
    return -2;
  }

  Future<void> _editCustomInterval() async {
    final controller = TextEditingController(
      text: _config.intervalMinutes == 0
          ? '45'
          : _config.intervalMinutes.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('自定义定时间隔'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '分钟（1–10080）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text.trim());
              if (minutes == null || minutes < 1 || minutes > 10080) {
                return;
              }
              Navigator.pop(ctx, minutes);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _update(() async => _config.intervalMinutes = value);
  }

  Future<void> _update(Future<void> Function() change) async {
    widget.onBusyChanged(true);
    try {
      await change();
      await _config.save();
      await AutoSyncService.instance.applyConfigChanged();
      if (mounted) setState(() {});
    } finally {
      widget.onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        _section(palette, '自动同步'),
        _switch('自动同步全量数据', _config.fullAuto,
            (bool v) => _update(() async => _config.fullAuto = v)),
        _switch('自动同步阅读进度', _config.progressAuto,
            (bool v) => _update(() async => _config.progressAuto = v)),
        _slider(
          '进度同步延迟 ${_config.progressDebounceSeconds} 秒',
          _config.progressDebounceSeconds.toDouble(),
          2,
          30,
          divisions: 14,
          onChanged: (double v) =>
              _update(() async => _config.progressDebounceSeconds = v.round()),
        ),
        _slider(
          '全量同步延迟 ${_config.fullDebounceMinutes} 分钟',
          _config.fullDebounceMinutes.toDouble(),
          1,
          30,
          divisions: 29,
          onChanged: (double v) =>
              _update(() async => _config.fullDebounceMinutes = v.round()),
        ),
        ListTile(
          dense: true,
          title: const Text('定时间隔'),
          subtitle: Text(_config.intervalMinutes == 0
              ? '关闭'
              : '每 ${_config.intervalMinutes} 分钟'),
          trailing: DropdownButton<int>(
            value: _intervalValue,
            items: <DropdownMenuItem<int>>[
              const DropdownMenuItem<int>(value: 0, child: Text('关闭')),
              const DropdownMenuItem<int>(value: 5, child: Text('5 分钟')),
              const DropdownMenuItem<int>(value: 10, child: Text('10 分钟')),
              const DropdownMenuItem<int>(value: 15, child: Text('15 分钟')),
              const DropdownMenuItem<int>(value: 30, child: Text('30 分钟')),
              const DropdownMenuItem<int>(value: 60, child: Text('1 小时')),
              const DropdownMenuItem<int>(value: 240, child: Text('4 小时')),
              const DropdownMenuItem<int>(value: 720, child: Text('12 小时')),
              if (_intervalValue == -2)
                DropdownMenuItem<int>(
                  value: -2,
                  child: Text('当前 ${_config.intervalMinutes} 分钟'),
                ),
              const DropdownMenuItem<int>(value: -1, child: Text('自定义…')),
            ],
            onChanged: (int? value) {
              if (value == -1) {
                _editCustomInterval();
              } else if (value != null && value != -2) {
                _update(() async => _config.intervalMinutes = value);
              }
            },
          ),
        ),
        _section(palette, '同步时机'),
        _switch('应用启动时', _config.syncOnStart,
            (bool v) => _update(() async => _config.syncOnStart = v)),
        _switch('打开书籍时', _config.syncOnBookOpen,
            (bool v) => _update(() async => _config.syncOnBookOpen = v)),
        _switch('离开书籍/退到后台时', _config.syncOnBookClose,
            (bool v) => _update(() async => _config.syncOnBookClose = v)),
        _switch('网络恢复时', _config.syncOnNetwork,
            (bool v) => _update(() async => _config.syncOnNetwork = v)),
        _switch('仅 Wi-Fi（图书文件）', _config.wifiOnly,
            (bool v) => _update(() async => _config.wifiOnly = v)),
        _switch('阅读进度允许使用移动网络', _config.progressOnMobile,
            (bool v) => _update(() async => _config.progressOnMobile = v)),
        _section(palette, '同步内容'),
        _switch('书籍元数据（标题、作者、阅读时间）', _config.syncBooks,
            (bool v) => _update(() async => _config.syncBooks = v)),
        _switch('书签', _config.syncBookmarks,
            (bool v) => _update(() async => _config.syncBookmarks = v)),
        _switch('阅读设置、主题、预设', _config.syncReaderSettings,
            (bool v) => _update(() async => _config.syncReaderSettings = v)),
        _switch('阅读统计汇总', _config.syncStats,
            (bool v) => _update(() async => _config.syncStats = v)),
        _switch('书籍原文件（可选，内容哈希寻址）', _config.syncFiles,
            (bool v) => _update(() async => _config.syncFiles = v)),
        _switch('上传前加密图书文件（推荐）', _config.encryptFiles,
            (bool v) => _update(() async => _config.encryptFiles = v)),
        _switch('允许读取旧明文云文件', _config.allowLegacyPlainFiles,
            (bool v) => _update(() async => _config.allowLegacyPlainFiles = v)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '默认使用同步密码对图书文件做 AES-256-GCM 加密，云端对象以 .enc 结尾。'
            '旧版本上传的明文对象不会自动删除；开启“允许读取旧明文”后才会下载，'
            '开启前会拒绝并保留失败记录。',
            style: TextStyle(fontSize: 11, color: palette.muted, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            '排版参数、屏幕方向与字体渲染默认只作用于本设备；开启“阅读设置”只同步全局设置、主题与预设，不覆盖每本书的本地排版。',
            style: TextStyle(fontSize: 11, color: palette.muted, height: 1.5),
          ),
        ),
        _section(palette, '操作偏好'),
        ListTile(
          dense: true,
          title: const Text('进度冲突策略'),
          subtitle: const Text('询问模式会保留双方，不自动覆盖'),
          trailing: DropdownButton<String>(
            value: _config.conflictPolicy,
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'local', child: Text('保留本机')),
              DropdownMenuItem<String>(value: 'cloud', child: Text('采用云端')),
              DropdownMenuItem<String>(value: 'ask', child: Text('询问（保留冲突）')),
            ],
            onChanged: (String? value) =>
                _update(() async => _config.conflictPolicy = value ?? 'local'),
          ),
        ),
        if (ProgressConflictStore.instance.items.isNotEmpty) ...<Widget>[
          _section(palette, '待解决冲突'),
          for (final conflict in ProgressConflictStore.instance.items)
            Card(
              margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('《${conflict.title}》',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('本机：${_positionLine(conflict, conflict.local)}',
                        style: TextStyle(fontSize: 11, color: palette.muted)),
                    Text('云端：${_positionLine(conflict, conflict.remote)}',
                        style: TextStyle(fontSize: 11, color: palette.muted)),
                    const SizedBox(height: 4),
                    Text('自动同步未覆盖任何一方，选择后会生成可持续同步的新修订。',
                        style: TextStyle(fontSize: 11, color: palette.muted)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => _resolveConflict(
                                conflict, ProgressChoice.local),
                            child: const Text('保留本机'),
                          ),
                          TextButton(
                            onPressed: () => _resolveConflict(
                                conflict, ProgressChoice.cloud),
                            child: const Text('采用云端'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        _switch('打开书时自动跳到云端进度', _config.autoJumpProgress,
            (bool v) => _update(() async => _config.autoJumpProgress = v)),
        _switch('发现云端更新时提示', _config.promptCloudProgress,
            (bool v) => _update(() async => _config.promptCloudProgress = v)),
        _switch('阅读页显示同步按钮', _config.showReaderSyncButton,
            (bool v) => _update(() async => _config.showReaderSyncButton = v)),
        _section(palette, '设备与安全'),
        ListTile(
          dense: true,
          leading: const Icon(Icons.devices_other_outlined, size: 20),
          title: const Text('同步目标'),
          subtitle: Text(
            _config.configured
                ? '${_config.provider.toUpperCase()} · ${_config.provider == 'webdav' ? _config.webdavUrl : _config.s3Endpoint}'
                : '未配置云存储',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          trailing: TextButton(
            onPressed: () => _toast(context, '设备标识用于区分同步来源，不包含账号信息'),
            child: const Text('说明'),
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.lock_outline_rounded, size: 20),
          title: const Text('凭据'),
          subtitle: const Text('密码只保存在系统安全存储，不写入备份与日志'),
        ),
      ],
    );
  }

  Widget _section(ReadPalette palette, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
        child: Text(title, style: TextStyle(fontSize: 12, color: palette.muted)),
      );

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        value: value,
        onChanged: onChanged,
      );

  Widget _slider(String title, double value, double min, double max,
      {required int divisions, required ValueChanged<double> onChanged}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(title, style: const TextStyle(fontSize: 13)),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      );
}

class _BackupTab extends StatefulWidget {
  const _BackupTab({required this.onBusyChanged});
  final ValueChanged<bool> onBusyChanged;

  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  final BackupService _service = BackupService();
  List<BackupInfo> _local = <BackupInfo>[];
  List<RemoteEntry> _cloud = <RemoteEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final local = await _service.listLocal();
    if (!mounted) return;
    setState(() => _local = local);
    await _refreshCloud(silent: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshCloud({bool silent = false}) async {
    if (!SyncConfig.instance.configured) return;
    try {
      final secrets = await SyncSecrets.load();
      final store = SyncBackendFactory.create(SyncConfig.instance, secrets);
      final entries = await _service.listCloud(store);
      if (mounted) setState(() => _cloud = entries);
    } catch (error) {
      if (!silent && mounted) _toast(context, '云端备份列表失败：$error');
    }
  }

  Future<void> _create() async {
    widget.onBusyChanged(true);
    try {
      final info = await _service.createBackup();
      await _refresh();
      if (mounted) {
        _toast(context, '备份完成：${info.bytes ~/ 1024}KB');
        setState(() {});
      }
    } catch (error) {
      if (mounted) _toast(context, '备份失败：$error');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _restore(BackupInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('恢复此备份？'),
        content: const Text('恢复前会自动创建“恢复前快照”。现有书籍不会被删除，只补充缺失内容并合并书签/设置。'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('恢复')),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onBusyChanged(true);
    try {
      final report = await _service.restore(info.path);
      await LibraryStore.instance.init();
      if (mounted) {
        _toast(context,
            '恢复完成：新增 ${report.booksRestored} 本，已有 ${report.booksSkipped} 本，书签 ${report.bookmarks} 条');
      }
    } catch (error) {
      if (mounted) _toast(context, '恢复失败：$error');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _uploadCloud() async {
    if (!SyncConfig.instance.configured) {
      _toast(context, '请先配置云存储');
      return;
    }
    widget.onBusyChanged(true);
    try {
      final secrets = await SyncSecrets.load();
      final store = SyncBackendFactory.create(SyncConfig.instance, secrets);
      await _service.uploadCloud(store, secrets.encryptionPassword);
      await _refreshCloud(silent: true);
      if (mounted) _toast(context, '已上传加密备份到云端');
    } catch (error) {
      if (mounted) _toast(context, '上传失败：$error');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _restoreCloud(RemoteEntry entry) async {
    final secrets = await SyncSecrets.load();
    final store = SyncBackendFactory.create(SyncConfig.instance, secrets);
    widget.onBusyChanged(true);
    try {
      final report = await _service.restoreCloud(
        store,
        entry.key,
        secrets.encryptionPassword,
      );
      await LibraryStore.instance.init();
      if (mounted) {
        _toast(context, '云端恢复完成：新增 ${report.booksRestored} 本');
      }
    } catch (error) {
      if (mounted) _toast(context, '云端恢复失败：$error');
    } finally {
      widget.onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('创建本地备份'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploadCloud,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('上传加密备份'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('备份包含书籍文件、书签、阅读设置与统计。恢复采用“先快照、后合并”，不会清空现有书库。',
            style: TextStyle(fontSize: 11, color: palette.muted, height: 1.5)),
        const SizedBox(height: 18),
        Text('本地备份', style: TextStyle(fontSize: 12, color: palette.muted)),
        const SizedBox(height: 6),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_local.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('还没有备份', style: TextStyle(color: palette.muted)),
          )
        else
          for (final info in _local)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.archive_outlined, size: 22),
              title: Text(info.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${_formatTime(info.createdAt.toIso8601String())} · ${info.bytes ~/ 1024}KB'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: '恢复',
                    icon: const Icon(Icons.restore_rounded, size: 20),
                    onPressed: () => _restore(info),
                  ),
                  IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () async {
                      await _service.deleteLocal(info.path);
                      await _refresh();
                    },
                  ),
                ],
              ),
            ),
        const SizedBox(height: 18),
        Text('云端备份', style: TextStyle(fontSize: 12, color: palette.muted)),
        const SizedBox(height: 6),
        if (_cloud.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('没有云端备份（需先配置云存储）', style: TextStyle(color: palette.muted)),
          )
        else
          for (final entry in _cloud)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined, size: 22),
              title: Text(entry.key.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${_formatTime(entry.modifiedAt?.toIso8601String() ?? '')} · ${entry.size ~/ 1024}KB'),
              trailing: IconButton(
                tooltip: '恢复',
                icon: const Icon(Icons.cloud_download_outlined, size: 20),
                onPressed: () => _restoreCloud(entry),
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _refreshCloud(),
          child: const Text('刷新云端备份列表'),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final palette = ReadPalette.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        SyncHistoryStore.instance,
        SyncTaskQueue.instance,
        ProgressHistoryStore.instance,
        LibraryStore.instance,
      ]),
      builder: (BuildContext context, Widget? child) {
        final entries = SyncHistoryStore.instance.entries;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('最近同步记录',
                      style: TextStyle(fontSize: 12, color: palette.muted)),
                ),
                TextButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () => SyncHistoryStore.instance.clear(),
                  child: const Text('清空'),
                ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('暂无记录。执行同步或备份后会写入真实结果。',
                    style: TextStyle(color: palette.muted, fontSize: 13)),
              )
            else
              for (final entry in entries)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border.all(color: palette.outline),
                    borderRadius: BorderRadius.circular(kEink ? 0 : 10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        switch (entry.status) {
                          'success' => Icons.check_circle_outline_rounded,
                          'conflict' => Icons.compare_arrows_rounded,
                          _ => Icons.error_outline_rounded,
                        },
                        size: 18,
                        color: palette.ink,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(_kindLabel(entry.kind),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.ink)),
                                const Spacer(),
                                Text(_formatTime(entry.at.toIso8601String()),
                                    style: TextStyle(fontSize: 11, color: palette.muted)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(entry.message,
                                style: TextStyle(fontSize: 12, color: palette.muted, height: 1.4)),
                            if (entry.errorType.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text('类型：${entry.errorType}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.error)),
                              Text('处理建议：${entry.suggestion}',
                                  style: TextStyle(fontSize: 11, color: palette.muted)),
                            ],
                            if (entry.conflicts > 0) ...<Widget>[
                              const SizedBox(height: 4),
                              Text('冲突 ${entry.conflicts} 条',
                                  style: TextStyle(fontSize: 11, color: palette.muted)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 18),
            Text('云端阅读进度历史', style: TextStyle(fontSize: 12, color: palette.muted)),
            const SizedBox(height: 4),
            Text('仅显示真实从云端收到的设备位置；恢复会写入本机进度，不覆盖云端历史。',
                style: TextStyle(fontSize: 11, color: palette.muted, height: 1.4)),
            const SizedBox(height: 8),
            for (final book in LibraryStore.instance.books.take(12))
              if (book.contentHash != null &&
                  ProgressHistoryStore.instance.forHash(book.contentHash!).isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border.all(color: palette.outline),
                    borderRadius: BorderRadius.circular(kEink ? 0 : 10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.ink)),
                      for (final point in ProgressHistoryStore.instance
                          .forHash(book.contentHash!)
                          .take(3))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded, size: 16),
                          title: Text(
                            point.format == 'PDF'
                                ? '第 ${point.page + 1} 页'
                                : '字符 ${point.offset}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            '${point.device.substring(0, point.device.length.clamp(0, 6))}… · ${_formatTime(point.updatedAt.toIso8601String())}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: TextButton(
                            onPressed: () => _restoreCloudPoint(context, book, point),
                            child: const Text('恢复'),
                          ),
                        ),
                    ],
                  ),
                ),
            if (SyncTaskQueue.instance.tasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('待重试队列', style: TextStyle(fontSize: 12, color: palette.muted)),
              const SizedBox(height: 6),
              for (final task in SyncTaskQueue.instance.tasks)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    task.permanentlyFailed
                        ? Icons.error_outline_rounded
                        : Icons.schedule_rounded,
                    size: 18,
                  ),
                  title: Text(
                    '${_kindLabel(task.kind)} · 第 ${task.attempts} 次'
                    '${task.bookHash.isEmpty ? '' : ' · ${task.bookHash.substring(0, task.bookHash.length.clamp(0, 8))}…'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: task.permanentlyFailed
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    task.permanentlyFailed
                        ? '已持久失败，重试不会自动丢弃：${task.lastError}'
                        : (task.lastError.isEmpty ? '等待网络' : task.lastError),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: task.permanentlyFailed
                      ? TextButton(
                          onPressed: () => SyncTaskQueue.instance.retry(task),
                          child: const Text('重试'),
                        )
                      : Text(
                          _formatTime(task.nextAt.toIso8601String()),
                          style: TextStyle(fontSize: 11, color: palette.muted),
                        ),
                ),
            ],
          ],
        );
      },
    );
  }

  static String _kindLabel(String kind) => switch (kind) {
        'full' => '全量同步',
        'progress' => '阅读进度',
        'backup' => '备份',
        'restore' => '恢复',
        'test' => '连接测试',
        _ => kind,
      };
}



Future<void> _restoreCloudPoint(
  BuildContext context,
  Book book,
  CloudProgressPoint point,
) async {
  try {
    if (book.format.toUpperCase() == 'PDF') {
      await LibraryStore.instance.applySyncedProgress(
        book,
        chapterIndex: 0,
        pageIndex: point.page,
        charOffset: -1,
      );
    } else {
      final chapters = splitChapters(book.content);
      var index = chapters.length - 1;
      for (var i = 0; i < chapters.length; i++) {
        if (point.offset < chapters[i].end) {
          index = i;
          break;
        }
      }
      final chapter = chapters[index];
      await LibraryStore.instance.applySyncedProgress(
        book,
        chapterIndex: index,
        pageIndex: 0,
        charOffset: (point.offset - chapter.start).clamp(0, chapter.length),
      );
    }
    if (context.mounted) {
      _toast(context, '已恢复《${book.title}》的云端位置，下次打开生效');
    }
  } catch (error) {
    if (context.mounted) _toast(context, '恢复失败：$error');
  }
}
