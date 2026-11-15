import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户导入的字体（TTF/OTF）。文件复制到应用目录，重启后重新注册。
class UserFontStore extends ChangeNotifier {
  UserFontStore._();

  static final UserFontStore instance = UserFontStore._();

  static const String _key = 'read.reader.fonts.v1';
  static const int _maxFontBytes = 12 * 1024 * 1024;

  SharedPreferences? _prefs;
  final List<UserFont> _fonts = <UserFont>[];

  List<UserFont> get fonts => List<UserFont>.unmodifiable(_fonts);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _fonts.clear();
    final String? raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        for (final dynamic entry in list) {
          if (entry is Map<String, dynamic>) {
            _fonts.add(UserFont.fromJson(entry));
          }
        }
      } catch (_) {}
    }
    for (final UserFont font in _fonts) {
      await _load(font);
    }
    notifyListeners();
  }

  Future<UserFont?> importFont() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['ttf', 'otf'],
      withData: false,
      withReadStream: true,
    );
    final PlatformFile? picked = result?.files.singleOrNull;
    if (picked == null) return null;
    if (picked.size <= 0 || picked.size > _maxFontBytes) {
      throw const FormatException('字体文件必须小于 12MB');
    }

    // Android SAF providers do not always expose a filesystem path.
    Stream<List<int>>? stream = picked.readStream;
    if (stream == null && picked.path != null) {
      final file = File(picked.path!);
      if (await file.exists()) stream = file.openRead();
    }
    if (stream == null) {
      throw const FormatException('文件提供者无法提供字体内容');
    }

    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(docs.path + '/fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final String family = 'user-' + DateTime.now().microsecondsSinceEpoch.toString();
    final String name = p.basenameWithoutExtension(picked.name);
    final String target = dir.path + '/' + family +
        p.extension(picked.name).toLowerCase();
    final dest = File(target);
    final sink = dest.openWrite();
    int size = 0;
    final signature = <int>[];
    try {
      await for (final chunk in stream) {
        size += chunk.length;
        if (size > _maxFontBytes) {
          throw const FormatException('字体文件超过 12MB');
        }
        if (signature.length < 4) {
          signature.addAll(chunk.take(4 - signature.length));
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      final trueType = signature.length == 4 &&
          signature[0] == 0 && signature[1] == 1 &&
          signature[2] == 0 && signature[3] == 0;
      final openType = signature.length == 4 &&
          String.fromCharCodes(signature) == 'OTTO';
      if (!trueType && !openType) {
        throw const FormatException('不是有效的 TTF/OTF 字体');
      }
      final font = UserFont(family: family, name: name, path: target);
      if (!await _load(font)) {
        throw const FormatException('字体加载失败，请检查文件是否损坏');
      }
      _fonts.add(font);
      await _persist();
      notifyListeners();
      return font;
    } catch (_) {
      await sink.close();
      if (await dest.exists()) await dest.delete();
      rethrow;
    }
  }

  Future<void> deleteFont(UserFont font) async {
    _fonts.removeWhere((UserFont f) => f.family == font.family);
    try {
      final File file = File(font.path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await _persist();
    notifyListeners();
  }

  Future<bool> _load(UserFont font) async {
    try {
      final File file = File(font.path);
      if (!await file.exists()) return false;
      final ByteData data = ByteData.sublistView(
        Uint8List.fromList(await file.readAsBytes()),
      );
      final FontLoader loader = FontLoader(font.family)
        ..addFont(Future<ByteData>.value(data));
      await loader.load();
      return true;
    } catch (_) {
      // A corrupt saved font must not prevent opening the reader.
      return false;
    }
  }

  Future<void> _persist() async {
    await _prefs?.setString(
      _key,
      jsonEncode(_fonts.map((UserFont f) => f.toJson()).toList()),
    );
  }
}

class UserFont {
  const UserFont({
    required this.family,
    required this.name,
    required this.path,
  });

  final String family;
  final String name;
  final String path;

  Map<String, Object?> toJson() => <String, Object?>{
        'family': family,
        'name': name,
        'path': path,
      };

  static UserFont fromJson(Map<String, dynamic> json) => UserFont(
        family: json['family'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
      );
}
