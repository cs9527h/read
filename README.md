# read

> **公开项目准备说明（2026-11-15）**：这是一个正在开发的 Flutter 阅读器，当前仅有 TXT 基础链路。请先阅读 [P1 源码与构建核验报告](docs/P1_AUDIT_20261115.md)；未完成的格式、真机验收和跨平台同步不得当成现成功能。发布 APK 前应验证签名、两个包名和安装升级行为。


极简全平台电子书阅读器。目标：**阅读相关功能完整保留 + 多端同步**，去掉主题商店、装饰特效、社交与会员广告。

- 平台：Android（手机）、Android（墨水屏平板独立包）、Windows
- 技术栈：Flutter 单仓多目标
- 构建：全部通过 GitHub Actions 完成（无本地 Flutter/Android SDK 环境）

## 当前进度（诚实标注）

| 模块 | 状态 |
|---|---|
| 书架 + 持久化（本地副本、删除、最近阅读排序） | 已实现 |
| TXT 文件导入（UTF-8 / GB18030 自动识别） | 已实现 |
| 纯文本阅读、测量分页、翻页、字号/行距/背景调节 | 已实现，单元测试覆盖分页 |
| 智能分章 + 目录跳转 | 已实现（标题正则识别，单元测试覆盖） |
| 阅读进度持久化（按章 + 页） | 已实现 |
| 墨水屏主题（纯黑白、无动画、禁用夜间） | 已实现 |
| 自定义正则分章、内容替换 | 未开始 |
| EPUB（文字章节模式）、Markdown、HTML 导入 | **开发分支已添加，CI 和真机待验证**；图片/版式尚不支持 |
| PDF/MOBI/AZW3/CHM/DOCX/CBZ/CBR | 未开始 |
| 标注、笔记、导出卡片 | 未开始 |
| 查词、翻译、AI 助手 | 未开始 |
| 听书（TTS）、跟读高亮 | 未开始 |
| 统计（时长/字数/热力图） | 未开始 |
| 多端同步 | **仅开发分支新增了纯内存 rev/墓碑冲突合并逻辑**；WebDAV、加密、数据库、云端双向同步均未实现 |
| Windows 客户端 | 未开始 |
| SQLite（drift）数据层 | 未开始；目前使用 JSON / SharedPreferences |

> 上表只记录真实实现。占位、模拟、静态界面不会标为完成。

## 构建

推送 `main` 或手动触发 `.github/workflows/build-android.yml`，产物为两个 APK：

- `read-android.apk`：普通 Android 版
- `read-eink.apk`：墨水屏版（`--dart-define=EINK=true`）

## 目录

```
lib/main.dart                 入口
lib/src/theme.dart            主题（含墨水屏分支）
lib/src/bookshelf/            书架
lib/src/reader/               阅读页与分页
lib/src/model/                数据模型
test/                         单元测试
.github/workflows/            CI 构建
```

## 许可

MIT

## 本轮开发验证范围

- [P2.0 阅读兼容与同步内核报告](docs/P2_0_COMPAT_SYNC_20261115.md)
- EPUB 目前是阅读顺序上的**文本提取**，不是 EPUB3 复杂图文版式引擎；不能展示 EPUB 图片、富格式表格或 DRM 内容。
- 同步模块目前只是冲突规则原型和测试；**绝不上传阅读数据到云端，也不假称已具备多设备同步**。
- 公开状态保持私有；正式 APK 仅在 GitHub Actions 成功后才能提供。
