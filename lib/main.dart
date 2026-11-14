import 'package:flutter/material.dart';

import 'package:read/src/bookshelf/bookshelf_page.dart';
import 'package:read/src/theme.dart';

void main() {
  runApp(const ReadApp());
}

class ReadApp extends StatelessWidget {
  const ReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'read',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const BookshelfPage(),
    );
  }
}
