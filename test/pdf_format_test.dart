import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/formats/pdf_format.dart';
void main() {
  test('PDF header read from disk', () async {
    final directory = await Directory.systemTemp.createTemp('read-pdf');
    try {
      final f = File(directory.path + '/example.pdf');
      await f.writeAsBytes(ascii.encode('%PDF-1.7\nbody'));
      await PdfFormat.verifyHeader(f);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('TXT renamed PDF is rejected', () async {
    final directory = await Directory.systemTemp.createTemp('read-pdf');
    try {
      final f = File(directory.path + '/wrong.pdf');
      await f.writeAsString('plain text not PDF');
      await expectLater(PdfFormat.verifyHeader(f), throwsFormatException);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
