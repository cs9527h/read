import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret synchronization settings. Passwords/keys live in [SecretVault]
/// and are never written to SharedPreferences, logs or sync documents.
class SyncConfig extends ChangeNotifier {
  SyncConfig._();

  static final SyncConfig instance = SyncConfig._();

  static const String _key = 'read.sync.config.v2';
  static const String _deviceKey = 'read.sync.device.v1';

  SharedPreferences? _prefs;

  String provider = 'webdav'; // webdav | s3
  String webdavUrl = '';
  String webdavDirectory = 'Read';
  String webdavUsername = '';
  String s3Endpoint = '';
  String s3Region = 'auto';
  String s3Bucket = '';
  String s3Prefix = 'Read';
  String s3AccessKey = '';

  bool fullAuto = false;
  bool progressAuto = false;
  int progressDebounceSeconds = 8;
  int fullDebounceMinutes = 2;
  int intervalMinutes = 0; // 0 = off
  bool syncOnStart = false;
  bool syncOnBookOpen = false;
  bool syncOnBookClose = false;
  bool syncOnNetwork = true;
  bool wifiOnly = false;
  bool showReaderSyncButton = true;

  bool syncBooks = true;
  bool syncBookmarks = true;
  bool syncReaderSettings = false; // layout is device-specific by default
  bool syncStats = false;
  bool syncFiles = false;

  bool autoJumpProgress = false;
  bool promptCloudProgress = true;
  /// local | cloud | ask. Automatic runs default to local to protect the
  /// position the user is currently reading.
  String conflictPolicy = 'local';

  String lastSyncAt = '';
  String lastSyncStatus = '';
  String lastProgressAt = '';
  String lastError = '';

  bool get configured => provider == 'webdav'
      ? webdavUrl.trim().isNotEmpty && _webdavSecretCached
      : s3Endpoint.trim().isNotEmpty &&
          s3Bucket.trim().isNotEmpty &&
          _s3SecretCached;

  bool _webdavSecretCached = false;
  bool _s3SecretCached = false;

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_deviceKey);
    if (cached != null && cached.length >= 16) return cached;
    final random = Random.secure();
    final value = List<int>.generate(16, (_) => random.nextInt(256))
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (!await prefs.setString(_deviceKey, value)) {
      throw StateError('无法保存本机设备标识');
    }
    return value;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null && raw.length < 64 * 1024) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(raw) as Map<String, dynamic>;
        provider = _string(data['provider'], provider);
        webdavUrl = _string(data['webdavUrl'], webdavUrl);
        webdavDirectory = _string(data['webdavDirectory'], webdavDirectory);
        webdavUsername = _string(data['webdavUsername'], webdavUsername);
        s3Endpoint = _string(data['s3Endpoint'], s3Endpoint);
        s3Region = _string(data['s3Region'], s3Region);
        s3Bucket = _string(data['s3Bucket'], s3Bucket);
        s3Prefix = _string(data['s3Prefix'], s3Prefix);
        s3AccessKey = _string(data['s3AccessKey'], s3AccessKey);
        fullAuto = data['fullAuto'] == true;
        progressAuto = data['progressAuto'] == true;
        progressDebounceSeconds =
            (data['progressDebounceSeconds'] as num?)?.toInt() ?? 8;
        fullDebounceMinutes =
            (data['fullDebounceMinutes'] as num?)?.toInt() ?? 2;
        intervalMinutes = (data['intervalMinutes'] as num?)?.toInt() ?? 0;
        syncOnStart = data['syncOnStart'] == true;
        syncOnBookOpen = data['syncOnBookOpen'] == true;
        syncOnBookClose = data['syncOnBookClose'] == true;
        syncOnNetwork = data['syncOnNetwork'] != false;
        wifiOnly = data['wifiOnly'] == true;
        showReaderSyncButton = data['showReaderSyncButton'] != false;
        syncBooks = data['syncBooks'] != false;
        syncBookmarks = data['syncBookmarks'] != false;
        syncReaderSettings = data['syncReaderSettings'] == true;
        syncStats = data['syncStats'] == true;
        syncFiles = data['syncFiles'] == true;
        autoJumpProgress = data['autoJumpProgress'] == true;
        promptCloudProgress = data['promptCloudProgress'] != false;
        conflictPolicy = _string(data['conflictPolicy'], 'local');
        lastSyncAt = _string(data['lastSyncAt'], '');
        lastSyncStatus = _string(data['lastSyncStatus'], '');
        lastProgressAt = _string(data['lastProgressAt'], '');
        lastError = _string(data['lastError'], '');
      } catch (_) {
        // Corruption must not prevent app launch; defaults remain conservative.
      }
    }
    final vault = SecretVault.instance;
    _webdavSecretCached =
        (await vault.read(SecretVault.webdavPasswordKey)) != null;
    _s3SecretCached = (await vault.read(SecretVault.s3SecretKey)) != null;
    notifyListeners();
  }

  String _string(Object? value, String fallback) =>
      value is String ? value : fallback;

  Future<void> save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final data = <String, Object?>{
      'provider': provider,
      'webdavUrl': webdavUrl,
      'webdavDirectory': webdavDirectory,
      'webdavUsername': webdavUsername,
      's3Endpoint': s3Endpoint,
      's3Region': s3Region,
      's3Bucket': s3Bucket,
      's3Prefix': s3Prefix,
      's3AccessKey': s3AccessKey,
      'fullAuto': fullAuto,
      'progressAuto': progressAuto,
      'progressDebounceSeconds': progressDebounceSeconds,
      'fullDebounceMinutes': fullDebounceMinutes,
      'intervalMinutes': intervalMinutes,
      'syncOnStart': syncOnStart,
      'syncOnBookOpen': syncOnBookOpen,
      'syncOnBookClose': syncOnBookClose,
      'syncOnNetwork': syncOnNetwork,
      'wifiOnly': wifiOnly,
      'showReaderSyncButton': showReaderSyncButton,
      'syncBooks': syncBooks,
      'syncBookmarks': syncBookmarks,
      'syncReaderSettings': syncReaderSettings,
      'syncStats': syncStats,
      'syncFiles': syncFiles,
      'autoJumpProgress': autoJumpProgress,
      'promptCloudProgress': promptCloudProgress,
      'conflictPolicy': conflictPolicy,
      'lastSyncAt': lastSyncAt,
      'lastSyncStatus': lastSyncStatus,
      'lastProgressAt': lastProgressAt,
      'lastError': lastError,
    };
    if (!await prefs.setString(_key, jsonEncode(data))) {
      throw StateError('同步设置保存失败');
    }
    final vault = SecretVault.instance;
    _webdavSecretCached =
        (await vault.read(SecretVault.webdavPasswordKey)) != null;
    _s3SecretCached = (await vault.read(SecretVault.s3SecretKey)) != null;
    notifyListeners();
  }

  Future<void> markSync(String status, {String? error}) async {
    lastSyncAt = DateTime.now().toIso8601String();
    lastSyncStatus = status;
    lastError = error ?? '';
    await save();
  }

  Future<void> markProgress(String status, {String? error}) async {
    lastProgressAt = DateTime.now().toIso8601String();
    lastSyncStatus = status;
    lastError = error ?? '';
    await save();
  }

  /// Safe, non-secret diagnostic dictionary for history/export.
  Map<String, Object?> diagnostics() => <String, Object?>{
        'provider': provider,
        'target': provider == 'webdav' ? webdavUrl : s3Endpoint,
        'directory': provider == 'webdav' ? webdavDirectory : s3Prefix,
        'bucket': s3Bucket,
        'fullAuto': fullAuto,
        'progressAuto': progressAuto,
        'syncFiles': syncFiles,
        'lastSyncAt': lastSyncAt,
        'lastSyncStatus': lastSyncStatus,
        'lastProgressAt': lastProgressAt,
      };
}

/// Password/token vault. The default implementation is Android Keystore /
/// iOS Keychain backed; [MemorySecretVault] is used only in tests.
abstract class SecretVault {
  static SecretVault instance = SecureSecretVault();

  static const String webdavPasswordKey = 'read.sync.webdav.password';
  static const String encryptionKey = 'read.sync.encryption.password';
  static const String s3SecretKey = 'read.sync.s3.secret';

  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSecretVault implements SecretVault {
  SecureSecretVault({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }
}

class MemorySecretVault implements SecretVault {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null || value.isEmpty) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Credentials are loaded into memory right before a network operation.
class SyncSecrets {
  const SyncSecrets({
    this.webdavPassword = '',
    this.encryptionPassword = '',
    this.s3SecretKey = '',
  });

  final String webdavPassword;
  final String encryptionPassword;
  final String s3SecretKey;

  static Future<SyncSecrets> load() async {
    final vault = SecretVault.instance;
    return SyncSecrets(
      webdavPassword: await vault.read(SecretVault.webdavPasswordKey) ?? '',
      encryptionPassword: await vault.read(SecretVault.encryptionKey) ?? '',
      s3SecretKey: await vault.read(SecretVault.s3SecretKey) ?? '',
    );
  }

  Future<void> store({
    String? webdavPassword,
    String? encryptionPassword,
    String? s3SecretKey,
  }) async {
    final vault = SecretVault.instance;
    if (webdavPassword != null) {
      await vault.write(SecretVault.webdavPasswordKey, webdavPassword);
    }
    if (encryptionPassword != null) {
      await vault.write(SecretVault.encryptionKey, encryptionPassword);
    }
    if (s3SecretKey != null) {
      await vault.write(SecretVault.s3SecretKey, s3SecretKey);
    }
  }

  @override
  String toString() => 'SyncSecrets(redacted)';
}
