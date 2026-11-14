import 'package:flutter/material.dart';

import 'package:read/src/model/book.dart';

/// 阅读页：按测量结果分页，PageView 翻页，字号可调。
/// 当前只做纯文本阅读；格式解析、标注、查词等按阶段接入。
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  double _fontSize = 18;
  List<String> _pages = <String>[];
  bool _paginated = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title, style: const TextStyle(fontSize: 15)),
        actions: <Widget>[
          IconButton(
            tooltip: '缩小字号',
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _changeFont(-1),
          ),
          IconButton(
            tooltip: '放大字号',
            icon: const Icon(Icons.text_increase),
            onPressed: () => _changeFont(1),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!_paginated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _measure(constraints.biggest);
            });
          }
          if (_pages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final controller = PageController(initialPage: widget.book.progress.value);
          return PageView.builder(
            controller: controller,
            itemCount: _pages.length,
            onPageChanged: (int index) => widget.book.progress.value = index,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Text(
                _pages[index],
                style: TextStyle(fontSize: _fontSize, height: 1.7),
              ),
            ),
          );
        },
      ),
    );
  }

  void _changeFont(double delta) {
    final double next = (_fontSize + delta).clamp(12, 32);
    if (next == _fontSize) return;
    setState(() {
      _fontSize = next;
      _paginated = false;
      _pages = <String>[];
    });
  }

  void _measure(Size size) {
    _paginated = true;
    final TextStyle style = TextStyle(fontSize: _fontSize, height: 1.7);
    final double width = size.width - 40;
    final double height = size.height - 32;
    if (width <= 0 || height <= 0) return;
    setState(() {
      _pages = paginate(widget.book.content, style, width, height);
    });
  }
}

/// 逐行累加测量，超过可用高度就换页。
List<String> paginate(
  String text,
  TextStyle style,
  double maxWidth,
  double maxHeight,
) {
  final List<String> pages = <String>[];
  final TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
  final List<String> lines = text.split('\n');
  String current = '';
  for (final String line in lines) {
    final String candidate = current.isEmpty ? line : '$current\n$line';
    painter.text = TextSpan(text: candidate, style: style);
    painter.layout(maxWidth: maxWidth);
    if (painter.height > maxHeight && current.isNotEmpty) {
      pages.add(current);
      current = line;
    } else {
      current = candidate;
    }
  }
  if (current.isNotEmpty) pages.add(current);
  return pages.isEmpty ? <String>[''] : pages;
}
