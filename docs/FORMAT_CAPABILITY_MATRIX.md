# Read 格式支持能力矩阵

> 依据真实源码 `lib/src/formats/format_engine.dart`、`pdf_format.dart` 与测试用例生成。
> 区分「完整支持 / 有限支持 / 不支持」，不以截图或占位冒充。更新 2026-11-16。

| 格式 | 支持级别 | 解析路径 | 测试证据 | 说明与限制 |
|---|---|---|---|---|
| TXT (UTF-8/16/GB18030) | 完整 | decodeText | format_engine_test: BOM/UTF-16/损坏用例 | 单本上限 40MB；超大分段索引未实现 |
| EPUB（文字版） | 有限 | ZipDecoder + OPF spine → 纯文本 | format_engine_test: spine 正文/标题去重 | 图片/CSS/嵌入字体/复杂排版未渲染；仅文本模式 |
| Markdown | 完整 | markdown → HTML → 纯文本 | format_engine_test | 表格/代码块保留为纯文本 |
| HTML | 有限 | htmlToPlainText | format_engine_test: 排除 script/style | 移除非可信脚本，仅文本节点 |
| PDF（文字/扫描） | 有限 | pdfrx 原生渲染 | pdf_format_test | 逐页显示+位置保存；标注/文字复制/OCR 未实现 |
| MOBI / AZW / AZW3 | 不支持 | — | — | 无解析器；DRM 文件明确不支持 |
| CHM / DOCX / RTF / FB2 | 不支持 | — | — | 未实现 |
| CBZ / CBR 漫画 | 不支持 | — | — | 未实现图像阅读器 |

## 安全边界
- 单文件 40MB 上限（PDF 256MB），EPUB 解压容量 100MB 上限，防内存耗尽/压缩炸弹。
- EPUB 链接路径做越界校验（`_resolve` 拒绝 `..` 与绝对路径），HTTP 仅 HTTPS（云同步侧）。
- 未知格式直接抛出可读异常，不假装解码。

## 与 1000 项台账对应
R0121-R0160（模块 04）。该模块 0 项已验证完成 / 14 已实现待验证 / 9 部分 / 2 阻塞 / 15 未开始。
