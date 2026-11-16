import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/ui/read_icon.dart';

/// 图标渲染烟雾测试：确保每个语义在两套界面语言下都能构建、不抛异常。
/// 视觉审核用的总览图见 docs/visual_audit/（由 --update-goldens 生成后归档）。
void main() {
  testWidgets('all glyphs render in both modes', (WidgetTester tester) async {
    final List<ReadGlyph> all = ReadGlyph.values;
    for (final bool eink in <bool>[false, true]) {
      final Color ink = eink ? Colors.white : const Color(0xFF1A1A18);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: eink ? Colors.black : const Color(0xFFFAF8F4),
          child: Wrap(
            children: <Widget>[
              for (final ReadGlyph g in all)
                ReadIcon(g, size: 30, color: ink, semanticLabel: g.name),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ReadIcon), findsNWidgets(all.length));
      expect(tester.takeException(), isNull);
    }
  });
}
