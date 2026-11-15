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

  SharedPreferences? _prefs;
  final List<UserFont> _fonts = <UserFont>[];

  List<UserFont> get fonts => List<UserFont>.unmodifiable(_fonts);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    );
    final PlatformFile? file = result?.files.singleOrNull;
    if (file?.path == null) return null;
    final File source = File(file!.path!);
    if (!await source.exists()) return null;
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final String family = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final String name = p.basenameWithoutExtension(file.name);
    final String target = '${dir.path}/$family${p.extension(file.name).toLowerCase()}';
    await source.copy(target);
    final UserFont font = UserFont(
      family: family,
      name: name,
      path: target,
    );
    await _load(font);
    _fonts.add(font);
    await _persist();
    notifyListeners();
    return font;
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

  Future<void> _load(UserFont font) async {
    try {
      final File file = File(font.path);
      if (!await file.exists()) return;
      final ByteData data = ByteData.sublistView(
        Uint8List.fromList(await file.readAsBytes()),
      );
      final FontLoader loader = FontLoader(font.family)
        ..addFont(Future<ByteData>.value(data));
      await loader.load();
    } catch (_) {
      // 坏字体文件不影响应用启动，只是不出现预览。
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
