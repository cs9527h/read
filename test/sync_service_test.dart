import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/bookmark_meta_store.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/sync/encrypted_sync_envelope.dart';
import 'package:read/src/sync/metadata_sync_service.dart';
import 'package:read/src/sync/remote_store.dart';
import 'package:read/src/sync/sync_document.dart';
import 'package:read/src/sync/sync_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRemoteStore implements RemoteObjectStore {
  final Map<String, Uint8List> objects = <String, Uint8List>{};
  final Map<String, String> etags = <String, String>{};
  int writes = 0;

  @override
  String get displayName => 'fake';

  @override
  Future<void> testConnection() async {}

  @override
  Future<RemoteSnapshot?> read(String key) async {
    final bytes = objects[key];
    if (bytes == null) return null;
    return RemoteSnapshot(bytes: bytes, etag: etags[key]);
  }

  @override
  Future<String?> write(Uint8List bytes, String key, {String? expectedEtag}) async {
    if (expectedEtag == null && objects.containsKey(key)) {
      throw const RemoteConflictException('exists');
    }
    if (expectedEtag != null && etags[key] != expectedEtag) {
      throw const RemoteConflictException('changed');
    }
    objects[key] = bytes;
    writes++;
    final etag = 'etag-$writes';
    etags[key] = etag;
    return etag;
  }

  @override
  Future<void> delete(String key) async {
    objects.remove(key);
    etags.remove(key);
  }

  @override
  Future<List<RemoteEntry>> list({String prefix = '', int max = 200}) async =>
      <RemoteEntry>[];
}

const String hash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String password = 'correct horse battery';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('全量同步：上传后合并远端标题与书签，条件写入不覆盖', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LibraryStore.instance.init();
    LibraryStore.instance.books.clear();
    final book = Book(
      id: 'b1',
      title: '本机书名',
      author: '本机作者',
      content: '正文' * 100,
      format: 'TXT',
      sourcePath: '/tmp/sync-book.txt',
      contentHash: hash,
      fileName: 'book.txt',
      fileSize: 200,
    );
    LibraryStore.instance.books.add(book);
    await BookmarkStore.replaceAll(book.id, <int>[3, 9]);
    await BookmarkMetaStore.setNote(book.id, 3, '本地备注');

    final store = FakeRemoteStore();
    final service = MetadataSyncService();
    final report = await service.sync(
      store: store,
      encryptionPassword: password,
      includeBookmarks: true,
      includeSettings: false,
      includeStats: false,
      includeFiles: false,
      downloadMissingFiles: false,
      targetId: 'fake-target',
    );
    expect(report.status, 'success');
    expect(store.objects.containsKey('metadata.enc'), isTrue);
    expect(store.writes, 1);

    // Remote device adds bookmark 5 and edits metadata with higher revisions.
    final remote = SyncDocument(
      deviceId: 'remote-device',
      createdAt: DateTime.now(),
      records: <String, SyncRecord>{
        'book:$hash': SyncRecord(
          id: 'book:$hash',
          kind: 'book',
          rev: 5,
          deviceId: 'remote-device',
          updatedAt: 2,
          deleted: false,
          fields: <String, dynamic>{
            'hash': hash,
            'title': '远端书名',
            'author': '远端作者',
            'format': 'TXT',
            'file_name': 'book.txt',
            'file_size': 200,
            'chapter_count': 3,
            'last_read_at': 5,
            'tags': <String>['小说', '待读'],
          },
        ),
        'bookmark:$hash:5': SyncRecord(
          id: 'bookmark:$hash:5',
          kind: 'bookmark',
          rev: 5,
          deviceId: 'remote-device',
          updatedAt: 2,
          deleted: false,
          fields: <String, dynamic>{
            'book_hash': hash,
            'offset': 5,
            'note': '远端备注',
            'created_at': 1234,
          },
        ),
        'bookmark:$hash:3': SyncRecord(
          id: 'bookmark:$hash:3',
          kind: 'bookmark',
          rev: 5,
          deviceId: 'remote-device',
          updatedAt: 2,
          deleted: true,
          fields: const <String, dynamic>{},
        ),
        'bookmark:$hash:9': SyncRecord(
          id: 'bookmark:$hash:9',
          kind: 'bookmark',
          rev: 5,
          deviceId: 'remote-device',
          updatedAt: 2,
          deleted: true,
          fields: const <String, dynamic>{},
        ),
      },
    );
    final encrypted = await EncryptedSyncEnvelope.encrypt(remote.encode(), password);
    store.objects['metadata.enc'] = encrypted;
    store.etags['metadata.enc'] = 'remote-etag';

    final second = await service.sync(
      store: store,
      encryptionPassword: password,
      includeBookmarks: true,
      includeSettings: false,
      includeStats: false,
      includeFiles: false,
      downloadMissingFiles: false,
      targetId: 'fake-target',
    );
    expect(second.downloaded, greaterThan(0));
    expect(LibraryStore.instance.bookByHash(hash)!.title, '远端书名');
    expect(await BookmarkStore.load(book.id), <int>[5]);
    expect(LibraryStore.instance.bookByHash(hash)!.tags, <String>['小说', '待读']);
    final meta = (await BookmarkMetaStore.load(book.id))[5];
    expect(meta?.note, '远端备注');
    expect(meta?.createdAt, 1234);
    expect(store.writes, 2);

    // Corrupt ciphertext must be rejected without overwriting the remote.
    store.objects['metadata.enc'] = Uint8List.fromList(utf8.encode('{"format":"broken"}'));
    expect(
      () => service.sync(
        store: store,
        encryptionPassword: password,
        includeBookmarks: true,
        includeSettings: false,
        includeStats: false,
        includeFiles: false,
        downloadMissingFiles: false,
        targetId: 'fake-target',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
