import 'package:flutter/material.dart';

import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';
import 'package:read/src/ui/read_icon.dart';

/// 统一的底部弹层：高度自适应、可滚动、原版圆角 / 墨水屏直角。
Future<T?> showReadSheet<T>(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  String? subtitle,
  double maxHeightFactor = 0.82,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (BuildContext ctx) {
      final ReadPalette palette = ReadPalette.of(ctx);
      final bool eink = ReadUi.instance.isEink;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * maxHeightFactor,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: eink
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(22)),
          border: eink ? const Border(top: BorderSide(color: Colors.black, width: 2)) : null,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!eink)
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 9),
                    decoration: BoxDecoration(
                      color: palette.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, height: 1.5, color: palette.muted),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class SheetMenuItem extends StatelessWidget {
  const SheetMenuItem({
    super.key,
    required this.title,
    required this.onTap,
    this.glyph,
    this.subtitle,
    this.trailing,
    this.danger = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final ReadGlyph? glyph;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final Color color = !enabled
        ? palette.muted
        : danger
            ? (ReadUi.instance.isEink ? Colors.black : const Color(0xFFB4423A))
            : palette.ink;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              SizedBox(
                width: 24,
                child: ReadIcon(glyph!, size: 19, color: color),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: color,
                      fontWeight: danger ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: palette.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class SheetSeparator extends StatelessWidget {
  const SheetSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(height: 1, color: palette.outline),
    );
  }
}

class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: palette.muted,
        ),
      ),
    );
  }
}

/// 输入框弹窗。返回 null 表示取消。
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String confirm,
  String? hint,
  String? helper,
  String? initial,
  int maxLines = 1,
}) {
  final TextEditingController controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) {
      final ReadPalette palette = ReadPalette.of(ctx);
      return AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 16),
          side: ReadUi.instance.isEink
              ? const BorderSide(color: Colors.black, width: 2)
              : BorderSide.none,
        ),
        title: Text(title, style: TextStyle(fontSize: 17, color: palette.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: maxLines,
              style: TextStyle(fontSize: 15, color: palette.ink),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 10),
                  borderSide: BorderSide(color: palette.outline),
                ),
              ),
              onSubmitted: (String value) => Navigator.pop(ctx, value),
            ),
            if (helper != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(helper, style: TextStyle(fontSize: 11.5, height: 1.5, color: palette.muted)),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(confirm),
          ),
        ],
      );
    },
  );
}

/// 二次确认。
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = '确定',
  bool danger = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      final ReadPalette palette = ReadPalette.of(ctx);
      return AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReadUi.instance.isEink ? 0 : 16),
          side: ReadUi.instance.isEink
              ? const BorderSide(color: Colors.black, width: 2)
              : BorderSide.none,
        ),
        title: Text(title, style: TextStyle(fontSize: 17, color: palette.ink)),
        content: Text(message,
            style: TextStyle(fontSize: 13.5, height: 1.6, color: palette.muted)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirm,
              style: TextStyle(
                color: danger && !ReadUi.instance.isEink ? const Color(0xFFB4423A) : palette.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
