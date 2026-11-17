import 'dart:convert';

/// 阅读配色主题。内置 6 套，可另建自定义主题。
class ReaderTheme {
  const ReaderTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.background,
    required this.foreground,
    required this.secondary,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final bool isDark;
  final int background;
  final int foreground;
  final int secondary;
  final bool builtIn;

  ReaderTheme copyWith({
    String? name,
    bool? isDark,
    int? background,
    int? foreground,
    int? secondary,
  }) =>
      ReaderTheme(
        id: id,
        name: name ?? this.name,
        isDark: isDark ?? this.isDark,
        background: background ?? this.background,
        foreground: foreground ?? this.foreground,
        secondary: secondary ?? this.secondary,
        builtIn: builtIn,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'isDark': isDark,
        'background': background,
        'foreground': foreground,
        'secondary': secondary,
      };

  static ReaderTheme fromJson(Map<String, dynamic> json) => ReaderTheme(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '自定义主题',
        isDark: json['isDark'] == true,
        background: (json['background'] as num).toInt(),
        foreground: (json['foreground'] as num).toInt(),
        secondary: (json['secondary'] as num?)?.toInt() ?? 0xFF888888,
      );

  String encode() => jsonEncode(toJson());
}

/// 内置主题：白、灰白、米黄、护眼绿、深灰、纯黑。
const List<ReaderTheme> kBuiltInThemes = <ReaderTheme>[
  ReaderTheme(
    id: 'paper',
    name: '纸白',
    isDark: false,
    background: 0xFFFBF8F1,
    foreground: 0xFF26231E,
    secondary: 0xFF7C756A,
    builtIn: true,
  ),
  ReaderTheme(
    id: 'gray',
    name: '灰白',
    isDark: false,
    background: 0xFFF1F2F3,
    foreground: 0xFF232426,
    secondary: 0xFF7C8085,
    builtIn: true,
  ),
  ReaderTheme(
    id: 'sepia',
    name: '米黄',
    isDark: false,
    background: 0xFFF5EFE1,
    foreground: 0xFF41382B,
    secondary: 0xFF8C8170,
    builtIn: true,
  ),
  ReaderTheme(
    id: 'green',
    name: '护眼绿',
    isDark: false,
    background: 0xFFE3EFE3,
    foreground: 0xFF22301F,
    secondary: 0xFF5F7459,
    builtIn: true,
  ),
  ReaderTheme(
    id: 'darkGray',
    name: '深灰',
    isDark: true,
    background: 0xFF232426,
    foreground: 0xFFC7C9CB,
    secondary: 0xFF8A8D90,
    builtIn: true,
  ),
  ReaderTheme(
    id: 'night',
    name: '纯黑',
    isDark: true,
    background: 0xFF000000,
    foreground: 0xFFB4B6B9,
    secondary: 0xFF6E7174,
    builtIn: true,
  ),
];

ReaderTheme? builtInThemeById(String id) {
  for (final ReaderTheme theme in kBuiltInThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}
