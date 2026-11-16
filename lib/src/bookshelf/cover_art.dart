import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:read/src/model/book.dart';
import 'package:read/src/theme.dart';
import 'package:read/src/theme/ui_mode.dart';

/// 内置模板封面。全部由 Canvas 绘制，不依赖任何图片资源，
/// 因此离线可用、体积为零，并且黑白/彩色两套界面各有自己的版式。
class CoverTemplate {
  const CoverTemplate(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static const List<CoverTemplate> all = <CoverTemplate>[
    CoverTemplate('ink', '墨线', '细线分割，留白最多'),
    CoverTemplate('block', '色块', '大面积底色，标题下压'),
    CoverTemplate('frame', '细框', '双线边框，古典排版'),
    CoverTemplate('grid', '网格', '几何网格，现代感'),
    CoverTemplate('serif', '大字', '大字号书名，极简'),
    CoverTemplate('night', '夜色', '深底浅字，安静'),
  ];
}

const List<Color> _classicInk = <Color>[
  Color(0xFF2F4A3C),
  Color(0xFF1F2933),
  Color(0xFF5A4032),
  Color(0xFF3B4A6B),
  Color(0xFF6B4A3A),
  Color(0xFF2B2B2B),
];

Color _seedColor(String title) {
  int hash = 0;
  for (final int rune in title.runes) {
    hash = (hash * 31 + rune) & 0x7fffffff;
  }
  return _classicInk[hash % _classicInk.length];
}

/// 把模板封面渲染成 PNG，并写入应用目录，供书架持久显示。
Future<File> renderTemplateCover({
  required Book book,
  required String templateId,
  required bool eink,
}) async {
  const double width = 600;
  const double height = 900;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  _paintCover(
    canvas,
    const Size(width, height),
    title: book.title,
    author: book.author,
    templateId: templateId,
    eink: eink,
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  if (bytes == null) throw StateError('封面渲染失败');
  final Directory base = await getApplicationDocumentsDirectory();
  final Directory dir = Directory('${base.path}/covers');
  await dir.create(recursive: true);
  final File file = File('${dir.path}/${book.id}-${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file;
}

void _paintCover(
  Canvas canvas,
  Size size, {
  required String title,
  required String author,
  required String templateId,
  required bool eink,
}) {
  final Color seed = _seedColor(title);
  final Color bg = eink ? Colors.white : seed;
  final Color fg = eink ? Colors.black : Colors.white;
  final Paint bgPaint = Paint()..color = bg;
  final Rect rect = Offset.zero & size;
  canvas.drawRect(rect, bgPaint);

  void text(
    String value,
    double x,
    double y,
    double maxWidth,
    double fontSize,
    FontWeight weight, {
    Color? color,
    double height = 1.25,
    TextAlign align = TextAlign.left,
    bool serif = false,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color ?? fg,
          fontSize: fontSize,
          fontWeight: weight,
          height: height,
          fontFamily: serif ? 'serif' : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 8,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(x, y));
    painter.dispose();
  }

  final double pad = size.width * 0.10;
  final double inner = size.width - pad * 2;

  switch (templateId) {
    case 'block':
      canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.58),
        Paint()..color = eink ? Colors.white : Colors.black.withValues(alpha: 0.22),
      );
      canvas.drawRect(
        Rect.fromLTWH(pad, size.height * 0.30, inner * 0.34, 4),
        Paint()..color = fg,
      );
      text(title, pad, size.height * 0.46, inner, size.width * 0.105, FontWeight.w700);
      text(author, pad, size.height * 0.86, inner, size.width * 0.038, FontWeight.w400,
          color: fg.withValues(alpha: 0.7));
    case 'frame':
      canvas.drawRect(
        Rect.fromLTWH(pad * 0.6, pad * 0.6, size.width - pad * 1.2, size.height - pad * 1.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = fg,
      );
      canvas.drawRect(
        Rect.fromLTWH(pad * 0.6 + 10, pad * 0.6 + 10, size.width - pad * 1.2 - 20,
            size.height - pad * 1.2 - 20),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = fg.withValues(alpha: 0.45),
      );
      text(title, pad * 1.4, size.height * 0.28, size.width - pad * 2.8,
          size.width * 0.098, FontWeight.w600, align: TextAlign.center, serif: true);
      text(author, pad * 1.4, size.height * 0.78, size.width - pad * 2.8,
          size.width * 0.036, FontWeight.w400, align: TextAlign.center, serif: true,
          color: fg.withValues(alpha: 0.7));
    case 'grid':
      final Paint line = Paint()
        ..color = fg.withValues(alpha: eink ? 0.28 : 0.18)
        ..strokeWidth = 1;
      for (int i = 1; i < 6; i++) {
        final double y = size.height * i / 6;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
      for (int i = 1; i < 4; i++) {
        final double x = size.width * i / 4;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      }
      canvas.drawRect(
        Rect.fromLTWH(pad, size.height * 0.20, inner, size.height * 0.36),
        Paint()..color = eink ? Colors.white : seed.withValues(alpha: 0.92),
      );
      canvas.drawRect(
        Rect.fromLTWH(pad, size.height * 0.20, inner, size.height * 0.36),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = fg,
      );
      text(title, pad + 18, size.height * 0.26, inner - 36, size.width * 0.092,
          FontWeight.w700);
      text(author, pad, size.height * 0.86, inner, size.width * 0.036, FontWeight.w400,
          color: fg.withValues(alpha: 0.7));
    case 'serif':
      text(title, pad, size.height * 0.16, inner, size.width * 0.155, FontWeight.w700,
          height: 1.15, serif: true);
      canvas.drawLine(
        Offset(pad, size.height * 0.74),
        Offset(pad + inner * 0.28, size.height * 0.74),
        Paint()
          ..color = fg
          ..strokeWidth = 3,
      );
      text(author, pad, size.height * 0.78, inner, size.width * 0.04, FontWeight.w400,
          serif: true, color: fg.withValues(alpha: 0.72));
    case 'night':
      final Paint p = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(size.width, size.height),
          eink
              ? <Color>[Colors.white, Colors.white]
              : <Color>[seed, Color.lerp(seed, Colors.black, 0.55)!],
        );
      canvas.drawRect(rect, p);
      canvas.drawCircle(
        Offset(size.width * 0.72, size.height * 0.24),
        size.width * 0.11,
        Paint()..color = eink ? Colors.black : Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset(size.width * 0.78, size.height * 0.21),
        size.width * 0.10,
        Paint()..color = eink ? Colors.white : Color.lerp(seed, Colors.black, 0.35)!,
      );
      text(title, pad, size.height * 0.55, inner * 0.8, size.width * 0.095,
          FontWeight.w600, serif: true);
      text(author, pad, size.height * 0.84, inner, size.width * 0.036, FontWeight.w400,
          color: fg.withValues(alpha: 0.7));
    default: // ink
      canvas.drawLine(
        Offset(pad, size.height * 0.14),
        Offset(pad, size.height * 0.86),
        Paint()
          ..color = fg.withValues(alpha: 0.55)
          ..strokeWidth = 2,
      );
      text(title, pad + 22, size.height * 0.20, inner - 22, size.width * 0.10,
          FontWeight.w600, serif: true);
      text(author, pad + 22, size.height * 0.84, inner - 22, size.width * 0.034,
          FontWeight.w400, color: fg.withValues(alpha: 0.65));
  }

  if (eink) {
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black,
    );
  } else {
    // 一层很轻的纸纹，避免纯色封面看起来像色卡。
    final Paint grain = Paint()..color = Colors.white.withValues(alpha: 0.03);
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), grain);
    }
  }
}

/// 书封：优先使用用户设置的封面图，否则用当前模板的实时绘制版本。
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.templateId = 'ink',
    this.showEdge = true,
  });

  final Book book;
  final String templateId;
  final bool showEdge;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final bool eink = ReadUi.instance.isEink;
    final String? path = book.coverPath;
    final bool hasFile = path != null && File(path).existsSync();

    Widget content;
    if (hasFile) {
      content = Image.file(
        File(path),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _painted(context, eink),
      );
    } else {
      content = _painted(context, eink);
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(eink ? 0 : 5),
        child: Container(
          decoration: BoxDecoration(
            border: showEdge ? Border.all(color: eink ? Colors.black : palette.outline) : null,
            boxShadow: eink
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _painted(BuildContext context, bool eink) {
    return CustomPaint(
      painter: _CoverPainter(
        title: book.title,
        author: book.author,
        templateId: templateId,
        eink: eink,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter({
    required this.title,
    required this.author,
    required this.templateId,
    required this.eink,
  });

  final String title;
  final String author;
  final String templateId;
  final bool eink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // 模板按 600x900 设计，这里等比缩放到实际封面尺寸。
    canvas.scale(size.width / 600, size.height / 900);
    _paintCover(
      canvas,
      const Size(600, 900),
      title: title,
      author: author,
      templateId: templateId,
      eink: eink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoverPainter old) =>
      old.title != title ||
      old.author != author ||
      old.templateId != templateId ||
      old.eink != eink;
}

/// 查看大图 / 保存封面。
class CoverViewerPage extends StatelessWidget {
  const CoverViewerPage({super.key, required this.book, this.templateId = 'ink'});

  final Book book;
  final String templateId;

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('封面'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: BookCover(book: book, templateId: templateId),
          ),
        ),
      ),
    );
  }
}

/// 预置封面：直接用模板 + 当前书名生成，不写文件，零成本预览。
List<String> get coverTemplateIds =>
    CoverTemplate.all.map((CoverTemplate t) => t.id).toList(growable: false);

double coverAspectRatio(bool compact) => compact ? 0.66 : 0.70;

/// 极简的"AI 封面"占位实现：明确声明未配置，不伪造结果。
class CoverAiService {
  const CoverAiService._();

  static const bool configured = false;

  static Future<File> generate(Book book) async {
    throw UnsupportedError(
      'AI 封面尚未接入。需要配置一个图像生成服务（接口已预留），当前不会伪造封面。',
    );
  }

  static String get statusLabel =>
      configured ? '已配置' : '未配置，需要填入图像生成服务地址与密钥';

  static String get explanation =>
      '书架与编辑页都已预留 AI 封面入口。要真正生成，需要在此处接入一个图像模型服务；'
      '未配置时点击只会说明状态，不会假装生成成功。';
}

/// 删除封面文件，避免残留占空间。
Future<void> deleteCoverFile(String? path) async {
  if (path == null) return;
  final File file = File(path);
  if (await file.exists()) await file.delete();
}

/// 把用户选择的图片复制到应用目录，避免外部文件被移动后封面丢失。
Future<File> adoptCoverImage(File source, String bookId) async {
  final Directory base = await getApplicationDocumentsDirectory();
  final Directory dir = Directory('${base.path}/covers');
  await dir.create(recursive: true);
  final String ext = source.path.split('.').last.toLowerCase();
  final String safeExt = <String>['png', 'jpg', 'jpeg', 'webp'].contains(ext) ? ext : 'png';
  final File target = File('${dir.path}/$bookId-${DateTime.now().millisecondsSinceEpoch}.$safeExt');
  await source.copy(target.path);
  return target;
}

/// 网络图片：下载到临时文件后走同一条保存逻辑。
Future<File> downloadCover(String url) async {
  final Uri uri = Uri.parse(url);
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const FormatException('只支持 http/https 图片地址');
  }
  final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final HttpClientRequest request = await client.getUrl(uri);
    final HttpClientResponse response = await request.close();
    if (response.statusCode != 200) {
      throw FormatException('图片下载失败：HTTP ${response.statusCode}');
    }
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/cover-${DateTime.now().microsecondsSinceEpoch}.img');
    await response.pipe(file.openWrite());
    if (await file.length() > 12 * 1024 * 1024) {
      await file.delete();
      throw const FormatException('图片超过 12MB');
    }
    return file;
  } finally {
    client.close();
  }
}

/// 供编辑页实时预览使用。
Future<Uint8List> renderCoverPng({
  required String title,
  required String author,
  required String templateId,
  required bool eink,
}) async {
  const double width = 600;
  const double height = 900;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  _paintCover(
    canvas,
    const Size(width, height),
    title: title,
    author: author,
    templateId: templateId,
    eink: eink,
  );
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(width.toInt(), height.toInt());
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  if (data == null) throw StateError('封面渲染失败');
  return data.buffer.asUint8List();
}

/// 生成一组随机但不刺眼的主色，用于模板预览。
List<Color> get coverPalettePreview => List<Color>.generate(
    6, (int i) => _classicInk[(i + math.Random(i).nextInt(6)) % _classicInk.length]);
