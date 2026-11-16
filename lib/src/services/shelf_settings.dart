import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 书架外观与行为偏好。只放真正生效的开关，避免设置页出现按了没用的项。
class ShelfSettings extends ChangeNotifier {
  ShelfSettings._();

  static final ShelfSettings instance = ShelfSettings._();

  static const String _showProgressKey = 'read.shelf.showProgress';
  static const String _showCloudKey = 'read.shelf.showCloud';
  static const String _showPrivateKey = 'read.shelf.showPrivate';
  static const String _columnsKey = 'read.shelf.columns';
  static const String _compactKey = 'read.shelf.compact';

  SharedPreferences? _prefs;

  bool _showProgress = true;
  bool _showCloud = true;
  bool _showPrivate = true;
  int _columns = 0; // 0 = 自适应
  bool _compact = false;

  bool get showProgress => _showProgress;
  bool get showCloud => _showCloud;
  bool get showPrivate => _showPrivate;
  int get columns => _columns;
  bool get compact => _compact;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _showProgress = _prefs!.getBool(_showProgressKey) ?? true;
    _showCloud = _prefs!.getBool(_showCloudKey) ?? true;
    _showPrivate = _prefs!.getBool(_showPrivateKey) ?? true;
    _columns = (_prefs!.getInt(_columnsKey) ?? 0).clamp(0, 6);
    _compact = _prefs!.getBool(_compactKey) ?? false;
    notifyListeners();
  }

  Future<void> setShowProgress(bool value) async {
    _showProgress = value;
    await _prefs?.setBool(_showProgressKey, value);
    notifyListeners();
  }

  Future<void> setShowCloud(bool value) async {
    _showCloud = value;
    await _prefs?.setBool(_showCloudKey, value);
    notifyListeners();
  }

  Future<void> setShowPrivate(bool value) async {
    _showPrivate = value;
    await _prefs?.setBool(_showPrivateKey, value);
    notifyListeners();
  }

  Future<void> setColumns(int value) async {
    _columns = value.clamp(0, 6);
    await _prefs?.setInt(_columnsKey, _columns);
    notifyListeners();
  }

  Future<void> setCompact(bool value) async {
    _compact = value;
    await _prefs?.setBool(_compactKey, value);
    notifyListeners();
  }
}
