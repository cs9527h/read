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
}
