import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:read/src/services/wifi_transfer_service.dart';

void main() {
  final service = WifiTransferService.instance;

  test('multipart 解析保留二进制内容与文件名', () {
    final body = <int>[
      ...utf8.encode('--boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="book.txt"\r\n'
          'Content-Type: text/plain\r\n\r\n'),
      ...utf8.encode('第一章\r\n正文'),
      ...utf8.encode('\r\n--boundary--\r\n'),
    ];
    final files = service.parseMultipartFiles(body, 'boundary');
    expect(files, hasLength(1));
    expect(files.first.name, 'book.txt');
    expect(utf8.decode(files.first.bytes), '第一章\r\n正文');
  });

  test('multipart 支持多个文件并忽略空文件字段', () {
    final body = <int>[
      ...utf8.encode('--b\r\n'
          'Content-Disposition: form-data; name="file"; filename="a.epub"\r\n\r\n'
          'AAA\r\n'
          '--b\r\n'
          'Content-Disposition: form-data; name="file"; filename=""\r\n\r\n'
          '\r\n'
          '--b\r\n'
          'Content-Disposition: form-data; name="file"; filename="../../b.pdf"\r\n\r\n'
          'PDF\r\n'
          '--b--\r\n'),
    ];
    final files = service.parseMultipartFiles(body, 'b');
    expect(files.map((f) => f.name), <String>['a.epub', '../../b.pdf']);
    expect(files.map((f) => utf8.decode(f.bytes)), <String>['AAA', 'PDF']);
  });
}
