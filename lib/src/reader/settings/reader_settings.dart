import 'dart:convert';

/// 阅读设置的默认值。所有键都在这里出现一次，缺键时用默认值补齐。
const Map<String, Object?> kReaderDefaults = <String, Object?>{
  // 字体
  'fontFamily': null, // null = 系统字体
  'fontSize': 18.0,
  'fontWeight': 400,
  'letterSpacing': 0.2,
  'wordSpacing': 0.0,
  'textScaleX': 1.0,
  'lineHeight': 1.55,
  // 段落
  'paragraphSpacingBefore': 0.0,
  'paragraphSpacingAfter': 0.0,
  'indentMode': 'fixed', // none | fixed | em
  'indentChars': 2.0,
  'align': 'left', // left | center | right | justify
  'preserveBlankLines': true,
  'ignoreExtraBlankLines': false,
  'boldPattern': '',
  'bottomAlign': false,
  // 边距与布局
  'marginTop': 10.0,
  'marginBottom': 6.0,
  'marginLeft': 20.0,
  'marginRight': 20.0,
  'marginPreset': 'standard',
  'immersive': true,
  'showSystemBars': false,
  'orientation': 'system', // system | portrait | landscape
  'columns': 'auto', // auto | one | two
  'columnGap': 24.0,
  // 主题
  'themeId': 'paper',
  'textColor': null,
  'backgroundColor': null,
  'bgImagePath': null,
  'bgImageFit': 'cover', // cover | contain | fill | center
  'bgImageOpacity': 1.0,
  'bgImageDim': 0.0,
  'followSystemTheme': false,
  'dayThemeId': 'paper',
  'nightThemeId': 'night',
  // 页眉页脚
  'headerShow': false,
  'headerLeft': '{chapter}',
  'headerCenter': '',
  'headerRight': '{time}',
  'headerFontSize': 11.0,
  'headerFontFamily': null,
  'headerColor': null,
  'headerOpacity': 0.55,
  'footerShow': true,
  'footerLeft': '{book}',
  'footerCenter': '',
  'footerRight': '{page}/{pages} · {percent}',
  'footerFontSize': 11.0,
  'footerFontFamily': null,
  'footerColor': null,
  'footerOpacity': 0.55,
  'footerProgressBar': false,
  // 章节标题
  'titleFontSize': 20.0,
  'titleFontFamily': null,
  'titleWeight': 600,
  'titleColor': null,
  'titleAlign': 'left',
  'titleTemplate': 'plain', // plain | centered | divider | none
  'titleGapTop': 4.0,
  'titleGapBottom': 18.0,
  'titleNumberNewLine': false,
  'chapterStartBlank': 0.0,
  // 辅助线
  'guideShow': false,
  'guideStyle': 'solid', // solid | dashed
  'guideThickness': 0.5,
  'guideOpacity': 0.12,
  'guideColor': null,
  // 翻页与交互
  'pageTurnMode': 'slide', // cover | slide | none | scroll
  'animationMs': 240,
  'autoTurn': false,
  'autoTurnSeconds': 30,
  'tapLeft': 'prev',
  'tapCenter': 'menu',
  'tapRight': 'next',
  'volumeKeys': false,
  'reverseDirection': false,
  // 显示
  'brightness': 1.0,
  'followSystemBrightness': true,
  'minimalMode': false,
  'bottomActions': 'toc,bookmark,settings',
};

/// Validate untrusted layout JSON before persisting it. The reader uses
/// strongly typed getters; a string in a numeric field must not reach them.
Map<String, Object?> validatedReaderSettingsMap(Map<String, dynamic> input) {
  final result = <String, Object?>{};
  for (final entry in input.entries) {
    final key = entry.key;
    if (!kReaderDefaults.containsKey(key)) continue;
    final value = entry.value;
    final fallback = kReaderDefaults[key];
    if (value == null) {
      if (fallback != null) {
        throw FormatException('配置 $key 不能为空');
      }
      result[key] = null;
    } else if (fallback is bool) {
      if (value is! bool) throw FormatException('配置 $key 必须是开关');
      result[key] = value;
    } else if (fallback is int) {
      if (value is! num || !value.isFinite) {
        throw FormatException('配置 $key 必须是有效整数');
      }
      final n = value.toInt();
      if (n < 0 || n > 1000000) {
        throw FormatException('配置 $key 超出范围');
      }
      result[key] = n;
    } else if (fallback is double) {
      if (value is! num || !value.isFinite) {
        throw FormatException('配置 $key 必须是有效数值');
      }
      final n = value.toDouble();
      if (n < -1000 || n > 10000) {
        throw FormatException('配置 $key 超出范围');
      }
      result[key] = n;
    } else if (fallback is String) {
      if (value is! String || value.length > 1024) {
        throw FormatException('配置 $key 必须是有效文本');
      }
      result[key] = value;
    } else {
      // Nullable defaults need key-specific checking; a string in
      // textColor is as dangerous as a string in fontSize.
      const colorKeys = <String>{
        'textColor', 'backgroundColor', 'headerColor', 'footerColor',
        'titleColor', 'guideColor',
      };
      const pathKeys = <String>{
        'fontFamily', 'titleFontFamily', 'bgImagePath',
        'headerFontFamily', 'footerFontFamily',
      };
      if (colorKeys.contains(key) &&
          value is int && value >= 0 && value <= 0xFFFFFFFF) {
        result[key] = value;
      } else if (pathKeys.contains(key) &&
          value is String && value.length <= 1024) {
        result[key] = value;
      } else {
        throw FormatException('配置 $key 类型不支持');
      }
    }
  }
  // Reject settings that would cause invalid dimensions or broken indexes.
  final fontSize = result['fontSize'];
  if (fontSize is num && (fontSize < 8 || fontSize > 72)) {
    throw const FormatException('字体大小必须在 8–72 之间');
  }
  final lineHeight = result['lineHeight'];
  if (lineHeight is num && (lineHeight < 0.6 || lineHeight > 4)) {
    throw const FormatException('行距超出安全范围');
  }
  for (final field in const ['fontWeight', 'titleWeight']) {
    final weight = result[field];
    if (weight is num && (weight < 100 || weight > 900 ||
        weight.toInt() % 100 != 0)) {
      throw FormatException('配置 $field 不是有效字体粗细');
    }
  }
  for (final field in const [
    'marginTop', 'marginBottom', 'marginLeft', 'marginRight',
  ]) {
    final margin = result[field];
    if (margin is num && (margin < 0 || margin > 300)) {
      throw FormatException('配置 $field 超出合理页边距');
    }
  }
  return result;
}

/// 不可变的阅读设置；内部用 Map 存放，便于合并「全局 → 主题 → 本书」。
class ReaderSettings {
  ReaderSettings([Map<String, Object?> raw = const <String, Object?>{}])
      : _raw = Map<String, Object?>.unmodifiable(<String, Object?>{
          ...kReaderDefaults,
          ...raw,
        });

  final Map<String, Object?> _raw;

  Map<String, Object?> toJson() => Map<String, Object?>.from(_raw);

  Object? operator [](String key) => _raw[key];

  ReaderSettings patch(Map<String, Object?> values) =>
      ReaderSettings(<String, Object?>{..._raw, ...values});

  /// 相对 [base] 的差异，用于「本书覆盖」只保存用户真正改过的键。
  Map<String, Object?> diffFrom(ReaderSettings base) {
    final Map<String, Object?> out = <String, Object?>{};
    for (final String key in _raw.keys) {
      if (jsonEncode(_raw[key]) != jsonEncode(base._raw[key])) {
        out[key] = _raw[key];
      }
    }
    return out;
  }

  // 字体
  String? get fontFamily => _raw['fontFamily'] as String?;
  double get fontSize => (_raw['fontSize'] as num).toDouble();
  int get fontWeight => (_raw['fontWeight'] as num).toInt();
  double get letterSpacing => (_raw['letterSpacing'] as num).toDouble();
  double get wordSpacing => (_raw['wordSpacing'] as num).toDouble();
  double get textScaleX => (_raw['textScaleX'] as num).toDouble();
  double get lineHeight => (_raw['lineHeight'] as num).toDouble();

  // 段落
  double get paragraphSpacingBefore =>
      (_raw['paragraphSpacingBefore'] as num).toDouble();
  double get paragraphSpacingAfter =>
      (_raw['paragraphSpacingAfter'] as num).toDouble();
  String get indentMode => _raw['indentMode'] as String;
  double get indentChars => (_raw['indentChars'] as num).toDouble();
  String get align => _raw['align'] as String;
  bool get preserveBlankLines => _raw['preserveBlankLines'] == true;
  bool get ignoreExtraBlankLines => _raw['ignoreExtraBlankLines'] == true;
  String get boldPattern => _raw['boldPattern'] as String;
  bool get bottomAlign => _raw['bottomAlign'] == true;

  // 边距与布局
  double get marginTop => (_raw['marginTop'] as num).toDouble();
  double get marginBottom => (_raw['marginBottom'] as num).toDouble();
  double get marginLeft => (_raw['marginLeft'] as num).toDouble();
  double get marginRight => (_raw['marginRight'] as num).toDouble();
  String get marginPreset => _raw['marginPreset'] as String;
  bool get immersive => _raw['immersive'] == true;
  bool get showSystemBars => _raw['showSystemBars'] == true;
  String get orientation => _raw['orientation'] as String;
  String get columns => _raw['columns'] as String;
  double get columnGap => (_raw['columnGap'] as num).toDouble();

  // 主题
  String get themeId => _raw['themeId'] as String;
  int? get textColor => _raw['textColor'] as int?;
  int? get backgroundColor => _raw['backgroundColor'] as int?;
  String? get bgImagePath => _raw['bgImagePath'] as String?;
  String get bgImageFit => _raw['bgImageFit'] as String;
  double get bgImageOpacity => (_raw['bgImageOpacity'] as num).toDouble();
  double get bgImageDim => (_raw['bgImageDim'] as num).toDouble();
  bool get followSystemTheme => _raw['followSystemTheme'] == true;
  String get dayThemeId => _raw['dayThemeId'] as String;
  String get nightThemeId => _raw['nightThemeId'] as String;

  // 页眉页脚
  bool get headerShow => _raw['headerShow'] == true;
  String get headerLeft => _raw['headerLeft'] as String;
  String get headerCenter => _raw['headerCenter'] as String;
  String get headerRight => _raw['headerRight'] as String;
  double get headerFontSize => (_raw['headerFontSize'] as num).toDouble();
  String? get headerFontFamily => _raw['headerFontFamily'] as String?;
  int? get headerColor => _raw['headerColor'] as int?;
  double get headerOpacity => (_raw['headerOpacity'] as num).toDouble();
  bool get footerShow => _raw['footerShow'] == true;
  String get footerLeft => _raw['footerLeft'] as String;
  String get footerCenter => _raw['footerCenter'] as String;
  String get footerRight => _raw['footerRight'] as String;
  double get footerFontSize => (_raw['footerFontSize'] as num).toDouble();
  String? get footerFontFamily => _raw['footerFontFamily'] as String?;
  int? get footerColor => _raw['footerColor'] as int?;
  double get footerOpacity => (_raw['footerOpacity'] as num).toDouble();
  bool get footerProgressBar => _raw['footerProgressBar'] == true;

  // 章节标题
  double get titleFontSize => (_raw['titleFontSize'] as num).toDouble();
  String? get titleFontFamily => _raw['titleFontFamily'] as String?;
  int get titleWeight => (_raw['titleWeight'] as num).toInt();
  int? get titleColor => _raw['titleColor'] as int?;
  String get titleAlign => _raw['titleAlign'] as String;
  String get titleTemplate => _raw['titleTemplate'] as String;
  double get titleGapTop => (_raw['titleGapTop'] as num).toDouble();
  double get titleGapBottom => (_raw['titleGapBottom'] as num).toDouble();
  bool get titleNumberNewLine => _raw['titleNumberNewLine'] == true;
  double get chapterStartBlank => (_raw['chapterStartBlank'] as num).toDouble();

  // 辅助线
  bool get guideShow => _raw['guideShow'] == true;
  String get guideStyle => _raw['guideStyle'] as String;
  double get guideThickness => (_raw['guideThickness'] as num).toDouble();
  double get guideOpacity => (_raw['guideOpacity'] as num).toDouble();
  int? get guideColor => _raw['guideColor'] as int?;

  // 翻页与交互
  String get pageTurnMode => _raw['pageTurnMode'] as String;
  int get animationMs => (_raw['animationMs'] as num).toInt();
  bool get autoTurn => _raw['autoTurn'] == true;
  int get autoTurnSeconds => (_raw['autoTurnSeconds'] as num).toInt();
  String get tapLeft => _raw['tapLeft'] as String;
  String get tapCenter => _raw['tapCenter'] as String;
  String get tapRight => _raw['tapRight'] as String;
  bool get volumeKeys => _raw['volumeKeys'] == true;
  bool get reverseDirection => _raw['reverseDirection'] == true;

  // 显示
  double get brightness => (_raw['brightness'] as num).toDouble();
  bool get followSystemBrightness => _raw['followSystemBrightness'] == true;
  bool get minimalMode => _raw['minimalMode'] == true;
  List<String> get bottomActions {
    const allowed = <String>{'toc', 'bookmark', 'search', 'settings'};
    final value = (_raw['bottomActions'] as String?) ?? '';
    final selected = <String>[];
    for (final action in value.split(',')) {
      if (allowed.contains(action) && !selected.contains(action)) {
        selected.add(action);
        if (selected.length == 3) break;
      }
    }
    return selected.isEmpty ? <String>['toc', 'bookmark', 'settings'] : selected;
  }

  static ReaderSettings fromJsonString(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('阅读配置不是合法 JSON 对象');
    }
    return ReaderSettings(validatedReaderSettingsMap(decoded));
  }

  String toJsonString() => jsonEncode(_raw);

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings && jsonEncode(other._raw) == jsonEncode(_raw);

  @override
  int get hashCode => jsonEncode(_raw).hashCode;
}

/// 文字颜色是否被自定义覆盖时，用于回退到主题色。
int? readNullableColor(Object? value) => value is int ? value : null;
