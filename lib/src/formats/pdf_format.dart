import 'dart:io';
import 'dart:convert';

/// Checks a local PDF signature without loading the entire file.
class PdfFormat {
  static const int maxFileBytes = 512 * 1024 * 1024;
  static Future<void> verifyHeader(File file) async {
    final int size = await file.length();
    if (size < 8) throw const FormatException('PDF 文件太小或损坏');
    if (size > maxFileBytes) throw const FormatException('PDF 超过 512 MB 限制');
    final RandomAccessFile f = await file.open();
    try {
      final bytes = await f.read(8);
      if (bytes.length < 5 || ascii.decode(bytes.sublist(0, 5)) != '%PDF-') {
        throw const FormatException('文件没有 PDF 标识，不可按 PDF 打开');
      }
    } finally {
      await f.close();
    }
  }
}
