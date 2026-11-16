import 'package:flutter/material.dart';

import 'package:read/src/services/diagnostics_service.dart';

/// Diagnostics are local by default. Upload is explicit opt-in to a user-owned
/// HTTPS receiver, never to an undocumented hardcoded address.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  final DiagnosticsService _service = DiagnosticsService.instance;
  late final TextEditingController _endpoint;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController(text: _service.endpoint);
  }

  @override
  void dispose() {
    _endpoint.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _save(bool consent) async {
    setState(() => _busy = true);
    try {
      await _service.configure(
        consent: consent,
        uploadEndpoint: _endpoint.text,
      );
      if (consent) {
        await _service.uploadIfDue(force: true);
      }
      if (mounted) setState(() {});
      _message(consent ? '已开启诊断上传' : '已关闭诊断上传');
    } on FormatException {
      _message('请填写有效的 HTTPS 接收地址');
    } catch (_) {
      _message('保存失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    final ok = await _service.uploadIfDue(force: true);
    if (mounted) setState(() => _busy = false);
    _message(ok ? '诊断已发送' : '未发送：请检查接收地址与网络');
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0C0C0C);
    const fg = Color(0xFFF2F2F2);
    const dim = Color(0xFFB0B0B0);
    final items = _service.events.reversed.take(12).toList();
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('诊断日志'),
        backgroundColor: bg,
        foregroundColor: fg,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          const Text('只记录启动、同步与错误事件。'
              '不收集书籍正文、书名、路径、密码或 API Key。',
              style: TextStyle(color: dim, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _endpoint,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(color: fg),
            decoration: const InputDecoration(
              labelText: 'HTTPS 日志接收地址',
              hintText: 'https://your-server.example/logs',
              hintStyle: TextStyle(color: dim, fontSize: 12),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动上传诊断', style: TextStyle(color: fg)),
            subtitle: const Text('默认关闭；仅上传已脱敏事件',
                style: TextStyle(color: dim, fontSize: 12)),
            value: _service.enabled,
            onChanged: _busy ? null : (value) => _save(value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: _busy ? null : () => _save(_service.enabled),
                child: const Text('保存地址'),
              ),
              OutlinedButton(
                onPressed: _busy || !_service.enabled ? null : _upload,
                child: const Text('立即上传'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await _service.clear();
                        if (mounted) setState(() {});
                        _message('本地日志已清空');
                      },
                child: const Text('清空日志'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('本地事件 · ${_service.events.length} 条',
              style: const TextStyle(color: fg, fontSize: 14)),
          const SizedBox(height: 8),
          for (final event in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                '${event['at']}  ${event['event']}',
                style: const TextStyle(
                  color: dim, fontSize: 11, height: 1.4,
                ),
              ),
            ),
          if (items.isEmpty)
            const Text('暂无日志',
                style: TextStyle(color: dim, fontSize: 12)),
        ],
      ),
    );
  }
}
