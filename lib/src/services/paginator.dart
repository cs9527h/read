import 'package:flutter/material.dart';

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
