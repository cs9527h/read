import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:read/src/theme.dart';

/// 两套界面语言：
/// - [ReadUiMode.classic] 原版：更精致、圆角、带低对比强调；
/// - [ReadUiMode.eink] 墨水屏版：细线、单色、无填充、几何化。
///
/// 这两套不是简单换皮：图标由同一套几何语义驱动，但笔画粗细、端点、
/// 装饰细节、局部几何都不同，见 `ui/read_icon.dart`。
enum ReadUiMode { classic, eink }

class ReadUi extends ChangeNotifier {
  ReadUi._();

  static final ReadUi instance = ReadUi._();

  static const String prefsKey = 'read.ui.mode.v1';

  ReadUiMode _mode = kEink ? ReadUiMode.eink : ReadUiMode.classic;

  ReadUiMode get mode => _mode;

  bool get isEink => _mode == ReadUiMode.eink;

  String get label => isEink ? '墨水屏版' : '原版';

  /// 构建变体 `--dart-define=EINK=true` 决定默认值；用户在设置里可覆盖。
  Future<void> init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(prefsKey);
    _mode = switch (stored) {
      'eink' => ReadUiMode.eink,
      'classic' => ReadUiMode.classic,
      _ => kEink ? ReadUiMode.eink : ReadUiMode.classic,
    };
  }

  Future<void> setMode(ReadUiMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, mode.name);
    notifyListeners();
  }
}
