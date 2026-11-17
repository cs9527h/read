import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:read/src/bookshelf/cover_search_service.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';
import 'package:read/src/ui/sheet.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 内置浏览器封面搜索：打开图片搜索页，抓取候选图片，点选后自动裁切为 3:4 封面。
///
/// 返回下载并裁切后的临时图片 [File]；调用方负责 adopt 到应用目录并清理。
/// 若 WebView 不可用或抓不到候选，仍可粘贴图片直链。
class CoverSearchPage extends StatefulWidget {
  const CoverSearchPage({super.key, required this.query});

  final String query;

  @override
  State<CoverSearchPage> createState() => _CoverSearchPageState();
}

class _CoverSearchPageState extends State<CoverSearchPage> {
  late final WebViewController _controller;
  bool _webviewReady = false;
  bool _extracting = false;
  bool _busy = false;
  List<String> _candidates = <String>[];
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String _) {
            if (!mounted) return;
            setState(() => _webviewReady = true);
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            setState(() => _error = '网页加载受限：${error.description}。可改用下方「粘贴图片直链」。');
          },
        ),
      )
      ..loadRequest(Uri.parse(CoverSearchService.searchUrl(widget.query)));
  }

  Future<void> _extract() async {
    setState(() {
      _extracting = true;
      _error = null;
    });
    try {
      final String? json = await _controller.runJavaScriptReturningResult(
        CoverSearchService.extractImagesJs,
      ) as String?;
      final List<String> urls = CoverSearchService.parseInjectedCandidates(json ?? '');
      if (!mounted) return;
      setState(() {
        _candidates = urls;
        if (urls.isEmpty) {
          _error = '未能从页面提取到图片直链，可改用下方「粘贴图片直链」。';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '提取失败：$e');
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _useUrl(String url) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final List<int> raw = await CoverSearchService.download(url);
      final cropped = CoverSearchService.cropToCover(
        Uint8List.fromList(raw),
      );
      final File temp = File(
        '${Directory.systemTemp.path}/cover-search-${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temp.writeAsBytes(cropped);
      if (!mounted) return;
      Navigator.of(context).pop(temp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '处理图片失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteUrl() async {
    final String? url = await promptText(
      context,
      title: '粘贴图片直链',
      hint: 'https://…/cover.jpg',
      confirm: '使用',
      helper: '可复制搜索页里任意封面图片的地址；支持 jpg/png/webp。',
    );
    if (url == null || url.trim().isEmpty) return;
    final List<String> urls = CoverSearchService.extractImageUrls(url.trim());
    if (urls.isEmpty) {
      if (!mounted) return;
      setState(() => _error = '这不是有效的图片直链');
      return;
    }
    await _useUrl(urls.first);
  }

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索书籍封面'),
        actions: <Widget>[
          IconButton(
            tooltip: '提取本页图片',
            onPressed: _webviewReady && !_extracting ? _extract : null,
            icon: const Icon(Icons.image_search),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Text(
                  '在下方浏览器里搜索「$widget.query 封面」，点右上角按钮提取页面图片；也可直接粘贴图片直链。',
                  style: TextStyle(color: palette.muted, fontSize: 12, height: 1.4),
                ),
              ),
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),
            ],
          ),
          if (_candidates.isNotEmpty)
            _buildCandidates(palette),
          if (_extracting || _busy)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _pasteUrl,
            icon: const Icon(Icons.link),
            label: const Text('粘贴图片直链'),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidates(ReadPalette palette) {
    return Positioned.fill(
      child: Container(
        color: palette.background,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('本页图片（${_candidates.length}）',
                        style: TextStyle(
                            color: palette.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _candidates = <String>[]),
                    child: const Text('返回浏览器'),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_error!,
                    style: TextStyle(color: palette.muted, fontSize: 12)),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _candidates.length,
                itemBuilder: (BuildContext ctx, int i) {
                  final String url = _candidates[i];
                  return GestureDetector(
                    onTap: _busy ? null : () => _useUrl(url),
                    child: ClipRRect(
                      borderRadius: ReadUi.instance.isEink
                          ? BorderRadius.zero
                          : BorderRadius.circular(8),
                      child: Container(
                        color: palette.surface,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: ReadIcon(ReadGlyph.image,
                                size: 28, color: palette.muted),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
