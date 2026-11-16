import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 空书箱也要能存在，所以不能只从书籍的 collections 反推。
class CollectionStore extends ChangeNotifier {
  CollectionStore._();

  static final CollectionStore instance = CollectionStore._();

  static const String _key = 'read.collections.v1';

  SharedPreferences? _prefs;
  final List<String> _names = <String>[];

  List<String> get names => List<String>.unmodifiable(_names);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _names
      ..clear()
      ..addAll(_prefs!.getStringList(_key) ?? const <String>[]);
    notifyListeners();
  }

  Future<void> add(String name) async {
    final String value = name.trim();
    if (value.isEmpty || _names.contains(value)) return;
    _names.add(value);
    await _persist();
  }

  Future<void> rename(String from, String to) async {
    final String value = to.trim();
    if (value.isEmpty) return;
    final int index = _names.indexOf(from);
    if (index < 0) return;
    _names[index] = value;
    await _persist();
  }

  Future<void> remove(String name) async {
    if (_names.remove(name)) await _persist();
  }

  Future<void> _persist() async {
    await _prefs?.setStringList(_key, _names);
    notifyListeners();
  }
}
