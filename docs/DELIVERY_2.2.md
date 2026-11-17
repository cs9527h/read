# Read 2.2 批次交付说明（2026-11-17）

> 分支 `dev/overhaul-2.2`；基线 `main@6161010`。
> `flutter analyze` 0 error / 0 warning；`flutter test` **239/239** 通过。
> 只记录有真实代码与自动化证据的改动；未做的一律列入“未完成/阻塞”。

本批直接回应用户本轮反馈：S3 同步失败、同步残废、不要同步密码、局域网直传恢复、
阅读白边、阅读/整体/墨水屏 UI、封面联网搜索自动裁切、克制美观少无用设置。

## 一、本批完成项

| 用户反馈 | 交付 | 证据 |
|---|---|---|
| 不需要同步密码 / 同步功能残废 | 端到端加密密钥改为本机自动生成并安全存储，用户零配置；旧密码继续沿用保证历史备份可读；同步页/数据工具页移除密码输入与过时校验文案 | `sync_config.dart`/`sync_page.dart`/`data_tools_page.dart` |
| S3 同步失败 | `region='auto'/空` 回退 `us-east-1` 修复 SignatureDoesNotMatch；允许 http endpoint（本地 MinIO）；scheme 跟随 endpoint | `s3_store.dart` + 5 条测试 |
| 局域网全量/选择恢复 | `LanBackupService`（私有网段白名单、basename 校验、无密码、只读、退后台停止）+ `LanBackupClient`（连对端、拉列表、下载校验）+「局域网备份互传」页，复用逐本预览与非破坏选择性恢复 | 11 条真实 TCP 测试 |
| 阅读两边空白白边 | 默认左右边距 20→14（手机预设同步），文字更铺满 | `reader_settings.dart` + 断言 |
| 阅读界面简陋/UI 丑 | 默认主题改柔和暖纸白（背景 0xFFFBF8F1 / 正文 0xFF26231E）；章首加克制细分隔线；默认开启页脚极细进度条；渲染审核图已更新 | `reader_theme.dart`/`reader_settings.dart` + `docs/visual_audit/reader_page.png` |
| 章首/进度条溢出裁字 | 修复 divider 模板与进度条开启时分页高度预算未计入导致 RenderFlex 溢出、文字被裁两个真实 bug | `reader_engine.dart`/`reader_page.dart` + 冒烟测试 |
| 封面联网搜索 + 点封面自动裁切 | `CoverSearchService`（搜索地址、JS 抓图、候选提取去重、下载校验、3:4 居中裁切压缩）+ `CoverSearchPage` 内置浏览器（WebView 搜图、图片网格、点选即裁切设为封面，附直链降级）；编辑页空占位「搜图」改为真实功能 | 14 条测试（含 loopback HTTP） |

## 二、提交记录

- `87ea6f6` 同步可用性整改：免密码 + 局域网备份直传 + S3 修复
- `025be47` 阅读视觉整改：暖纸白主题 + 章节分隔线 + 底部进度条 + 修章首裁字 bug
- `008ff12` 易用性整改：消除阅读白边 + 内置浏览器封面搜索自动裁切

## 三、新增依赖

- `webview_flutter ^4.13.0`（内置浏览器封面搜索；minSdk 19，低于本项目 24，不抬高安装门槛）
- `image ^4.5.0`（封面下载后居中裁切与压缩）

## 四、未完成 / 需外部条件（如实记录）

- **真机验证**：WebView 封面搜索在真实 Android 7.0 设备上的图片抓取与点击裁切，需在真机确认（沙箱无法运行 WebView 平台视图）；单测覆盖了全部图片处理纯逻辑与 HTTP 下载，但未覆盖 WebView 渲染。
- **S3 实机**：region 回退与 http endpoint 已用纯逻辑测试覆盖，未接真实 S3/MinIO 账号联调。
- **局域网直传**：服务/客户端用 loopback 真实 TCP 覆盖，未做两台真机跨设备发现；采用对端输入 IP:端口方式，非自动广播发现。
- 既有未完成项保持不变：大文件分块索引、跨页选字、PDF 标注/裁边、EPUB CSS/脚注、CBZ/CBR、FB2/MOBI/AZW3、词典翻译、AI、云书库、更多云盘账号。
- 签名仍为公开预览密钥，正式分发前必须替换并规划覆盖升级。

## 五、约束保持

单 APK `app.readen.read`；内置墨水屏（运行时切换，无独立包）；minSdk 24（Android 7.0）；
升级兼容（旧 SharedPreferences 键与旧密码保留）；可回滚（每批独立提交）。
