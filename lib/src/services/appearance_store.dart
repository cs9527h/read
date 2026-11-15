import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 外观偏好：主题模式、全局字体缩放、书架是否显示大标题。
/// 只存真正生效的选项，避免设置页出现“按了没用”的开关。
class AppearanceStore extends ChangeNotifier {
  AppearanceStore._();

  static final AppearanceStore instance = AppearanceStore._();

  static const String _modeKey = 'read.appearance.themeMode';
  static const String _scaleKey = 'read.appearance.fontScale';
  static const String _bigTitleKey = 'read.appearance.bigTitle';

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  double _fontScale = 1.0;
  bool _bigTitle = true;

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get bigTitle => _bigTitle;

  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final String? mode = _prefs!.getString(_modeKey);
    _themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _fontScale = (_prefs!.getDouble(_scaleKey) ?? 1.0).clamp(0.85, 1.4);
    _bigTitle = _prefs!.getBool(_bigTitleKey) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_modeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.85, 1.4);
    await _prefs?.setDouble(_scaleKey, _fontScale);
    notifyListeners();
  }

  Future<void> setBigTitle(bool value) async {
    _bigTitle = value;
    await _prefs?.setBool(_bigTitleKey, value);
    notifyListeners();
  }
}
