import 'package:flutter/material.dart';

import '../services/library_store.dart';
import 'progress_models.dart';
import 'progress_sync_service.dart';
import 'webdav_encrypted_object.dart';

/// Explicit opt-in, metadata-only sync. Cloud and encryption passwords are
/// never persisted; entering credentials alone makes no network request.
class ProgressSyncPage extends StatefulWidget {
  const ProgressSyncPage({super.key});

  @override
  State<ProgressSyncPage> createState() => _ProgressSyncPageState();
}

class _ProgressSyncPageState extends State<ProgressSyncPage> {
  final _url = TextEditingController(
    text: 'https://dav.jianguoyun.com/dav/read-progress-v1.enc',
  );
  final _username = TextEditingController();
  final _webdavPassword = TextEditingController();
  final _encryptionPassword = TextEditingController();
  bool _busy = false;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _webdavPassword.dispose();
    _encryptionPassword.dispose();
    super.dispose();
  }

  Future<ProgressChoice?> _choose(ProgressSyncConflict conflict) {
    if (!mounted) return Future<ProgressChoice?>.value(null);
    final local = conflict.local;
    final remote = conflict.remote;
    String position(ProgressRecord record) => record.format == 'PDF'
        ? '第 ' + (record.page + 1).toString() + ' 页'
        : '字符位置 ' + (record.offset + 1).toString();
    return showDialog<ProgressChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('发现阅读进度冲突'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('《' + conflict.title + '》'),
            const SizedBox(height: 16),
            Text('本机：' + position(local)),
            Text('云端：' + position(remote)),
            const SizedBox(height: 12),
            const Text('两台设备都可能修改了进度。请选择保留哪一个位置，不会删除电子书。'),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消本次同步'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, ProgressChoice.local),
            child: const Text('使用本机'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ProgressChoice.cloud),
            child: const Text('使用云端'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync() async {
    if (_busy) return;
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      setState(() => _error = '请输入不含密码、查询参数的 HTTPS WebDAV 文件地址');
      return;
    }
    if (_username.text.isEmpty || _webdavPassword.text.isEmpty ||
        _encryptionPassword.text.length < 12) {
      setState(() => _error = '请填写账号、WebDAV 应用密码和至少 12 位的独立加密密码');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final report = await ProgressSyncService(LibraryStore.instance).sync(
        ProgressSyncCredentials(
          fileUrl: uri,
          username: _username.text,
          webdavPassword: _webdavPassword.text,
          encryptionPassword: _encryptionPassword.text,
        ),
        resolveConflict: _choose,
      );
      if (!mounted) return;
      setState(() {
        _result = '同步完成：检查 ' + report.scanned.toString() +
            ' 本，提交 ' + report.uploaded.toString() +
            ' 项，恢复 ' + report.downloaded.toString() +
            ' 项，处理冲突 ' + report.conflicts.toString() +
            ' 项。云端另有 ' + report.unmatched.toString() +
            ' 本尚未在此设备导入相同文件。';
      });
    } on ProgressSyncCancelled {
      if (mounted) setState(() => _result = '已取消：未上传或改写本机阅读进度');
    } on WebDavSyncException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            '同步未完成。请检查网络、权限与远端文件；本机原始电子书不会被删除。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebDAV · 阅读进度')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: <Widget>[
                Text('把阅读位置带到另一台设备',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text('手动、端到端加密的阅读进度同步。先在每台设备导入相同的原始电子书文件，再使用同一个云端文件地址与加密密码。'),
                const SizedBox(height: 20),
                TextField(
                  controller: _url,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 云端文件地址（HTTPS）',
                    helperText: '目录需已存在，文件可由首次同步创建',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _username,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'WebDAV 用户名'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _webdavPassword,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 应用密码',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _encryptionPassword,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '独立加密密码（至少 12 位）',
                    helperText: '两台设备必须一致；丢失后无法解密云端记录',
                  ),
                ),
                const SizedBox(height: 20),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  )),
                ],
                if (_result != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_result!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('立即同步阅读进度'),
                ),
                const SizedBox(height: 20),
                const Text(
                  '当前版本仅同步阅读进度元数据，不上传书籍文件、书签、笔记或阅读设置。'
                  '不自动连接服务器，不保存 WebDAV 密码或加密密码。'
                  '同一原始文件才会匹配；旧版仅保存页码的文本进度暂不上传。'
                  '网络中断、云端发生并发更新或密码不匹配时，会停止同步而不是强制覆盖。',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
