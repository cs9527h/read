import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/reader/settings/reader_settings_store.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/sync/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Directory root;

Future<void> _mockPathProvider(Directory dir) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async => dir.path,
  );
}

Book _addBook({
  required String id,
  required String title,
  required Uint8List bytes,
  required String fileName,
  bool writeFile = true,
}) {
  final File file = File('${root.path}/books/$id-${fileName}');
  if (writeFile) {
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }
  final Book book = Book(
    id: id,
    title: title,
    author: '作者',
    format: 'TXT',
    content: '正文',
    sourcePath: file.path,
    contentHash: sha256.convert(bytes).toString(),
    fileName: fileName,
    fileSize: bytes.length,
  );
  LibraryStore.instance.books.add(book);
  return book;
}

Future<String> _writeZip(String name, Map<String, List<int>> entries) async {
  final Archive archive = Archive();
  for (final MapEntry<String, List<int>> entry in entries.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  final List<int>? bytes = ZipEncoder().encode(archive);
  final File file = File('${root.path}/$name');
  await file.writeAsBytes(bytes!);
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('read-backup-test-');
    await _mockPathProvider(root);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LibraryStore.instance.init();
    LibraryStore.instance.books.clear();
    await ReaderSettingsStore.instance.init();
  });

  tearDown(() async {
    LibraryStore.instance.books.clear();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('完整备份产出逐书清单并通过回读校验', () async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('第一章 开始\n内容内容'));
    final Book book = _addBook(
        id: 'b1', title: '测试书', bytes: bytes, fileName: '测试书.txt');

    final BackupService service = BackupService();
    final BackupInfo info = await service.createBackup();
    expect(info.books, 1);
    expect(info.complete, isTrue);
    expect(info.booksComplete, 1);
    expect(info.booksMetadataOnly, 0);
    expect(info.issues, isEmpty);
    expect(File(info.path).existsSync(), isTrue);

    final BackupVerification verification = await service.verifyBackup(info.path);
    expect(verification.ok, isTrue, reason: verification.problems.join('；'));
    expect(verification.verifiedFiles, 1);
    expect(verification.manifest!.books.single.hash, book.contentHash);
    expect(verification.manifest!.books.single.fileIncluded, isTrue);
  });

  test('文件丢失时标记为仅元数据并给出原因，不显示完整备份', () async {
    _addBook(
        id: 'b1',
        title: '正常书',
        bytes: Uint8List.fromList(utf8.encode('正常内容')),
        fileName: 'ok.txt');
    _addBook(
        id: 'b2',
        title: '丢失书',
        bytes: Uint8List.fromList(utf8.encode('丢失内容')),
        fileName: 'lost.txt',
        writeFile: false);

    final BackupService service = BackupService();
    final BackupInfo info = await service.createBackup();
    expect(info.books, 2);
    expect(info.complete, isFalse);
    expect(info.booksComplete, 1);
    expect(info.booksMetadataOnly, 1);
    expect(info.issues.single.contains('原始文件已丢失'), isTrue);

    final BackupVerification verification = await service.verifyBackup(info.path);
    expect(verification.ok, isTrue);
    final BackupManifest manifest = verification.manifest!;
    expect(manifest.isComplete, isFalse);
    final BackupBookEntry lost =
        manifest.books.firstWhere((BackupBookEntry b) => b.title == '丢失书');
    expect(lost.fileIncluded, isFalse);
    expect(lost.reason.contains('丢失'), isTrue);
  });

  test('校验值不一致的文件不写入备份，并记录原因', () async {
    final Book book = _addBook(
        id: 'b1',
        title: '被改过',
        bytes: Uint8List.fromList(utf8.encode('原始')),
        fileName: 'modified.txt');
    // 备份前外部修改文件内容，哈希不再匹配。
    File(book.sourcePath!).writeAsStringSync('篡改后的内容');

    final BackupService service = BackupService();
    final BackupInfo info = await service.createBackup();
    expect(info.complete, isFalse);
    expect(info.issues.single.contains('校验值不一致'), isTrue);
  });

  test('损坏的备份会被校验拒绝，恢复前不做任何修改', () async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('内容'));
    final Book book = _addBook(
        id: 'b1', title: '书', bytes: bytes, fileName: 'book.txt');
    final String hash = book.contentHash!;
    // 手工构造一个哈希与内容不符的备份。
    final String metadata = jsonEncode(<String, Object?>{
      'format': BackupService.format,
      'schema': 2,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'books': <Object?>[
        <String, Object?>{
          'hash': hash,
          'title': '书',
          'author': '作者',
          'format': 'TXT',
          'file_name': 'book.txt',
          'file_size': 3,
          'file': 'books/$hash.txt',
        }
      ],
      'manifest': <String, Object?>{
        'schema': 2,
        'books': <Object?>[
          <String, Object?>{
            'hash': hash,
            'title': '书',
            'file_name': 'book.txt',
            'file_included': true,
            'status': 'complete',
            'reason': '',
            'file': 'books/$hash.txt',
          }
        ],
      },
      'bookmarks': <String, Object?>{},
    });
    final String path = await _writeZip('bad.zip', <String, List<int>>{
      'metadata.json': utf8.encode(metadata),
      'books/$hash.txt': utf8.encode('篡改内容'),
    });

    // 清空书架，确认恢复失败时不会新增任何书。
    LibraryStore.instance.books.clear();
    final BackupService service = BackupService();
    final BackupVerification verification = await service.verifyBackup(path);
    expect(verification.ok, isFalse);
    expect(verification.problems.single.contains('校验值不一致'), isTrue);

    await expectLater(
      service.restore(path),
      throwsA(isA<FormatException>()),
    );
    expect(LibraryStore.instance.books, isEmpty);
  });

  test('恢复前预览数量与书签，并支持只恢复指定书籍', () async {
    final Book a = _addBook(
        id: 'b1',
        title: '甲书',
        bytes: Uint8List.fromList(utf8.encode('甲内容')),
        fileName: 'a.txt');
    final Book b = _addBook(
        id: 'b2',
        title: '乙书',
        bytes: Uint8List.fromList(utf8.encode('乙内容')),
        fileName: 'b.txt');
    await BookmarkStore.replaceAll(a.id, <int>[3, 9]);

    final BackupService service = BackupService();
    final BackupInfo info = await service.createBackup();
    LibraryStore.instance.books.clear();

    final BackupPreview preview = await service.previewRestore(info.path);
    expect(preview.manifest.books.length, 2);
    expect(preview.booksNew, 2);
    expect(preview.booksExisting, 0);
    expect(preview.bookmarks, 2);
    expect(preview.legacy, isFalse);

    final BackupReport report = await service.restore(
      info.path,
      selection: RestoreSelection(hashes: <String>{b.contentHash!}),
    );
    expect(report.complete, isTrue);
    expect(report.booksRestored, 1);
    expect(LibraryStore.instance.books.length, 1);
    expect(LibraryStore.instance.books.single.title, '乙书');
    // 恢复前快照必须真实存在。
    expect(File(report.preRestoreBackup).existsSync(), isTrue);
  });

  test('旧版无清单备份仍可校验与恢复', () async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('旧版正文'));
    final String hash = sha256.convert(bytes).toString();
    final String metadata = jsonEncode(<String, Object?>{
      'format': BackupService.format,
      'created_at': '2025-01-01T00:00:00.000Z',
      'books': <Object?>[
        <String, Object?>{
          'hash': hash,
          'title': '旧书',
          'author': '作者',
          'format': 'TXT',
          'file_name': 'old.txt',
          'file_size': bytes.length,
          'file': 'books/$hash.txt',
        }
      ],
      'bookmarks': <String, Object?>{
        hash: <int>[5]
      },
      'settings': '',
    });
    final String path = await _writeZip('legacy.zip', <String, List<int>>{
      'metadata.json': utf8.encode(metadata),
      'books/$hash.txt': bytes,
    });

    final BackupService service = BackupService();
    final BackupVerification verification = await service.verifyBackup(path);
    expect(verification.ok, isTrue, reason: verification.problems.join('；'));
    expect(verification.manifest!.schema, 1);

    final BackupPreview preview = await service.previewRestore(path);
    expect(preview.legacy, isTrue);
    expect(preview.booksNew, 1);

    final BackupReport report = await service.restore(path);
    expect(report.complete, isTrue);
    expect(report.booksRestored, 1);
    expect(report.bookmarks, 1);
    expect(LibraryStore.instance.books.single.title, '旧书');
  });

  test('恢复中途失败不破坏原数据，重跑可继续且不重复导入', () async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode('可恢复内容'));
    final Book book = _addBook(
        id: 'b1', title: '好书', bytes: bytes, fileName: 'good.txt');
    final Uint8List badBytes = Uint8List.fromList(utf8.encode('坏格式内容'));
    final String badHash = sha256.convert(badBytes).toString();
    final String metadata = jsonEncode(<String, Object?>{
      'format': BackupService.format,
      'schema': 2,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'books': <Object?>[
        <String, Object?>{
          'hash': book.contentHash,
          'title': '好书',
          'author': '作者',
          'format': 'TXT',
          'file_name': 'good.txt',
          'file_size': bytes.length,
          'file': 'books/${book.contentHash}.txt',
        },
        <String, Object?>{
          'hash': badHash,
          'title': '坏格式书',
          'author': '作者',
          'format': 'TXT',
          'file_name': 'bad.xyz',
          'file_size': badBytes.length,
          'file': 'books/$badHash.xyz',
        },
      ],
      'manifest': <String, Object?>{
        'schema': 2,
        'books': <Object?>[
          <String, Object?>{
            'hash': book.contentHash,
            'title': '好书',
            'file_name': 'good.txt',
            'file_included': true,
            'file': 'books/${book.contentHash}.txt',
          },
          <String, Object?>{
            'hash': badHash,
            'title': '坏格式书',
            'file_name': 'bad.xyz',
            'file_included': true,
            'file': 'books/$badHash.xyz',
          },
        ],
      },
      'bookmarks': <String, Object?>{},
    });
    final String path = await _writeZip('mixed.zip', <String, List<int>>{
      'metadata.json': utf8.encode(metadata),
      'books/${book.contentHash}.txt': bytes,
      'books/$badHash.xyz': badBytes,
    });
    LibraryStore.instance.books.clear();

    final BackupService service = BackupService();
    final BackupReport first = await service.restore(path);
    expect(first.complete, isFalse);
    expect(first.booksRestored, 1);
    expect(first.booksFailed, 1);
    expect(first.issues.single.title, '坏格式书');
    // 成功的那本已落库，失败的一本没有被写成半成品。
    expect(LibraryStore.instance.books.length, 1);

    final BackupReport second = await service.restore(path);
    expect(second.booksRestored, 0);
    expect(second.booksSkipped, 1);
    expect(second.booksFailed, 1);
    expect(LibraryStore.instance.books.length, 1, reason: '不得重复导入');
  });

  test('路径穿越的备份条目被校验拒绝', () async {
    final String metadata = jsonEncode(<String, Object?>{
      'format': BackupService.format,
      'books': <Object?>[
        <String, Object?>{'hash': 'a' * 64, 'title': 'x', 'file': '../../evil.txt'}
      ],
    });
    final String path = await _writeZip('traversal.zip', <String, List<int>>{
      'metadata.json': utf8.encode(metadata),
      '../evil.txt': utf8.encode('x'),
    });
    final BackupVerification verification =
        await BackupService().verifyBackup(path);
    expect(verification.ok, isFalse);
    expect(verification.problems.single.contains('非法路径'), isTrue);
  });

  test('从未备份过的书籍也会进入清单，便于用户发现丢失', () async {
    final Book noHash = Book(
      id: 'legacy',
      title: '旧导入',
      author: '',
      format: 'TXT',
      content: '正文',
      sourcePath: '${root.path}/books/none.txt',
    );
    LibraryStore.instance.books.add(noHash);
    final BackupService service = BackupService();
    final BackupInfo info = await service.createBackup();
    expect(info.books, 1);
    expect(info.booksMetadataOnly, 1);
    expect(info.issues.single.contains('缺少内容标识'), isTrue);
  });
}
