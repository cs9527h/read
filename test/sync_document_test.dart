import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/services/reading_stats_store.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/sync/metadata_sync_source.dart';
import 'package:read/src/sync/sync_document.dart';
import 'package:read/src/sync/sync_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncRecord rec({
  required String id,
  String kind = 'bookmark',
  int rev = 1,
  String device = 'phone',
  bool deleted = false,
  Map<String, dynamic> fields = const <String, dynamic>{'offset': 3},
}) =>
    SyncRecord(
      id: id,
      kind: kind,
      rev: rev,
      deviceId: device,
      updatedAt: 1,
      deleted: deleted,
      fields: fields,
    );

SyncDocument doc(String device, List<SyncRecord> records) => SyncDocument(
      deviceId: device,
      createdAt: DateTime.utc(2026, 1, 1),
      records: <String, SyncRecord>{for (final r in records) r.id: r},
    );

const String hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('文档 JSON 往返保留墓碑与字段', () {
    final source = doc('a', <SyncRecord>[
      rec(id: 'bookmark:$hashA:3', fields: <String, dynamic>{'offset': 3}),
      rec(
        id: 'bookmark:$hashA:9',
        deleted: true,
        fields: const <String, dynamic>{},
      ),
    ]);
    final parsed = SyncDocument.fromJson(source.toJson());
    expect(parsed.records.length, 2);
    expect(parsed.records['bookmark:$hashA:9']!.deleted, isTrue);
    expect(parsed.encode().length, lessThan(8 * 1024 * 1024));
  });

  test('拒绝重复记录和不支持的格式', () {
    final json = doc('a', <SyncRecord>[rec(id: 'bookmark:a:1')]).toJson();
    final records = json['records'] as List<dynamic>;
    records.add(Map<String, dynamic>.from(records.first as Map));
    expect(() => SyncDocument.fromJson(json), throwsFormatException);
    json['format'] = 'other';
    expect(() => SyncDocument.fromJson(json), throwsFormatException);
  });

  test('本地删除对远端旧版本生成墓碑，不会被复活', () {
    final base = doc('a', <SyncRecord>[rec(id: 'bookmark:$hashA:3')]);
    final local = doc('b', <SyncRecord>[
      rec(
        id: 'bookmark:$hashA:3',
        rev: 2,
        device: 'b',
        deleted: true,
        fields: const <String, dynamic>{},
      ),
    ]);
    final remote = base;
    final merged = SyncDocumentMerger.merge(
      local: local,
      remote: remote,
      baseline: base,
    );
    expect(merged.document.records['bookmark:$hashA:3']!.deleted, isTrue);
  });

  test('双方同时编辑产生冲突记录但保留确定性结果', () {
    final base = doc('a', <SyncRecord>[
      rec(id: 'settings:reader', kind: 'settings', fields: <String, dynamic>{'v': 1}),
    ]);
    final local = doc('b', <SyncRecord>[
      rec(
        id: 'settings:reader',
        kind: 'settings',
        rev: 2,
        device: 'b',
        fields: <String, dynamic>{'v': 2},
      ),
    ]);
    final remote = doc('c', <SyncRecord>[
      rec(
        id: 'settings:reader',
        kind: 'settings',
        rev: 2,
        device: 'c',
        fields: <String, dynamic>{'v': 3},
      ),
    ]);
    final merged = SyncDocumentMerger.merge(
      local: local,
      remote: remote,
      baseline: base,
    );
    expect(merged.conflicts.length, 1);
    expect(merged.document.records['settings:reader']!.fields['v'], anyOf(2, 3));
  });

  group('本地同步文档构建与应用', () {
    late Book book;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await LibraryStore.instance.init();
      await ReaderSettingsStore.instance.init();
      await ReadingStatsStore.instance.init();
      LibraryStore.instance.books.clear();
      book = Book(
        id: 'local-1',
        title: '凡人修仙传',
        author: '忘语',
        content: '第一章\n正文' * 100,
        format: 'TXT',
        sourcePath: '/tmp/read-test-book.txt',
        contentHash: hashA,
        fileName: 'fanren.txt',
        fileSize: 123,
      );
      LibraryStore.instance.books.add(book);
      await BookmarkStore.replaceAll(book.id, <int>[3, 9]);
    });

    test('构建使用稳定内容哈希并包含书签', () async {
      final document = await LocalSyncSource().build(
        deviceId: 'device-a',
        includeBookmarks: true,
        includeSettings: false,
        includeStats: false,
      );
      expect(document.records.containsKey('book:$hashA'), isTrue);
      expect(document.records.containsKey('bookmark:$hashA:3'), isTrue);
      expect(document.records['book:$hashA']!.fields['title'], '凡人修仙传');
      expect(document.records['book:$hashA']!.rev, 1);
    });

    test('无变化再次构建不提升 revision', () async {
      final first = await LocalSyncSource().build(
        deviceId: 'device-a',
        includeBookmarks: true,
        includeSettings: false,
        includeStats: false,
      );
      final second = await LocalSyncSource().build(
        deviceId: 'device-a',
        includeBookmarks: true,
        includeSettings: false,
        includeStats: false,
        baseline: first,
      );
      expect(second.records['book:$hashA']!.rev,
          first.records['book:$hashA']!.rev);
    });

    test('应用远端书签并只保留远端集合', () async {
      final document = doc('remote', <SyncRecord>[
        rec(
          id: 'book:$hashA',
          kind: 'book',
          fields: <String, dynamic>{
            'hash': hashA,
            'title': '云端标题',
            'author': '云端作者',
            'chapter_count': 12,
            'last_read_at': 0,
          },
        ),
        rec(
          id: 'bookmark:$hashA:7',
          fields: <String, dynamic>{'book_hash': hashA, 'offset': 7},
        ),
        rec(
          id: 'bookmark:$hashA:3',
          fields: <String, dynamic>{'book_hash': hashA, 'offset': 3},
          deleted: true,
        ),
      ]);
      final result = await LocalSyncApplier().apply(
        document,
        includeBookmarks: true,
        includeSettings: false,
      );
      expect(result.booksMatched, 1);
      expect(await BookmarkStore.load(book.id), <int>[7]);
      expect(LibraryStore.instance.bookByHash(hashA)!.title, '云端标题');
    });
  });
}
