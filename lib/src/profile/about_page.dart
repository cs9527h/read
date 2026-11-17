import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:read/src/services/diagnostics_service.dart';
import 'package:read/src/version.dart';
import 'package:read/src/ui/read_icon.dart';

/// 关于：黑底白 logo，版本号与开源信息。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String repoUrl = 'https://github.com/cs9527h/read';

  /// QQ 群反馈入口（用户提供的官方加群链接）。
  static const String feedbackUrl = 'https://qm.qq.com/q/Yvc3ugiCoE';

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0C0C0C);
    const Color fg = Color(0xFFF2F2F2);
    const Color dim = Color(0xFF8C8C8C);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        leading: IconButton(
          icon: const ReadIcon(ReadGlyph.arrowLeft, size: 20, color: fg),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: <Widget>[
          const Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(painter: _FeatherPainter()),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'read',
              style: TextStyle(
                color: fg,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              appVersionLabel,
              style: const TextStyle(color: dim, fontSize: 13),
            ),
          ),
          const SizedBox(height: 32),
          _AboutRow(
            label: '反馈与帮助',
            value: 'QQ 群',
            onTap: () => _openFeedback(context),
          ),
          _AboutRow(
            label: '诊断日志',
            value: '仅保存在本机',
            onTap: () => _showDiagnostics(context),
          ),
          _AboutRow(
            label: '开源协议',
            value: 'MIT',
            onTap: () => _showLicense(context),
          ),
          _AboutRow(
            label: '项目地址',
            value: 'github.com/cs9527h/read',
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: repoUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制项目地址')),
              );
            },
          ),
          _AboutRow(
            label: '更新日志',
            value: '见 GitHub Releases',
            onTap: () async {
              const String url = '$repoUrl/releases';
              await Clipboard.setData(const ClipboardData(text: url));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制 Releases 地址')),
              );
            },
          ),
          _AboutRow(
            label: '检查更新',
            value: '预览版需手动安装',
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                backgroundColor: const Color(0xFF171717),
                title: const Text('检查更新', style: TextStyle(color: fg)),
                content: Text(
                  '当前为 $appVersionLabel（CI 测试签名）。'
                  '新版 APK 发布在 GitHub Releases，安装前请先卸载或确认签名一致。',
                  style: const TextStyle(color: dim, fontSize: 13, height: 1.5),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'read 是一个安静、离线优先的本地阅读器：不登录、不上传书籍、'
            '不内置示例内容。数据只存在你的设备上，同步走你自己的 WebDAV。',
            style: TextStyle(color: dim, fontSize: 12, height: 1.7),
          ),
        ],
      ),
    );
  }

  /// 优先交给系统打开 QQ；失败时给出可复制的链接，绝不假装已打开。
  Future<void> _openFeedback(BuildContext context) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(feedbackUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: feedbackUrl));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('反馈与帮助', style: TextStyle(color: Color(0xFFF2F2F2))),
        content: const Text(
          '没有找到可打开该链接的应用。链接已复制到剪贴板，'
          '可以粘贴到 QQ 或浏览器中打开。',
          style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 13, height: 1.6),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDiagnostics(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => const _DiagnosticsDialog(),
    );
  }

  void _showLicense(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Text('MIT License', style: TextStyle(color: Color(0xFFF2F2F2))),
        content: const SingleChildScrollView(
          child: Text(
            'Copyright (c) 2026 read contributors\n\n'
            'Permission is hereby granted, free of charge, to any person obtaining a copy '
            'of this software and associated documentation files (the "Software"), to deal '
            'in the Software without restriction, including without limitation the rights '
            'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
            'copies of the Software, and to permit persons to whom the Software is '
            'furnished to do so, subject to the following conditions:\n\n'
            'The above copyright notice and this permission notice shall be included in '
            'all copies or substantial portions of the Software.\n\n'
            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.',
            style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12, height: 1.6),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Text(label, style: const TextStyle(color: Color(0xFFF2F2F2), fontSize: 14)),
            const Spacer(),
            Text(value, style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 12)),
            const SizedBox(width: 6),
            const ReadIcon(ReadGlyph.chevronRight, size: 18, color: Color(0xFF8C8C8C)),
          ],
        ),
      ),
    );
  }
}

/// 手绘羽毛：只用白色描边，不依赖任何图片资源。
class _FeatherPainter extends CustomPainter {
  const _FeatherPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFF2F2F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final Path outline = Path()
      ..moveTo(size.width * 0.28, size.height * 0.86)
      ..quadraticBezierTo(size.width * 0.30, size.height * 0.34,
          size.width * 0.62, size.height * 0.16)
      ..quadraticBezierTo(size.width * 0.84, size.height * 0.24,
          size.width * 0.78, size.height * 0.50)
      ..quadraticBezierTo(size.width * 0.70, size.height * 0.76,
          size.width * 0.30, size.height * 0.88);
    canvas.drawPath(outline, paint);

    final Path stem = Path()
      ..moveTo(size.width * 0.18, size.height * 0.94)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.74,
          size.width * 0.74, size.height * 0.42);
    canvas.drawPath(stem, paint);

    for (int i = 0; i < 4; i++) {
      final double t = 0.32 + i * 0.14;
      final Path vane = Path()
        ..moveTo(size.width * (0.34 + t * 0.30), size.height * (0.72 - t * 0.42))
        ..lineTo(size.width * (0.30 + t * 0.46), size.height * (0.60 - t * 0.36));
      canvas.drawPath(vane, paint..strokeWidth = 1.4);
      paint.strokeWidth = 2.2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _DiagnosticsDialog extends StatefulWidget {
  const _DiagnosticsDialog();

  @override
  State<_DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends State<_DiagnosticsDialog> {
  @override
  Widget build(BuildContext context) {
    final DiagnosticsService diagnostics = DiagnosticsService.instance;
    return AlertDialog(
      backgroundColor: const Color(0xFF171717),
      title: const Text('诊断日志', style: TextStyle(color: Color(0xFFF2F2F2))),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: diagnostics.enabled,
                onChanged: (bool value) async {
                  await diagnostics.setEnabled(value);
                  if (mounted) setState(() {});
                },
                title: const Text('记录本地诊断',
                    style: TextStyle(color: Color(0xFFF2F2F2), fontSize: 13)),
              ),
              Text(
                '共 ${diagnostics.count} 条。只记录错误类型与时间，已脱敏，'
                '不包含书籍正文、笔记内容、密码或令牌，也不会自动上传。',
                style: const TextStyle(
                    color: Color(0xFF8C8C8C), fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 10),
              for (final DiagnosticEntry entry in diagnostics.entries.reversed.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '[${entry.kind}] ${entry.message}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFB8B8B8), fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await diagnostics.clear();
            if (mounted) setState(() {});
          },
          child: const Text('清空'),
        ),
        TextButton(
          onPressed: () async {
            final String report =
                diagnostics.exportReport(appVersion: appVersionLabel);
            await Clipboard.setData(ClipboardData(text: report));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('诊断报告已复制')),
            );
          },
          child: const Text('复制报告'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
