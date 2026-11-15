import 'package:flutter/material.dart';

const bool kEink = bool.fromEnvironment('EINK', defaultValue: false);

/// 黑白为主的中性色板：图标只用黑/灰，不使用彩色强调。
abstract final class ReadColors {
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF8A8F94);
  static const faint = Color(0xFFB7BBC0);
  static const background = Color(0xFFF5F6F7);
  static const surface = Color(0xFFFFFFFF);
  static const outline = Color(0xFFE7E9EB);
  static const inverse = Color(0xFF1B1B1B);

  // 深色
  static const darkInk = Color(0xFFECEDEE);
  static const darkMuted = Color(0xFF9BA0A5);
  static const darkBackground = Color(0xFF101112);
  static const darkSurface = Color(0xFF1A1C1E);
  static const darkOutline = Color(0xFF2A2D30);
}

@immutable
class ReadPalette {
  const ReadPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.outline,
    required this.icon,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color outline;
  final Color icon;

  static const ReadPalette light = ReadPalette(
    brightness: Brightness.light,
    background: ReadColors.background,
    surface: ReadColors.surface,
    ink: ReadColors.ink,
    muted: ReadColors.muted,
    outline: ReadColors.outline,
    icon: ReadColors.ink,
  );

  static const ReadPalette dark = ReadPalette(
    brightness: Brightness.dark,
    background: ReadColors.darkBackground,
    surface: ReadColors.darkSurface,
    ink: ReadColors.darkInk,
    muted: ReadColors.darkMuted,
    outline: ReadColors.darkOutline,
    icon: ReadColors.darkInk,
  );

  static const ReadPalette eink = ReadPalette(
    brightness: Brightness.light,
    background: Colors.white,
    surface: Colors.white,
    ink: Colors.black,
    muted: Colors.black,
    outline: Colors.black,
    icon: Colors.black,
  );

  static ReadPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// 无动画路由（墨水屏必须）。
class _NoAnimationTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

ThemeData buildTheme(Brightness brightness, {double fontScale = 1.0}) {
  if (kEink) {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black, fontSize: 18, height: 1.6),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _NoAnimationTransitionsBuilder(),
          TargetPlatform.windows: _NoAnimationTransitionsBuilder(),
        },
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }

  final ReadPalette palette =
      brightness == Brightness.dark ? ReadPalette.dark : ReadPalette.light;
  final TextTheme base = Typography.material2021().black;

  TextStyle scaled(TextStyle style, double size, FontWeight weight, {double height = 1.4}) =>
      style.copyWith(
        fontSize: size * fontScale,
        fontWeight: weight,
        height: height,
        color: palette.ink,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.ink,
      brightness: brightness,
      surface: palette.surface,
    ).copyWith(
      primary: palette.ink,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      onSurface: palette.ink,
      outline: palette.outline,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: palette.icon, size: 22),
    ),
    iconTheme: IconThemeData(color: palette.icon, size: 22),
    dividerColor: palette.outline,
    textTheme: TextTheme(
      headlineLarge: scaled(base.headlineLarge!, 30, FontWeight.w700, height: 1.2),
      headlineMedium: scaled(base.headlineMedium!, 22, FontWeight.w700),
      titleLarge: scaled(base.titleLarge!, 19, FontWeight.w600),
      titleMedium: scaled(base.titleMedium!, 16, FontWeight.w600),
      bodyLarge: scaled(base.bodyLarge!, 15, FontWeight.w400),
      bodyMedium: scaled(base.bodyMedium!, 14, FontWeight.w400),
      bodySmall: scaled(base.bodySmall!, 12, FontWeight.w400),
      labelLarge: scaled(base.labelLarge!, 14, FontWeight.w500),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}

/// 兼容旧调用的浅色主题。
ThemeData buildLightTheme({double fontScale = 1.0}) =>
    buildTheme(Brightness.light, fontScale: fontScale);
