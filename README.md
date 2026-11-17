# read

> **状态（2026-11-17）**：`2.1.0-preview`。2.1 批次完成 P0 整改：①**WiFi 传书安全**——默认关闭、6 位配对码 + 令牌、10 分钟过期、私有网段限制、限速/并发/白名单/文件头校验/临时文件清理；②**备份完整性**——逐书清单与跳过原因、写盘回读 SHA-256、恢复前预览与逐本选择、保护性快照、幂等重跑；③**SQLite 核心存储**——schema v2（高亮/同步队列/冲突）+ 旧数据增量迁移（旧键不删，可回滚）；④**启动按需解析正文**，单本书损坏不再拖垮整库；⑤**阅读统计纠错**——区分新读/重复阅读、空闲与后台不计时；⑥**QQ 反馈入口 + 本地诊断日志**（脱敏、轮转、不自动上传）。2.0 已实现单一手机版 APK、墨水屏内置、minSdk 24。1000 项对标 Reeden 逐条台账见 [docs/READ_REEDEN_1000_STATUS.md](docs/READ_REEDEN_1000_STATUS.md)，执行检查点见 [docs/REEDEN_1000_CHECKPOINT.md](docs/REEDEN_1000_CHECKPOINT.md)。**未实现/未真机验证项一律不标完成。**

极简全平台电子书阅读器。目标：**可靠的本地阅读 + 多端接着读**，去掉主题商店、社交与会员广告。

- 平台：Android 手机（内置原版/墨水屏双 UI）、Windows（实验性）
- 技术栈：Flutter 单仓多目标（Flutter 3.50 / Dart 3.14）
- 构建：GitHub Actions；仓库不保存 Android 平台壳，CI 用 `flutter create` 生成后再注入图标、签名、原生桥，并用 `tools/android/patch_android.py` 统一做低版本适配

## 已落地能力（只列真实代码）

| 模块 | 状态 |
|---|---|
| 书架、导入、持久化、最近阅读、删除 | 已实现 |
| 点封面直接阅读、长按多选、单书菜单 10 项 | 0.7.0 已实现 |
| 双界面语言（原版 / 墨水屏）+ `ReadGlyph` 语义图标 | 2.0.0 起**内置于单一手机版**，设置页运行时切换；不再发独立 eink 包 |
| 设备与数据：导入导出设置、跨设备恢复、云端数据对比 | 0.7.0 已实现 |
| 云端三态（仅本地/已同步/仅云端）+ 云朵徽章 | 0.7.0 已实现，判定见 `CloudPresence.stateFor` |
| 书籍编辑页：书名/作者/分类/评分/状态/置顶/私密/标签/书箱 + 封面菜单 8 项 | 0.7.0 已实现；AI 封面未接服务，界面标注「未接入」 |
| TXT 编码探测、分章、真实测量分页、字符锚点 | 已实现，单测覆盖 |
| EPUB / Markdown / HTML 文本章节导入 | 已实现（仅文本，非完整版式引擎） |
| 阅读设置：字体/字号/字重/字距/行距/段距/缩进/对齐/边距/页眉页脚 | 已实现，待真机走查 |
| 主题：内置 + 自定义、背景图、预设、三层配置继承 | 已实现 |
| 翻页：覆盖/平移/无动画/滚动；点击分区、自动翻页 | 已实现；仿真卷曲未做，不显示为可用 |
| 目录搜索、当前章定位、书内搜索、返回原位置 | 已实现 |
| 书内搜索历史（保存/单项删/全清/隐私开关，按书隔离） | 2.0.0 已实现，4 项单测覆盖 |
| WiFi 传书安全（配对码/令牌/限速/白名单/文件头校验） | 2.1.0 已实现，17 条真实 HTTP 测试 |
| 备份逐书清单 / 完整性校验 / 预览与选择性恢复 | 2.1.0 已实现，9 条备份测试 |
| SQLite 核心存储（进度/书签/高亮/队列/冲突）与迁移 | 2.1.0 已实现，5 条迁移测试 |
| 阅读统计区分新读与回看、空闲暂停 | 2.1.0 已实现，6 条统计测试 |
| QQ 反馈入口 + 本地诊断（脱敏、可导出） | 2.1.0 已实现，5 条诊断测试 |
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
- Android 真机安装回归、低版本真机（Android 7~9）实测、双设备同步、墨水屏设备实测。
- 百度网盘、123 云盘、OneDrive 未接入，界面不显示为“已支持”。
- 对标 Reeden 1000 条中仍有 344 未开始 / 302 部分实现，逐条见台账，未冒充通过。

## 自动化结果

- `flutter analyze --no-fatal-infos`：0 error，0 warning（146 info 为 Flutter 3.50 `material.dart` deprecated 等风格提示，CI 不视为失败）。
- `flutter test`：209/209 通过。
- 覆盖：分页与偏移映射、三层设置、章节识别（含跨行吞正文回归）、EPUB spine 正文、同步文档往返/墓碑/条件写冲突、设备原生通道契约、书籍元数据往返、书架/设置服务、书内搜索历史。
- CI（`build-android` + `build-windows-experimental`）：analyze、单测、**单一手机版 APK** 全部通过；构建后校验 APK 的 ABI（armeabi-v7a + arm64-v8a）与 minSdk。产物级结论以 CI 为准——本机开发环境无 Android SDK，`flutter build bundle` 在本机失败不具参考价值。

## 版本与发布

当前：**2.1.0-preview**。打 `v*` 标签触发 `.github/workflows/release.yml`，只构建 **`read-android.apk`** 一个手机版，附 `APK_SHA256.txt`。墨水屏已内置于该 APK（设置 → 界面版本切换），不再有 `read-eink.apk`。

CI 使用仓库内固定的预览密钥（`tools/android/read-preview.jks.b64`），预览版之间可覆盖升级（包名 `app.readen.read` 不变）；这是公开测试密钥，不能用于正式分发。

### 低版本安卓适配（2.0.0 起）

| 项 | 值 | 说明 |
|---|---|---|
| minSdk | 24（Android 7.0） | Flutter 3.50 官方下限；API 23 及以下属引擎 Unsupported，强行改会崩溃 |
| targetSdk / compileSdk | 36 | 跟随 Flutter 3.50 |
| ABI | armeabi-v7a（32 位）+ arm64-v8a（64 位） | 覆盖老机型与主流机型 |
| WebDAV http | 已放行（usesCleartextTraffic） | 修复 Android 9+ 明文同步失败 |
| 权限 | INTERNET、POST_NOTIFICATIONS | 网盘同步与听书通知 |

适配由 `tools/android/patch_android.py` 在 CI 生成壳后统一注入（幂等），两个工作流复用。

## 构建

推送 `main` 或手动触发 `.github/workflows/build-android.yml`：

- `read-android.apk`：唯一的手机版，内置原版/墨水屏双 UI

Windows 由 `.github/workflows/build-windows.yml` 构建；仓库不附真实 Windows 验收结论。

## 目录

```
lib/src/sync/            同步协议、WebDAV/S3、自动同步、备份、同步页
lib/src/reader/          阅读页、分页引擎、设置面板、PDF、原生设备桥
lib/src/services/        书架、书签、高亮、统计、字体、分章
lib/src/bookshelf/       书架与书籍详情
docs/READ_REEDEN_1000_STATUS.md/.csv  对标 Reeden 1000 项逐条台账（未完成项不冒充通过）
docs/REEDEN_1000_CHECKPOINT.md   可恢复执行检查点（环境/批次/恢复命令/下一批建议）
docs/REEDEN_PARITY_MATRIX.md / FORMAT_CAPABILITY_MATRIX.md / CLOUD_CAPABILITY_MATRIX.md  对标与能力矩阵
tools/android/patch_android.py   统一安卓低版本适配（minSdk/ABI/明文同步/权限/lint）
test/                    单元与组件测试
.github/workflows/       Android / Windows / Release
```

## 许可

MIT
