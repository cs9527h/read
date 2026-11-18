import 'package:flutter/material.dart';
import 'package:read/src/version.dart';
import 'package:read/src/theme.dart';

/// A concise offline history of *published* releases. Append a verified entry
/// on every release; unreleased work should not appear in the installed log.
class ReadReleaseNote {
  const ReadReleaseNote(this.version, this.date, this.changes);

  final String version;
  final String date;
  final List<String> changes;
}

const List<ReadReleaseNote> readReleaseNotes = <ReadReleaseNote>[
  ReadReleaseNote('2.3.0', '2026-11-18', <String>[
    '改善 S3 上传兼容性和跨设备密钥迁移。',
    '完善同步分页及数据一致性检查。',
  ]),
  ReadReleaseNote('2.2.0', '2026-11-17', <String>[
    '改进同步操作与错误提示。',
    '优化阅读界面和在线封面搜索。',
  ]),
  ReadReleaseNote('2.1.0', '2026-11-17', <String>[
    '增强本地数据、备份和 Wi-Fi 传书安全。',
    '修复阅读统计，加入诊断与反馈入口。',
  ]),
  ReadReleaseNote('2.0.0', '2026-11-17', <String>[
    '整合为单一手机版，墨水屏模式内置。',
    '完善较低版本 Android 设备的适配。',
  ]),
  ReadReleaseNote('1.1.1', '2026-11-17', <String>[
    '修复部分 EPUB 正文与章节处理问题。',
  ]),
  ReadReleaseNote('1.1.0', '2026-11-16', <String>[
    '优化阅读工具栏和跨章阅读体验。',
    '修复分章、高亮及部分同步问题。',
  ]),
  ReadReleaseNote('1.0.0', '2026-11-16', <String>[
    '进一步简化应用图标并增加屏幕预设。',
  ]),
  ReadReleaseNote('0.9.0', '2026-11-16', <String>[
    '调整应用图标并优化墨水屏主题。',
  ]),
];

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ReadPalette palette = ReadPalette.of(context);
    final Color background = palette.background;
    final Color surface = palette.surface;
    final Color ink = palette.ink;
    final Color muted = palette.muted;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: ink,
        title: const Text('更新日志', style: TextStyle(fontSize: 19)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        itemCount: readReleaseNotes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final ReadReleaseNote note = readReleaseNotes[index];
          return RepaintBoundary(
            child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.outline, width: 0.7),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text('Read ${note.version}',
                          style: const TextStyle(
                              color: ink, fontSize: 16,
                              fontWeight: FontWeight.w600))),
                      if (note.version == appVersion)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.accent, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            child: Text('当前版本',
                                style: TextStyle(
                                    color: palette.accent, fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(note.date,
                      style: const TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  for (final String change in note.changes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('· $change',
                          style: const TextStyle(
                              color: ink, fontSize: 13.5, height: 1.5)),
                    ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}
