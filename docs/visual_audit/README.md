# 视觉审核产物

本目录保存用 Flutter 真实渲染（`flutter test` + 测试框架光栅化）得到的界面图，
不是设计稿、不是效果图。

## v1.1.0

- `reader_page.png`：阅读页真实渲染（412×915 逻辑像素，2 倍密度，Noto Sans CJK）。
  用于审核标题层级、行距、首行缩进、段间距、页脚位置，确认正文未被裁切或遮挡。
  生成方式：`flutter test tool/render_audit_test.dart --update-goldens`
  （放在 `tool/` 而非 `test/`，避免 CI 因字体版本差异产生像素断言失败）。

## v0.9.0

- `glyphs_classic.png`：原版全部图标语义的真实渲染总览。
- `glyphs_eink.png`：墨水屏版全部图标语义的真实渲染总览。
- `eink_theme_gallery.png`：墨水屏主题组件（按钮/开关/复选/单选/滑块/进度/卡片）真实渲染。

说明：图标总览图使用测试默认字体，图中英文标签可能显示异常，不影响图标造型审核；
`reader_page.png` 已加载系统中文字体，中文正常显示。
