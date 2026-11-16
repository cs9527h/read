import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/encrypted_file_envelope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'correct horse battery';

  test('图书文件二进制加密往返且带认证头', () async {
    final random = Random(7);
    final plain = Uint8List.fromList(
      List<int>.generate(256 * 1024, (_) => random.nextInt(256)),
    );
    final encrypted = await EncryptedFileEnvelope.encrypt(plain, password);
    expect(encrypted.length, greaterThan(plain.length));
    expect(encrypted.sublist(0, 9), Uint8List.fromList('READFILE1'.codeUnits));
    final restored = await EncryptedFileEnvelope.decrypt(encrypted, password);
    expect(restored, plain);
  });

  test('错误密码和被篡改文件均被拒绝', () async {
    final plain = Uint8List.fromList(List<int>.generate(1024, (i) => i % 251));
    final encrypted = await EncryptedFileEnvelope.encrypt(plain, password);
    expect(
      () => EncryptedFileEnvelope.decrypt(encrypted, 'wrong password 123'),
      throwsA(isA<FormatException>()),
    );
    final tampered = Uint8List.fromList(encrypted);
    tampered[tampered.length - 1] ^= 1;
    expect(
      () => EncryptedFileEnvelope.decrypt(tampered, password),
      throwsA(isA<FormatException>()),
    );
  });
}
