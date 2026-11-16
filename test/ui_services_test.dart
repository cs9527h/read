import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/bookshelf/cover_art.dart';
import 'package:read/src/more/import_tools.dart';
import 'package:read/src/services/cloud_presence.dart';
import 'package:read/src/services/settings_portable.dart';
import 'package:read/src/model/book.dart';

void main() {
  group('云朵状态', () {
    test('未确认云端时一律 localOnly：不会给本地书挂云朵', () {
      CloudPresence.instance.markUnavailable();
      final Book book = Book(
        id: 'c1',
        title: '本地书',
        author: '作者',
        content: 'x',
        contentHash: 'abc123',
      );
      expect(CloudPresence.instance.stateFor(book), CloudState.localOnly);
      expect(CloudPresence.instance.available, isFalse);
      expect(CloudPresence.instance.progressOnly(book), isFalse);
    });

    test('没有 contentHash 的书不可能是云端书', () {
      final Book book = Book(id: 'c2', title: '无哈希', author: '作者', content: 'x');
      expect(CloudPresence.instance.stateFor(book), CloudState.localOnly);
    });
  });

  group('设置导出', () {
    test('导出的 JSON 不包含任何密钥字段', () async {
      final String json = await SettingsPortable.exportJson(includeBooks: false);
      final Map<String, dynamic> data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['app'], 'read');
      expect(data['kind'], 'settings');
      final Map<String, dynamic> sync = data['sync'] as Map<String, dynamic>;
      expect(sync.containsKey('webdavPassword'), isFalse);
      expect(sync.containsKey('s3SecretKey'), isFalse);
      expect(sync.containsKey('encryptionPassword'), isFalse);
      expect(json.contains('ghp_'), isFalse);
    });

    test('inspect 能识别自己的文件并列出覆盖范围', () {
      final String json = jsonEncode(<String, dynamic>{
        'app': 'read',
        'kind': 'settings',
        'formatVersion': 1,
        'exportedAt': '2026-11-16T00:00:00',
        'appearance': <String, dynamic>{'fontScale': 1.1},
        'reader': <String, dynamic>{'fontSize': 20.0},
        'shelf': <String, dynamic>{'sortMode': 'title'},
        'sync': <String, dynamic>{'provider': 'webdav'},
        'books': <dynamic>[
          <String, dynamic>{'hash': 'abc'},
        ],
      });
      final PortablePreview preview = SettingsPortable.inspect(json);
      expect(preview.parts.length, 5);
      expect(preview.summary, contains('阅读排版'));
      expect(preview.summary, contains('1 本'));
    });

    test('拒绝别的应用的 JSON', () {
      expect(
        () => SettingsPortable.inspect('{"app":"other","kind":"settings"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('拒绝未来版本，避免写入不认识的字段', () {
      final String json = jsonEncode(<String, dynamic>{
        'app': 'read',
        'kind': 'settings',
        'formatVersion': 99,
      });
      expect(
        () => SettingsPortable.inspect(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('导入工具', () {
    test('只接受阅读器支持的扩展名', () {
      expect(ImportTools.supported('/a/b.txt'), isTrue);
      expect(ImportTools.supported('/a/b.EPUB'), isTrue);
      expect(ImportTools.supported('/a/b.pdf'), isTrue);
      expect(ImportTools.supported('/a/b.md'), isTrue);
      expect(ImportTools.supported('/a/b.exe'), isFalse);
      expect(ImportTools.supported('/a/b'), isFalse);
    });

    test('导入结果文案覆盖导入/跳过/失败三种情况', () {
      const ImportSummary summary = ImportSummary(
        imported: 2,
        skipped: 1,
        failed: 0,
      );
      expect(summary.message, contains('导入 2 本'));
      expect(summary.message, contains('跳过重复 1 本'));
      expect(const ImportSummary().message, '没有可导入的文件');
    });
  });

  group('封面模板', () {
    test('模板 id 与模板列表一致，且不少于 4 个', () {
      expect(coverTemplateIds.length, CoverTemplate.all.length);
      expect(coverTemplateIds.length, greaterThanOrEqualTo(4));
      expect(coverTemplateIds, contains('ink'));
    });
  });
}
