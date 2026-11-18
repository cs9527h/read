import 'package:flutter/material.dart';

import 'package:read/src/theme/ui_mode.dart';

const bool kEink = bool.fromEnvironment('EINK', defaultValue: false);

/// 中性色板。原版用暖白纸感 + 一点墨绿强调；墨水屏版纯黑白、无强调色。
/// 图标仍以单色为主，强调色只用于进度、选中态等极少数地方。
abstract final class ReadColors {
  static const ink = Color(0xFF1A1A18);
  static const muted = Color(0xFF77726A);
  static const faint = Color(0xFFB4AEA3);
  static const background = Color(0xFFFAF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const outline = Color(0xFFE7E1D6);
  static const inverse = Color(0xFF1B1B1B);
  static const accent = Color(0xFF3F6B57);

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
    this.accent = ReadColors.accent,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color outline;
  final Color icon;
  final Color accent;

  static const ReadPalette light = ReadPalette(
    brightness: Brightness.light,
    background: ReadColors.background,
    surface: ReadColors.surface,
    ink: ReadColors.ink,
    muted: ReadColors.muted,
    outline: ReadColors.outline,
    icon: ReadColors.ink,
    accent: ReadColors.accent,
  );

  static const ReadPalette dark = ReadPalette(
    brightness: Brightness.dark,
    background: ReadColors.darkBackground,
    surface: ReadColors.darkSurface,
    ink: ReadColors.darkInk,
    muted: ReadColors.darkMuted,
    outline: ReadColors.darkOutline,
    icon: ReadColors.darkInk,
    accent: Color(0xFF7FA893),
  );

  static const ReadPalette eink = ReadPalette(
    brightness: Brightness.light,
    background: Colors.white,
    surface: Colors.white,
    ink: Colors.black,
    muted: Color(0xFF3A3A3A),
    outline: Color(0xFFBFBFBF),
    icon: Colors.black,
    accent: Colors.black,
  );

  /// 运行时读取界面语言：墨水屏版永远是黑白，原版跟随明暗模式。
  static ReadPalette of(BuildContext context) {
    if (ReadUi.instance.isEink) return eink;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
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

/// 墨水屏专用主题（任务 403/423/473）：
/// - 纯黑白、零阴影、零强调色，层级靠【字重 + 边框】而非灰度/颜色区分；
/// - 完整配置各组件，避免退回 Material 默认的圆角、阴影、蓝色强调；
/// - 全局无动画（路由、水波纹、滑块反馈），但通过字阶与 2px 描边保持精致。
ThemeData _buildEinkTheme({double fontScale = 1.0}) {
  const Color ink = Colors.black;
  const Color paper = Colors.white;
  final TextTheme base = Typography.material2021().black;
  TextStyle ts(double size, FontWeight weight, {double height = 1.35}) =>
      base.bodyMedium!.copyWith(
        fontSize: size * fontScale,
        fontWeight: weight,
        height: height,
        color: ink,
        letterSpacing: -0.1,
      );

  final TextTheme einkText = TextTheme(
    displayLarge: ts(34, FontWeight.w700, height: 1.15),
    headlineLarge: ts(26, FontWeight.w700, height: 1.2),
    headlineMedium: ts(21, FontWeight.w700),
    headlineSmall: ts(18, FontWeight.w700),
    titleLarge: ts(18, FontWeight.w700),
    titleMedium: ts(15, FontWeight.w700),
    titleSmall: ts(14, FontWeight.w600),
    bodyLarge: ts(15, FontWeight.w400, height: 1.55),
    bodyMedium: ts(14, FontWeight.w400, height: 1.55),
    bodySmall: ts(12, FontWeight.w400, height: 1.45),
    labelLarge: ts(14, FontWeight.w600),
    labelMedium: ts(12, FontWeight.w600),
    labelSmall: ts(11, FontWeight.w500),
  );

  return ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: paper,
    canvasColor: paper,
    primaryColor: ink,
    colorScheme: const ColorScheme.light(
      primary: ink,
      onPrimary: paper,
      secondary: ink,
      onSecondary: paper,
      surface: paper,
      onSurface: ink,
      error: ink,
      onError: paper,
    ),
    textTheme: einkText,
    iconTheme: const IconThemeData(color: ink, size: 22),
    dividerColor: const Color(0xFF9A9A9A),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF9A9A9A),
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      iconTheme: const IconThemeData(color: ink, size: 24),
      actionsIconTheme: const IconThemeData(color: ink, size: 22),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: ts(19, FontWeight.w700, height: 1.2),
      shape: const Border(bottom: BorderSide(color: ink, width: 2)),
      toolbarHeight: 56,
    ),
    // 按钮：选中=实心黑底白字，次级=黑边白底直角，靠填充而非颜色表达层级。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: paper,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: paper,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: ink, width: 1.6),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),
    // 开关/复选/单选：关闭=灰描边空心，开启=实心黑，用填充区分状态。
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> s) => s.contains(WidgetState.selected) ? paper : ink,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> s) => s.contains(WidgetState.selected) ? ink : paper,
      ),
      trackOutlineColor: WidgetStateProperty.all<Color>(ink),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> s) => s.contains(WidgetState.selected) ? ink : paper,
      ),
      checkColor: WidgetStateProperty.all<Color>(paper),
      side: const BorderSide(color: ink, width: 1.6),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> s) => s.contains(WidgetState.selected) ? ink : ink,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: ink,
      inactiveTrackColor: Color(0xFFBFBFBF),
      thumbColor: ink,
      overlayColor: Color(0x1A000000),
      activeTickMarkColor: ink,
      inactiveTickMarkColor: Color(0xFF9A9A9A),
      valueIndicatorColor: ink,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ink,
      linearTrackColor: Color(0xFFBFBFBF),
      circularTrackColor: Color(0xFFBFBFBF),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: paper,
      modalBackgroundColor: paper,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: ink, width: 2),
      ),
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: ink, fontSize: 14, height: 1.5),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: paper, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ink,
      unselectedLabelColor: const Color(0xFF555555),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      indicator: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ink, width: 3)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _NoAnimationTransitionsBuilder(),
        TargetPlatform.windows: _NoAnimationTransitionsBuilder(),
      },
    ),
    splashFactory: NoSplash.splashFactory,
    tooltipTheme: TooltipThemeData(
      decoration: ShapeDecoration(
        color: ink,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      textStyle: const TextStyle(color: paper, fontSize: 12),
    ),
  );
}

ThemeData buildTheme(Brightness brightness, {double fontScale = 1.0}) {
  if (ReadUi.instance.isEink) {
    return _buildEinkTheme(fontScale: fontScale);
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

  // 强调色用温润的墨绿，而非近黑的正文色：开关、滑块、进度条、选中
  // chip 等交互态因此带上书卷气质，正文与标题仍保持近黑，可读性不变。
  // 深色模式下换成更亮的浅墨绿，保证暗背景上的对比度。
  final Color accent = brightness == Brightness.dark
      ? const Color(0xFF8FBF9F)
      : ReadColors.accent;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: palette.surface,
    ).copyWith(
      primary: accent,
      onPrimary: Colors.white,
      onSurface: palette.ink,
      outline: palette.outline,
      secondary: accent,
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
