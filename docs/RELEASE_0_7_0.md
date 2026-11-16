# Read 0.7.0 — 阅读体验主线改造

本版本围绕「点书即读、双界面语言、云端状态可信、翻页丝滑」四条主线重做书架与阅读器。
所有新增能力均为真实实现；凡未接入或受环境限制的部分，下文明确标注。

## 一、点书即读（移除继续阅读中转页）

- 书架点击封面直接进入 `ReaderPage`，恢复上次章节与页内位置，不再经过详情页 / 继续阅读页。
- 「最近在读」信息仍保留在书架顶部统计与每本书的进度条上，不再占用独立中间页。
- `BookDetailPage` 仅从单本书菜单的「信息」进入，作为纯查看页。

## 二、双界面语言：原版 / 墨水屏

- 新增 `ReadUi`（`lib/src/theme/ui_mode.dart`），运行时可切换，持久化键 `read.ui.mode.v1`。
- 构建变体：`--dart-define=EINK=true` 时默认进入墨水屏界面，用户仍可在设置里覆盖。
- 新增统一图标系统 `ReadGlyph` + `ReadIcon`（`lib/src/ui/read_icon.dart`），58 个语义位各自提供两套几何：
  - 原版：`strokeWidth 1.7`、圆头圆角、10% 填充、圆点装饰。
  - 墨水屏：`strokeWidth 1.05`、平头直角、无填充、方块锚点，面向黑白低刷新率。
- 覆盖面：底部导航、顶部操作栏、阅读器顶栏/底栏、同步页、书架菜单、编辑信息页。
- 主题层 `ReadPalette.of()` 按界面语言分支，原版改为暖白纸感配色。
- 所有原 `kEink` 编译期判断改为 `ReadUi.instance.isEink` 运行时判断，切换界面风格即时生效（覆盖书架详情页、统计、同步、设置外观、历史、存储、PDF 页）。`kEink` 仅保留为首次启动的默认值。

## 三、移除「我的」，改为同步 / 设置 / 更多

- 底部导航：书架 / 同步 / 设置 / 更多，四项均按需懒构建（`Offstage` + `TickerMode`）。
- 原「我的」下的功能按语义重新归类到「更多」：导入、整理、统计、存储与关于，无空页面、无死链。

## 四、同步页新增设备与数据工具

`lib/src/sync/data_tools_page.dart`：

1. 导出本机设置 — `FilePicker.saveFile` 落盘，展示路径并可复制 JSON。不导出任何密钥。
2. 导入本机设置 — 校验 `app=read / kind=settings / formatVersion` 后，按范围勾选覆盖（外观 / 阅读 / 书架 / 同步 / 书单）。
3. 从其他设备恢复 — 仅设置 / 仅进度 / 仅书架 / 全部。
4. 云端数据对比 — 五组：阅读进度、书签笔记、书架元数据、设置、文件状态；分组展示「仅本地 / 仅云端 / 内容不同 / 一致」，逐项可「采用云端」或「推到云端」。

## 五、书架

- 总菜单 11 项：选择、WiFi 传书、从本机导入、扫描文件夹、智能导入、创建书箱、书架设置、标签管理、分类管理、书籍排序、更多。
- 单本菜单：阅读、信息、编辑信息、置顶、导出、分享、分类、加入书箱、移除、更多（私密 / 阅读状态 / 换封面 / 查看封面 / 清除封面）。
- 交互分工：点封面立即阅读，点「…」弹菜单，长按进入多选。
- 网格改为按单元格显式宽高计算 `childAspectRatio`，封面 / 标题 / 进度 / 云朵四层位置统一。
- 排序支持最近阅读、加入时间、书名、作者、进度、评分，置顶恒优先。

## 六、书籍编辑页

- 字段：书名、作者、分类、评分（5 星）、阅读状态（未读 / 在读 / 搁置 / 读完 / 弃读）、置顶、设为私密、标签、书箱。
- 封面菜单 8 项：模板封面（6 套内置 CustomPaint 模板）、AI 生成封面、搜图设置封面、网络图片、本机图片、查看大图、保存封面、预置封面。
- 保存经 `LibraryStore.updateBook()` 校验后 `pop(true)`，书架立即刷新封面与元数据。
- 「角色」字段：本项目数据模型无角色概念，页面用说明卡片如实解释并隐藏，不做假输入框。
- AI 封面：`CoverAiService.configured == false`，调用抛 `UnsupportedError` 并在 UI 上标注「未接入」，不伪造结果。

## 七、云朵徽章只在真云端书显示

`lib/src/services/cloud_presence.dart`：

- `CloudState { localOnly, synced, cloudOnly }`。
- `synced`：云端 `files/<hash>` 存在且本地有对应文件。
- `cloudOnly`：云端有完整元数据但本地无文件 —— 显示为可下载占位书。
- `localOnly`：未配置、无 contentHash、仅同步进度、同步失败、仅缓存记录 —— 均不显示云朵。
- 刷新失败保留旧结果并记录错误，不做乐观显示。

## 八、阅读器流畅度

- 分页结果按「布局签名 + 章节」缓存（`_paginationCache`），字号 / 行距 / 主题变化才失效。
- 相邻章预取：可取消的 `Timer(80ms)`，`dispose` 时 cancel。
- 翻页与滚动不再 `setState`，页眉页脚走 `ValueNotifier<int>` 精准刷新。
- 进度写盘 400ms 防抖，切后台 / 退出时 `_flushProgress()` 立即落盘。
- 阅读控制器用 `_controllerEpoch` 重建，旧 controller 延后一帧 dispose，避免重建期间手势丢失。
- 跨章切换用 120ms 短锁，`PageView` 前置虚页 + 真实相邻章正文页，章节过渡不再白屏。
- 设置面板 `AnimationStyle(duration: 240ms, curve: easeOutCubic)`；`onRepaginate` 只清布局签名，保留已有分页。

## 验证情况（如实说明）

| 项目 | 结果 |
| --- | --- |
| `flutter analyze lib` | 0 error，0 warning（120 条 info，均为 `material.dart` deprecation 与 `prefer_const` 风格提示） |
| `flutter test --no-pub` | 119 / 119 通过 |
| `flutter build bundle` | 失败：`Android SDK could not be found` |

`flutter build bundle` 的失败原因是本机构建环境缺少 Android SDK，与代码本身无关；本仓库的 CI（`.github/workflows/build-android.yml`）会在具备 SDK 的 runner 上完成真机产物编译。此版本未取得本地产物级构建结论，发布前应以 CI 产物为准。

## 桌面图标分套

两个变体是独立包名，装在同一台手机上必须能分辨，因此启动图标也分了两套：

| 变体 | 包名 | 图标 | 资源目录 |
| --- | --- | --- | --- |
| 原版 | `app.readen.read` | 墨绿对角渐变 + 象牙羽毛 + 柔和投影 + 内嵌羽枝刻痕 | `assets/app_icon_classic` |
| 墨水屏 | `app.readen.read.eink` | 纯黑底 + 白色细线羽毛（保持原设计） | `assets/app_icon` |

`tools/android/apply_icons.sh classic|eink` 在各自 `flutter build apk` 之前写入 mipmap；参数错误或目录缺失直接 `exit 1/2`，不会静默沿用上一套。

## 已知遗留

1. AI 封面未接入任何模型服务，仅保留入口与错误提示。
2. WiFi 传书为局域网 `HttpServer`（8765–8774），未做鉴权，仅在可信局域网使用。
3. 「分享」目前复制书籍信息，没有引入系统分享插件。
4. TTS、音量键翻页、Windows 宽屏未做真机走查。
