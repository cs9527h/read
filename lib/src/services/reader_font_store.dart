import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderFont {
  const ReaderFont(this.family, this.displayName);
  final String family;
  final String displayName;
}

/// User-supplied, app-private font assets; content-addressed identifiers.
class ReaderFontStore {
  ReaderFontStore._();
  static final ReaderFontStore instance = ReaderFontStore._();
  static const _catalogKey = 'read.reader.fonts.v1';
  static const _maxBytes = 12 * 1024 * 1024;
  final Set<String> _loaded = <String>{};

  bool _validFamily(String family) =>
      RegExp(r'^read_font_[a-f0-9]{24}$').hasMatch(family);

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory(root.path + Platform.pathSeparator + 'reader_fonts');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<Map<String, String>> _catalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_catalogKey);
    if (raw == null) return <String, String>{};
    try {
      final object = jsonDecode(raw);
      if (object is! Map) return <String, String>{};
      return <String, String>{
        for (final entry in object.entries)
          if (entry.key is String && entry.value is String &&
              _validFamily(entry.key as String))
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<List<ReaderFont>> list() async {
    final dir = await _directory();
    final catalog = await _catalog();
    final fonts = <ReaderFont>[];
    for (final entry in catalog.entries) {
      final file = File(dir.path + Platform.pathSeparator + entry.key + '.font');
      if (await file.exists()) {
        fonts.add(ReaderFont(entry.key, entry.value));
      }
    }
    fonts.sort((a, b) => a.displayName.compareTo(b.displayName));
    return fonts;
  }

  Future<bool> load(String family) async {
    if (family.isEmpty) return true;
    if (!_validFamily(family)) return false;
    if (_loaded.contains(family)) return true;
    final dir = await _directory();
    final file = File(dir.path + Platform.pathSeparator + family + '.font');
    if (!await file.exists()) return false;
    if (await file.length() > _maxBytes) return false;
    try {
      final bytes = await file.readAsBytes();
      final loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loaded.add(family);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ReaderFont?> importFromPicker() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['ttf', 'otf'],
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return null;
    final selected = pick.files.first;
    if (selected.size <= 0 || selected.size > _maxBytes) {
      throw const FormatException('字体文件必须小于 12MB');
    }
    final bytes = selected.bytes;
    if (bytes == null || bytes.length < 12 || bytes.length > _maxBytes) {
      throw const FormatException('无法读取字体文件内容');
    }
    final header = bytes.sublist(0, 4);
    final isTrueType = header[0] == 0 && header[1] == 1 &&
        header[2] == 0 && header[3] == 0;
    final isOpenType = utf8.decode(header, allowMalformed: true) == 'OTTO';
    if (!isTrueType && !isOpenType) {
      throw const FormatException('不是有效的 TTF/OTF 字体文件');
    }
    final family = 'read_font_' + sha256.convert(bytes).toString().substring(0, 24);
    final dir = await _directory();
    final file = File(dir.path + Platform.pathSeparator + family + '.font');
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    if (!await load(family)) {
      throw const FormatException('字体文件无法被系统加载');
    }
    final catalog = await _catalog();
    catalog[family] = selected.name;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_catalogKey, jsonEncode(catalog))) {
      throw StateError('字体索引保存失败');
    }
    return ReaderFont(family, selected.name);
  }
}
