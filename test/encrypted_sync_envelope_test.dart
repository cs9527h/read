import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/encrypted_sync_envelope.dart';

void main() {
  test('AES-GCM sync payload decrypts with the correct password', () async {
    final secret = await EncryptedSyncEnvelope.encrypt(
      jsonEncode(<String, dynamic>{'book': '中文书名', 'offset': 1234}),
      'my-long-local-passphrase-123',
    );
    expect(utf8.decode(secret), isNot(contains('中文书名')));
    final data = await EncryptedSyncEnvelope.decrypt(
      secret, 'my-long-local-passphrase-123');
    expect(jsonDecode(data)['offset'], 1234);
  });

  test('Wrong password does not reveal book metadata', () async {
    final secret = await EncryptedSyncEnvelope.encrypt(
        'private-book-data', 'correct-long-passphrase');
    await expectLater(
      EncryptedSyncEnvelope.decrypt(secret, 'incorrect-long-password'),
      throwsFormatException,
    );
  });

  test('Tampered ciphertext fails authentication', () async {
    final secret = await EncryptedSyncEnvelope.encrypt(
        'private-book-data', 'correct-long-passphrase');
    final record = jsonDecode(utf8.decode(secret)) as Map<String, dynamic>;
    final bytes = base64Decode(record['ciphertext'] as String);
    bytes[0] ^= 0x40;
    record['ciphertext'] = base64Encode(bytes);
    await expectLater(
      EncryptedSyncEnvelope.decrypt(
        Uint8List.fromList(utf8.encode(jsonEncode(record))),
        'correct-long-passphrase',
      ),
      throwsFormatException,
    );
  });
}
