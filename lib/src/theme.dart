import 'package:flutter/material.dart';

/// 墨水瓶模式：纯黑白、无动画、无阴影，适配 1-bit 灰阶屏。
const bool kEink = bool.fromEnvironment('EINK', defaultValue: false);

ThemeData buildTheme() {
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
        },
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF3F5D53),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, height: 1.6),
    ),
  );
}

/// 墨水屏不要翻页动画，直接切换。
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
