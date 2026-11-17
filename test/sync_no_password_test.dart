import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/s3_store.dart';
import 'package:read/src/sync/sync_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final MemorySecretVault vault = MemorySecretVault();
    vault.values.clear();
    SecretVault.instance = vault;
  });

  test('SyncSecrets.load 在无用户密码时自动生成 32 位密钥并持久化', () async {
    final secrets = await SyncSecrets.load();
    expect(secrets.encryptionPassword.length, 32);
    expect(secrets.encryptionPassword, matches(RegExp(r'^[A-Za-z0-9]{32}$')));

    // 再次加载必须复用同一把密钥，否则旧云端数据无法解密。
    final again = await SyncSecrets.load();
    expect(again.encryptionPassword, secrets.encryptionPassword);
  });

  test('SyncSecrets.load 沿用已有的旧用户密码，保持历史备份可读', () async {
    await SecretVault.instance.write(SecretVault.encryptionKey, 'my-legacy-passphrase-1234');
    final secrets = await SyncSecrets.load();
    expect(secrets.encryptionPassword, 'my-legacy-passphrase-1234');
  });

  test('SyncSecrets.load 拒绝过短残留值并 regeneration', () async {
    await SecretVault.instance.write(SecretVault.encryptionKey, 'short');
    final secrets = await SyncSecrets.load();
    expect(secrets.encryptionPassword.length, 32);
    expect(secrets.encryptionPassword, isNot('short'));
  });

  test('S3 region auto/空回退到 us-east-1，正常 region 原样保留', () {
    expect(S3Store.effectiveRegion('auto'), 'us-east-1');
    expect(S3Store.effectiveRegion('  '), 'us-east-1');
    expect(S3Store.effectiveRegion('us-west-2'), 'us-west-2');
    expect(S3Store.effectiveRegion(' ap-south-1 '), 'ap-south-1');
  });

  test('S3Store 接受 http 与 https endpoint，拒绝畸形地址', () {
    final httpStore = S3Store(
      endpoint: 'http://10.0.0.5:9000',
      region: 'auto',
      bucket: 'read',
      prefix: 'Read',
      accessKey: 'k',
      secretKey: 's',
    );
    expect(httpStore.region, 'us-east-1');
    expect(httpStore.displayName, contains('10.0.0.5'));

    final httpsStore = S3Store(
      endpoint: 'https://s3.example.com',
      region: 'eu-central-1',
      bucket: 'read',
      prefix: 'Read',
      accessKey: 'k',
      secretKey: 's',
    );
    expect(httpsStore.region, 'eu-central-1');

    expect(
      () => S3Store(
        endpoint: 'ftp://bad',
        region: 'auto',
        bucket: 'read',
        prefix: 'Read',
        accessKey: 'k',
        secretKey: 's',
      ),
      throwsFormatException,
    );
  });
}
