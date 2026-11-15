import 'dart:convert';

import 'dart:ui' show Brightness;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:read/src/reader/settings/reader_settings.dart';
import 'package:read/src/reader/settings/reader_theme.dart';

/// 阅读配置仓库：全局默认 / 主题排版 / 本书覆盖 三层，外加主题与预设。
///
/// 优先级（需求 94）：本书覆盖 > 当前主题 > 全局默认。
class ReaderSettingsStore extends ChangeNotifier {
  ReaderSettingsStore._();

  static final ReaderSettingsStore instance = ReaderSettingsStore._();

  static const String _globalKey = 'read.reader.settings.global.v2';
  static const String _bookPrefix = 'read.reader.settings.book.';
  static const String _themePrefix = 'read.reader.theme.typo.';
  static const String _themesKey = 'read.reader.themes.v2';
  static const String _presetsKey = 'read.reader.presets.v2';
  static const String configVersion = '2';

  SharedPreferences? _prefs;

  Map<String, Object?> _global = <String, Object?>{};
  final Map<String, Map<String, Object?>> _bookOverrides =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> _themeTypo =
      <String, Map<String, Object?>>{};

  final List<ReaderTheme> _customThemes = <ReaderTheme>[];

  final Map<String, ReaderSettings> _presets = <String, ReaderSettings>{};

  bool _ready = false;
  bool get ready => _ready;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _global = _decodeMap(_prefs!.getString(_globalKey));
    final String? themesRaw = _prefs!.getString(_themesKey);
    if (themesRaw != null) {
      try {
        final List<dynamic> list = jsonDecode(themesRaw) as List<dynamic>;
        _customThemes.addAll(list.map((dynamic e) =>
            ReaderTheme.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    for (final ReaderTheme theme in _builtInsAndCustom()) {
      final Map<String, Object?> typo =
          _decodeMap(_prefs!.getString('$_themePrefix${theme.id}'));
      if (typo.isNotEmpty) _themeTypo[theme.id] = typo;
    }
    final String? presetsRaw = _prefs!.getString(_presetsKey);
    if (presetsRaw != null) {
      try {
        final Map<String, dynamic> list =
            jsonDecode(presetsRaw) as Map<String, dynamic>;
        list.forEach((String name, dynamic value) {
          if (value is Map<String, dynamic>) {
            _presets[name] = ReaderSettings(value);
          }
        });
      } catch (_) {}
    }
    _ready = true;
    notifyListeners();
  }

  Map<String, Object?> _decodeMap(String? raw) {
    if (raw == null) return <String, Object?>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? Map<String, Object?>.from(decoded)
          : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }

  // -------------------------------------------------------------------------
  // 生效配置
  // -------------------------------------------------------------------------

  ReaderSettings globalSettings() => ReaderSettings(_global);

  Map<String, Object?> bookOverride(String bookId) =>
      Map<String, Object?>.from(_bookOverrides[bookId] ?? const <String, Object?>{});

  Map<String, Object?> themeTypo(String themeId) =>
      Map<String, Object?>.from(_themeTypo[themeId] ?? const <String, Object?>{});

  /// 合并三层，得到某本书真正生效的设置。
  ReaderSettings resolve(String bookId) {
    final Map<String, Object?> book = _bookOverrides[bookId] ?? const <String, Object?>{};
    final String themeId =
        (book['themeId'] as String?) ??
        (_global['themeId'] as String?) ??
        'paper';
    final Map<String, Object?> themeTypoMap =
        _themeTypo[themeId] ?? const <String, Object?>{};
    return ReaderSettings(<String, Object?>{
      ..._global,
      ...themeTypoMap,
      ...book,
    });
  }

  /// 修改的生效范围。
  Future<void> save(String bookId, ReaderSettings next, ReaderScope scope) async {
    switch (scope) {
      case ReaderScope.global:
        _global = next.toJson();
        await _prefs?.setString(_globalKey, jsonEncode(_global));
      case ReaderScope.theme:
        final String themeId = next.themeId;
        final Map<String, Object?> delta =
            next.diffFrom(ReaderSettings(<String, Object?>{
          ..._global,
          ...(_bookOverrides[bookId] ?? const <String, Object?>{}),
        }));
        _themeTypo[themeId] = <String, Object?>{
          ...(_themeTypo[themeId] ?? const <String, Object?>{}),
          ...delta,
        };
        await _prefs?.setString('$_themePrefix$themeId', jsonEncode(_themeTypo[themeId]));
      case ReaderScope.book:
        final Map<String, Object?> bookDelta =
            next.diffFrom(ReaderSettings(<String, Object?>{
          ..._global,
          ...(_themeTypo[next.themeId] ?? const <String, Object?>{}),
        }));
        _bookOverrides[bookId] = bookDelta;
        await _prefs?.setString('$_bookPrefix$bookId', jsonEncode(bookDelta));
        if (bookDelta.isEmpty) {
          await _prefs?.remove('$_bookPrefix$bookId');
          _bookOverrides.remove(bookId);
        }
    }
    notifyListeners();
  }

  Future<void> clearScope(String bookId, ReaderScope scope) async {
    switch (scope) {
      case ReaderScope.global:
        _global = <String, Object?>{};
        await _prefs?.remove(_globalKey);
      case ReaderScope.theme:
        final String themeId = resolve(bookId).themeId;
        _themeTypo.remove(themeId);
        await _prefs?.remove('$_themePrefix$themeId');
      case ReaderScope.book:
        _bookOverrides.remove(bookId);
        await _prefs?.remove('$_bookPrefix$bookId');
    }
    notifyListeners();
  }

  bool hasOverride(String bookId, ReaderScope scope) {
    switch (scope) {
      case ReaderScope.global:
        return _global.isNotEmpty;
      case ReaderScope.theme:
        return (_themeTypo[resolve(bookId).themeId] ?? const <String, Object?>{})
            .isNotEmpty;
      case ReaderScope.book:
        return (_bookOverrides[bookId] ?? const <String, Object?>{}).isNotEmpty;
    }
  }

  // -------------------------------------------------------------------------
  // 主题
  // -------------------------------------------------------------------------

  List<ReaderTheme> _builtInsAndCustom() => <ReaderTheme>[
        ...kBuiltInThemes,
        ..._customThemes,
      ];

  List<ReaderTheme> get allThemes => _builtInsAndCustom();

  List<ReaderTheme> get customThemes => List<ReaderTheme>.from(_customThemes);

  ReaderTheme themeById(String id) {
    for (final ReaderTheme theme in _builtInsAndCustom()) {
      if (theme.id == id) return theme;
    }
    return kBuiltInThemes.first;
  }

  /// 当前生效主题：支持「跟随系统深浅色」（需求 48）。
  ReaderTheme effectiveTheme(ReaderSettings settings, Brightness platformBrightness) {
    if (settings.followSystemTheme) {
      final String id = platformBrightness == Brightness.dark
          ? settings.nightThemeId
          : settings.dayThemeId;
      return themeById(id);
    }
    return themeById(settings.themeId);
  }

  Future<ReaderTheme> createTheme({
    required String name,
    required bool isDark,
    required int background,
    required int foreground,
 }) async {
    final String id = 'custom-${DateTime.now().millisecondsSinceEpoch}';
    final ReaderTheme theme = ReaderTheme(
      id: id,
      name: name.trim().isEmpty ? '自定义主题' : name.trim(),
      isDark: isDark,
      background: background,
      foreground: foreground,
      secondary: 0xFF888888,
    );
    _customThemes.add(theme);
    await _persistThemes();
    notifyListeners();
    return theme;
  }

  Future<void> updateTheme(ReaderTheme theme) async {
    final int index = _customThemes.indexWhere((ReaderTheme t) => t.id == theme.id);
    if (index < 0) return;
    _customThemes[index] = theme;
    await _persistThemes();
    notifyListeners();
  }

  Future<ReaderTheme?> duplicateTheme(String id) async {
    ReaderTheme? source;
    for (final ReaderTheme theme in _customThemes) {
      if (theme.id == id) {
        source = theme;
        break;
      }
    }
    if (source == null) return null;
    final ReaderTheme copy = await createTheme(
      name: '${source.name} 副本',
      isDark: source.isDark,
      background: source.background,
      foreground: source.foreground,
    );
    final Map<String, Object?> typo = _themeTypo[source.id] ?? const <String, Object?>{};
    if (typo.isNotEmpty) {
      _themeTypo[copy.id] = Map<String, Object?>.from(typo);
      await _prefs?.setString('$_themePrefix${copy.id}', jsonEncode(typo));
    }
    notifyListeners();
    return copy;
  }

  Future<void> renameTheme(String id, String name) async {
    ReaderTheme? theme;
    for (final ReaderTheme item in _customThemes) {
      if (item.id == id) {
        theme = item;
        break;
      }
    }
    if (theme == null) return;
    await updateTheme(theme.copyWith(name: name.trim()));
  }

  Future<void> deleteTheme(String id) async {
    _customThemes.removeWhere((ReaderTheme t) => t.id == id);
    _themeTypo.remove(id);
    await _prefs?.remove('$_themePrefix$id');
    await _persistThemes();
    notifyListeners();
  }

  Future<void> _persistThemes() async {
    await _prefs?.setString(
      _themesKey,
      jsonEncode(_customThemes.map((ReaderTheme t) => t.toJson()).toList()),
    );
  }

  // -------------------------------------------------------------------------
  // 预设（需求 96）与导入导出（需求 97）
  // -------------------------------------------------------------------------

  Map<String, ReaderSettings> get presets => Map<String, ReaderSettings>.from(_presets);

  Future<void> savePreset(String name, ReaderSettings settings) async {
    _presets[name.trim().isEmpty ? '未命名预设' : name.trim()] = settings;
    await _prefs?.setString(
      _presetsKey,
      jsonEncode(_presets.map((String key, ReaderSettings value) =>
          MapEntry<String, dynamic>(key, value.toJson()))),
    );
    notifyListeners();
  }

  Future<void> deletePreset(String name) async {
    _presets.remove(name);
    await _prefs?.setString(
      _presetsKey,
      jsonEncode(_presets.map((String key, ReaderSettings value) =>
          MapEntry<String, dynamic>(key, value.toJson()))),
    );
    notifyListeners();
  }

  String exportJson({String? bookId}) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'version': configVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'global': _global,
      'book': bookId == null ? _bookOverrides : <String, Object?>{bookId: resolve(bookId).toJson()},
      'themeTypo': _themeTypo,
      'themes': _customThemes.map((ReaderTheme t) => t.toJson()).toList(),
      'presets': _presets.map((String k, ReaderSettings v) =>
          MapEntry<String, Object?>(k, v.toJson())),
    });
  }

  /// 导入会校验结构；旧版本（version 1 / 缺失）按当前默认值迁移。
  Future<int> importJson(String raw) async {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('配置文件不是 JSON 对象');
    }
    final Object? version = decoded['version'];
    if (version != null && version != '1' && version != configVersion) {
      throw FormatException('不支持的配置版本：$version');
    }
    final Object? global = decoded['global'];
    if (global is Map<String, dynamic>) {
      _global = <String, Object?>{..._global, ...global};
      await _prefs?.setString(_globalKey, jsonEncode(_global));
    }
    final Object? book = decoded['book'];
    if (book is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in book.entries) {
        if (entry.value is Map<String, dynamic>) {
          final Map<String, Object?> value =
              Map<String, Object?>.from(entry.value as Map<String, dynamic>);
          _bookOverrides[entry.key] = value;
          await _prefs?.setString('$_bookPrefix${entry.key}', jsonEncode(value));
        }
      }
    }
    final Object? typo = decoded['themeTypo'];
    if (typo is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in typo.entries) {
        if (entry.value is Map<String, dynamic>) {
          final Map<String, Object?> value =
              Map<String, Object?>.from(entry.value as Map<String, dynamic>);
          _themeTypo[entry.key] = value;
          await _prefs?.setString('$_themePrefix${entry.key}', jsonEncode(value));
        }
      }
    }
    final Object? themes = decoded['themes'];
    if (themes is List<dynamic>) {
      for (final dynamic entry in themes) {
        if (entry is Map<String, dynamic>) {
          try {
            final ReaderTheme theme = ReaderTheme.fromJson(entry);
            if (!_customThemes.any((ReaderTheme t) => t.id == theme.id)) {
              _customThemes.add(theme);
            }
          } catch (_) {
            // 单条坏数据跳过，不影响其他配置。
          }
        }
      }
      await _persistThemes();
    }
    final Object? presets = decoded['presets'];
    if (presets is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in presets.entries) {
        if (entry.value is Map<String, dynamic>) {
          _presets[entry.key] = ReaderSettings(entry.value as Map<String, dynamic>);
        }
      }
      await _prefs?.setString(
        _presetsKey,
        jsonEncode(_presets.map((String key, ReaderSettings value) =>
            MapEntry<String, dynamic>(key, value.toJson()))),
      );
    }
    notifyListeners();
    return _bookOverrides.length + _themeTypo.length + _customThemes.length;
  }
}

enum ReaderScope { global, theme, book }

extension ReaderScopeLabel on ReaderScope {
  String get label => switch (this) {
        ReaderScope.global => '全局默认',
        ReaderScope.theme => '当前主题',
        ReaderScope.book => '本书',
      };

  String get hint => switch (this) {
        ReaderScope.global => '所有未单独设置的书都会继承',
        ReaderScope.theme => '只有使用这个主题时生效',
        ReaderScope.book => '只影响当前这本书',
      };
}
