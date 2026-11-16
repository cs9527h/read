import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 墨水屏主题组件烟雾测试：确保纯黑白主题下各状态组件能构建、不抛异常。
/// 视觉审核图见 docs/visual_audit/。
void main() {
  testWidgets('eink theme gallery', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ThemeData theme = _buildEinkForPreview();

    await tester.pumpWidget(MaterialApp(
      home: Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SizedBox(
            width: 900,
            height: 560,
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('页面标题', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('副标题 · 用字重与边框区分层级，而非灰度',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: FilledButton(onPressed: () {}, child: const Text('主要操作'))),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('次要操作'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextButton(onPressed: () {}, child: const Text('文字按钮'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        const Text('开关'),
                        const SizedBox(width: 8),
                        Switch(value: true, onChanged: (_) {}),
                        const SizedBox(width: 8),
                        Switch(value: false, onChanged: (_) {}),
                        const SizedBox(width: 20),
                        const Text('复选'),
                        const SizedBox(width: 8),
                        Checkbox(value: true, onChanged: (_) {}),
                        const SizedBox(width: 8),
                        Checkbox(value: false, onChanged: (_) {}),
                        const SizedBox(width: 20),
                        const Text('单选'),
                        const SizedBox(width: 8),
                        Radio<bool>(value: true, groupValue: true, onChanged: (_) {}),
                        const SizedBox(width: 8),
                        Radio<bool>(value: false, groupValue: true, onChanged: (_) {}),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(value: 0.62, onChanged: (_) {}),
                    LinearProgressIndicator(value: 0.6),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.6),
                      ),
                      child: const Text('描边标签（选中态靠实心填充区分）'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Center(child: Text('内容卡片 · 2px 黑描边替代阴影')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

ThemeData _buildEinkForPreview() {
  final TextTheme base = Typography.material2021().black;
  TextStyle ts(double size, FontWeight w) => base.bodyMedium!.copyWith(
      fontSize: size, fontWeight: w, color: Colors.black, letterSpacing: -0.1);
  const Color ink = Colors.black;
  return ThemeData(
    useMaterial3: false,
    colorScheme: const ColorScheme.light(primary: ink, onPrimary: Colors.white),
    textTheme: TextTheme(
      headlineMedium: ts(21, FontWeight.w700),
      bodyMedium: ts(14, FontWeight.w400),
      bodySmall: ts(12, FontWeight.w400),
    ),
    iconTheme: const IconThemeData(color: ink),
    dividerTheme: const DividerThemeData(color: Color(0xFF9A9A9A), thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink, foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), elevation: 0),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink, side: const BorderSide(color: ink, width: 1.6),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
          (s) => s.contains(WidgetState.selected) ? Colors.white : ink),
      trackColor: WidgetStateProperty.resolveWith<Color>(
          (s) => s.contains(WidgetState.selected) ? ink : Colors.white),
      trackOutlineColor: WidgetStateProperty.all<Color>(ink),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
          (s) => s.contains(WidgetState.selected) ? ink : Colors.white),
      checkColor: WidgetStateProperty.all<Color>(Colors.white),
      side: const BorderSide(color: ink, width: 1.6),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>((s) => ink),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: ink, inactiveTrackColor: Color(0xFFBFBFBF), thumbColor: ink,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ink, linearTrackColor: Color(0xFFBFBFBF),
    ),
    splashFactory: NoSplash.splashFactory,
  );
}
