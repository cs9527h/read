# 视觉审核产物（v0.9.0）

本目录保存用 Flutter 真实渲染（`flutter test` + 测试框架光栅化）得到的图标与主题总览图，
用于任务书 424「视觉重构必须基于真实 Flutter 页面截图审核」。

- `glyphs_classic.png`：原版全部图标语义的真实渲染总览。
- `glyphs_eink.png`：墨水屏版全部图标语义的真实渲染总览。
- `eink_theme_gallery.png`：墨水屏主题组件（按钮/开关/复选/单选/滑块/进度/卡片）真实渲染。

说明：测试环境使用无中文字形的测试字体，故图中文字显示为方块；真实 App 使用系统中文字体，
不影响图标与配色的审核结论。生成脚本保留在 `test/glyph_gallery_test.dart` 与
`test/eink_theme_test.dart`（改为烟雾测试以保证 CI 跨 Flutter 版本稳定）。
