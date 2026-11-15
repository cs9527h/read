import 'package:flutter/material.dart';

/// Read uses a deliberately quiet palette so that the books stay in focus.
abstract final class ReadColors {
  static const ink = Color(0xFF24332F);
  static const muted = Color(0xFF78847C);
  static const accent = Color(0xFF276859);
  static const background = Color(0xFFF6F6F1);
  static const paper = Color(0xFFFFFFFF);
  static const softGreen = Color(0xFFE5F0E9);
  static const outline = Color(0xFFE7EAE2);
}

/// E-Ink stays monochrome, with no card shadows or animated route transitions.
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
          TargetPlatform.windows: _NoAnimationTransitionsBuilder(),
        },
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ReadColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ReadColors.accent,
      brightness: Brightness.light,
      surface: ReadColors.paper,
    ).copyWith(
      primary: ReadColors.accent,
      onPrimary: Colors.white,
      onSurface: ReadColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ReadColors.background,
      foregroundColor: ReadColors.ink,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.25,
        color: ReadColors.ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        color: ReadColors.ink,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        color: ReadColors.ink,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.55,
        color: ReadColors.ink,
      ),
    ),
    dividerColor: ReadColors.outline,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ReadColors.paper,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: ReadColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: ReadColors.outline),
      ),
    ),
  );
}

class _NoAnimationTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
