import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Binary, authenticated encryption for original book files.
///
/// Layout: `READFILE1` (9 bytes) | salt (16) | nonce (12) | mac (16) | ciphertext.
/// AES-256-GCM rejects tampering; PBKDF2-HMAC-SHA256 derives the key from the
/// user's sync password. Passwords are never persisted by this class.
class EncryptedFileEnvelope {
  static const String magic = 'READFILE1';
  static const int maxPlainBytes = 48 * 1024 * 1024;
  static const int iterations = 210000;

  static final AesGcm _cipher = AesGcm.with256bits();
  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  static Future<SecretKey> _key(String password, List<int> salt) {
    if (password.length < 12) {
      throw const FormatException('同步密码至少需要 12 个字符');
    }
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static Future<Uint8List> encrypt(Uint8List plain, String password) async {
    if (plain.isEmpty) throw const FormatException('不能加密空文件');
    if (plain.length > maxPlainBytes) {
      throw const FormatException('图书文件超过 48MB 加密上限');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = _cipher.newNonce();
    final key = await _key(password, salt);
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );
    final out = BytesBuilder(copy: false);
    out.add(utf8.encode(magic));
    out.add(salt);
    out.add(nonce);
    out.add(box.mac.bytes);
    out.add(box.cipherText);
    return out.takeBytes();
  }

  static Future<Uint8List> decrypt(Uint8List data, String password) async {
    const header = 9 + 16 + 12 + 16;
    if (data.length <= header) {
      throw const FormatException('加密图书文件过短或已损坏');
    }
    if (utf8.decode(data.sublist(0, 9), allowMalformed: true) != magic) {
      throw const FormatException('不是 Read 加密图书文件');
    }
    final salt = data.sublist(9, 25);
    final nonce = data.sublist(25, 37);
    final mac = data.sublist(37, 53);
    final cipherText = data.sublist(53);
    if (cipherText.length > maxPlainBytes) {
      throw const FormatException('加密图书文件超过安全上限');
    }
    try {
      final key = await _key(password, salt);
      final plain = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const FormatException('同步密码错误或图书文件被篡改，已拒绝导入');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('加密图书文件损坏或无法解密');
    }
  }
}
