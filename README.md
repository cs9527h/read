# read

> **状态（2026-11-16）**：`0.5.0+6` 预览版。全量同步中心（WebDAV / S3 适配、端到端加密、三方合并、墓碑、持久化队列、进度快速通道、自动同步、备份恢复、历史）已落地；阅读页具备真实选词、高亮/笔记、TTS、目录搜索、同步快捷入口。逐项证据见 [docs/V1_100_STATUS.md](docs/V1_100_STATUS.md)。**真机双设备、真实云账号与 Windows 宽屏验收尚未完成，不能宣称 100 项全部通过。**

极简全平台电子书阅读器。目标：**可靠的本地阅读 + 多端接着读**，去掉主题商店、社交与会员广告。

- 平台：Android 手机、Android 墨水屏独立包、Windows
- 技术栈：Flutter 单仓多目标
- 构建：GitHub Actions；仓库不保存 Android 平台壳，CI 用 `flutter create` 生成后再注入图标、签名与原生桥

## 已落地能力（只列真实代码）

| 模块 | 状态 |
|---|---|
| 书架、导入、持久化、最近阅读、删除 | 已实现 |
| TXT 编码探测、分章、真实测量分页、字符锚点 | 已实现，单测覆盖 |
| EPUB / Markdown / HTML 文本章节导入 | 已实现（仅文本，非完整版式引擎） |
| 阅读设置：字体/字号/字重/字距/行距/段距/缩进/对齐/边距/页眉页脚 | 已实现，待真机走查 |
| 主题：内置 + 自定义、背景图、预设、三层配置继承 | 已实现 |
| 翻页：覆盖/平移/无动画/滚动；点击分区、自动翻页 | 已实现；仿真卷曲未做，不显示为可用 |
| 目录搜索、当前章定位、书内搜索、返回原位置 | 已实现 |
| 选词、复制、高亮、笔记、删除、随书同步 | 已实现；跨页选择未做 |
| TTS：系统引擎、本页/连续、语速、暂停/继续/停止 | 已实现，待真机验收 |
| 书籍详情页：封面、格式、大小、进度、书签数、本书排版、删除 | 已实现 |
| 多端同步：WebDAV、S3 适配器、AES-256-GCM、PBKDF2、ETag/If-Match | 已实现；S3 与坚果云无真实账号联调 |
| 三方合并、冲突记录、删除墓碑、持久化重试队列 | 已实现，单测覆盖 |
| 阅读进度独立通道：开书拉取、8 秒防抖上传、自动跳转、冲突选择 | 已实现，待双设备验收 |
| 自动同步：启动/开书/关书/网络恢复/定时/仅 Wi-Fi/防抖 | 已实现，后台被杀不承诺即时 |
| 备份：本地 ZIP、恢复前快照、云端加密备份、历史 | 已实现；选择性恢复未做 |
| 图书文件同步：哈希去重、可选上传/下载、SHA-256 校验 | 已实现；48MB 单文件上限、无断点续传 |
| Android 音量键翻页、电池变量、窗口亮度 | 原生桥已合并，待真机验收 |
| 阅读统计：时长/字数/每日/连续天、摘要同步 | 已实现；跨设备会话去重未做 |
| 墨水屏黑白主题、Windows CI 构建 | 已实现；Windows 宽屏无真机验收 |

## 明确未完成

- 标签/分类同步、封面/字体/词典同步、多云盘分离存储。
- SQLite/Drift 统一数据层与旧数据迁移回滚（Drift 依赖已声明，业务未迁移）。
- 超大 TXT 分块懒加载；EPUB 图片/CSS/脚注；PDF 真机完整验收。
- 跨页选择、内容替换净化、仿真卷曲翻页、手动修正目录。
- 云端覆盖本地 / 本地覆盖云端的高风险操作。
- 双 Android、Android↔Windows、墨水屏真机验收。
- 百度网盘、123 云盘、OneDrive 未接入，界面不显示为“已支持”。

## 自动化结果

- `flutter analyze --no-fatal-infos`：0 error，0 warning，106 info（Flutter 3.50 `material.dart` deprecated 与旧 lint）。
- `flutter test --no-test-assets`：92/92 通过。
- 覆盖：分页与偏移映射、三层设置、章节识别、同步文档往返、墓碑、双方编辑、条件写冲突、损坏密文拒绝、设备原生通道契约、同步端到端上传→远端合并→本地应用。

## 版本与发布

当前：**0.5.0+6**。打 `v*` 标签触发 `.github/workflows/release.yml`，构建 `read-android.apk` 与 `read-eink.apk` 并附 `APK_SHA256.txt`。

CI 使用仓库内固定的预览密钥（`tools/android/read-preview.jks.b64`），预览版之间可覆盖升级；这是公开测试密钥，不能用于正式分发。启动图标为黑底白色羽毛，CI 复制到各 dpi。

## 构建

推送 `main` 或手动触发 `.github/workflows/build-android.yml`：

- `read-android.apk`：普通 Android
- `read-eink.apk`：墨水屏（`--dart-define=EINK=true`）

Windows 由 `.github/workflows/build-windows.yml` 构建；仓库不附真实 Windows 验收结论。

## 目录

```
lib/src/sync/            同步协议、WebDAV/S3、自动同步、备份、同步页
lib/src/reader/          阅读页、分页引擎、设置面板、PDF、原生设备桥
lib/src/services/        书架、书签、高亮、统计、字体、分章
lib/src/bookshelf/       书架与书籍详情
docs/V1_100_STATUS.md    V1.0 100 项逐项状态与证据
docs/READER_100_STATUS.md 早期阅读 100 项状态
test/                    单元与组件测试
.github/workflows/       Android / Windows / Release
```

## 许可

MIT
