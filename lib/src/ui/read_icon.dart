import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:read/src/theme/ui_mode.dart';

/// 全应用图标语义。同一个语义在两套界面语言里由不同几何绘制，
/// 避免"原版和墨水屏只是换了几张 png"。
enum ReadGlyph {
  shelf,
  sync,
  settings,
  more,
  search,
  plus,
  ellipsis,
  sort,
  grid,
  list,
  filter,
  folder,
  tag,
  wifi,
  importFile,
  scan,
  sparkle,
  close,
  check,
  chevronRight,
  chevronDown,
  arrowLeft,
  arrowUp,
  arrowDown,
  book,
  info,
  edit,
  pin,
  export,
  share,
  trash,
  download,
  cloud,
  cloudCheck,
  cloudOff,
  cloudDownload,
  image,
  camera,
  star,
  lock,
  palette,
  layers,
  wand,
  eye,
  save,
  device,
  restore,
  compare,
  clock,
  shield,
  refresh,
  toc,
  type,
  bookmark,
  headphones,
  moon,
  sun,
  note,
  play,
  pause,
  stop,
  quote,
  minus,
  cloudUpload,
  person,
}

/// 一个矢量图标。颜色默认跟随 IconTheme，尺寸默认 22。
class ReadIcon extends StatelessWidget {
  const ReadIcon(
    this.glyph, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeScale = 1,
    this.semanticLabel,
  });

  final ReadGlyph glyph;
  final double size;
  final Color? color;
  final double strokeScale;

  /// 屏幕阅读器标签。图标在 IconButton/ListTile 里时通常由父级提供语义，
  /// 裸用时可显式传入，避免 CustomPaint 图标对读屏不可见（任务 179）。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color resolved =
        color ?? IconTheme.of(context).color ?? Theme.of(context).iconTheme.color ?? Colors.black;
    final Widget icon = ListenableBuilder(
      listenable: ReadUi.instance,
      builder: (BuildContext context, Widget? _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GlyphPainter(
              glyph: glyph,
              color: resolved,
              eink: ReadUi.instance.isEink,
              strokeScale: strokeScale,
            ),
          ),
        );
      },
    );
    if (semanticLabel == null) return icon;
    return Semantics(label: semanticLabel, image: true, child: icon);
  }
}

enum _Kind { line, poly, circle, rect, arc, dot }

class _Shape {
  const _Shape.line(double x1, double y1, double x2, double y2)
      : kind = _Kind.line,
        p = const <double>[],
        a = x1,
        b = y1,
        c = x2,
        d = y2,
        radius = 0,
        filled = false;

  const _Shape.poly(List<double> points, {this.filled = false})
      : kind = _Kind.poly,
        p = points,
        a = 0,
        b = 0,
        c = 0,
        d = 0,
        radius = 0;

  const _Shape.circle(double cx, double cy, double r, {this.filled = false})
      : kind = _Kind.circle,
        p = const <double>[],
        a = cx,
        b = cy,
        c = r,
        d = 0,
        radius = 0;

  const _Shape.rect(double left, double top, double width, double height,
      {this.radius = 0, this.filled = false})
      : kind = _Kind.rect,
        p = const <double>[],
        a = left,
        b = top,
        c = width,
        d = height;

  const _Shape.arc(double cx, double cy, double r, double start, double sweep)
      : kind = _Kind.arc,
        p = const <double>[],
        a = cx,
        b = cy,
        c = r,
        d = start,
        radius = sweep,
        filled = false;

  const _Shape.dot(double cx, double cy, double r)
      : kind = _Kind.dot,
        p = const <double>[],
        a = cx,
        b = cy,
        c = r,
        d = 0,
        radius = 0,
        filled = true;

  final _Kind kind;
  final List<double> p;
  final double a, b, c, d;
  final double radius;
  final bool filled;
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.eink,
    required this.strokeScale,
  });

  final ReadGlyph glyph;
  final Color color;
  final bool eink;
  final double strokeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24 * (eink ? 0.93 : 1.0);
    canvas.save();
    canvas.translate((size.width - 24 * scale) / 2, (size.height - 24 * scale) / 2);
    canvas.scale(scale);

    // 统一线宽与视觉重量（任务 410/411）：普通版圆头略加粗，墨水屏高对比
    // 线性在细笔画下需要补偿，避免纯黑白时发虚。填充由 10% 提到 13%，
    // 让实心语义有质感又不至于脏。
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (eink ? 1.35 : 1.9) * strokeScale
      ..strokeCap = eink ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = eink ? StrokeJoin.miter : StrokeJoin.round
      ..isAntiAlias = true;
    final Paint fill = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final _Shape shape in _geometry(glyph, eink)) {
      switch (shape.kind) {
        case _Kind.line:
          canvas.drawLine(Offset(shape.a, shape.b), Offset(shape.c, shape.d), stroke);
        case _Kind.poly:
          final Path path = Path()..moveTo(shape.p[0], shape.p[1]);
          for (int i = 2; i < shape.p.length; i += 2) {
            path.lineTo(shape.p[i], shape.p[i + 1]);
          }
          if (shape.filled && !eink) canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
        case _Kind.circle:
          if (shape.filled && !eink) {
            canvas.drawCircle(Offset(shape.a, shape.b), shape.c, fill);
          }
          canvas.drawCircle(Offset(shape.a, shape.b), shape.c, stroke);
        case _Kind.rect:
          final Rect rect = Rect.fromLTWH(shape.a, shape.b, shape.c, shape.d);
          if (shape.radius > 0) {
            final RRect rr = RRect.fromRectAndRadius(
              rect,
              Radius.circular(eink ? 0.5 : shape.radius),
            );
            if (shape.filled && !eink) canvas.drawRRect(rr, fill);
            canvas.drawRRect(rr, stroke);
          } else {
            if (shape.filled && !eink) canvas.drawRect(rect, fill);
            canvas.drawRect(rect, stroke);
          }
        case _Kind.arc:
          canvas.drawArc(
            Rect.fromCircle(center: Offset(shape.a, shape.b), radius: shape.c),
            shape.d,
            shape.radius,
            false,
            stroke,
          );
        case _Kind.dot:
          if (eink) {
            canvas.drawRect(
              Rect.fromCenter(
                center: Offset(shape.a, shape.b),
                width: shape.c * 1.5,
                height: shape.c * 1.5,
              ),
              Paint()..color = color,
            );
          } else {
            canvas.drawCircle(
              Offset(shape.a, shape.b),
              shape.c,
              Paint()..color = color,
            );
          }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.eink != eink || old.strokeScale != strokeScale;
}

List<_Shape> _geometry(ReadGlyph glyph, bool eink) {
  switch (glyph) {
    case ReadGlyph.shelf:
      return eink
          ? const <_Shape>[
              _Shape.line(5, 4, 5, 20),
              _Shape.line(10, 4, 10, 20),
              _Shape.line(15, 4, 15, 20),
              _Shape.line(19.5, 6.5, 19.5, 20),
              _Shape.line(3, 20, 21, 20),
            ]
          : const <_Shape>[
              _Shape.rect(3.5, 4, 4.2, 16, radius: 1.2, filled: true),
              _Shape.rect(9.1, 4, 4.2, 16, radius: 1.2, filled: true),
              _Shape.rect(14.7, 6, 4.2, 14, radius: 1.2, filled: true),
            ];
    case ReadGlyph.sync:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[4.5, 10, 4.5, 7, 10, 7]),
              _Shape.arc(12, 12, 7.2, math.pi * 0.86, math.pi * 0.62),
              _Shape.arc(12, 12, 7.2, math.pi * 1.86, math.pi * 0.62),
              _Shape.poly(<double>[19.5, 14, 19.5, 17, 14, 17]),
            ]
          : const <_Shape>[
              _Shape.arc(12, 12, 7.4, math.pi * 0.78, math.pi * 0.72),
              _Shape.arc(12, 12, 7.4, math.pi * 1.78, math.pi * 0.72),
              _Shape.poly(<double>[5.6, 8.2, 5.2, 13.4, 10.2, 12.4]),
              _Shape.poly(<double>[18.4, 15.8, 18.8, 10.6, 13.8, 11.6]),
            ];
    case ReadGlyph.settings:
      // 两版统一为"齿轮"语义（任务 413）：墨水屏用方头高对比齿，
      // 原版用圆头弧齿，识别度一致而风格不同。
      return eink
          ? const <_Shape>[
              _Shape.circle(12, 12, 3.0),
              _Shape.line(12, 2.6, 12, 5.0),
              _Shape.line(12, 19, 12, 21.4),
              _Shape.line(2.6, 12, 5, 12),
              _Shape.line(19, 12, 21.4, 12),
              _Shape.line(5.4, 5.4, 7.1, 7.1),
              _Shape.line(16.9, 16.9, 18.6, 18.6),
              _Shape.line(18.6, 5.4, 16.9, 7.1),
              _Shape.line(7.1, 16.9, 5.4, 18.6),
            ]
          : const <_Shape>[
              _Shape.circle(12, 12, 3.1),
              _Shape.arc(12, 12, 7.2, math.pi * 0.95, math.pi * 0.72),
              _Shape.arc(12, 12, 7.2, math.pi * 1.95, math.pi * 0.72),
              _Shape.arc(12, 12, 7.2, math.pi * 0.02, math.pi * 0.7),
              _Shape.arc(12, 12, 7.2, math.pi * 1.02, math.pi * 0.7),
              _Shape.line(12, 2.6, 12, 4.6),
              _Shape.line(12, 19.4, 12, 21.4),
            ];
    case ReadGlyph.more:
      return <_Shape>[
        const _Shape.dot(5.2, 12, 1.55),
        const _Shape.dot(12, 12, 1.55),
        const _Shape.dot(18.8, 12, 1.55),
      ];
    case ReadGlyph.search:
      return eink
          ? const <_Shape>[
              _Shape.circle(10.6, 10.6, 6.2),
              _Shape.line(15.2, 15.2, 20.4, 20.4),
            ]
          : const <_Shape>[
              _Shape.circle(10.4, 10.4, 6.6, filled: true),
              _Shape.line(15.4, 15.4, 20.2, 20.2),
            ];
    case ReadGlyph.plus:
      return const <_Shape>[
        _Shape.line(12, 4.8, 12, 19.2),
        _Shape.line(4.8, 12, 19.2, 12),
      ];
    case ReadGlyph.ellipsis:
      return <_Shape>[
        const _Shape.dot(12, 5.4, 1.5),
        const _Shape.dot(12, 12, 1.5),
        const _Shape.dot(12, 18.6, 1.5),
      ];
    case ReadGlyph.sort:
      return eink
          ? const <_Shape>[
              _Shape.line(4, 7, 13, 7),
              _Shape.line(4, 12, 10, 12),
              _Shape.line(4, 17, 7, 17),
              _Shape.line(18, 4.5, 18, 19.5),
              _Shape.poly(<double>[15.4, 16.6, 18, 19.6, 20.6, 16.6]),
            ]
          : const <_Shape>[
              _Shape.line(4, 6.5, 12.5, 6.5),
              _Shape.line(4, 12, 9.5, 12),
              _Shape.line(4, 17.5, 7, 17.5),
              _Shape.line(18, 5, 18, 19),
              _Shape.poly(<double>[15, 16, 18, 19.4, 21, 16]),
            ];
    case ReadGlyph.grid:
      return <_Shape>[
        _Shape.rect(4, 4, 6.6, 6.6, radius: eink ? 0 : 1.6, filled: true),
        _Shape.rect(13.4, 4, 6.6, 6.6, radius: eink ? 0 : 1.6, filled: true),
        _Shape.rect(4, 13.4, 6.6, 6.6, radius: eink ? 0 : 1.6, filled: true),
        _Shape.rect(13.4, 13.4, 6.6, 6.6, radius: eink ? 0 : 1.6, filled: true),
      ];
    case ReadGlyph.list:
      return eink
          ? const <_Shape>[
              _Shape.line(4, 6, 20, 6),
              _Shape.line(4, 12, 20, 12),
              _Shape.line(4, 18, 20, 18),
            ]
          : <_Shape>[
              const _Shape.dot(5, 6, 1.3),
              const _Shape.dot(5, 12, 1.3),
              const _Shape.dot(5, 18, 1.3),
              const _Shape.line(8.6, 6, 20, 6),
              const _Shape.line(8.6, 12, 20, 12),
              const _Shape.line(8.6, 18, 20, 18),
            ];
    case ReadGlyph.filter:
      return const <_Shape>[
        _Shape.poly(<double>[3.6, 5.2, 20.4, 5.2, 13.8, 12.6, 13.8, 19.4, 10.2, 17.2, 10.2, 12.6]),
      ];
    case ReadGlyph.folder:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[3.5, 7, 3.5, 19.5, 20.5, 19.5, 20.5, 7, 11.5, 7, 10, 4.8, 3.5, 4.8]),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[3.4, 6.8, 10.2, 6.8, 11.8, 9.2, 20.6, 9.2, 20.6, 19.2, 3.4, 19.2]),
              _Shape.line(3.4, 7, 3.4, 6.6),
            ];
    case ReadGlyph.tag:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[4, 4, 12, 4, 20, 12, 12.4, 19.6, 4, 11.2, 4, 4]),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[3.8, 3.8, 11.6, 3.8, 20.2, 12.4, 12.6, 20, 3.8, 11.2]),
              _Shape.dot(8.4, 8.4, 1.5),
            ];
    case ReadGlyph.wifi:
      return eink
          ? const <_Shape>[
              _Shape.arc(12, 18.5, 10.5, -math.pi * 0.72, math.pi * 0.44),
              _Shape.arc(12, 18.5, 6.2, -math.pi * 0.78, math.pi * 0.56),
              _Shape.dot(12, 19, 0.9),
            ]
          : const <_Shape>[
              _Shape.arc(12, 19, 11, -math.pi * 0.7, math.pi * 0.4),
              _Shape.arc(12, 19, 6.8, -math.pi * 0.74, math.pi * 0.48),
              _Shape.circle(12, 19, 1.4, filled: true),
            ];
    case ReadGlyph.importFile:
      return const <_Shape>[
        _Shape.line(12, 3.6, 12, 13.4),
        _Shape.poly(<double>[8.6, 10, 12, 13.6, 15.4, 10]),
        _Shape.poly(<double>[4.4, 15.4, 4.4, 20.4, 19.6, 20.4, 19.6, 15.4]),
      ];
    case ReadGlyph.scan:
      return const <_Shape>[
        _Shape.poly(<double>[3.6, 8.4, 3.6, 3.6, 8.4, 3.6]),
        _Shape.poly(<double>[15.6, 3.6, 20.4, 3.6, 20.4, 8.4]),
        _Shape.poly(<double>[20.4, 15.6, 20.4, 20.4, 15.6, 20.4]),
        _Shape.poly(<double>[8.4, 20.4, 3.6, 20.4, 3.6, 15.6]),
        _Shape.line(3.6, 12, 20.4, 12),
      ];
    case ReadGlyph.sparkle:
      return <_Shape>[
        const _Shape.poly(<double>[12, 3.4, 13.9, 10.1, 20.6, 12, 13.9, 13.9, 12, 20.6, 10.1, 13.9, 3.4, 12, 10.1, 10.1], filled: true),
        const _Shape.poly(<double>[18.4, 3.2, 19.1, 5.4, 21.3, 6.1, 19.1, 6.8, 18.4, 9, 17.7, 6.8, 15.5, 6.1, 17.7, 5.4]),
      ];
    case ReadGlyph.close:
      return const <_Shape>[
        _Shape.line(6, 6, 18, 18),
        _Shape.line(18, 6, 6, 18),
      ];
    case ReadGlyph.check:
      return const <_Shape>[
        _Shape.poly(<double>[4.6, 12.4, 9.8, 17.6, 19.4, 6.4]),
      ];
    case ReadGlyph.chevronRight:
      return const <_Shape>[
        _Shape.poly(<double>[9.4, 5.4, 16, 12, 9.4, 18.6]),
      ];
    case ReadGlyph.chevronDown:
      return const <_Shape>[
        _Shape.poly(<double>[5.4, 9.4, 12, 16, 18.6, 9.4]),
      ];
    case ReadGlyph.arrowLeft:
      return const <_Shape>[
        _Shape.line(20, 12, 4.6, 12),
        _Shape.poly(<double>[10, 5.6, 4.2, 12, 10, 18.4]),
      ];
    case ReadGlyph.arrowUp:
      return const <_Shape>[
        _Shape.line(12, 20, 12, 4.6),
        _Shape.poly(<double>[5.6, 10, 12, 4.2, 18.4, 10]),
      ];
    case ReadGlyph.arrowDown:
      return const <_Shape>[
        _Shape.line(12, 4, 12, 19.4),
        _Shape.poly(<double>[5.6, 14, 12, 19.8, 18.4, 14]),
      ];
    case ReadGlyph.book:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[3.8, 5, 9.6, 5, 12, 7.2, 14.4, 5, 20.2, 5, 20.2, 19, 14.4, 19, 12, 21.2]),
              _Shape.poly(<double>[3.8, 5, 3.8, 19, 9.6, 19, 12, 21.2]),
              _Shape.line(12, 7.2, 12, 21.2),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[3.4, 4.6, 9.4, 4.6, 12, 7, 14.6, 4.6, 20.6, 4.6, 20.6, 18.6, 14.6, 18.6, 12, 20.8], filled: true),
              _Shape.poly(<double>[3.4, 4.6, 3.4, 18.6, 9.4, 18.6, 12, 20.8]),
              _Shape.line(12, 7, 12, 20.8),
            ];
    case ReadGlyph.info:
      return <_Shape>[
        const _Shape.circle(12, 12, 8.4),
        const _Shape.dot(12, 7.6, 0.95),
        const _Shape.line(12, 11, 12, 17),
      ];
    case ReadGlyph.edit:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[4, 20, 5.2, 14.6, 16.4, 3.4, 20.6, 7.6, 9.4, 18.8, 4, 20]),
              _Shape.line(14.6, 5.2, 18.8, 9.4),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[3.6, 20.4, 4.8, 14.2, 16.2, 2.8, 21.2, 7.8, 9.8, 19.2], filled: true),
              _Shape.line(14.8, 4.4, 19.6, 9.2),
              _Shape.line(4.8, 14.2, 9.8, 19.2),
            ];
    case ReadGlyph.pin:
      return eink
          ? const <_Shape>[
              _Shape.line(12, 13.6, 12, 21),
              _Shape.poly(<double>[6.4, 13.6, 17.6, 13.6, 15.4, 9.6, 15.4, 4.4, 8.6, 4.4, 8.6, 9.6]),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[7, 13.2, 17, 13.2, 15, 9.4, 15, 4.2, 9, 4.2, 9, 9.4], filled: true),
              _Shape.line(12, 13.2, 12, 20.8),
              _Shape.line(9, 4.2, 15, 4.2),
            ];
    case ReadGlyph.export:
      return const <_Shape>[
        _Shape.line(12, 15.4, 12, 3.6),
        _Shape.poly(<double>[8.2, 7.2, 12, 3.2, 15.8, 7.2]),
        _Shape.poly(<double>[4.6, 13.4, 4.6, 20.4, 19.4, 20.4, 19.4, 13.4]),
      ];
    case ReadGlyph.share:
      return <_Shape>[
        const _Shape.circle(17.6, 5.6, 2.6),
        const _Shape.circle(6.4, 12, 2.6),
        const _Shape.circle(17.6, 18.4, 2.6),
        const _Shape.line(8.7, 10.6, 15.3, 7),
        const _Shape.line(8.7, 13.4, 15.3, 17),
      ];
    case ReadGlyph.trash:
      return eink
          ? const <_Shape>[
              _Shape.line(4.4, 6.4, 19.6, 6.4),
              _Shape.line(9.6, 3.8, 14.4, 3.8),
              _Shape.rect(6.4, 6.4, 11.2, 14.2),
              _Shape.line(10, 9.4, 10, 17.6),
              _Shape.line(14, 9.4, 14, 17.6),
            ]
          : const <_Shape>[
              _Shape.line(4.2, 6.6, 19.8, 6.6),
              _Shape.poly(<double>[9.2, 6.2, 9.2, 3.6, 14.8, 3.6, 14.8, 6.2]),
              _Shape.poly(<double>[6.4, 6.6, 7.4, 20.6, 16.6, 20.6, 17.6, 6.6]),
              _Shape.line(10.4, 10.4, 10.6, 17),
              _Shape.line(13.6, 10.4, 13.4, 17),
            ];
    case ReadGlyph.download:
      return const <_Shape>[
        _Shape.line(12, 3.8, 12, 15),
        _Shape.poly(<double>[7.6, 10.8, 12, 15.2, 16.4, 10.8]),
        _Shape.poly(<double>[4.4, 16.4, 4.4, 20.4, 19.6, 20.4, 19.6, 16.4]),
      ];
    case ReadGlyph.cloud:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[7, 18.4, 4.6, 18.4, 4.6, 12, 7.2, 12, 8.4, 7.6, 14, 7.2, 16.4, 11.6, 19, 11.6, 19, 18.4, 7, 18.4]),
            ]
          : const <_Shape>[
              _Shape.arc(9, 14.4, 4.6, math.pi * 0.5, math.pi * 1.05),
              _Shape.arc(15, 12.6, 5.2, math.pi * 1.1, math.pi * 0.95),
              _Shape.arc(16.6, 16, 3.6, math.pi * 1.6, math.pi * 0.9),
              _Shape.line(8.4, 18.4, 17, 18.4),
            ];
    case ReadGlyph.cloudCheck:
      return <_Shape>[
        ..._geometry(ReadGlyph.cloud, eink),
        const _Shape.poly(<double>[9, 12.4, 11.2, 14.6, 15.4, 10.4]),
      ];
    case ReadGlyph.cloudOff:
      return <_Shape>[
        ..._geometry(ReadGlyph.cloud, eink),
        const _Shape.line(4.4, 4.4, 19.6, 19.6),
      ];
    case ReadGlyph.cloudDownload:
      return <_Shape>[
        ..._geometry(ReadGlyph.cloud, eink),
        const _Shape.line(12, 9.6, 12, 15.4),
        const _Shape.poly(<double>[9.6, 13, 12, 15.6, 14.4, 13]),
      ];
    case ReadGlyph.image:
      return <_Shape>[
        _Shape.rect(3.6, 4.4, 16.8, 15.2, radius: eink ? 0 : 2.4, filled: true),
        const _Shape.circle(8.6, 9.2, 1.7),
        const _Shape.poly(<double>[4.4, 17.4, 9.6, 12.4, 13.2, 15.6, 16, 13, 19.8, 17.2]),
      ];
    case ReadGlyph.camera:
      return <_Shape>[
        _Shape.rect(3.4, 6.6, 17.2, 13.4, radius: eink ? 0 : 2.6, filled: true),
        const _Shape.circle(12, 13, 4),
        const _Shape.poly(<double>[8.6, 6.6, 9.8, 4.2, 14.2, 4.2, 15.4, 6.6]),
      ];
    case ReadGlyph.star:
      return <_Shape>[
        _Shape.poly(
          const <double>[12, 3.4, 14.7, 9.4, 21, 10.2, 16.4, 14.6, 17.6, 20.8, 12, 17.8, 6.4, 20.8, 7.6, 14.6, 3, 10.2, 9.3, 9.4],
          filled: true,
        ),
      ];
    case ReadGlyph.lock:
      return <_Shape>[
        _Shape.rect(5, 10.6, 14, 10, radius: eink ? 0 : 2.2, filled: true),
        _Shape.arc(12, 10.6, 4.6, math.pi, math.pi),
        const _Shape.dot(12, 15.4, 1.1),
      ];
    case ReadGlyph.palette:
      return <_Shape>[
        const _Shape.circle(12, 12, 8.6),
        const _Shape.dot(8.8, 9, 1.2),
        const _Shape.dot(15.2, 9, 1.2),
        const _Shape.dot(8, 14.6, 1.2),
        _Shape.arc(12, 12, 4.4, math.pi * 0.05, math.pi * 0.55),
      ];
    case ReadGlyph.layers:
      return const <_Shape>[
        _Shape.poly(<double>[12, 3.6, 21, 8.2, 12, 12.8, 3, 8.2, 12, 3.6]),
        _Shape.poly(<double>[3, 12.4, 12, 17, 21, 12.4]),
        _Shape.poly(<double>[3, 16.4, 12, 21, 21, 16.4]),
      ];
    case ReadGlyph.wand:
      return <_Shape>[
        const _Shape.line(4, 20, 15.4, 8.6),
        const _Shape.poly(<double>[13.4, 6.6, 17.4, 10.6, 19.2, 8.8, 15.2, 4.8]),
        const _Shape.line(6.4, 5.4, 6.4, 8.6),
        const _Shape.line(4.8, 7, 8, 7),
        const _Shape.line(18.4, 15.4, 18.4, 18.6),
        const _Shape.line(16.8, 17, 20, 17),
      ];
    case ReadGlyph.eye:
      return <_Shape>[
        const _Shape.poly(<double>[2.6, 12, 7.2, 6.6, 12, 5, 16.8, 6.6, 21.4, 12, 16.8, 17.4, 12, 19, 7.2, 17.4]),
        const _Shape.circle(12, 12, 3.4),
      ];
    case ReadGlyph.save:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[4.4, 4.4, 17.4, 4.4, 19.6, 6.6, 19.6, 19.6, 4.4, 19.6, 4.4, 4.4]),
              _Shape.rect(8.4, 4.4, 7.2, 5),
              _Shape.rect(7.4, 12.4, 9.2, 7.2),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[4.2, 4.2, 16.6, 4.2, 19.8, 7.4, 19.8, 19.8, 4.2, 19.8]),
              _Shape.rect(8.2, 4.2, 7.6, 5.2, radius: 1),
              _Shape.rect(7.2, 12.2, 9.6, 7.6, radius: 1.4, filled: true),
            ];
    case ReadGlyph.device:
      return <_Shape>[
        _Shape.rect(6.6, 2.8, 10.8, 18.4, radius: eink ? 0 : 2.6, filled: true),
        const _Shape.line(10.4, 5.2, 13.6, 5.2),
        const _Shape.line(10.6, 18.4, 13.4, 18.4),
      ];
    case ReadGlyph.restore:
      return <_Shape>[
        _Shape.arc(12, 12, 7.6, math.pi * 0.7, math.pi * 1.75),
        const _Shape.poly(<double>[4.4, 8.2, 4.2, 13.2, 9.2, 12.6]),
        const _Shape.line(12, 8, 12, 12.4),
        const _Shape.line(12, 12.4, 15.2, 14.2),
      ];
    case ReadGlyph.compare:
      return eink
          ? const <_Shape>[
              _Shape.rect(3.6, 4.4, 6.8, 15.2),
              _Shape.rect(13.6, 4.4, 6.8, 15.2),
              _Shape.line(10.4, 9.4, 13.6, 9.4),
              _Shape.line(10.4, 14.4, 13.6, 14.4),
            ]
          : const <_Shape>[
              _Shape.rect(3.4, 4.4, 6.8, 15.2, radius: 1.8, filled: true),
              _Shape.rect(13.8, 4.4, 6.8, 15.2, radius: 1.8, filled: true),
              _Shape.line(10.6, 9.4, 13.4, 9.4),
              _Shape.line(10.6, 14.6, 13.4, 14.6),
            ];
    case ReadGlyph.clock:
      return <_Shape>[
        _Shape.circle(12, 12, 8.4),
        const _Shape.line(12, 7.2, 12, 12.4),
        const _Shape.line(12, 12.4, 16, 14.6),
      ];
    case ReadGlyph.shield:
      return const <_Shape>[
        _Shape.poly(<double>[12, 3.2, 19.4, 6.2, 19.4, 12.2, 12, 20.8, 4.6, 12.2, 4.6, 6.2, 12, 3.2]),
        _Shape.poly(<double>[8.8, 11.8, 11.2, 14.2, 15.4, 9.8]),
      ];
    case ReadGlyph.refresh:
      return <_Shape>[
        _Shape.arc(12, 12, 7.4, math.pi * 0.62, math.pi * 1.68),
        const _Shape.poly(<double>[4.6, 8.2, 4.4, 13.4, 9.4, 12.6]),
      ];
    case ReadGlyph.toc:
      return eink
          ? const <_Shape>[
              _Shape.line(4, 6, 20, 6),
              _Shape.line(7, 12, 20, 12),
              _Shape.line(7, 18, 20, 18),
              _Shape.dot(4.6, 12, 1),
              _Shape.dot(4.6, 18, 1),
            ]
          : const <_Shape>[
              _Shape.line(3.6, 6, 20.4, 6),
              _Shape.line(7, 12, 20.4, 12),
              _Shape.line(7, 18, 20.4, 18),
              _Shape.dot(4.8, 12, 1.2),
              _Shape.dot(4.8, 18, 1.2),
            ];
    case ReadGlyph.type:
      return const <_Shape>[
        _Shape.poly(<double>[4, 5.4, 12.4, 5.4]),
        _Shape.line(8.2, 5.4, 8.2, 18.6),
        _Shape.line(14.4, 11.4, 20.4, 11.4),
        _Shape.line(17.4, 11.4, 17.4, 18.6),
      ];
    case ReadGlyph.bookmark:
      return <_Shape>[
        _Shape.poly(<double>[6, 3.6, 18, 3.6, 18, 20.6, 12, 15.8, 6, 20.6], filled: true),
      ];
    case ReadGlyph.headphones:
      return <_Shape>[
        _Shape.arc(12, 12.4, 7.6, math.pi, math.pi),
        _Shape.rect(3.6, 12.4, 4.4, 7.4, radius: eink ? 0 : 2, filled: true),
        _Shape.rect(16, 12.4, 4.4, 7.4, radius: eink ? 0 : 2, filled: true),
      ];
    case ReadGlyph.moon:
      // 实心月牙（任务 413）：两圆求交生成的多边形，两端尖角自然。
      return <_Shape>[
        const _Shape.poly(<double>[
          13.1, 3.0, 11.2, 3.1, 9.4, 3.6, 7.7, 4.5, 6.2, 5.7, 5.1, 7.2,
          4.2, 8.9, 3.8, 10.7, 3.7, 12.6, 4.0, 14.4, 4.7, 16.2, 5.8, 17.8,
          7.1, 19.1, 8.7, 20.1, 10.5, 20.7, 12.3, 21.0, 14.2, 20.9, 16.0,
          20.4, 17.7, 19.5, 19.2, 18.3, 20.3, 16.8, 20.3, 16.8, 18.7, 17.4,
          16.9, 17.7, 15.2, 17.6, 13.5, 17.1, 12.0, 16.2, 10.7, 15.0, 9.7,
          13.6, 9.0, 11.9, 8.8, 10.2, 8.9, 8.4, 9.5, 6.8, 10.4, 5.2, 11.6,
          4.0, 13.1, 3.0,
        ], filled: true),
      ];
    case ReadGlyph.sun:
      return <_Shape>[
        const _Shape.circle(12, 12, 4.6),
        const _Shape.line(12, 2.4, 12, 5),
        const _Shape.line(12, 19, 12, 21.6),
        const _Shape.line(2.4, 12, 5, 12),
        const _Shape.line(19, 12, 21.6, 12),
        const _Shape.line(5.2, 5.2, 7, 7),
        const _Shape.line(17, 17, 18.8, 18.8),
        const _Shape.line(18.8, 5.2, 17, 7),
        const _Shape.line(7, 17, 5.2, 18.8),
      ];
    case ReadGlyph.note:
      return <_Shape>[
        _Shape.rect(4.4, 3.6, 15.2, 16.8, radius: eink ? 0 : 2.2, filled: true),
        const _Shape.line(8, 8.4, 16, 8.4),
        const _Shape.line(8, 12.4, 16, 12.4),
        const _Shape.line(8, 16.4, 13, 16.4),
      ];
    case ReadGlyph.play:
      return eink
          ? const <_Shape>[
              _Shape.poly(<double>[7.8, 5.2, 7.8, 18.8, 18.6, 12]),
            ]
          : const <_Shape>[
              _Shape.poly(<double>[7.2, 4.8, 7.2, 19.2, 19.4, 12], filled: true),
            ];
    case ReadGlyph.pause:
      return const <_Shape>[
        _Shape.rect(7.4, 5, 3.6, 14, filled: true),
        _Shape.rect(13, 5, 3.6, 14, filled: true),
      ];
    case ReadGlyph.stop:
      return <_Shape>[
        _Shape.rect(7.4, 7.4, 9.2, 9.2, radius: eink ? 0 : 1.6, filled: true),
      ];
    case ReadGlyph.quote:
      // 双引号（任务 413）：两个逗号形引号，避免误读为"快退"。
      return eink
          ? const <_Shape>[
              _Shape.circle(8.4, 9.2, 2.0),
              _Shape.line(9.4, 11.0, 6.6, 17.6),
              _Shape.circle(16.4, 9.2, 2.0),
              _Shape.line(17.4, 11.0, 14.6, 17.6),
            ]
          : const <_Shape>[
              _Shape.circle(8.4, 9.2, 2.1, filled: true),
              _Shape.line(9.4, 11.0, 6.6, 17.6),
              _Shape.circle(16.4, 9.2, 2.1, filled: true),
              _Shape.line(17.4, 11.0, 14.6, 17.6),
            ];
    case ReadGlyph.minus:
      return const <_Shape>[
        _Shape.line(5, 12, 19, 12),
      ];
    case ReadGlyph.cloudUpload:
      return <_Shape>[
        ..._geometry(ReadGlyph.cloud, eink),
        const _Shape.line(12, 15.6, 12, 9.4),
        const _Shape.poly(<double>[9.6, 12, 12, 9.2, 14.4, 12]),
      ];
    case ReadGlyph.person:
      return <_Shape>[
        const _Shape.circle(12, 7.8, 3.6),
        _Shape.arc(12, 18.4, 6.2, math.pi, math.pi),
      ];
  }
}
