import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/wifi_transfer_service.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// WiFi 传书：在设备上真的起一个局域网 HTTP 服务，用浏览器上传文件。
///
/// 安全策略（对应用户需求 P0-1）：
/// - 服务默认关闭，必须由用户点「启动」；
/// - 启动后生成 6 位一次性配对码，浏览器必须先配对，上传请求带令牌；
/// - 配对码 10 分钟过期、错误 5 次作废，可随时手动刷新；
/// - 只接受私有网段来源，公网地址直接拒绝；
/// - 单文件 40MB、扩展名白名单、PDF/EPUB 文件头校验；
/// - 同时最多 2 个上传，每 IP 每分钟限速；
/// - 用户可随时停止；默认退到后台即停止服务。
class WifiTransferPage extends StatefulWidget {
  const WifiTransferPage({super.key});

  @override
  State<WifiTransferPage> createState() => _WifiTransferPageState();
}

class _WifiTransferPageState extends State<WifiTransferPage>
    with WidgetsBindingObserver {
  late final WifiTransferService _service;
  StreamSubscription<WifiTransferEvent>? _events;
  Timer? _ticker;
  bool _keepInBackground = false;
  final List<WifiTransferEvent> _log = <WifiTransferEvent>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = WifiTransferService(
      onImport: (File file, String name) async {
        final Book? book = await LibraryStore.instance.importPath(
          file.path,
          displayName: name,
        );
        if (book == null) {
          return WifiImportResult(
            ok: false,
            duplicate: true,
            message: '重复文件，已跳过：$name',
          );
        }
        return WifiImportResult(ok: true, message: '已导入《${book.title}》');
      },
    );
    _service.addListener(_onServiceChanged);
    _events = _service.events.listen((WifiTransferEvent event) {
      if (!mounted) return;
      setState(() {
        if (event.state != 'receiving') {
          final int index = _log.indexWhere(
              (WifiTransferEvent e) => e.fileName == event.fileName && e.state == 'receiving');
          if (index >= 0) _log.removeAt(index);
          _log.insert(0, event);
          if (_log.length > 30) _log.removeLast();
        }
      });
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _service.isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _events?.cancel();
    _service.removeListener(_onServiceChanged);
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // 除非用户显式允许后台传书，否则离开前台立即停止监听。
      _service.onAppPaused(keepRunning: _keepInBackground);
    }
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  String _clock(DateTime? at) {
    final DateTime now = at ?? DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  String _remaining() {
    final DateTime? at = _service.expiresAt;
    if (at == null) return '';
    final int seconds = at.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return '已过期';
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final bool eink = ReadUi.instance.isEink;
    final bool running = _service.isRunning;
    final double radius = eink ? 0 : 16;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('WiFi 传书'),
        leading: IconButton(
          icon: ReadIcon(ReadGlyph.arrowLeft, size: 21, color: palette.ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: <Widget>[
          _card(
            palette,
            radius,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ReadIcon(ReadGlyph.wifi, size: 20, color: palette.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      running ? '传书服务已开启' : '传书服务已关闭',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if (running)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.background,
                        borderRadius: BorderRadius.circular(eink ? 0 : 999),
                      ),
                      child: Text('${_service.activeUploads} 个上传中',
                          style:
                              TextStyle(fontSize: 11, color: palette.muted)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                running
                    ? '在电脑浏览器打开下面的地址，输入配对码后即可上传。'
                    : '服务默认关闭。只有在需要传书时才开启，传完建议立即停止，'
                        '避免局域网内其他设备连接。',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: palette.muted),
              ),
              const SizedBox(height: 14),
              if (!running)
                _primaryButton(
                  palette,
                  radius,
                  icon: ReadGlyph.wifi,
                  label: _service.status == WifiTransferStatus.starting
                      ? '正在启动…'
                      : '启动传书服务',
                  onTap: _service.status == WifiTransferStatus.starting
                      ? null
                      : () async {
                          await _service.start();
                          if (!mounted) return;
                          if (_service.status == WifiTransferStatus.failed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(_service.lastError ?? '启动失败')),
                            );
                          }
                        },
                )
              else ...<Widget>[
                for (final String ip in _service.addresses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: 'http://$ip:${_service.port}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('地址已复制')),
                        );
                      },
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'http://$ip:${_service.port}',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          ReadIcon(ReadGlyph.export,
                              size: 16, color: palette.muted),
                        ],
                      ),
                    ),
                  ),
                if (_service.addresses.isEmpty)
                  Text('没有找到局域网地址，请先连接 WiFi。',
                      style:
                          TextStyle(fontSize: 12.5, color: palette.muted)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(eink ? 0 : 12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('配对码',
                                style: TextStyle(
                                    fontSize: 11.5, color: palette.muted)),
                            const SizedBox(height: 4),
                            Text(
                              _service.pairingCode,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(_remaining(),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures()
                                  ],
                                  color: palette.muted)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              _service.rotateSecrets();
                              setState(() {});
                            },
                            child: Text('刷新',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.ink)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _secondaryButton(
                        palette,
                        radius,
                        label: '停止服务',
                        onTap: () async {
                          await _service.stop();
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
              if (_service.lastError != null && running) ...<Widget>[
                const SizedBox(height: 6),
                Text(_service.lastError!,
                    style: TextStyle(fontSize: 11.5, color: palette.muted)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _keepInBackground,
            onChanged: (bool value) => setState(() => _keepInBackground = value),
            title: Text('退到后台仍保持传书',
                style: TextStyle(fontSize: 13, color: palette.ink)),
            subtitle: Text('关闭后，离开本页或切到后台会立即停止服务。',
                style: TextStyle(fontSize: 11.5, color: palette.muted)),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text('传输记录',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.muted)),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await LibraryStore.instance.init();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('书架已刷新')),
                    );
                  }
                },
                child: const Text('刷新书架'),
              ),
            ],
          ),
          if (_log.isEmpty)
            Text('还没有收到文件',
                style: TextStyle(fontSize: 12.5, color: palette.muted))
          else
            for (final WifiTransferEvent event in _log)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_clock(event.at),
                        style: TextStyle(
                            fontSize: 11.5, color: palette.muted)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event.state == 'imported'
                            ? '${event.fileName} · ${event.message}'
                            : event.state == 'duplicate'
                                ? '${event.fileName} · 重复，已跳过'
                                : event.state == 'rejected'
                                    ? '${event.fileName} · 已拦截：${event.message}'
                                    : '${event.fileName} · ${event.message}',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: event.state == 'imported'
                              ? palette.ink
                              : palette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _card(ReadPalette palette, double radius,
      {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.outline),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _primaryButton(
    ReadPalette palette,
    double radius, {
    required ReadGlyph icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: ReadIcon(icon, size: 18, color: palette.background),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: palette.ink,
          foregroundColor: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _secondaryButton(
    ReadPalette palette,
    double radius, {
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: Text(label),
    );
  }
}
