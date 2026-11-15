import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Encrypts sync metadata before upload; never upload plaintext with this API.
///
/// Per-archive random salt and nonce. PBKDF2-HMAC-SHA256 is used for a user
/// passphrase, AES-256-GCM authenticates data and detects tampering.
/// Passphrases and cloud account passwords are NEVER persisted by this class.
class EncryptedSyncEnvelope {
  static const String format = 'read-sync-aes-gcm-v1';
  static const int iterations = 210000;
  static const int maxCipherBytes = 16 * 1024 * 1024;

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

  static Future<Uint8List> encrypt(String plaintext, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = _cipher.newNonce();
    final key = await _key(password, salt);
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );
    return Uint8List.fromList(utf8.encode(jsonEncode(<String, dynamic>{
      'format': format,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    })));
  }

  static Future<String> decrypt(Uint8List data, String password) async {
    if (data.length > maxCipherBytes) {
      throw const FormatException('同步文件超出安全大小限制');
    }
    late final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      if (envelope['format'] != format) {
        throw const FormatException('不支持的加密同步格式');
      }
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final cipherText = base64Decode(envelope['ciphertext'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      if (salt.length != 16 || nonce.length != 12 || mac.length != 16 ||
          cipherText.length > maxCipherBytes) {
        throw const FormatException('加密同步文件字段损坏');
      }
      final key = await _key(password, salt);
      final plainBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(plainBytes);
    } on SecretBoxAuthenticationError {
      throw const FormatException('同步密码错误或文件被篡改，已拒绝导入');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('加密同步文件损坏或无法解析');
    }
  }
}
