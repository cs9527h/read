import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ReaderSettingsStore.instance.init();
  });

  test('三层合并优先级：本书 > 主题 > 全局', () async {
    final ReaderSettingsStore store = ReaderSettingsStore.instance;
    final String bookId = 'book-priority';
    await store.save(
      bookId,
      store.resolve(bookId).patch(<String, Object?>{
        'fontSize': 20.0,
        'themeId': 'paper',
      }),
      ReaderScope.global,
    );
    expect(store.resolve(bookId).fontSize, 20.0);

    await store.save(
      bookId,
      store.resolve(bookId).patch(<String, Object?>{'fontSize': 22.0}),
      ReaderScope.theme,
    );
    expect(store.resolve(bookId).fontSize, 22.0);

    await store.save(
      bookId,
      store.resolve(bookId).patch(<String, Object?>{'fontSize': 24.0}),
      ReaderScope.book,
    );
    expect(store.resolve(bookId).fontSize, 24.0);
    expect(store.hasOverride(bookId, ReaderScope.book), isTrue);

    await store.clearScope(bookId, ReaderScope.book);
    expect(store.resolve(bookId).fontSize, 22.0);
    await store.clearScope(bookId, ReaderScope.theme);
    expect(store.resolve(bookId).fontSize, 20.0);
  });

  test('本书覆盖只保存与主题/全局不同的键', () async {
    final ReaderSettingsStore store = ReaderSettingsStore.instance;
    final String bookId = 'book-delta';
    final ReaderSettings base = store.resolve(bookId);
    await store.save(bookId, base, ReaderScope.book);
    expect(store.bookOverride(bookId), isEmpty);

    await store.save(
      bookId,
      base.patch(<String, Object?>{'lineHeight': 2.1}),
      ReaderScope.book,
    );
    expect(store.bookOverride(bookId).keys.toSet(), <String>{'lineHeight'});
  });

  test('预设保存、应用与删除', () async {
    final ReaderSettingsStore store = ReaderSettingsStore.instance;
    final ReaderSettings preset =
        store.resolve('b').patch(<String, Object?>{'fontSize': 26.0});
    await store.savePreset('大字', preset);
    expect(store.presets['大字']!.fontSize, 26.0);
    await store.deletePreset('大字');
    expect(store.presets.containsKey('大字'), isFalse);
  });

  test('配置导出后可以再次导入（含版本号）', () async {
    final ReaderSettingsStore store = ReaderSettingsStore.instance;
    final String bookId = 'book-export';
    await store.save(
      bookId,
      store.resolve(bookId).patch(<String, Object?>{'fontSize': 28.0}),
      ReaderScope.book,
    );
    final String json = store.exportJson(bookId: bookId);
    expect(json, contains('"version": "2"'));
    expect(json, contains('28.0'));

    final int count = await store.importJson(json);
    expect(count, greaterThan(0));
    expect(store.resolve(bookId).fontSize, 28.0);
  });

  test('不支持的配置版本会被拒绝', () async {
    final ReaderSettingsStore store = ReaderSettingsStore.instance;
    await expectLater(
      store.importJson('{"version": "99", "global": {}}'),
      throwsA(isA<FormatException>()),
    );
  });
  test('单本书设置跨 init 重启恢复且不污染其他书籍', () async {
    final store = ReaderSettingsStore.instance;
    await store.save(
      'book-local',
      store.resolve('book-local').patch(<String, Object?>{
        'fontSize': 29.0,
        'marginLeft': 35.0,
        'titleFontSize': 26.0,
      }),
      ReaderScope.book,
    );
    expect(store.resolve('book-local').fontSize, 29.0);
    await store.init(); // Simulates the next app launch on the same prefs.
    expect(store.resolve('book-local').fontSize, 29.0);
    expect(store.resolve('book-local').marginLeft, 35.0);
    expect(store.resolve('book-local').titleFontSize, 26.0);
    expect(store.resolve('another-book').fontSize, 18.0);
    expect(store.hasOverride('book-local', ReaderScope.book), isTrue);
  });

  test('重新初始化必须清掉已经被外部删除的旧配置缓存', () async {
    final store = ReaderSettingsStore.instance;
    await store.save(
      'book-stale',
      store.resolve('book-stale').patch(<String, Object?>{
        'fontSize': 31.0,
      }),
      ReaderScope.book,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('read.reader.settings.book.book-stale');
    await store.init();
    expect(store.resolve('book-stale').fontSize, 18.0);
    expect(store.hasOverride('book-stale', ReaderScope.book), isFalse);
  });

  test('修改全局参数不应泄漏当前书籍的专属字号边距', () async {
    final store = ReaderSettingsStore.instance;
    await store.save(
      'local-a',
      store.resolve('local-a').patch(<String, Object?>{
        'fontSize': 30.0,
        'marginLeft': 39.0,
      }),
      ReaderScope.book,
    );
    await store.save(
      'local-a',
      store.resolve('local-a').patch(<String, Object?>{'lineHeight': 2.2}),
      ReaderScope.global,
    );
    expect(store.resolve('local-a').fontSize, 30.0);
    expect(store.resolve('local-a').marginLeft, 39.0);
    expect(store.resolve('other-b').fontSize, 18.0);
    expect(store.resolve('other-b').marginLeft, 8.0);
    expect(store.resolve('other-b').lineHeight, 2.2);
    await store.init();
    expect(store.resolve('other-b').fontSize, 18.0);
    expect(store.resolve('other-b').lineHeight, 2.2);
    expect(store.resolve('local-a').fontSize, 30.0);
  });

  test('损坏的 JSON 配置不得写入或覆盖任何已有阅读设置', () async {
    final store = ReaderSettingsStore.instance;
    await store.save(
      'safe-book',
      store.resolve('safe-book').patch(<String, Object?>{'fontSize': 22.0}),
      ReaderScope.global,
    );
    final before = store.resolve('safe-book').fontSize;
    await expectLater(
      store.importJson('{"version":"2","global":{"fontSize":32},'
          '"book":{"other":{"lineHeight":"not-a-number"}}}'),
      throwsA(isA<FormatException>()),
    );
    expect(store.resolve('safe-book').fontSize, before);
    await store.init();
    expect(store.resolve('safe-book').fontSize, before);
  });

  test('非法字号和字体粗细在导入时被明确拒绝', () async {
    final store = ReaderSettingsStore.instance;
    await expectLater(
      store.importJson('{"version":"2","global":{"fontSize":999}}'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      store.importJson('{"version":"2","global":{"fontWeight":123}}'),
      throwsA(isA<FormatException>()),
    );
    expect(store.resolve('plain').fontSize, 18);
  });

  test('快速连续修改字号后重启应恢复最后一次设置', () async {
    final store = ReaderSettingsStore.instance;
    final writes = <Future<void>>[];
    for (final size in <double>[19, 24, 17, 28]) {
      writes.add(store.save(
        'rapid-book',
        store.resolve('rapid-book').patch(<String, Object?>{'fontSize': size}),
        ReaderScope.book,
      ));
    }
    await Future.wait(writes);
    await store.init();
    expect(store.resolve('rapid-book').fontSize, 28.0);
  });

}
