import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';

/// Native PDF page reader; reflow and OCR are not implemented.
class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({super.key, required this.book});
  final Book book;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  @override
  Widget build(BuildContext context) {
    final path = widget.book.sourcePath;
    if (path == null || path.isEmpty) {
      return const Scaffold(body: Center(child: Text('PDF 原文件不存在')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title, overflow: TextOverflow.ellipsis)),
      body: PdfViewer.file(
        path,
        initialPageNumber: widget.book.pageIndex.value + 1,
        params: PdfViewerParams(
          backgroundColor: kEink ? Colors.white : const Color(0xFFEDEDED),
          onPageChanged: (int? pageNumber) {
            if (pageNumber == null || pageNumber < 1) return;
            widget.book.chapterIndex.value = 0;
            widget.book.pageIndex.value = pageNumber - 1;
            widget.book.charOffset.value = -1;
            LibraryStore.instance.saveProgress(widget.book);
          },
        ),
      ),
    );
  }
}
