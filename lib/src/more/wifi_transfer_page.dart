import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// WiFi 传书：在设备上真的起一个 HTTP 服务，同一局域网内的电脑/手机
/// 用浏览器打开地址就能上传文件。不是"演示按钮"。
///
/// 限制（会在界面上写明）：
/// - 设备与发送端必须在同一局域网；
/// - 部分系统会拦截入站连接，需要用户允许；
/// - 单文件上限 40MB（与阅读器解析上限一致）。
class WifiTransferPage extends StatefulWidget {
  const WifiTransferPage({super.key});

  @override
  State<WifiTransferPage> createState() => _WifiTransferPageState();
}

class _WifiTransferPageState extends State<WifiTransferPage> {
  HttpServer? _server;
  int _port = 8765;
  List<String> _addresses = <String>[];
  String? _error;
  bool _starting = false;
  final List<String> _log = <String>[];

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    HttpServer? server;
    for (int port = 8765; port < 8775; port++) {
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: false);
        _port = port;
        break;
      } on SocketException {
        continue;
      }
    }
    if (server == null) {
      setState(() {
        _starting = false;
        _error = '端口 8765–8774 都被占用，无法启动传书服务';
      });
      return;
    }
    _server = server;
    server.listen(_handle, onError: (Object error) {
      if (mounted) setState(() => _error = '$error');
    });
    final List<String> addresses = <String>[];
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          if (address.isLoopback) continue;
          addresses.add(address.address);
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _starting = false;
      _addresses = addresses;
    });
  }

  Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    try {
      if (request.method == 'GET' && (request.uri.path == '/' || request.uri.path.isEmpty)) {
        response.headers.contentType =
            ContentType('text', 'html', charset: 'utf-8');
        response.write(_page());
        await response.close();
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/upload') {
        final String rawName = request.uri.queryParameters['name'] ?? 'upload.txt';
        final String name = Uri.decodeComponent(rawName);
        final int declared = request.contentLength;
        if (declared > 40 * 1024 * 1024) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          response.write('文件超过 40MB');
          await response.close();
          return;
        }
        final Directory temp = Directory.systemTemp;
        final File target = File(
          '${temp.path}/wifi-${DateTime.now().microsecondsSinceEpoch}-'
          '${name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}',
        );
        final IOSink sink = target.openWrite();
        int received = 0;
        await for (final List<int> chunk in request) {
          received += chunk.length;
          if (received > 40 * 1024 * 1024) {
            await sink.close();
            await target.delete();
            response.statusCode = HttpStatus.requestEntityTooLarge;
            response.write('文件超过 40MB');
            await response.close();
            return;
          }
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();

        String message;
        int status = HttpStatus.ok;
        try {
          final Book? book = await LibraryStore.instance.importPath(
            target.path,
            displayName: name,
          );
          if (book == null) {
            message = '重复文件，已跳过：$name';
          } else {
            message = '已导入《${book.title}》';
            if (mounted) {
              setState(() {
                _log.insert(0, '${_time()} · $message');
              });
            }
          }
        } catch (error) {
          status = HttpStatus.badRequest;
          message = '导入失败：$error';
        } finally {
          if (await target.exists()) await target.delete();
        }
        response.statusCode = status;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(<String, Object?>{
          'ok': status == HttpStatus.ok,
          'message': message,
        }));
        await response.close();
        return;
      }
      response.statusCode = HttpStatus.notFound;
      await response.close();
    } catch (error) {
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.write('$error');
        await response.close();
      } catch (_) {}
    }
  }

  String _time() {
    final DateTime now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _page() => '''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Read · WiFi 传书</title>
<style>
  :root{--ink:#1a1a18;--muted:#77726a;--line:#e7e1d6;--bg:#faf8f4}
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
       background:var(--bg);color:var(--ink);font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif}
  .card{width:min(92vw,440px);background:#fff;border:1px solid var(--line);border-radius:18px;padding:26px}
  h1{font-size:20px;margin:0 0 6px}
  p{font-size:13px;line-height:1.7;color:var(--muted);margin:0 0 16px}
  .drop{border:1.5px dashed var(--line);border-radius:14px;padding:28px 16px;text-align:center;
        color:var(--muted);font-size:13px;cursor:pointer}
  .drop.hover{border-color:var(--ink);color:var(--ink)}
  input{display:none}
  .log{margin-top:16px;font-size:12px;color:var(--muted);white-space:pre-wrap;min-height:18px}
  .ok{color:#2f6b4f}
  .err{color:#b4423a}
</style></head>
<body><div class="card">
  <h1>传到 Read</h1>
  <p>支持 TXT / EPUB（文字版）/ PDF / Markdown / HTML，单文件不超过 40MB。传完后回到 App，书架会自动刷新。</p>
  <div class="drop" id="drop">点击选择文件，或把文件拖到这里<input type="file" id="file" multiple /></div>
  <div class="log" id="log"></div>
</div>
<script>
const drop=document.getElementById('drop'),file=document.getElementById('file'),log=document.getElementById('log');
drop.onclick=()=>file.click();
['dragenter','dragover'].forEach(e=>drop.addEventListener(e,ev=>{ev.preventDefault();drop.classList.add('hover')}));
['dragleave','drop'].forEach(e=>drop.addEventListener(e,ev=>{ev.preventDefault();drop.classList.remove('hover')}));
drop.addEventListener('drop',ev=>upload(ev.dataTransfer.files));
file.addEventListener('change',()=>upload(file.files));
async function upload(files){
  for(const f of files){
    log.textContent='正在上传 '+f.name+' …';
    try{
      const r=await fetch('/upload?name='+encodeURIComponent(f.name),{method:'POST',body:f});
      const j=await r.json();
      log.className='log '+(j.ok?'ok':'err');
      log.textContent=j.message;
    }catch(e){log.className='log err';log.textContent='上传失败：'+e;}
  }
}
</script></body></html>''';

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final bool eink = ReadUi.instance.isEink;
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.outline),
              borderRadius: BorderRadius.circular(eink ? 0 : 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ReadIcon(ReadGlyph.wifi, size: 20, color: palette.ink),
                    const SizedBox(width: 10),
                    Text('在电脑浏览器打开',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.ink)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_starting)
                  Text('正在启动服务…',
                      style: TextStyle(fontSize: 13, color: palette.muted))
                else if (_addresses.isEmpty)
                  Text(
                    _error ?? '没有找到局域网地址。请先连接 WiFi，再重新进入本页。',
                    style: TextStyle(fontSize: 13, height: 1.6, color: palette.muted),
                  )
                else
                  for (final String ip in _addresses)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: 'http://$ip:$_port'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('地址已复制')),
                          );
                        },
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'http://$ip:$_port',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                            ReadIcon(ReadGlyph.export, size: 16, color: palette.muted),
                          ],
                        ),
                      ),
                    ),
                if (_error != null && _addresses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(_error!, style: TextStyle(fontSize: 11.5, color: palette.muted)),
                ],
                const SizedBox(height: 4),
                Text(
                  '设备与发送端需在同一局域网；部分系统会弹窗询问是否允许入站连接，需要点允许。',
                  style: TextStyle(fontSize: 11.5, height: 1.6, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
            for (final String line in _log)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line,
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: palette.ink)),
              ),
        ],
      ),
    );
  }
}
