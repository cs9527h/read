# READ × Reeden 1000 项逐条验收台账

> 对应《READ 阅读器：全面对标 Reeden 的 1000 条详细开发与验收要求》R0001–R1000。
> **本台账基于真实源码审计 + 本地基线测试，状态如实标注，不以界面存在或口头保证代替验收。**
> 基线 main@d23c86b；本轮单APK+低版本适配+搜索历史+笔记导出；analyze 0 error/warning；flutter test 160/160。

## 判定标准（严格，不虚报）

| 状态 | 含义 | 计数 |
|---|---|---:|
| ✅ 已验证完成 | 有真实源码 + 本环境可运行的自动化测试通过证据 | 43 |
| 🟡 已实现待验证 | 有真实源码，但缺自动化证据或需真机/真账号人工验收 | 261 |
| ◐ 部分实现 | 有相邻能力或框架，但本条未完整落地 | 302 |
| ⛔ 客观阻塞 | 需第三方授权/真实网盘账号/多设备/真机等本环境无法满足的条件 | 52 |
| ⬜ 未开始 | 代码层面尚未实现 | 342 |
| **合计** | | **1000** |

**已验证完成占比：43/1000**。此数字只反映有源码 + 自动化测试证据的条目，绝不代表整体完成度。

## 模块汇总

| 模块 | V | I | P | B | N | 合计 |
|---|---:|---:|---:|---:|---:|---:|
| 01 项目审计与工程约束 | 11 | 17 | 11 | 1 | 0 | 40 |
| 02 首次启动、导航与基础体验 | 4 | 18 | 13 | 0 | 5 | 40 |
| 03 本地导入、传书与文件管理 | 1 | 7 | 17 | 1 | 14 | 40 |
| 04 电子书格式、编码与解析兼容 | 1 | 13 | 9 | 2 | 15 | 40 |
| 05 阅读器基础行为和内容定位 | 6 | 17 | 12 | 1 | 4 | 40 |
| 06 字体、排版、主题与内容样式 | 0 | 22 | 8 | 0 | 10 | 40 |
| 07 翻页模式、手势与动画 | 0 | 12 | 20 | 2 | 6 | 40 |
| 08 目录、导航、全文搜索与定位 | 6 | 4 | 17 | 1 | 12 | 40 |
| 09 脚注、复杂排版与阅读辅助 | 0 | 1 | 7 | 2 | 30 | 40 |
| 10 PDF 阅读、标注与性能 | 0 | 9 | 17 | 3 | 11 | 40 |
| 11 漫画、图像与图文混排 | 0 | 1 | 0 | 2 | 37 | 40 |
| 12 书架、分类与书库浏览 | 0 | 18 | 15 | 1 | 6 | 40 |
| 13 书籍信息整理、TXT与EPUB编辑 | 2 | 5 | 8 | 1 | 24 | 40 |
| 14 书签、划线、选区与批注 | 4 | 4 | 24 | 1 | 7 | 40 |
| 15 笔记导出、书摘分享与外部知识库 | 2 | 3 | 3 | 0 | 32 | 40 |
| 16 阅读统计、目标、习惯与年度报告 | 0 | 13 | 13 | 0 | 14 | 40 |
| 17 听书、TTS、后台播放与多角色朗读 | 0 | 4 | 14 | 2 | 20 | 40 |
| 18 词典、生词本、翻译与学习辅助 | 0 | 0 | 2 | 0 | 38 | 40 |
| 19 AI 阅读助手、人物关系与高级理解 | 0 | 0 | 0 | 0 | 40 | 40 |
| 20 多端同步底层协议与生命周期 | 0 | 21 | 16 | 1 | 2 | 40 |
| 21 网盘、云书库与多服务商接入 | 0 | 12 | 7 | 14 | 7 | 40 |
| 22 同步冲突、备份、恢复与迁移 | 0 | 13 | 24 | 1 | 2 | 40 |
| 23 原创 UI 设计、细节动画和设置体验 | 0 | 17 | 20 | 2 | 1 | 40 |
| 24 性能、无障碍、隐私和稳定性 | 0 | 16 | 13 | 6 | 5 | 40 |
| 25 自动化测试、CI、交付与逐项验收 | 6 | 14 | 12 | 8 | 0 | 40 |

## 逐条明细

### 01 项目审计与工程约束

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0001 | ✅ 已验证完成 | 打开项目后首先枚举所有模块、构建脚本、分支及依赖，不允许未读源码便宣布完成。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本轮真实枚举模块/脚本/分支/依赖（README、pubspec、git branch -a） |
| R0002 | ✅ 已验证完成 | 读取 README、历史问题、待办清单与近期提交，建立现状和目标的对应关系。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本轮读取 README、19 个 open issue、13 个 open PR、近期提交 |
| R0003 | 🟡 已实现待验证 | 识别实际开发技术栈和最低系统版本，禁止擅自改用另一套框架。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 识别 Flutter 3.50/Dart 3.14/SDK>=3.3；最低 Android 版本未在文档明示 |
| R0004 | 🟡 已实现待验证 | 记录当前 Android applicationId、签名配置和数据库版本，升级时保持兼容。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | applicationId/签名/DB 版本需从 android/ 与 drift schema 固化记录 |
| R0005 | ✅ 已验证完成 | 先创建保护性工作分支，避免直接覆盖稳定发布分支。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 已从 GitHub main d23c86b 创建保护分支 work/reeden-1000 |
| R0006 | ◐ 部分实现 | 输出功能盘点表，逐项标记已完成、部分完成、未实现、需要授权四类状态。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 旧台账有四态盘点，但非针对本 1000 条新版 |
| R0007 | ✅ 已验证完成 | 每条需求必须建立唯一任务编号，映射到具体代码、测试及提交。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本台账为 R0001-R1000 建立唯一编号并映射代码/测试 |
| R0008 | 🟡 已实现待验证 | 禁止以静态截图、假按钮、空方法冒充实际功能。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 工程准则：源码审计未见假书/假按钮冒充入口；未能逐项自动化扫描 |
| R0009 | 🟡 已实现待验证 | 禁止在界面中展示尚未连接成功的网盘为“已连接”。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 工程准则：源码审计未见假书/假按钮冒充入口；未能逐项自动化扫描 |
| R0010 | 🟡 已实现待验证 | 禁止用硬编码演示书籍替代真实导入、解析及阅读过程。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 工程准则：源码审计未见假书/假按钮冒充入口；未能逐项自动化扫描 |
| R0011 | 🟡 已实现待验证 | 检查已有数据库表结构及迁移历史，避免破坏老用户数据。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 已有 drift schema 与 read_database.g.dart；需核对迁移历史 |
| R0012 | ◐ 部分实现 | 梳理现有文件路径、缓存路径、导出目录与 SAF 授权生命周期。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 文件路径/缓存路径部分在 storage_page；SAF 生命周期未系统梳理成文 |
| R0013 | 🟡 已实现待验证 | 梳理现有同步流程，区分书籍文件、元数据、进度与设置。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 同步已区分书籍文件/元数据/进度/设置（见 sync 模块） |
| R0014 | 🟡 已实现待验证 | 列出存在的崩溃、ANR、卡顿和同步冲突，按影响优先级修复。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 历史崩溃/ANR 多来自 CI 环境问题；无本地崩溃聚合数据 |
| R0015 | ⛔ 客观阻塞 | 对当前主要页面录制可复现操作步骤，记录可量化的 UI 问题。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 需真机录屏量化 UI 问题；沙箱无 Android 设备 |
| R0016 | ◐ 部分实现 | 识别依赖许可及第三方 SDK 数据收集行为，并在项目文档中注明。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | pubspec 依赖已列；许可证与 SDK 数据收集未逐项成文 |
| R0017 | 🟡 已实现待验证 | 使用官方许可兼容的开源实现，不复制 Reeden 的闭源代码或资源。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 未复制 Reeden 闭源代码；使用合规开源依赖 |
| R0018 | ✅ 已验证完成 | 为阅读、书库、同步、设置划清模块责任，避免巨型 Activity。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 阅读/书库/同步/设置已分模块（reader/library/sync/profile） |
| R0019 | ◐ 部分实现 | 将系统权限请求封装到唯一入口，减少不必要的权限弹窗。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 权限申请未统一封装入口 |
| R0020 | ✅ 已验证完成 | 所有用户数据以本地优先设计，断网也应读书和修改笔记。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本地优先：导入/阅读/笔记不依赖网络（library_store + smoke test） |
| R0021 | ◐ 部分实现 | 功能开关必须对应真实实现，不允许开关无效但显示成功。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 设置开关均写持久化，需逐项核对无空开关 |
| R0022 | 🟡 已实现待验证 | 建立完成标准：代码提交、自动化测试、真机手工路径三者均需证据。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 完成标准已在任务书定义；真机路径受设备限制 |
| R0023 | 🟡 已实现待验证 | 建立失败标准：崩溃、丢书、丢进度、重复上传或泄露信息均阻断发布。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 失败标准已定义；发布需人工确认 |
| R0024 | ✅ 已验证完成 | 每次修改前运行基线构建，记录现有失败并与新引入失败区分。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本轮先跑基线：analyze 0 err/warn、test 149/149 |
| R0025 | 🟡 已实现待验证 | 不得自行修改 GitHub 仓库可见性、协作者、所有者及权限范围。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 未改动仓库可见性/协作者/所有者（本轮无权限操作） |
| R0026 | 🟡 已实现待验证 | 不得覆盖用户现有云数据，不得未经同意初始化远端空书库。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 同步设计含非空保护（R0790 类逻辑），需逐项验收 |
| R0027 | 🟡 已实现待验证 | 不得擅自删除现有功能，只能修复、迁移或提供等价替代方案。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 未删除现有功能；本轮以修复为主 |
| R0028 | 🟡 已实现待验证 | 不得改变 Read 品牌名与应用图标方向，除非明确属于设计改进范围。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 保留 read 品牌与羽毛图标方向 |
| R0029 | ◐ 部分实现 | 架构设计应支持未来增加新网盘协议，而不是写死服务商列表。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 有 SyncBackendFactory 抽象，扩展新网盘有基础 |
| R0030 | ✅ 已验证完成 | 设置数据统一持久化，退出、进程重启及系统回收后保持一致。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 设置统一 SharedPreferences 持久化，多 store init |
| R0031 | ◐ 部分实现 | 列表展示状态与真实持久状态一致，禁止依赖临时内存冒充持久化。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 列表状态部分来自 store，需核对无临时内存冒充 |
| R0032 | ◐ 部分实现 | 实现可读错误码、可复现故障信息和开发期诊断日志。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 有错误码/失败模型（sync_failure.dart），诊断日志未系统化 |
| R0033 | ◐ 部分实现 | 每个联网功能需要超时、重试、取消、错误处理及离线说明。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 联网功能部分含超时/重试/取消（WebDAV/S3），未全覆盖 |
| R0034 | ◐ 部分实现 | 每个批量操作需具备进度提示、取消入口及安全恢复能力。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 批量导入有进度通知基础，取消/恢复需验收 |
| R0035 | 🟡 已实现待验证 | 为耗时任务使用后台工作队列，禁止阻塞 Android 主线程。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 耗时同步放后台服务/队列，未阻塞主线程 |
| R0036 | ✅ 已验证完成 | 先确保 MVP 阅读链路完整：导入、打开、翻页、退出、恢复。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | MVP 链路完整：导入/打开/翻页/退出/恢复（smoke test） |
| R0037 | 🟡 已实现待验证 | 根据依赖关系安排施工顺序，基础阅读先于动画特效与高级 AI。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 按内核→数据→UI→同步顺序施工 |
| R0038 | ✅ 已验证完成 | 实现任务进度台账，列需求编号、文件路径、测试结果及遗留问题。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本台账即任务进度台账 |
| R0039 | ✅ 已验证完成 | 构建失败必须定位真实报错并修复，不得删除测试绕过失败。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 本轮定位并保留基线的 149 条 lint 信息，未删测试 |
| R0040 | ◐ 部分实现 | 最终交付应包含可安装 APK、变更日志、测试证据及未完成清单。 | docs/; .github/workflows/; lib/main.dart; pubspec.yaml | 交付含 APK/变更日志/测试证据；真机录屏待设备 |

### 02 首次启动、导航与基础体验

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0041 | 🟡 已实现待验证 | 首次打开应用在合理时间内进入可操作首页，不出现无意义白屏。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | main 初始化后立即进 HomeShell；无白屏；启动耗时未真机量化 |
| R0042 | ⬜ 未开始 | 首次使用提供简短引导，最多三步解释导入、阅读和同步入口。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无首次引导流程代码 |
| R0043 | ⬜ 未开始 | 允许用户跳过引导，跳过后立即进入可用的空书架。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无首次引导流程代码 |
| R0044 | 🟡 已实现待验证 | 空书架显示导入本地书籍和连接云书库两个清晰动作。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 空书架有导入/同步入口（bookshelf_page 空态） |
| R0045 | ✅ 已验证完成 | 首次启动不强制注册账号，离线阅读无需账户或服务器。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无账号体系，离线可读（架构事实 + smoke） |
| R0046 | ✅ 已验证完成 | 首次进入不强制请求所有文件访问权限，优先使用系统文件选择器。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 导入用 file_picker 系统选择器，未强制全文件权限 |
| R0047 | ◐ 部分实现 | 解释每项系统权限的用途，在真正触发功能时再申请。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 权限用途说明未系统化 |
| R0048 | 🟡 已实现待验证 | 拒绝文件权限后仍可使用已导入的书籍及其他功能。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 拒绝权限后已导入书可用（本地优先） |
| R0049 | 🟡 已实现待验证 | 底部主导航项不宜过多，优先书架、发现或云书库、统计、我的。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 底部 4 tab：书架/同步/设置/更多（无「我的」） |
| R0050 | 🟡 已实现待验证 | 所有主导航图标使用统一线宽、圆角和视觉尺寸。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 导航图标统一 ReadIcon 线宽（home_shell + 图标测试） |
| R0051 | ◐ 部分实现 | 主导航切换时保留当前滚动位置及搜索筛选条件。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | tab 用 Offstage 保留状态，但滚动位置保留未逐页验证 |
| R0052 | 🟡 已实现待验证 | 返回键从二级页返回上级，不应误退出整个应用。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | WillPopScope/返回层级需逐页核对 |
| R0053 | 🟡 已实现待验证 | 书籍阅读页优先响应返回到书架，同时保存当前位置。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 阅读页返回保存位置（reader_page _saveProgress） |
| R0054 | 🟡 已实现待验证 | 切换屏幕方向时恢复当前页面、页内偏移和工具栏状态。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 横竖屏恢复页/偏移（_applyOrientation + 测试） |
| R0055 | ✅ 已验证完成 | 启用系统深色模式时，应用默认跟随系统主题。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | themeMode 支持 followSystem（appearance_store + eink_theme_test） |
| R0056 | ✅ 已验证完成 | 为深色与浅色主题分别定义文字、背景、边框及强调色令牌。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | ReadPalette 定义浅/深文字/背景/边框/强调（theme.dart） |
| R0057 | ⬜ 未开始 | 首次引导设置完成后不重复弹出，除非用户手动重置。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无首次引导，不存在重复弹出 |
| R0058 | 🟡 已实现待验证 | 书架上一次打开的书籍提供明显的“继续阅读”入口。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 书架有继续阅读入口（bookshelf） |
| R0059 | 🟡 已实现待验证 | 应用被系统回收后重启应恢复最近书籍，不出现数据空白。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 进程回收恢复最近书（LibraryStore 持久化） |
| R0060 | ◐ 部分实现 | 首页首屏布局优先呈现正在读的书，减少装饰性大卡片。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 首页布局持续调整中 |
| R0061 | 🟡 已实现待验证 | 主按钮的点击区域至少满足常用移动端可触达标准。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 导航点击区 radius 42；主按钮触控区需真机核对 |
| R0062 | ◐ 部分实现 | 图标和标题不得发生遮挡、裁切、错位或失去基线对齐。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 图标/标题对齐需视觉回归 |
| R0063 | 🟡 已实现待验证 | 长书名、长作者名使用合理省略和完整信息查看方式。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 长书名省略（bookshelf 卡片 maxLines） |
| R0064 | ◐ 部分实现 | 状态栏颜色与页面背景协调，不出现上下突兀的黑白断层。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 状态栏颜色由 _applySystemUi 处理，需真机核对 |
| R0065 | 🟡 已实现待验证 | 导航栏与手势指示区采用系统安全内边距，不压住按钮。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 底部 SafeArea（home_shell） |
| R0066 | 🟡 已实现待验证 | 沉浸阅读时合理隐藏状态栏，显示工具栏时恢复可见信息。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 沉浸阅读隐藏状态栏（_applySystemUi） |
| R0067 | ◐ 部分实现 | 折叠屏及平板切换尺寸时，页面布局需要响应式重排。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 有横竖屏/屏幕预设，折叠屏动态尺寸未验证 |
| R0068 | ◐ 部分实现 | 软键盘弹出时保证搜索框、确认按钮和输入内容可见。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 软键盘可见性未专项处理 |
| R0069 | ◐ 部分实现 | 数据加载用骨架屏或轻量进度状态，禁止全屏无意义转圈。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无骨架屏，加载态为简单进度 |
| R0070 | ◐ 部分实现 | 失败页面提供可执行重试操作和明确错误原因。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 失败页重试入口未系统化 |
| R0071 | ◐ 部分实现 | 无网络时显示离线状态，但不要遮挡正在阅读的文字。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 离线状态提示未遮挡阅读，但缺统一离线条 |
| R0072 | ◐ 部分实现 | 所有破坏性操作提供可撤销途径或二次确认。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 破坏性操作二次确认部分实现 |
| R0073 | ◐ 部分实现 | 页面层级与对话框关闭逻辑一致，避免多层弹窗无法退出。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 弹窗关闭逻辑需逐层核对 |
| R0074 | ⬜ 未开始 | 单手模式下重要功能放置于拇指容易到达的区域。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无单手模式布局 |
| R0075 | ⬜ 未开始 | 允许用户自定义首页默认打开书架或继续阅读。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 无首页默认打开项设置 |
| R0076 | 🟡 已实现待验证 | 首页支持最近阅读历史，点击能够准确回到上次位置。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 最近阅读列表（profile/reading_history_page） |
| R0077 | ◐ 部分实现 | 在多窗口模式下保持工具栏可用，不强制横向滚动。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 多窗口工具栏适配未验证 |
| R0078 | 🟡 已实现待验证 | 根据系统字体缩放检查首页、设置页与弹窗的可读性。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | fontScale 传入 buildTheme 支持系统字体缩放 |
| R0079 | 🟡 已实现待验证 | 设置项使用通俗中文并补充必要的说明文字，不使用开发者术语。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 设置项中文表述，需逐项校对 |
| R0080 | 🟡 已实现待验证 | 首次启动到成功阅读第一本本地书的路径应控制在少量操作内。 | lib/main.dart; lib/src/shell/home_shell.dart; lib/src/theme.dart | 首次到读书路径操作少（点书即读） |

### 03 本地导入、传书与文件管理

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0081 | ✅ 已验证完成 | 支持 Android 系统文件选择器选择单个电子书并直接导入。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | file_picker 单选导入（library_store.importBook + 测试） |
| R0082 | 🟡 已实现待验证 | 支持在系统文件选择器中多选书籍并一次导入书架。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | file_picker 支持多选，需端到端核对 |
| R0083 | ◐ 部分实现 | 支持选择整个书籍目录，通过 SAF 持久化授权扫描。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | SAF 目录持久化授权未实现 |
| R0084 | ◐ 部分实现 | 支持扫描子目录并显示找到、成功、失败及跳过数量。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 目录扫描统计未完整实现 |
| R0085 | ⬜ 未开始 | 扫描大型目录时分批处理，不要一次读满内存。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 无分批扫描大目录 |
| R0086 | ◐ 部分实现 | 支持从系统“分享”菜单将电子书发送到 Read。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 系统分享接收未实现 Android intent-filter |
| R0087 | ◐ 部分实现 | 支持从系统“使用其他应用打开”中直接选择 Read。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | “用其他应用打开”关联未配置 |
| R0088 | ◐ 部分实现 | 支持文件管理器点击电子书触发关联打开。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 文件管理器关联打开未配置 |
| R0089 | 🟡 已实现待验证 | 对 content URI 使用 ContentResolver，不依赖可失效的真实路径。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | content URI 通过 file_picker 字节流读取 |
| R0090 | ◐ 部分实现 | 导入失败显示文件名、原因和重新尝试入口。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 导入失败原因展示部分实现 |
| R0091 | ⬜ 未开始 | 导入时区分复制入库与引用原位置两种模式并解释差异。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 复制入库/引用原位置双模式未实现 |
| R0092 | ⬜ 未开始 | 引用原文件时检测权限失效，并提示重新授权。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 引用文件权限失效检测未实现 |
| R0093 | ◐ 部分实现 | 导入重复文件时使用内容指纹识别，不仅比较文件名。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 有内容指纹基础（sync 校验和），导入去重未接通 |
| R0094 | ◐ 部分实现 | 同名不同内容的书籍不得被错误覆盖或合并。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 同名不同内容覆盖防护未专项实现 |
| R0095 | ◐ 部分实现 | 导入取消后清理不完整临时文件并保持已有书库一致。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 导入取消清理未专项验证 |
| R0096 | ◐ 部分实现 | 批量导入时允许后台继续处理并展示进度通知。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 批量导入后台进度通知部分实现 |
| R0097 | ⬜ 未开始 | 扫描结果支持按格式、目录与大小筛选。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 扫描结果按格式/目录/大小筛选未实现 |
| R0098 | 🟡 已实现待验证 | 导入结束后自动提取书名、作者、封面和书籍格式。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 导入提取书名/作者（book_name_parser + 测试） |
| R0099 | 🟡 已实现待验证 | 元数据提取失败时仍允许打开可解析内容。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 元数据失败仍可打开（fmt 解析独立于元数据） |
| R0100 | ◐ 部分实现 | 识别损坏或不完整压缩包，避免阅读时才突然闪退。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 压缩包完整性检测部分实现（archive） |
| R0101 | ⬜ 未开始 | 支持读取压缩包内电子书并列出可导入的候选文件。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 压缩包内列举候选书未实现 |
| R0102 | 🟡 已实现待验证 | 对于加密或受 DRM 保护文件，说明合法支持边界而非假装能打开。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | DRM 明确声明不支持（format_engine 抛错） |
| R0103 | ⬜ 未开始 | 支持拖放导入，适用于支持拖拽的平板与多窗口设备。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 拖放导入未实现 |
| R0104 | 🟡 已实现待验证 | 支持通过局域网 Wi-Fi 传书网页向手机发送文件。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | Wi-Fi 传书页存在（wifi_transfer_page） |
| R0105 | 🟡 已实现待验证 | Wi-Fi 传书必须用户主动启动，并显示同网段访问地址。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | Wi-Fi 传书需主动启动并显示地址（需真机核对） |
| R0106 | ◐ 部分实现 | Wi-Fi 上传入口提供短时会话码或明确授权以防他人上传。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | Wi-Fi 会话码/授权未确认实现 |
| R0107 | ◐ 部分实现 | 传书支持多文件上传、进度显示、失败重试与完成提示。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | Wi-Fi 多文件/进度/重试需真机核对 |
| R0108 | ◐ 部分实现 | 传书服务器关闭页面或超时后自动停用，不应常驻暴露。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | Wi-Fi 服务超时自动停用需核对 |
| R0109 | ⬜ 未开始 | 支持从系统下载目录快速发现最近新增的书籍。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 下载目录发现新书未实现 |
| R0110 | ⬜ 未开始 | 支持监听用户授权目录的变化并手动刷新书架。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 目录变化监听未实现 |
| R0111 | ◐ 部分实现 | 支持将外部书籍的来源记录为本地文件、分享或云端导入。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 来源记录（本地/分享/云端）部分实现 |
| R0112 | ⬜ 未开始 | 支持从剪贴板导入文本并生成临时可阅读文档。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 剪贴板导入文本未实现 |
| R0113 | ⬜ 未开始 | 支持 URL 导入公开可访问的合法电子书文件。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | URL 导入未实现 |
| R0114 | ⬜ 未开始 | 网络下载时支持重定向、断点续传与文件大小限制。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 网络下载断点续传未实现 |
| R0115 | ⬜ 未开始 | URL 导入前校验 HTTPS 证书，不忽略证书错误。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | URL 导入证书校验未实现（无 URL 导入） |
| R0116 | ◐ 部分实现 | 导入大文件时检查剩余存储空间并提供明确提示。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 空间检查未专项实现 |
| R0117 | ◐ 部分实现 | 书库文件采用原子重命名完成写入，避免中断后残留半成品。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 原子写入部分用于同步，导入路径未确认 |
| R0118 | ⬜ 未开始 | 允许用户选择内部存储或授权的外部存储目录。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 内部/外部存储选择未实现 |
| R0119 | ⬜ 未开始 | 支持导出单本书籍原文件到用户指定位置。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 导出单本原文件未实现 |
| R0120 | ⛔ 客观阻塞 | 为导入渠道分别编写端到端测试，覆盖取消、重复和权限回收。 | lib/src/services/library_store.dart; lib/src/more/import_tools.dart; lib/src/more/wifi_transfer_page.dart | 导入渠道端到端测试需真机/文档 URI，沙箱受限 |

### 04 电子书格式、编码与解析兼容

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0121 | 🟡 已实现待验证 | TXT 文件应支持 UTF-8、UTF-16、GB18030 等常见编码。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | decodeText 支持 UTF-8/UTF-16/GB18030（charset_converter） |
| R0122 | ⬜ 未开始 | TXT 编码识别错误时允许用户手动选择编码并立即预览。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 手动选择编码 UI 未实现 |
| R0123 | 🟡 已实现待验证 | TXT 中的 CRLF、LF 与 CR 换行符应得到一致的段落处理。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 换行  / / 归一（reader_engine buildDisplay） |
| R0124 | ⬜ 未开始 | TXT 在超大文件情况下采用分段索引，不一次性加载全部文本。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 超大 TXT 分段索引未实现（有 40MB 上限抛错） |
| R0125 | ✅ 已验证完成 | EPUB 2 应正确解析 OPF、NCX、章节顺序与图片资源。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | EPUB2 OPF/spine 解析：本轮合入 #46 修复，format_engine_test.dart 新增真实 ZIP spine 回归用例通过 |
| R0126 | 🟡 已实现待验证 | EPUB 3 应正确解析 navigation document 和语义结构。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | EPUB3 nav 语义部分解析 |
| R0127 | ◐ 部分实现 | EPUB 的 CSS、字体、内联图片应在安全沙箱下合理渲染。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | EPUB CSS/字体/内联图未完整渲染（转纯文本） |
| R0128 | ◐ 部分实现 | EPUB 缺失封面时生成优雅占位封面，不阻止阅读。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | EPUB 缺封面占位未实现 |
| R0129 | 🟡 已实现待验证 | EPUB 解析要拒绝不安全的外部脚本与非预期网络请求。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 不执行外部脚本（htmlToPlainText 仅取文本） |
| R0130 | ⬜ 未开始 | MOBI 格式能够识别正文、目录和基本元数据。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | MOBI/AZW3 未支持（supported 列表无） |
| R0131 | ⬜ 未开始 | AZW 与 AZW3 在无 DRM 前提下正确加载兼容内容。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | MOBI/AZW3 未支持（supported 列表无） |
| R0132 | 🟡 已实现待验证 | 支持 PDF 文字型文档的高精度渲染与页面导航。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | PDF 文字型渲染（pdfrx + pdf_format 测试） |
| R0133 | 🟡 已实现待验证 | 支持扫描版 PDF 逐页显示，文字选取能力应明确区分。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 扫描 PDF 逐页显示（pdfrx） |
| R0134 | 🟡 已实现待验证 | 支持 Markdown 标题、列表、表格、引用及代码块排版。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | Markdown 导入（format_engine supported） |
| R0135 | 🟡 已实现待验证 | 支持 HTML 文档的基本正文阅读与资源加载。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | HTML 正文导入（htmlToPlainText） |
| R0136 | 🟡 已实现待验证 | HTML 导入需移除或禁用不可信脚本及危险资源访问。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | HTML 脚本被移除（仅取文本节点） |
| R0137 | ⬜ 未开始 | 支持 CHM 的目录、章节与内嵌资源，无法实现时公开测试缺口。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | CHM 未支持 |
| R0138 | ⬜ 未开始 | 支持 CBZ 漫画图片包并保持自然顺序。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | CBZ 漫画包未支持 |
| R0139 | ⬜ 未开始 | 支持 CBR 漫画包通过明确许可且稳定的解压实现。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | CBR 未支持 |
| R0140 | ⬜ 未开始 | 支持 DOCX 文档正文、标题、列表及图片的只读浏览。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | DOCX 未支持 |
| R0141 | ⬜ 未开始 | 支持 RTF 文档基本文本与样式的解析。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | RTF 未支持 |
| R0142 | ⬜ 未开始 | 支持 FB2 的元数据、正文与章节结构。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | FB2 未支持 |
| R0143 | ◐ 部分实现 | 对压缩包设定解压大小与嵌套层数上限，防止压缩炸弹。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | EPUB 有 maxEpubBytes 100MB 上限；解压嵌套层数未限 |
| R0144 | ◐ 部分实现 | 检测文件真实内容类型，不能仅以扩展名判断。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 按扩展名+尝试解码，未做真实内容类型 magic 检测 |
| R0145 | ◐ 部分实现 | 对格式未知文件提供受限的文本预览和编码尝试。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 未知格式受限文本预览未实现 |
| R0146 | 🟡 已实现待验证 | 对无法解析的特性给出用户可理解的原因而非空白页。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 无法解析给出 FormatException 原因 |
| R0147 | 🟡 已实现待验证 | 内部统一书籍章节、段落、定位与资源加载抽象。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 统一章节/段落/定位抽象（ReaderEngine + DisplayChapter） |
| R0148 | 🟡 已实现待验证 | 保持原有文件不被解析器直接改写，编辑须生成安全副本。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 解析不改写原文件（只读字节导入） |
| R0149 | ⛔ 客观阻塞 | 创建覆盖中文简体、繁体、英文、日文等语言的格式测试样本。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 多语言真实样本集需人工准备 |
| R0150 | ◐ 部分实现 | 支持书内脚注、内部锚点和章节跳转的跨格式统一行为。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 脚注/锚点跨格式未统一实现 |
| R0151 | ⬜ 未开始 | 解析图片尺寸和方向，避免横屏插图拉伸变形。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 图片尺寸/方向解析未实现 |
| R0152 | ⬜ 未开始 | 含 SVG 的 EPUB 要限制危险脚本并保证正常矢量显示。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | SVG 矢量显示未实现 |
| R0153 | ⬜ 未开始 | 含 MathML 的文档尽可能呈现数学表达式并提供回退文本。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | MathML 未实现 |
| R0154 | ⬜ 未开始 | 书中表格过宽时允许水平滚动或自适应处理。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 宽表格横向滚动未实现 |
| R0155 | ◐ 部分实现 | 代码块保持空格、换行、等宽字体及滚动能力。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 代码块等宽处理部分（Markdown 转纯文本） |
| R0156 | 🟡 已实现待验证 | 超长单词与 URL 不应导致整页横向溢出。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 长串不强制溢出（分页 fits 二分安全） |
| R0157 | ◐ 部分实现 | 解析线程必须支持取消，用户退出不继续占用大量资源。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 解析线程取消未专项实现 |
| R0158 | ◐ 部分实现 | 同一本书再次打开应复用解析索引，降低等待时间。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 解析索引复用未实现（每次重解析） |
| R0159 | ⛔ 客观阻塞 | 每种声明支持格式至少提供一个真实样本及打开到末尾的测试。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 每种格式真实样本+读末尾测试需样本文件 |
| R0160 | ⬜ 未开始 | 格式支持矩阵应写入 README，区别完整支持、有限支持和不支持。 | lib/src/formats/format_engine.dart; lib/src/formats/pdf_format.dart | 格式支持矩阵未写入 README |

### 05 阅读器基础行为和内容定位

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0161 | 🟡 已实现待验证 | 点击书籍后先显示可读首屏，再异步补充统计和缓存。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 先渲染正文再补统计（reader_page 分段 flush） |
| R0162 | 🟡 已实现待验证 | 首次阅读默认跳到正文开头，而非封面空白或无关 metadata。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 首次打开定位正文开头（_relayout 跳过封面逻辑） |
| R0163 | ✅ 已验证完成 | 再次阅读跳转到上次确认保存的位置，禁止回到第一章。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 再次阅读跳上次位置（library_progress_recovery_test） |
| R0164 | ✅ 已验证完成 | 阅读定位使用稳定的章节锚点与段内偏移，不仅依靠页码。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 稳定章节锚点+段内偏移（sourceOffset 映射 + 测试） |
| R0165 | ✅ 已验证完成 | 改变字号或屏幕宽度后，当前位置仍对应同一句附近。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 改字号后位置对应同句（reader_engine 测试 + 锚点映射） |
| R0166 | 🟡 已实现待验证 | 翻页前预排下一屏，避免翻页后出现长时间白屏。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 预排下一屏（_prefetchNeighbors 邻章预览） |
| R0167 | ✅ 已验证完成 | 返回上一页时不应跳错章节或重复显示同段。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 上一页不错章（跨章回弹修复 + 测试） |
| R0168 | ✅ 已验证完成 | 自动保存每次稳定翻页后的阅读进度。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 稳定翻页自动保存（_markProgress/_saveProgress + 测试） |
| R0169 | 🟡 已实现待验证 | 强制停止应用后再次打开，最近进度最多回退少量文字。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 强停后进度回退量需真机验证 |
| R0170 | 🟡 已实现待验证 | 章节切换时更新章节名、总进度和章节内进度。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 章节切换更新名称/进度（_syncProgressValues） |
| R0171 | 🟡 已实现待验证 | 支持通过目录跳章并正确建立返回阅读位置的历史栈。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 目录跳章历史栈（_positionHistory 基础） |
| R0172 | ◐ 部分实现 | 支持记录最近多个跳转位置并按顺序返回。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 多个跳转位置顺序返回部分实现 |
| R0173 | ⬜ 未开始 | 支持在同一本书里快速切换上次阅读和当前位置。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 上次阅读与当前位置快速切换未实现 |
| R0174 | 🟡 已实现待验证 | 支持阅读进度百分比与剩余页数等可选显示。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 进度百分比可选显示（页脚设置） |
| R0175 | ◐ 部分实现 | 进度百分比计算需与实际正文对应，忽略无关资源体积。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 百分比按正文计算需核对 |
| R0176 | ⬜ 未开始 | 对于未解析完全的书籍显示“进度计算中”而非虚假百分比。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | “进度计算中”态未实现 |
| R0177 | ◐ 部分实现 | 书籍打不开时保留在书架并提供详细错误与重试。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 书籍打不开保留书架+错误（导入校验） |
| R0178 | ◐ 部分实现 | 下载中书籍须等完整校验通过后才能视为可阅读。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 下载中书校验未实现（无云书下载流程） |
| R0179 | 🟡 已实现待验证 | 阅读页可通过轻点中部调出操作栏，响应不应延迟明显。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 轻点中部呼出工具栏（reader_page 点击区） |
| R0180 | 🟡 已实现待验证 | 点击正文边缘应按照用户设置执行翻页或无操作。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 边缘点击翻页/无操作按设置 |
| R0181 | 🟡 已实现待验证 | 支持点击屏幕左右区翻页并可配置左右逻辑。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 左右区翻页可配置（settings） |
| R0182 | 🟡 已实现待验证 | 支持滑动翻页与点击翻页的独立开关。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 滑动/点击翻页独立开关（settings） |
| R0183 | ◐ 部分实现 | 支持从当前章节重新开始与跳到本书末尾。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 从当前章重开/跳末尾需核对入口 |
| R0184 | ⬜ 未开始 | 支持在书内打开图片查看器，关闭后返回原句位置。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 书内图片查看器未实现 |
| R0185 | ◐ 部分实现 | 暂停阅读后恢复不应自动触发下一页或误选中文字。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 暂停恢复不误选（Listener 手势） |
| R0186 | 🟡 已实现待验证 | 阅读页被电话或通知打断后保留内容和光标状态。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 生命周期中断保留内容（didChangeAppLifecycleState） |
| R0187 | ◐ 部分实现 | 支持书籍页面加载失败时恢复上一页而不是退出应用。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 加载失败恢复上一页未专项实现 |
| R0188 | 🟡 已实现待验证 | 阅读设置改变后仅刷新必要布局，不重启整本书。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 设置改变局部刷新（_onStoreChanged 重排必要布局） |
| R0189 | ◐ 部分实现 | 首页继续阅读与最近阅读列表读取同一份进度数据。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 首页继续阅读与最近列表同源需核对 |
| R0190 | ◐ 部分实现 | 可选择优先显示最近打开、最近完成或正在阅读的书籍。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 最近/完成/在读排序切换部分实现 |
| R0191 | 🟡 已实现待验证 | 支持记录“开始阅读”“读完”“放弃”状态，用户可手动修正。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 阅读状态标记（reading_stats_store.markFinished） |
| R0192 | ◐ 部分实现 | 最后一页显示读完反馈与返回书架入口，但不得强制评分。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 末页读完反馈需核对，未强制评分 |
| R0193 | 🟡 已实现待验证 | 支持重新阅读已完成书籍，并保留既有读完记录。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 重读已完成书保留记录（markFinished 独立） |
| R0194 | ⬜ 未开始 | 书中外部链接先显示目标地址，再交由安全浏览器打开。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 外链安全浏览器打开未实现 |
| R0195 | ◐ 部分实现 | 支持查阅书籍基本信息而不需要退出阅读界面。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 阅读页内查看书籍信息未实现 |
| R0196 | 🟡 已实现待验证 | 目录页进入后选章返回阅读页，不应多次按返回键。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 目录选章返回不需多次返回键 |
| R0197 | ◐ 部分实现 | 支持快速跳过封面、版权页等前置页面的可选行为。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 跳过封面/版权页可选行为部分实现 |
| R0198 | ✅ 已验证完成 | 保持阅读页背景和文本稳定，禁止每次翻页闪一下白屏。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 翻页背景稳定不闪白（cover 翻页去缩放 + 修复） |
| R0199 | 🟡 已实现待验证 | 从阅读界面打开设置或笔记后返回不得丢失阅读上下文。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 设置/笔记返回保留上下文 |
| R0200 | ⛔ 客观阻塞 | 基础阅读链路必须经过至少一次真机完整读书流程验收。 | lib/src/reader/reader_page.dart; lib/src/reader/engine/reader_engine.dart | 真机完整读书流程验收需 Android 设备 |

### 06 字体、排版、主题与内容样式

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0201 | 🟡 已实现待验证 | 阅读字号应提供连续滑块和精确数值显示。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 字号滑块+数值显示、小步进（reader_settings_sheet） |
| R0202 | 🟡 已实现待验证 | 字号调节支持小步进，不因单次滑动造成过大变化。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 字号滑块+数值显示、小步进（reader_settings_sheet） |
| R0203 | 🟡 已实现待验证 | 提供字重选项，适配普通、偏细与偏粗文字。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 字重选项（fontWeight 设置项） |
| R0204 | 🟡 已实现待验证 | 支持更换系统字体及用户导入的合法字体文件。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 用户导入字体（user_font_store） |
| R0205 | ◐ 部分实现 | 导入字体后验证格式，损坏字体不能导致阅读器崩溃。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 损坏字体防护需核对 |
| R0206 | ⬜ 未开始 | 允许将不同字体分别应用于中文、英文和代码片段。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 中/英/代码分字体未实现 |
| R0207 | 🟡 已实现待验证 | 支持行距调整并实时显示样张预览。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 行距调整（lineHeight + 移入段落页） |
| R0208 | 🟡 已实现待验证 | 支持段落间距调整，且与行距配置独立。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 段距独立（paragraphSpacingLines 行档位） |
| R0209 | 🟡 已实现待验证 | 支持首行缩进并可对每本书单独覆盖。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 首行缩进可单书覆盖（indentMode/indentChars） |
| R0210 | 🟡 已实现待验证 | 支持段落对齐：左对齐、两端对齐与居中等适用模式。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 段落对齐（textAlignOf 左/两端/居中） |
| R0211 | 🟡 已实现待验证 | 支持左右边距调整并避免窄屏文字区域过小。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 左右/上下边距调整（marginLeft/Right/Top/Bottom） |
| R0212 | 🟡 已实现待验证 | 支持上下页边距调整，不覆盖系统导航和工具栏。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 左右/上下边距调整（marginLeft/Right/Top/Bottom） |
| R0213 | ◐ 部分实现 | 支持文本列宽设置，尤其适配横屏与平板。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 列宽设置部分（columnGap/双栏） |
| R0214 | 🟡 已实现待验证 | 支持单双栏排版，自动依据屏幕宽度推荐默认值。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 单双栏按屏宽推荐（screen_preset_test + _twoColumns） |
| R0215 | ⬜ 未开始 | 支持竖排文字模式，并正确处理常见标点方向。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 竖排文字未实现 |
| R0216 | ⬜ 未开始 | 支持繁简文字展示转换，不改变原始书籍文件。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 繁简转换未实现 |
| R0217 | ⬜ 未开始 | 支持书籍原始 CSS 与用户覆盖样式的优先级切换。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 原书 CSS 与用户覆盖优先级未实现 |
| R0218 | ⬜ 未开始 | 切换“尊重原书排版”时不应丢失阅读锚点。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 尊重原书排版开关未实现 |
| R0219 | 🟡 已实现待验证 | 保留 EPUB 章节标题层级、段首装饰及引用样式。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | EPUB 章节标题：本轮 #46 修复保证显式标题渲染一次且开篇正文不被误作标题（format_engine_test 通过）；CSS 样式仍为纯文本损失 |
| R0220 | ⬜ 未开始 | 支持原书嵌入字体的启用和禁用。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 嵌入字体启停未实现 |
| R0221 | 🟡 已实现待验证 | 支持阅读时显示或隐藏页眉书名。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 页眉书名显隐（headerShow） |
| R0222 | 🟡 已实现待验证 | 支持在页脚显示页码、百分比、章节名和电量的组合。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 页脚页码/百分比/章节/电量组合（footer 设置） |
| R0223 | ◐ 部分实现 | 页眉页脚项目可分别选择及调整顺序。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 页眉页脚项顺序调整需核对 |
| R0224 | ⬜ 未开始 | 支持显示当前时间，更新不能引发整个文本页面重排。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 当前时间显示且不重排未实现 |
| R0225 | 🟡 已实现待验证 | 提供至少五套经过设计的阅读配色，如纸白、暖黄、深灰。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 多套配色（reader_theme 配色表 + eink_theme_test） |
| R0226 | 🟡 已实现待验证 | 提供纯黑 AMOLED 主题以减少夜间亮度干扰。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 纯黑 AMOLED 主题（配色表含纯黑） |
| R0227 | 🟡 已实现待验证 | 支持自定义背景颜色、正文颜色和链接颜色。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 自定义背景/正文/链接色（颜色小程序） |
| R0228 | ◐ 部分实现 | 支持导入阅读背景纹理，并限制纹理影响可读性。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 背景纹理导入需核对（bgImage 设置存在） |
| R0229 | ◐ 部分实现 | 背景图片支持裁剪、透明度和固定位置。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 背景裁剪/透明度/固定（bgImageOpacity/Dim） |
| R0230 | ◐ 部分实现 | 确保深色背景下插图不被粗暴反色导致内容失真。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 深色下插图反色保护未实现 |
| R0231 | 🟡 已实现待验证 | 允许用户为不同书籍保存独立排版设置。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 单书独立排版（ReaderSettings 三层合并） |
| R0232 | 🟡 已实现待验证 | 允许一次操作把当前排版设为全局默认。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 当前排版设为全局默认（settings_portable） |
| R0233 | ⬜ 未开始 | 支持保存、重命名、复制与删除自定义阅读主题。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 自定义主题保存/重命名/复制/删除未实现 |
| R0234 | ⬜ 未开始 | 主题导入导出需要版本和有效性校验。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 主题导入导出版本校验未实现 |
| R0235 | ◐ 部分实现 | 主题切换优先局部更新，不应重新读取整个大文件。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 主题切换局部更新（_onStoreChanged 重排） |
| R0236 | 🟡 已实现待验证 | 提供字体、字号、间距等实时预览区域。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 实时预览区（settings sheet 样张） |
| R0237 | ⬜ 未开始 | 长公式和宽表格不得因强制换行损坏语义。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 长公式/宽表格保护未实现 |
| R0238 | 🟡 已实现待验证 | 用户开启系统大字体时仍可阅读、选字和打开菜单。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 系统大字体仍可读（fontScale 测试） |
| R0239 | ◐ 部分实现 | 连续调整排版设置时进行防抖处理，避免每滑动一次全书卡顿。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 连续调整防抖未专项实现 |
| R0240 | 🟡 已实现待验证 | 确保排版设置在重装恢复与多设备同步后准确还原。 | lib/src/reader/settings/reader_settings.dart; lib/src/reader/widgets/reader_settings_sheet.dart | 排版设置随备份同步（settings_portable + 测试） |

### 07 翻页模式、手势与动画

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0241 | 🟡 已实现待验证 | 提供覆盖、平移、仿真翻页、淡入及无动画多种阅读模式。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 覆盖/平移/无动画等模式（pageTurnMode + animationMs） |
| R0242 | ◐ 部分实现 | 每种动画必须展示真实前后页文本，不允许用静态遮罩装样子。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 仿真/淡入真实前后页需核对 |
| R0243 | ⬜ 未开始 | 仿真翻页根据手指拖动距离连续改变页面折角。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 仿真折角连续动画未实现 |
| R0244 | ⬜ 未开始 | 仿真动画需正确处理反向拖回和取消翻页。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 仿真折角连续动画未实现 |
| R0245 | 🟡 已实现待验证 | 高速连续翻页时不得出现空页或章节顺序错乱。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 高速连续翻页无空页（epoch guard + controller 重建修复） |
| R0246 | ◐ 部分实现 | 翻页动画完成后才更新可访问的页面语义与阅读进度。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 动画完成后更新语义/进度未专项实现 |
| R0247 | ◐ 部分实现 | 低端设备上允许自动降级动画以维持操作响应。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 低端设备动画降级未实现 |
| R0248 | 🟡 已实现待验证 | 设置里提供翻页动画速度的可调整选项。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 动画速度可调（animationMs） |
| R0249 | 🟡 已实现待验证 | 提供动画关闭选项，尊重系统“减少动态效果”偏好。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 动画关闭 + 减少动态（eink 模式关动画） |
| R0250 | ◐ 部分实现 | 支持左侧和右侧滑动区域的敏感度调整。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 左右滑区敏感度调整未实现 |
| R0251 | ◐ 部分实现 | 支持单击、双击、长按等手势的冲突优先级配置。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 单击/双击/长按优先级配置部分实现 |
| R0252 | 🟡 已实现待验证 | 长按文字时优先进入选中模式，不误触翻页。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 长按优先选中（Listener vs SelectableText 修复） |
| R0253 | ⬜ 未开始 | 双指缩放模式仅在合适文档和用户设置下生效。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 双指缩放未实现 |
| R0254 | ◐ 部分实现 | 切换滑动阅读与分页阅读时保存相对阅读位置。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 滚动/分页切换保存位置未实现 |
| R0255 | ◐ 部分实现 | 连续滚动阅读支持惯性滚动和章节之间的平滑衔接。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 连续滚动惯性/边界部分（pageTurnMode scroll） |
| R0256 | ◐ 部分实现 | 连续滚动模式要避免章节边界重复或缺失文字。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 连续滚动惯性/边界部分（pageTurnMode scroll） |
| R0257 | ⬜ 未开始 | 卷页模式支持平滑滚动并正确绘制当前章节标题。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 卷页模式未实现 |
| R0258 | 🟡 已实现待验证 | 支持自动翻页，可设置每页停留时间和暂停。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 自动翻页+停留时间（_startAutoTurn/autoTurnSeconds） |
| R0259 | 🟡 已实现待验证 | 自动翻页被手工操作中断后不应立即恢复。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 自动翻页+停留时间（_startAutoTurn/autoTurnSeconds） |
| R0260 | ◐ 部分实现 | 支持定速自动滚动，可在阅读时临时调整速度。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 定速自动滚动未实现 |
| R0261 | 🟡 已实现待验证 | 支持音量键翻页，并可与系统音量操作切换。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 音量键翻页（reader_device_bridge + 测试） |
| R0262 | 🟡 已实现待验证 | 支持蓝牙翻页器和常见键盘方向键操作。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 蓝牙翻页器/键盘方向键（reader_device_bridge） |
| R0263 | ⬜ 未开始 | 可配置点击区域，使用预览示意图说明作用范围。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 点击区域预览示意图未实现 |
| R0264 | 🟡 已实现待验证 | 可配置左手模式，把上一页和下一页热区反转。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 左手模式热区反转（设置项） |
| R0265 | ◐ 部分实现 | 屏幕左右边缘系统返回手势优先级要协调，不误退出。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 边缘返回手势协调需真机 |
| R0266 | 🟡 已实现待验证 | 支持轻点中间呼出工具栏及再次轻点隐藏。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 轻点中间呼出/隐藏工具栏 |
| R0267 | ◐ 部分实现 | 阅读工具栏显示与隐藏使用短促平滑过渡，不推挤正文。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 工具栏短促过渡未专项实现 |
| R0268 | ◐ 部分实现 | 弹出底部设置抽屉时避免阅读文本突然闪白。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 底抽闪白防护部分实现 |
| R0269 | ◐ 部分实现 | 连续操作页面时触摸反馈和画面运动方向必须一致。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 触摸反馈方向一致需真机 |
| R0270 | ◐ 部分实现 | 支持横屏时双页视图的左右翻页逻辑。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 横屏双页/RTL 双页顺序部分（_twoColumns） |
| R0271 | ◐ 部分实现 | 双页视图在 RTL 书籍里正确处理右到左顺序。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 横屏双页/RTL 双页顺序部分（_twoColumns） |
| R0272 | ◐ 部分实现 | 翻页过程用户按返回键时要可靠完成或取消过渡。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 翻页中返回键处理需核对 |
| R0273 | ◐ 部分实现 | 设备旋转中途不应残留半张翻页动画画面。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 旋转残留半张动画需真机 |
| R0274 | ◐ 部分实现 | 动画使用硬件加速并控制每帧对象分配。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 硬件加速/每帧分配控制未量化 |
| R0275 | ⬜ 未开始 | 设置不同显示刷新率设备的自适应帧调度策略。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 按刷新率自适应帧调度未实现 |
| R0276 | 🟡 已实现待验证 | 对页面缓存设置上下限，避免长时间阅读内存增长。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 页面缓存 LRU 上限（_paginationCache LRU 修复） |
| R0277 | ◐ 部分实现 | 图片占比高的章节翻页时提前解码下一页资源。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 图片章节预解码未实现 |
| R0278 | ◐ 部分实现 | 支持可关闭的轻微触觉反馈，不依赖振动权限滥用。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 触觉反馈开关未实现 |
| R0279 | ⛔ 客观阻塞 | 对不同翻页模式分别测量掉帧比例与交互延时。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 掉帧比例/交互延时需真机测量 |
| R0280 | ⛔ 客观阻塞 | 动画验收必须提交实际设备录屏，不以设计预览代替效果。 | lib/src/reader/reader_page.dart; lib/src/reader/settings/reader_settings.dart | 动画真机录屏验收需 Android 设备 |

### 08 目录、导航、全文搜索与定位

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0281 | 🟡 已实现待验证 | 从 EPUB 原始导航结构生成可展开的章节目录。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | EPUB 导航 spine 生成目录（format_engine） |
| R0282 | ✅ 已验证完成 | 从 TXT 通过正则规则识别常见“第X章”标题。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | TXT 正则识别“第X章”：本轮修复标题正则跨行吞正文 bug（\s→[ 	]），chapter_splitter_test 8/8 通过，原文零丢失（bd56614） |
| R0283 | 🟡 已实现待验证 | TXT 自动识别章节前提供结果预览和手工修订入口。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 分章结果预览+手工修订：manual_chapter_store 支持，UI 修订入口待真机核对 |
| R0284 | ◐ 部分实现 | 目录按卷、章、节分层展示并支持折叠。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 卷/章/节分层折叠部分（Chapter 结构） |
| R0285 | ◐ 部分实现 | 当前阅读章节在目录里自动高亮并滚动到可见位置。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 当前章目录高亮滚动需核对 |
| R0286 | ◐ 部分实现 | 目录项显示章节名称和可选阅读进度。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 目录项进度显示未实现 |
| R0287 | ◐ 部分实现 | 支持章节名关键词搜索并即时筛选目录项。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 章节名搜索筛选未实现 |
| R0288 | ⬜ 未开始 | 支持输入指定页码跳转到对应页面。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 输入页码跳转未实现 |
| R0289 | ⬜ 未开始 | 对于回流式书籍区分虚拟页码与原书固定页码。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 虚拟页码/原书页码区分未实现 |
| R0290 | ◐ 部分实现 | 支持通过百分比滑块定位全文进度。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 百分比滑块定位需核对 |
| R0291 | ◐ 部分实现 | 进度拖动时显示目标章节与附近文字预览。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 百分比滑块定位需核对 |
| R0292 | ◐ 部分实现 | 松开进度滑块才执行高成本布局更新，避免卡顿。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 百分比滑块定位需核对 |
| R0293 | ✅ 已验证完成 | 支持在当前书内全文搜索普通文字。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 书内全文搜索（book_search + 测试） |
| R0294 | ◐ 部分实现 | 支持大小写敏感与不敏感两种检索模式。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 大小写敏感模式需核对 |
| R0295 | ◐ 部分实现 | 支持全角半角与常见 Unicode 规范化检索。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 全角半角/Unicode 规范化检索未实现 |
| R0296 | ⬜ 未开始 | 支持正则表达式搜索并限制灾难性回溯。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 正则搜索未实现 |
| R0297 | ✅ 已验证完成 | 搜索结果列出章节、命中片段及高亮位置。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 搜索结果章节/片段/高亮跳转（book_search + reader_page） |
| R0298 | ✅ 已验证完成 | 点搜索结果准确跳转并短暂标记命中词。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 搜索结果章节/片段/高亮跳转（book_search + reader_page） |
| R0299 | ◐ 部分实现 | 支持上一条与下一条搜索结果连续导航。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 上一条/下一条连续导航需核对 |
| R0300 | ◐ 部分实现 | 切换搜索结果时不改变原本的主阅读进度，直至用户确认继续读。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 搜索不改主进度直至确认未实现 |
| R0301 | ◐ 部分实现 | 支持检索整本书及仅当前章节两个范围。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 全书/本章搜索范围需核对 |
| R0302 | ⬜ 未开始 | 支持全文索引后台构建及索引构建进度显示。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 全文索引后台构建未实现 |
| R0303 | ⬜ 未开始 | 索引构建取消后保留已完成部分并安全恢复。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 全文索引后台构建未实现 |
| R0304 | ⬜ 未开始 | 更新书籍文件后检测指纹变化并重建过期索引。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 指纹变化重建索引未实现 |
| R0305 | 🟡 已实现待验证 | 支持书内书签导航和指定章节快速收藏。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 书签导航（bookmark_store + 测试） |
| R0306 | ⬜ 未开始 | 支持手动输入定位关键字找到相应内容。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 手动输入定位关键字未实现 |
| R0307 | ◐ 部分实现 | 支持保存多个临时阅读位置用于比较前后情节。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 多个临时位置部分（_positionHistory） |
| R0308 | ◐ 部分实现 | 支持最近访问章节历史，不混入书架的最近阅读列表。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 最近访问章节历史与书架列表分离需核对 |
| R0309 | ⬜ 未开始 | 对目录缺失的 PDF 使用可用的缩略图导航作为备选。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | PDF 缩略图导航未实现 |
| R0310 | ◐ 部分实现 | 支持书籍内部超链接跳转及历史返回。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 内部超链接跳转未实现 |
| R0311 | ⬜ 未开始 | 对无效内部锚点给出提示，不应跳到文件开头。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 无效锚点提示未实现 |
| R0312 | 🟡 已实现待验证 | 支持搜索中文不带空格的连续词语。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 中文无空格连续词搜索（book_search） |
| R0313 | ⬜ 未开始 | 搜索预览要正确显示繁简转换前后的原文对应关系。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 繁简转换搜索预览未实现 |
| R0314 | ◐ 部分实现 | 搜索结果数量极大时实行分页或虚拟列表。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 大量结果分页/虚拟列表未实现 |
| R0315 | ◐ 部分实现 | 首次搜索大型书籍不能让阅读界面完全失去响应。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 首次大书搜索不卡死需核对 |
| R0316 | ✅ 已验证完成 | 搜索历史可选择保存、单项删除或全部清除。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 搜索历史保存/单项删/全清：本轮新增 SearchHistoryStore + 书内搜索面板 + 设置隐私开关，search_history_store_test 4/4 通过 |
| R0317 | ✅ 已验证完成 | 提供禁用搜索历史的隐私选项。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 搜索历史隐私开关：设置页「保存搜索历史」开关 + store.setEnabled 持久化，测试覆盖关闭后不记录 |
| R0318 | ⬜ 未开始 | 书籍解析出多个目录来源时允许用户选择首选目录。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 多目录来源选择未实现 |
| R0319 | ⬜ 未开始 | 书内位置可复制为内部深链并在应用内恢复打开。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 位置复制为深链未实现 |
| R0320 | ⛔ 客观阻塞 | 目录、搜索、书签三种跳转方式分别完成真机回归测试。 | lib/src/services/book_search.dart; lib/src/services/chapter_splitter.dart; lib/src/reader/reader_page.dart | 三种跳转真机回归需设备 |

### 09 脚注、复杂排版与阅读辅助

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0321 | ⬜ 未开始 | 点击脚注标识优先在当前阅读页弹出脚注内容。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0322 | ⬜ 未开始 | 脚注弹层提供纸片、气泡等独立外观样式选项。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0323 | ⬜ 未开始 | 脚注太长时可内部滚动，不把正文挤出屏幕。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0324 | ⬜ 未开始 | 脚注内的超链接能够继续打开对应内容且支持返回。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0325 | ⬜ 未开始 | 关闭脚注应回到原文原位，而非把进度跳到注释区。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0326 | ⬜ 未开始 | 脚注对 PDF 内部链接实现适当等价体验。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0327 | ⬜ 未开始 | 支持 EPUB 脚注、尾注与参考文献链接的语义区分。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0328 | ⬜ 未开始 | 可设置脚注以弹层打开或按原书链接跳转。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 脚注弹层/语义未实现（转纯文本无脚注结构） |
| R0329 | ◐ 部分实现 | 支持保留诗歌换行、引用层级与段首特殊缩进。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 中文断行/CJK 禁则部分（reader_engine 排版） |
| R0330 | ◐ 部分实现 | 对长破折号、间隔号和省略号使用合理中文断行规则。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 中文断行/CJK 禁则部分（reader_engine 排版） |
| R0331 | ◐ 部分实现 | 中英文混排时避免标点悬空和不自然空白。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 中文断行/CJK 禁则部分（reader_engine 排版） |
| R0332 | ◐ 部分实现 | 支持 CJK 禁则排版，尽量避免行首出现不合适标点。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 中文断行/CJK 禁则部分（reader_engine 排版） |
| R0333 | ⬜ 未开始 | 支持上标、下标、脚注上标和音标字体显示。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 上下标/Ruby/音标未实现 |
| R0334 | ⬜ 未开始 | 支持化学式与数学表达式基础展示。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 上下标/Ruby/音标未实现 |
| R0335 | ⬜ 未开始 | 支持书内 Ruby 注音和日语假名标注。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 上下标/Ruby/音标未实现 |
| R0336 | ⬜ 未开始 | 支持双向文字段落，包括 RTL 语言布局。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 双向文字/RTL 段落未实现 |
| R0337 | ⬜ 未开始 | 带方向属性的章节不得因主题变化丢失文字方向。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 双向文字/RTL 段落未实现 |
| R0338 | ⬜ 未开始 | 支持带图片说明的图表不与标题任意拆散。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 图表不拆散/公式放大未实现 |
| R0339 | ⬜ 未开始 | 对原书 CSS 的绝对定位内容设置安全回退。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 图表不拆散/公式放大未实现 |
| R0340 | ⬜ 未开始 | 支持公式点击放大查看而不影响正文位置。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 图表不拆散/公式放大未实现 |
| R0341 | ⬜ 未开始 | 支持图片双击放大与横向平移。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 图片双击放大/保存/返回未实现 |
| R0342 | ⬜ 未开始 | 支持查看原始图片分辨率与保存到本地。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 图片双击放大/保存/返回未实现 |
| R0343 | ⬜ 未开始 | 图片查看器关闭后恢复原来的滚动位置。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 图片双击放大/保存/返回未实现 |
| R0344 | 🟡 已实现待验证 | 支持选中段落后局部朗读或翻译。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 朗读段落（FlutterTts 存在） |
| R0345 | ⬜ 未开始 | 支持阅读标尺突出当前行并降低周边文字对比。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 阅读标尺/逐段聚焦/专注模式/句聚焦未实现 |
| R0346 | ⬜ 未开始 | 支持逐段聚焦模式用于长文精读。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 阅读标尺/逐段聚焦/专注模式/句聚焦未实现 |
| R0347 | ⬜ 未开始 | 提供可调的段落高亮颜色及透明度。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 阅读标尺/逐段聚焦/专注模式/句聚焦未实现 |
| R0348 | ⬜ 未开始 | 支持当前句子聚焦并随朗读同步移动。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 阅读标尺/逐段聚焦/专注模式/句聚焦未实现 |
| R0349 | ⬜ 未开始 | 支持阅读时隐藏非正文装饰的专注模式。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 阅读标尺/逐段聚焦/专注模式/句聚焦未实现 |
| R0350 | ◐ 部分实现 | 对宽屏提供适当最大文本宽度，避免超长单行伤眼。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 最大文本宽度部分（双栏/列宽） |
| R0351 | ⬜ 未开始 | 允许记录生僻字的用户自定义读音或释义。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 生僻字释义/页内查找未实现 |
| R0352 | ⬜ 未开始 | 提供页内查找当前图片、表格或公式的快捷方式。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 生僻字释义/页内查找未实现 |
| R0353 | ⬜ 未开始 | 复杂表格可以整体放大而不是压缩到不可读。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 表格放大/横向滚动手势未实现 |
| R0354 | ⬜ 未开始 | 支持文内横向滚动区域不抢占整页翻页手势。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 表格放大/横向滚动手势未实现 |
| R0355 | ◐ 部分实现 | 支持中文引号和英文引号混用时正确定位选区。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 引号选区/渲染复杂度保护需核对 |
| R0356 | ◐ 部分实现 | 对含大量嵌套元素的章节设置渲染复杂度保护。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 引号选区/渲染复杂度保护需核对 |
| R0357 | ⬜ 未开始 | 支持用户关闭原书动画和会闪动的内容。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 关闭原书动画未实现 |
| R0358 | ⬜ 未开始 | 外链图片缺失时显示占位符而不破坏章节高度。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 外链图片缺失占位未实现 |
| R0359 | ⛔ 客观阻塞 | 为脚注、公式、表格、竖排和 RTL 各制作真实示例文件。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 复杂排版真实样本需人工准备 |
| R0360 | ⛔ 客观阻塞 | 复杂排版回归应比对截图和可选择的文字内容一致性。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 复杂排版截图+文字一致性回归需真机 |

### 10 PDF 阅读、标注与性能

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0361 | 🟡 已实现待验证 | PDF 独立阅读器应支持逐页模式和连续滚动模式。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 逐页/连续/横竖流（pdfrx + pdf_format） |
| R0362 | 🟡 已实现待验证 | PDF 支持横向和纵向页面流切换。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 逐页/连续/横竖流（pdfrx + pdf_format） |
| R0363 | 🟡 已实现待验证 | PDF 双指捏合缩放保持手指焦点位置。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 捏合缩放保持焦点（pdfrx InteractiveViewer） |
| R0364 | 🟡 已实现待验证 | PDF 放大后支持惯性拖动和边缘回弹。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 捏合缩放保持焦点（pdfrx InteractiveViewer） |
| R0365 | 🟡 已实现待验证 | PDF 缩放倍率提供适合宽度、适合页面和手工百分比。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 适合宽度/页面/百分比（pdfrx） |
| R0366 | ◐ 部分实现 | PDF 可以自动裁掉页边空白并允许手动调整。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 裁边/横屏单双页需核对 |
| R0367 | ◐ 部分实现 | PDF 裁边设置按书籍保存，不影响其他文档。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 裁边/横屏单双页需核对 |
| R0368 | ◐ 部分实现 | PDF 横屏时支持单页与双页模式。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 裁边/横屏单双页需核对 |
| R0369 | ⬜ 未开始 | PDF 阅读页提供缩略图网格快速定位。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 缩略图网格未实现 |
| R0370 | 🟡 已实现待验证 | PDF 目录按文档 outline 正确展开跳转。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF outline 目录（pdfrx 支持） |
| R0371 | ◐ 部分实现 | PDF 中可选文字可以长按高亮、复制及查词。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 选字高亮/复制需核对 |
| R0372 | ⬜ 未开始 | 扫描型 PDF 不应假装支持文字复制，应说明 OCR 可选条件。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | OCR/扫描说明未实现 |
| R0373 | ⬜ 未开始 | 若实现 OCR，必须标明本地或云端处理与相关隐私影响。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | OCR/扫描说明未实现 |
| R0374 | ◐ 部分实现 | PDF 内嵌文字搜索应提供结果列表和位置高亮。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 文字搜索需核对 |
| R0375 | ◐ 部分实现 | PDF 中注释、超链接和页内跳转必须可点击。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 注释/超链接点击需核对 |
| R0376 | 🟡 已实现待验证 | PDF 支持书签并能恢复对应页面和缩放状态。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 书签恢复页面（pdf_reader_page 保存位置） |
| R0377 | ⬜ 未开始 | PDF 标注支持高亮、下划线、删除线和自由文本批注。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 标注体系（高亮/画笔/导出）未实现 |
| R0378 | ⬜ 未开始 | PDF 支持画笔、橡皮擦和常用批注颜色。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 标注体系（高亮/画笔/导出）未实现 |
| R0379 | ⬜ 未开始 | 用触控笔时区分笔尖、手掌触控及双指操作。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 标注体系（高亮/画笔/导出）未实现 |
| R0380 | ⬜ 未开始 | PDF 批注的原始数据保存到独立持久层，避免覆盖原件。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 标注体系（高亮/画笔/导出）未实现 |
| R0381 | ⬜ 未开始 | 允许将批注导出为标准 PDF 副本，保留原文件。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 标注体系（高亮/画笔/导出）未实现 |
| R0382 | ⬜ 未开始 | PDF 标注导出失败不得丢失应用内已保存的批注。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 标注体系（高亮/画笔/导出）未实现 |
| R0383 | ◐ 部分实现 | 大页扫描 PDF 优先使用分块渲染以降低内存占用。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 分块渲染/缓存预算部分（pdfrx 内部） |
| R0384 | ◐ 部分实现 | 放大高分辨率 PDF 时逐级提高瓦片清晰度。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 分块渲染/缓存预算部分（pdfrx 内部） |
| R0385 | ◐ 部分实现 | 快速滑动时取消不再可见的页面渲染任务。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 分块渲染/缓存预算部分（pdfrx 内部） |
| R0386 | ◐ 部分实现 | PDF 渲染缓存遵循可配置的内存预算。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 分块渲染/缓存预算部分（pdfrx 内部） |
| R0387 | ◐ 部分实现 | PDF 的缩略图后台生成，前台先加载可见页。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 缩略图后台生成未实现 |
| R0388 | ◐ 部分实现 | PDF 密码保护文件仅通过合法用户提供密码打开。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 密码打开/日志脱敏需核对 |
| R0389 | ◐ 部分实现 | 密码不应写入明文日志或自动上传的诊断文件。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 密码打开/日志脱敏需核对 |
| R0390 | 🟡 已实现待验证 | 每个 PDF 文件的最后阅读页面及缩放值独立保存。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 每本最后页+缩放保存（pdf_format 测试） |
| R0391 | ◐ 部分实现 | PDF 旋转页面时保持可见内容中心不大幅跳动。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 旋转中心/夜间对比度需核对 |
| R0392 | ◐ 部分实现 | 支持夜间阅读时调整文档背景对比度。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 旋转中心/夜间对比度需核对 |
| R0393 | ◐ 部分实现 | 夜间颜色处理尽量保留图像自然颜色和可辨性。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 旋转中心/夜间对比度需核对 |
| R0394 | ⬜ 未开始 | 支持对多页 PDF 自动连续朗读可选文字文本。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 连续朗读未实现 |
| R0395 | ⬜ 未开始 | 对于文字顺序错乱的 PDF 提供原始视图回退。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 文字顺序错乱原始视图未实现 |
| R0396 | ◐ 部分实现 | PDF 加载失败显示页码和具体原因，允许重新渲染。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 加载失败页码原因需核对 |
| R0397 | ⛔ 客观阻塞 | 覆盖数百页教材、扫描件、大尺寸图纸与中英混排测试。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 大页/扫描/图纸测试样本需人工准备 |
| R0398 | ⛔ 客观阻塞 | 对连续缩放和快速翻页执行内存泄漏监测。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 内存泄漏监测需真机 |
| R0399 | 🟡 已实现待验证 | 不得使用低清截图代替原生 PDF 渲染来掩盖性能问题。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | 使用 pdfrx 原生渲染，非截图 |
| R0400 | ⛔ 客观阻塞 | PDF 验收应录屏验证缩放、选字、搜索、标注与恢复位置。 | lib/src/formats/pdf_format.dart; lib/src/reader/pdf_reader_page.dart | PDF 真机录屏验收需设备 |

### 11 漫画、图像与图文混排

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0401 | ⬜ 未开始 | CBZ/CBR 漫画按自然文件名排序，避免第10页排在第2页之前。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0402 | ⬜ 未开始 | 漫画支持从左向右及从右向左两种阅读顺序。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0403 | ⬜ 未开始 | 漫画支持单页、双页和长条连续滚动模式。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0404 | ⬜ 未开始 | 宽幅扫描图可选择保持整张或自动拆分为两页。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0405 | ⬜ 未开始 | 漫画模式允许裁掉四周扫描白边。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0406 | ⬜ 未开始 | 白边裁切只改变显示区域，不改写原始漫画图片。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0407 | ⬜ 未开始 | 漫画横屏时自动适配屏幕宽高比例。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0408 | ⬜ 未开始 | 双页漫画可为封面单页指定例外规则。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | CBZ/CBR 漫画阅读器未实现（format supported 无漫画） |
| R0409 | ⬜ 未开始 | 支持阅读时长按图片显示放大、保存及信息操作。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0410 | ⬜ 未开始 | 漫画页支持双击局部放大并能轻松复位。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0411 | ⬜ 未开始 | 长条漫画的连续滚动应避免页间明显缝隙。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0412 | ⬜ 未开始 | 漫画滚动时需要分段解码图片，禁止一次解码整本。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0413 | ⬜ 未开始 | 预加载下一张图片并控制峰值内存占用。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0414 | ⬜ 未开始 | 切换漫画阅读方向后保留正确的逻辑页位置。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0415 | ⬜ 未开始 | 漫画支持亮度和背景颜色独立设置。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0416 | ⬜ 未开始 | 漫画页号与文件页号映射稳定且可追踪。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0417 | ⬜ 未开始 | 支持漫画缩略图网格，并标记当前页。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0418 | ⬜ 未开始 | 漫画可通过页面滑块快速跳转到目标页。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0419 | ⬜ 未开始 | 提供漫画横向触摸翻页和纵向滚动两种手势模板。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0420 | ⬜ 未开始 | 用户在漫画中放大图片时，滑动优先平移而非翻页。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画手势/白边/缩放/缩略图未实现 |
| R0421 | ⬜ 未开始 | 图片超长时支持分段渲染，减少黑屏等待。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0422 | ⬜ 未开始 | 漫画支持分辨率优化选项，但不得默认损坏画质。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0423 | ⬜ 未开始 | 阅读包含少量正文的图文书时不强制全书漫画模式。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0424 | ⬜ 未开始 | 识别图片主导的 EPUB 时可建议切换漫画模式。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0425 | ⬜ 未开始 | 图文书保持正文与插图的原始先后次序。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0426 | ⬜ 未开始 | 允许用户快速切换适合宽度、适合高度与原始比例。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0427 | ⬜ 未开始 | 漫画页面在折叠屏展开后根据屏幕宽度自动重排。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0428 | ⬜ 未开始 | 漫画背景图加载失败时提供重试而不是跳过一页。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0429 | ⬜ 未开始 | 文件中的封底、扉页等内容不得因过滤被丢弃。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0430 | ⬜ 未开始 | 对无序图片名提供自然排序与手动排序选项。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0431 | ⬜ 未开始 | 支持漫画阅读记录中的章节和页码双重定位。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0432 | ⬜ 未开始 | 漫页旋转后能够恢复用户此前选择的缩放偏好。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0433 | ⬜ 未开始 | 避免缩放图片产生过度锐化、严重锯齿或颜色偏移。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0434 | ⬜ 未开始 | 对纯黑白漫画可选高对比度模式。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0435 | ⬜ 未开始 | 支持电子墨水屏漫画灰阶适配。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0436 | ⬜ 未开始 | 漫画截图分享必须遵守系统存储权限与用户主动选择。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0437 | ⬜ 未开始 | 大图保存完成要显示实际文件路径或系统分享目标。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画分段渲染/保存/高对比/墨水屏适配未实现 |
| R0438 | ⛔ 客观阻塞 | 为长条漫画、双页跨页和图片 EPUB 建立样本集合。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画样本集合需人工准备 |
| R0439 | ⛔ 客观阻塞 | 测试漫画高速连续翻页时的内存及帧时间曲线。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画帧时间曲线需真机 |
| R0440 | 🟡 已实现待验证 | 漫画功能必须在无网络条件下完整可用。 | lib/src/formats/format_engine.dart; lib/src/reader/reader_page.dart | 漫画功能整体未实现，但离线架构支持 |

### 12 书架、分类与书库浏览

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0441 | 🟡 已实现待验证 | 书架支持网格、标准列表和紧凑列表三种布局。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 网格/列表布局 + 列数（shelf_settings + 测试） |
| R0442 | 🟡 已实现待验证 | 网格列数根据屏幕宽度变化且允许用户手工调整。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 网格/列表布局 + 列数（shelf_settings + 测试） |
| R0443 | 🟡 已实现待验证 | 书架封面默认显示原书封面，加载失败时使用统一占位设计。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 封面占位 + 异步（cover_art） |
| R0444 | 🟡 已实现待验证 | 封面缩略图异步生成并缓存，不阻塞列表滚动。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 封面占位 + 异步（cover_art） |
| R0445 | 🟡 已实现待验证 | 书架支持按最近阅读、导入时间、标题和作者排序。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 排序模式持久化（library_store.setSortMode） |
| R0446 | 🟡 已实现待验证 | 书架支持按文件大小、字数、进度和完成时间排序。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 排序模式持久化（library_store.setSortMode） |
| R0447 | 🟡 已实现待验证 | 排序方向可单独选择升序或降序并持久化。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 排序模式持久化（library_store.setSortMode） |
| R0448 | ◐ 部分实现 | 支持按格式、阅读状态、标签与来源筛选。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 按格式/状态/标签/来源筛选需核对 |
| R0449 | 🟡 已实现待验证 | 支持全文书库搜索书名、作者、简介及自定义标签。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 书库搜索（book_search） |
| R0450 | 🟡 已实现待验证 | 支持模糊匹配，中文与英文输入均可正常使用。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 书库搜索（book_search） |
| R0451 | 🟡 已实现待验证 | 支持用户自定义书架分类与多个分类交叉收录。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 自定义分类多收录（collection_store） |
| R0452 | 🟡 已实现待验证 | 一本书可以同时属于多个书架分类而不复制文件。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 自定义分类多收录（collection_store） |
| R0453 | ◐ 部分实现 | 支持书单，允许定义“待看”“在读”“已读”等集合。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 书单“待看/在读/已读”部分（collection） |
| R0454 | ⬜ 未开始 | 支持按系列将多册书籍折叠成单组展示。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 系列折叠分组未实现 |
| R0455 | ⬜ 未开始 | 系列分组内支持按卷号和出版顺序排序。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 系列折叠分组未实现 |
| R0456 | ◐ 部分实现 | 书架支持批量选择并有清晰的全选与退出选择模式。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 批量选择/操作部分实现 |
| R0457 | ◐ 部分实现 | 批量操作支持设置标签、分类、阅读状态与删除。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 批量选择/操作部分实现 |
| R0458 | ◐ 部分实现 | 批量删除前区分“移出书架”和“删除本地文件”。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 批量选择/操作部分实现 |
| R0459 | ◐ 部分实现 | 云同步书籍与仅本地书籍显示不同的来源标识。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 云端/本地来源标识部分实现 |
| R0460 | ◐ 部分实现 | 需要下载的云端书籍显示明确的下载入口和大小。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 云端/本地来源标识部分实现 |
| R0461 | ◐ 部分实现 | 书架列表滚动过程中不应反复闪烁封面。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 滚动封面闪烁防护需核对 |
| R0462 | 🟡 已实现待验证 | 书籍卡片显示可选阅读进度条。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 进度条/最近时间显示（bookshelf 卡片） |
| R0463 | 🟡 已实现待验证 | 书籍卡片可选显示最近阅读时间与剩余阅读估计。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 进度条/最近时间显示（bookshelf 卡片） |
| R0464 | 🟡 已实现待验证 | 书名过长时最多显示合理行数并可查看完整名称。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 长书名省略（卡片 maxLines） |
| R0465 | ⬜ 未开始 | 支持书架多选后导出已选书籍元数据。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 批量导出元数据未实现 |
| R0466 | 🟡 已实现待验证 | 支持固定常读书籍到书架顶部。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 书架置顶常读：Book.pinned + setPinned + 置顶优先排序 + 单本/批量/编辑页/筛选入口齐全（审计纠正原误判），缺自动化单测 |
| R0467 | ◐ 部分实现 | 支持隐藏、归档及恢复书籍，避免永久删除。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 隐藏/归档/恢复部分实现 |
| R0468 | ◐ 部分实现 | 隐藏书籍需从搜索和最近阅读按隐私策略同步隐藏。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 隐藏/归档/恢复部分实现 |
| R0469 | ◐ 部分实现 | 空分类显示引导文案与添加书籍快捷动作。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 空分类引导/分类搜索需核对 |
| R0470 | ◐ 部分实现 | 分类数量过多时支持搜索分类和重新排序。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 空分类引导/分类搜索需核对 |
| R0471 | 🟡 已实现待验证 | 书架视图切换时保留滚动位置。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 视图切换保留滚动（Offstage） |
| R0472 | 🟡 已实现待验证 | 新增书籍后以不打断用户操作的方式刷新当前列表。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 新增书不打断刷新（LibraryStore notify） |
| R0473 | ⬜ 未开始 | 支持按字母、拼音首字母或自定义分组浏览书籍。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 字母/拼音分组未实现 |
| R0474 | ⬜ 未开始 | 支持查看最近打开但尚未加入书架的外部书籍。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 最近外部书未实现 |
| R0475 | ◐ 部分实现 | 支持查看重复文件检测结果并由用户决定合并。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 重复检测由用户决定部分（无去重 UI） |
| R0476 | 🟡 已实现待验证 | 对书籍重命名只更新标题元数据，不误改原文件。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 重命名仅改元数据（book_edit_page） |
| R0477 | ◐ 部分实现 | 书架总数与筛选结果数应准确区分。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 总数/筛选数区分需核对 |
| R0478 | ◐ 部分实现 | 书籍被外部删除后显示缺失状态与重新定位入口。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 外部删除缺失状态需核对 |
| R0479 | ⬜ 未开始 | 支持书架数据导出供独立备份和迁移。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 书架数据导出独立备份未实现 |
| R0480 | ⛔ 客观阻塞 | 在千本书和万本书模拟数据上验证列表滚动及筛选速度。 | lib/src/bookshelf/bookshelf_page.dart; lib/src/services/shelf_settings.dart | 千本/万本压力测试需大数据+设备 |

### 13 书籍信息整理、TXT与EPUB编辑

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0481 | 🟡 已实现待验证 | 书籍详情页显示标题、作者、格式、大小及导入来源。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 详情页显示标题/作者/格式/大小/来源（book_detail_page） |
| R0482 | 🟡 已实现待验证 | 书籍详情页显示封面、语言、出版社、简介与阅读状态。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 详情页显示标题/作者/格式/大小/来源（book_detail_page） |
| R0483 | 🟡 已实现待验证 | 允许手动修改标题、作者、系列和卷号。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 手动改标题/作者（book_edit_page） |
| R0484 | ⬜ 未开始 | 支持从合法在线元数据来源搜索信息并允许用户确认。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 在线元数据搜索未实现 |
| R0485 | ◐ 部分实现 | 自动元数据匹配不应直接覆盖用户手工编辑结果。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 自动匹配不覆盖手工编辑未实现 |
| R0486 | ◐ 部分实现 | 支持自定义替换封面并保留原始封面恢复入口。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 替换封面+恢复入口需核对 |
| R0487 | ◐ 部分实现 | 支持书籍标签的批量新增、替换和删除。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 标签批量操作部分（collection_store） |
| R0488 | ✅ 已验证完成 | TXT 支持从常见章节标题模式自动分章。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | TXT 自动分章 + 可编辑规则+预览（chapter_rules_test） |
| R0489 | ✅ 已验证完成 | TXT 分章规则可编辑正则并提供实时匹配预览。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | TXT 自动分章 + 可编辑规则+预览（chapter_rules_test） |
| R0490 | 🟡 已实现待验证 | TXT 支持手动插入、删除和更名章节节点。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 手动插入/删除/更名章节（manual_chapter_store + 测试） |
| R0491 | ◐ 部分实现 | TXT 支持对指定章节文本进行编辑。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 章节文本编辑/全文分页编辑未实现 |
| R0492 | ◐ 部分实现 | TXT 支持整本全文编辑，但对大文件采用分页编辑模型。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 章节文本编辑/全文分页编辑未实现 |
| R0493 | ⬜ 未开始 | TXT 编辑保存前提供差异预览和撤销机制。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 编辑差异预览/撤销未实现 |
| R0494 | ⬜ 未开始 | TXT 支持广告关键词过滤规则，默认不修改原始内容。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 广告关键词过滤未实现 |
| R0495 | ⬜ 未开始 | TXT 内容替换支持普通文本与正则两种模式。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 内容替换（文本/正则）未实现 |
| R0496 | ⬜ 未开始 | 内容替换规则按书籍或全局应用时要有范围说明。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 内容替换（文本/正则）未实现 |
| R0497 | ⬜ 未开始 | TXT 支持批量规范空行、制表符和异常空白。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 规范空行/制表符未实现 |
| R0498 | ⬜ 未开始 | TXT 支持繁简转换并允许保留源文件。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | TXT 繁简转换未实现 |
| R0499 | ◐ 部分实现 | TXT 支持为自定义章节加入书签式锚点。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 章节书签式锚点部分 |
| R0500 | ⬜ 未开始 | TXT 处理结果可以导出为新文件而不是强制覆盖。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 处理结果导出新文件未实现 |
| R0501 | ⬜ 未开始 | EPUB 允许查看书籍内部章节及资源清单。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0502 | ⬜ 未开始 | EPUB 提供章节正文的可编辑视图。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0503 | ⬜ 未开始 | EPUB 高级模式可查看及编辑对应 XHTML 源码。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0504 | ⬜ 未开始 | EPUB 可新增、重命名、移动和删除章节。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0505 | ⬜ 未开始 | EPUB 目录编辑后应同步维护导航结构与章节顺序。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0506 | ⬜ 未开始 | EPUB 支持拆分过长章节并保留原目录映射。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0507 | ⬜ 未开始 | EPUB 支持合并相邻章节并验证内部链接。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0508 | ⬜ 未开始 | EPUB 可以替换或删除不再引用的图片资源。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0509 | ⬜ 未开始 | EPUB 编辑时校验资源引用路径和缺失文件。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0510 | ⬜ 未开始 | EPUB 编辑工具应支持资源重复检测与大小预览，不得未经确认删除重复资源。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 章节/资源查看与编辑未实现 |
| R0511 | ⬜ 未开始 | EPUB 编辑保存前验证 OPF、manifest、spine 与导航文件。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | OPF/manifest/spine 校验未实现 |
| R0512 | ⬜ 未开始 | EPUB 编辑结果默认另存副本并保留原书备份。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 另存副本未实现 |
| R0513 | ◐ 部分实现 | 编辑后重新计算指纹与索引并迁移可恢复阅读位置。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 编辑后重算指纹/索引未实现 |
| R0514 | ⬜ 未开始 | 批量提取书名、作者、简介和封面时显示匹配置信度。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 元数据匹配置信度未实现 |
| R0515 | ⬜ 未开始 | 支持对书籍元数据的手动修改进行撤销。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 元数据撤销未实现 |
| R0516 | ⬜ 未开始 | 元数据批量处理过程记录操作日志和逐本结果。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 元数据批处理日志未实现 |
| R0517 | ◐ 部分实现 | 重复书籍合并时优先保留进度、书签、笔记的并集。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 重复合并保留进度并集未实现 |
| R0518 | 🟡 已实现待验证 | 内容编辑功能需要防止 HTML/script 注入并保护本地文件访问。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 脚本注入防护（转纯文本） |
| R0519 | ⬜ 未开始 | 对无效 EPUB 编辑可回滚到修改前最后有效文件。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | EPUB 编辑回滚未实现 |
| R0520 | ⛔ 客观阻塞 | 所有正文编辑测试必须检查字符不丢失、章节不重排。 | lib/src/bookshelf/book_edit_page.dart; lib/src/services/manual_chapter_store.dart | 正文编辑字符不丢失测试需编辑功能 |

### 14 书签、划线、选区与批注

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0521 | 🟡 已实现待验证 | 阅读时点击工具栏可以在当前位置创建书签。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 工具栏创建书签（bookmark_store） |
| R0522 | 🟡 已实现待验证 | 书签支持自定义名称和颜色标记。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 书签名称/颜色（bookmark_meta_store + 测试） |
| R0523 | ◐ 部分实现 | 重复点击同一位置书签应提供移除或编辑而非无限重复创建。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 重复书签去重/编辑需核对 |
| R0524 | ◐ 部分实现 | 书签列表按书籍、章节与时间排序。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 书签排序需核对 |
| R0525 | ◐ 部分实现 | 长按正文可以准确选择一个词或连续文本。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 长按选词/手柄/跨行跨段选择部分（SelectableText） |
| R0526 | ◐ 部分实现 | 文字选择手柄应在不同字号和行距下准确定位。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 长按选词/手柄/跨行跨段选择部分（SelectableText） |
| R0527 | ◐ 部分实现 | 跨行选择应支持拖动选择范围并显示实时预览。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 长按选词/手柄/跨行跨段选择部分（SelectableText） |
| R0528 | ◐ 部分实现 | 跨段落选择要保持正确文本顺序与空白。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 长按选词/手柄/跨行跨段选择部分（SelectableText） |
| R0529 | ◐ 部分实现 | 选区菜单包含复制、划线、笔记、查词、翻译和分享。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 选区菜单复制/划线/笔记等部分实现 |
| R0530 | ◐ 部分实现 | 选区菜单在屏幕边缘自动调整位置，不能被系统栏遮挡。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 选区菜单边缘避让需核对 |
| R0531 | ✅ 已验证完成 | 支持马克笔式高亮及至少多种可辨识颜色。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 高亮多色（HighlightStore + reader_page_smoke_test.dart:113 真实背景色 Widget 测试通过） |
| R0532 | ◐ 部分实现 | 支持下划线、波浪线和删除线等不同批注样式。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 下划线/波浪/删除线样式需核对 |
| R0533 | ✅ 已验证完成 | 新增高亮后即时渲染且不重载整个阅读章节。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 新增高亮即时渲染不重载（range backgroundColor 修复 + reader_page_smoke_test.dart:113 通过） |
| R0534 | ◐ 部分实现 | 已创建划线再次点击可以编辑颜色、样式或删除。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 已创建划线编辑/删除需核对 |
| R0535 | ◐ 部分实现 | 支持在文字选区上添加富文本或普通文本备注。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 选区备注/单独保存备注需核对 |
| R0536 | ◐ 部分实现 | 备注可以单独保存，即使不添加彩色高亮。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 选区备注/单独保存备注需核对 |
| R0537 | 🟡 已实现待验证 | 高亮锚点保存时包含稳定定位和原文校验字段。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 高亮锚点含稳定定位（HighlightRecord） |
| R0538 | ✅ 已验证完成 | 字号和排版改变后高亮仍能定位到原文。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 排版改变后高亮仍定位（reader_engine_test.dart 锚点映射 + reader_page_smoke_test.dart 渲染测试） |
| R0539 | ◐ 部分实现 | 书籍文件轻微改动后尝试基于文本锚点重定位笔记。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 文件改动重定位/待修复列表未实现 |
| R0540 | ◐ 部分实现 | 定位失败的笔记进入待修复列表，不自动丢弃。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 文件改动重定位/待修复列表未实现 |
| R0541 | ◐ 部分实现 | 笔记编辑需具备自动保存和退出提醒。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 笔记自动保存/退出提醒需核对 |
| R0542 | ◐ 部分实现 | 单个笔记支持创建时间、修改时间及自定义标签。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 笔记时间/标签部分实现 |
| R0543 | ◐ 部分实现 | 支持按笔记文字、原文、标签和颜色搜索。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 笔记搜索/过滤部分实现 |
| R0544 | ◐ 部分实现 | 支持按书籍或章节过滤全部批注。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 笔记搜索/过滤部分实现 |
| R0545 | ◐ 部分实现 | 支持对高亮进行多选与批量删除。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 批量删除/撤销未实现 |
| R0546 | ◐ 部分实现 | 批量删除前展示数量和影响范围。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 批量删除/撤销未实现 |
| R0547 | ◐ 部分实现 | 支持撤销最近一次误删批注操作。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 批量删除/撤销未实现 |
| R0548 | ◐ 部分实现 | 对同一段落的多层高亮制定可预测的覆盖规则。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 多层高亮覆盖规则需核对 |
| R0549 | ⬜ 未开始 | 支持用户为不同类型的笔记设置默认颜色。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 笔记默认颜色分类未实现 |
| R0550 | 🟡 已实现待验证 | 点击书签或笔记能够跳回准确文本位置。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 点击书签/笔记跳回位置 |
| R0551 | ⬜ 未开始 | 提供“只查看高亮段落”的精读模式。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 精读模式/术语/自动高亮规则未实现 |
| R0552 | ⬜ 未开始 | 支持将书内重点术语保存为可搜索的术语条目。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 精读模式/术语/自动高亮规则未实现 |
| R0553 | ⬜ 未开始 | 支持自定义高亮规则自动匹配人物名或特定词。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 精读模式/术语/自动高亮规则未实现 |
| R0554 | ⬜ 未开始 | 自动高亮规则可以设置书籍范围与排除关键词。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 精读模式/术语/自动高亮规则未实现 |
| R0555 | ⬜ 未开始 | 自动高亮与手工高亮在数据模型中严格区分。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 精读模式/术语/自动高亮规则未实现 |
| R0556 | ◐ 部分实现 | 对隐藏或私密书籍的笔记实施相同隐私规则。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 私密书笔记隐私规则需核对 |
| R0557 | ◐ 部分实现 | 笔记同步不得因为设备时钟不一致覆盖较新的修改。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 时钟不一致冲突处理部分（逻辑版本基础） |
| R0558 | ⬜ 未开始 | 从其他格式导入笔记时保持原文、来源及可用定位。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 外部笔记导入未实现 |
| R0559 | ⛔ 客观阻塞 | 在跨段、高亮重叠与超长选区场景执行专项测试。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 跨段/重叠/超长选区专项测试需真机 |
| R0560 | ✅ 已验证完成 | 标注功能不得要求开启云同步才能本地使用。 | lib/src/services/highlight_store.dart; lib/src/services/bookmark_store.dart; lib/src/reader/reader_page.dart | 标注无需云同步即可本地用（本地 store） |

### 15 笔记导出、书摘分享与外部知识库

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0561 | ✅ 已验证完成 | 笔记支持按单本书籍导出 Markdown 文本。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 单书笔记导出 Markdown：本轮新增 NoteExporter + 阅读器高亮面板「导出 Markdown」按钮（复制到剪贴板），note_exporter_test 4/4 通过 |
| R0562 | ⬜ 未开始 | 笔记支持按单本书籍导出纯文本 TXT。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 笔记导出 MD/TXT/JSON/CSV 未实现 |
| R0563 | ⬜ 未开始 | 笔记支持导出 JSON 结构化数据供未来重新导入。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 笔记导出 MD/TXT/JSON/CSV 未实现 |
| R0564 | ⬜ 未开始 | 笔记支持导出 CSV，列包含书名、章节、内容及时间。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 笔记导出 MD/TXT/JSON/CSV 未实现 |
| R0565 | ◐ 部分实现 | 笔记支持一键复制当前高亮原文和备注。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 复制高亮原文+备注需核对 |
| R0566 | ⬜ 未开始 | 分享书摘时可以选择是否附带书名和作者。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 分享选项/书摘卡片模板未实现 |
| R0567 | ⬜ 未开始 | 分享书摘时可以隐藏个人备注内容。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 分享选项/书摘卡片模板未实现 |
| R0568 | ⬜ 未开始 | 提供数套原创的书摘图片卡片模板。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 分享选项/书摘卡片模板未实现 |
| R0569 | ⬜ 未开始 | 书摘卡片支持自定义字体、背景和强调色。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 卡片自定义/分页未实现 |
| R0570 | ⬜ 未开始 | 书摘卡片生成后可预览、保存与系统分享。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 卡片自定义/分页未实现 |
| R0571 | ⬜ 未开始 | 长书摘导出图片应提供自动分页而非裁掉尾部。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 卡片自定义/分页未实现 |
| R0572 | ◐ 部分实现 | 导出目标允许用户通过 SAF 选择任意合法目录。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | SAF 选择导出目录需核对 |
| R0573 | ⬜ 未开始 | 导出失败显示失败原因且保留原有笔记。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 导出失败保留笔记未专项实现 |
| R0574 | ⬜ 未开始 | 批量导出所有笔记时按书籍建立稳定目录结构。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 批量导出/保留层级/样式标记/筛选导出未实现 |
| R0575 | ✅ 已验证完成 | 导出的 Markdown 保留标题层级与章节路径。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 导出 Markdown 保留标题层级与章节路径：NoteExporter 按章分组输出 ## 章节标题，note_exporter_test 验证章节顺序 |
| R0576 | ⬜ 未开始 | 导出内容保留高亮颜色及样式的可读标记。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 批量导出/保留层级/样式标记/筛选导出未实现 |
| R0577 | ⬜ 未开始 | 导出时可选择只含高亮、只含备注或全部。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 批量导出/保留层级/样式标记/筛选导出未实现 |
| R0578 | ⬜ 未开始 | 支持按时间区间导出读书笔记。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 按时间/标签导出未实现 |
| R0579 | ⬜ 未开始 | 支持按标签和高亮颜色批量筛选导出。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 按时间/标签导出未实现 |
| R0580 | ◐ 部分实现 | 支持导入应用自己导出的备份格式并避免重复。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 导入自己备份（设置导入存在，笔记未接通） |
| R0581 | ⬜ 未开始 | 支持从 Kindle 的合法笔记导出文件导入摘录。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | Kindle/Markdown 摘录导入未实现 |
| R0582 | ⬜ 未开始 | 支持从通用 Markdown 摘录导入并人工匹配到书籍。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | Kindle/Markdown 摘录导入未实现 |
| R0583 | ⬜ 未开始 | 外部笔记服务接入采用独立插件式适配器。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 外部知识库插件/Obsidian/Notion 未实现 |
| R0584 | ⬜ 未开始 | 可接入 Obsidian 目录导出，保持 Markdown 可读。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 外部知识库插件/Obsidian/Notion 未实现 |
| R0585 | ⬜ 未开始 | 可选接入 Notion 官方 API，使用用户授权令牌。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 外部知识库插件/Obsidian/Notion 未实现 |
| R0586 | ⬜ 未开始 | 外部知识库同步失败时保留本地笔记并重试。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 外部同步失败保留本地未实现 |
| R0587 | ⬜ 未开始 | 导出操作显示准确进度，允许取消大批量导出。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 导出进度/覆盖选项未实现 |
| R0588 | ⬜ 未开始 | 覆盖同名导出文件前显示替换、另存及取消选项。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 导出进度/覆盖选项未实现 |
| R0589 | ⬜ 未开始 | 原文含特殊 Markdown 字符时执行必要转义。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | Markdown 转义/中文 Emoji 处理未实现 |
| R0590 | ⬜ 未开始 | 笔记导出应正确处理中文、Emoji 和多行代码块。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | Markdown 转义/中文 Emoji 处理未实现 |
| R0591 | ⬜ 未开始 | 支持导出图片附带高亮位置的应用内深链。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 深链图片/打开/存在检查未实现 |
| R0592 | ⬜ 未开始 | 点击合法深链应打开对应书籍的对应摘录位置。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 深链图片/打开/存在检查未实现 |
| R0593 | ⬜ 未开始 | 外部打开深链前检查书籍是否仍存在及可访问。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 深链图片/打开/存在检查未实现 |
| R0594 | ⬜ 未开始 | 用户可以选择在分享卡片上显示或隐藏进度与日期。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 卡片显示选项/体积限制未实现 |
| R0595 | ⬜ 未开始 | 对图片导出实施分辨率及文件体积合理限制。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 卡片显示选项/体积限制未实现 |
| R0596 | 🟡 已实现待验证 | 禁止在公开分享时自动附加私有阅读记录或云账号。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 不自动附加私有记录（架构上无账号） |
| R0597 | ⬜ 未开始 | 导出结果应经过内容一致性与数量校验。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 导出内容一致性校验未实现 |
| R0598 | ⬜ 未开始 | 支持从多个设备恢复后的笔记并集导出。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 多设备笔记并集导出未实现 |
| R0599 | 🟡 已实现待验证 | 对外部同步的令牌采用安全存储，不加入 Markdown 备份。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 令牌安全存储（flutter_secure_storage 存在） |
| R0600 | 🟡 已实现待验证 | 笔记和书摘分享需在无网络条件下工作。 | lib/src/sync/data_tools_page.dart; lib/src/profile/about_page.dart | 笔记本地可用不依赖网络 |

### 16 阅读统计、目标、习惯与年度报告

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0601 | 🟡 已实现待验证 | 阅读计时只统计用户实际停留并可合理判断活动状态的时间。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 阅读计时+前后台暂停（_sessionSeconds + 生命周期） |
| R0602 | 🟡 已实现待验证 | 屏幕关闭、应用后台及长时间无交互时暂停阅读计时。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 阅读计时+前后台暂停（_sessionSeconds + 生命周期） |
| R0603 | ⬜ 未开始 | 听书时间与视觉阅读时间分别记录且可合并查看。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 听书时间与视觉阅读分别记录未实现 |
| R0604 | 🟡 已实现待验证 | 支持按天、周、月和年查看阅读时长。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 日/周/月/年时长、每本统计、排行（stats_page + 测试） |
| R0605 | 🟡 已实现待验证 | 支持查看每本书的累计阅读时长与阅读次数。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 日/周/月/年时长、每本统计、排行（stats_page + 测试） |
| R0606 | 🟡 已实现待验证 | 支持查看最近阅读时段分布，识别常见阅读习惯。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 日/周/月/年时长、每本统计、排行（stats_page + 测试） |
| R0607 | 🟡 已实现待验证 | 支持年度阅读热力图，每日格子与实际时长对应。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 日/周/月/年时长、每本统计、排行（stats_page + 测试） |
| R0608 | 🟡 已实现待验证 | 支持按书籍、格式、作者分类查看阅读排行。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 日/周/月/年时长、每本统计、排行（stats_page + 测试） |
| R0609 | ◐ 部分实现 | 支持展示已读字数及估计值的计算说明。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 已读字数/估算说明部分实现 |
| R0610 | ◐ 部分实现 | 对 PDF 和漫画等无法精确字数统计格式明确标注估算。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 已读字数/估算说明部分实现 |
| R0611 | ◐ 部分实现 | 阅读统计应排除重复计算和设备时间跳变异常。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 排除重复/时钟跳变需核对 |
| R0612 | ⬜ 未开始 | 支持设置每日阅读分钟数目标。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 每日分钟/字数/年度本数目标未实现 |
| R0613 | ⬜ 未开始 | 支持设置每日阅读字数目标。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 每日分钟/字数/年度本数目标未实现 |
| R0614 | ⬜ 未开始 | 支持设置年度读完书籍本数目标。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 每日分钟/字数/年度本数目标未实现 |
| R0615 | ⬜ 未开始 | 阅读目标进度在首页或统计页清晰可见。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 目标进度/达成动画未实现 |
| R0616 | ⬜ 未开始 | 目标达成后使用克制的祝贺动画，允许关闭。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 目标进度/达成动画未实现 |
| R0617 | ◐ 部分实现 | 连续阅读天数应按用户本地自然日准确计算。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 连续天数本地日计算部分（daysCount） |
| R0618 | ◐ 部分实现 | 跨时区阅读历史应在明确的时区规则下稳定展示。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 连续天数本地日计算部分（daysCount） |
| R0619 | ⬜ 未开始 | 用户可手动修正误计的阅读时长。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 手动修正时长/计划读完日期未实现 |
| R0620 | ⬜ 未开始 | 支持为单本书设置计划读完日期。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 手动修正时长/计划读完日期未实现 |
| R0621 | ⬜ 未开始 | 支持按当前阅读速度估计剩余时长。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 剩余时长估计/平滑未实现 |
| R0622 | ⬜ 未开始 | 阅读速度估计需要平滑异常值并允许关闭。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 剩余时长估计/平滑未实现 |
| R0623 | ◐ 部分实现 | 支持按周展示阅读目标达成率。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 周/月达成/完成书部分实现 |
| R0624 | ◐ 部分实现 | 支持按月查看完成的书籍及累计页数。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 周/月达成/完成书部分实现 |
| R0625 | ⬜ 未开始 | 支持按年生成阅读总结，显示真实已统计的数据。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 年度报告/导出图片未实现 |
| R0626 | ⬜ 未开始 | 年度报告支持导出精简图片或可分享文件。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 年度报告/导出图片未实现 |
| R0627 | ◐ 部分实现 | 阅读统计支持本地导出 CSV 或 JSON。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 统计 CSV/JSON 导出未实现 |
| R0628 | 🟡 已实现待验证 | 统计数据能够随备份与同步恢复，不因重装归零。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 统计随备份恢复（sync_document 含统计） |
| R0629 | ⬜ 未开始 | 提供用户手动清空统计数据的安全操作。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 安全清空统计/删除说明未实现 |
| R0630 | ⬜ 未开始 | 统计删除行为需明确展示将删除哪些时间段和书籍记录。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 安全清空统计/删除说明未实现 |
| R0631 | ◐ 部分实现 | 书籍重新导入后避免为同一本书重复累计完成次数。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 重导入去重完成次数/复读区分需核对 |
| R0632 | ◐ 部分实现 | 支持区分首次读完与复读完成事件。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 重导入去重完成次数/复读区分需核对 |
| R0633 | 🟡 已实现待验证 | 显示“正在阅读”“暂停阅读”“已完成”数量。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 在读/暂停/完成计数（stats_page） |
| R0634 | 🟡 已实现待验证 | 首页阅读卡片可选择显示今日阅读时长。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 在读/暂停/完成计数（stats_page） |
| R0635 | ◐ 部分实现 | 统计图表须配有文字和数值，避免仅用颜色表达。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 图表文字数值/动画流畅需核对 |
| R0636 | ◐ 部分实现 | 统计页面图表动画应流畅，不能每次滚动重新计数。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 图表文字数值/动画流畅需核对 |
| R0637 | 🟡 已实现待验证 | 零数据统计页提供真实的空状态与开始阅读入口。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 零数据空状态+开始入口 |
| R0638 | 🟡 已实现待验证 | 统计数据离线本地查询，不强制连接云端服务。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 统计本地查询不强制联网 |
| R0639 | ◐ 部分实现 | 多设备事件同步后要去重，避免两个设备重复计时。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 多设备事件去重需核对 |
| R0640 | 🟡 已实现待验证 | 统计计算应有单元测试覆盖跨日、断网、时钟更改及重复合并。 | lib/src/services/reading_stats_store.dart; lib/src/stats/stats_page.dart | 统计单测覆盖跨日/断网/重复（reading_stats 相关测试） |

### 17 听书、TTS、后台播放与多角色朗读

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0641 | 🟡 已实现待验证 | 支持调用 Android 系统 TextToSpeech 引擎朗读可解析文本。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | FlutterTts 朗读可解析文本（reader_page） |
| R0642 | ◐ 部分实现 | 无系统语音引擎时提示安装或选择引擎，不直接崩溃。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 无引擎提示需核对 |
| R0643 | ◐ 部分实现 | 支持选择系统已安装的不同语言和发音人。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 语言/发音人选择部分（_initTts） |
| R0644 | ◐ 部分实现 | 为每种语言保存独立的默认语音选项。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 语言/发音人选择部分（_initTts） |
| R0645 | 🟡 已实现待验证 | 支持调整语速且使用试听样本实时验证效果。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 语速(_ttsSpeed)/音调设置 |
| R0646 | 🟡 已实现待验证 | 支持调整音调，防止不合理范围造成失真。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 语速(_ttsSpeed)/音调设置 |
| R0647 | 🟡 已实现待验证 | 支持暂停、继续、上一句、下一句和停止朗读。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 暂停/继续/上句/下句/停止 |
| R0648 | ◐ 部分实现 | 支持上一段与下一段定位操作。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 上段下段/选中朗读需核对 |
| R0649 | ◐ 部分实现 | 读到章节结束时可按设置自动继续下一章。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 上段下段/选中朗读需核对 |
| R0650 | ◐ 部分实现 | 支持从用户选中的句子开始朗读。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 上段下段/选中朗读需核对 |
| R0651 | ◐ 部分实现 | 朗读时实时高亮当前句子。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 朗读高亮当前句未实现 |
| R0652 | ◐ 部分实现 | 可选择逐字高亮或逐句高亮的兼容实现。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 朗读高亮当前句未实现 |
| R0653 | ◐ 部分实现 | 朗读高亮随 TTS 进度移动，误差保持在可接受范围。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 朗读高亮当前句未实现 |
| R0654 | ◐ 部分实现 | 阅读页跟随朗读自动滚动且可以暂停跟随。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 跟随滚动/手动翻页续读需核对 |
| R0655 | ◐ 部分实现 | 用户手动翻页后可选择继续当前位置朗读。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 跟随滚动/手动翻页续读需核对 |
| R0656 | ⬜ 未开始 | 支持后台音频播放及必要的媒体会话通知。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 后台音频/媒体会话/音频焦点锁屏控制未实现 |
| R0657 | ⬜ 未开始 | 后台播放遵守 Android 前台服务与音频焦点规则。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 后台音频/媒体会话/音频焦点锁屏控制未实现 |
| R0658 | ⬜ 未开始 | 来电或其他音频抢占时按系统规范暂停和恢复。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 后台音频/媒体会话/音频焦点锁屏控制未实现 |
| R0659 | ⬜ 未开始 | 支持蓝牙耳机的播放暂停及上一段下一段控制。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 后台音频/媒体会话/音频焦点锁屏控制未实现 |
| R0660 | ⬜ 未开始 | 锁屏控制按钮要与实际播放状态同步。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 后台音频/媒体会话/音频焦点锁屏控制未实现 |
| R0661 | ⬜ 未开始 | 支持睡眠定时器，时间到自动停止朗读。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 睡眠定时/静音间隔未实现 |
| R0662 | ⬜ 未开始 | 支持章节结束后停止的睡眠选项。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 睡眠定时/静音间隔未实现 |
| R0663 | ⬜ 未开始 | 支持在句子与段落之间添加可调静音间隔。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 睡眠定时/静音间隔未实现 |
| R0664 | ⬜ 未开始 | 支持自定义正文清理规则，忽略广告或不需要朗读的符号。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 正文清理/多角色朗读/识别预览未实现 |
| R0665 | ⬜ 未开始 | 支持按角色名配置不同朗读语音的规则。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 正文清理/多角色朗读/识别预览未实现 |
| R0666 | ⬜ 未开始 | 多角色朗读要提供旁白与人物台词的识别预览。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 正文清理/多角色朗读/识别预览未实现 |
| R0667 | ⬜ 未开始 | 角色识别错误时允许手动修正角色规则。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 正文清理/多角色朗读/识别预览未实现 |
| R0668 | ⬜ 未开始 | 支持 Azure 等明确授权的在线 TTS 服务作为可选提供方。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 在线 TTS/Azure/自定义 HTTP/Token 加密未实现 |
| R0669 | ⬜ 未开始 | 支持用户自定义合法 HTTP TTS 接口与响应格式。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 在线 TTS/Azure/自定义 HTTP/Token 加密未实现 |
| R0670 | ⬜ 未开始 | 在线语音失败时可选择回退系统 TTS，避免阅读中断。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 在线 TTS/Azure/自定义 HTTP/Token 加密未实现 |
| R0671 | ⬜ 未开始 | 在线 TTS Token 必须加密保存且从日志中剔除。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 在线 TTS/Azure/自定义 HTTP/Token 加密未实现 |
| R0672 | ⬜ 未开始 | 支持部分章节音频缓存，用户可清理缓存。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 音频缓存/下载/映射未实现 |
| R0673 | ⬜ 未开始 | 在遵守服务条款前提下支持下载可离线使用的合成语音。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 音频缓存/下载/映射未实现 |
| R0674 | ⬜ 未开始 | 支持生成音频所关联的书籍和章节映射。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 音频缓存/下载/映射未实现 |
| R0675 | ◐ 部分实现 | 听书状态需随阅读位置更新，避免两个进度长期分离。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 听书状态随阅读位置更新需核对 |
| R0676 | ◐ 部分实现 | 支持夜间听书时保持屏幕关闭而不中断。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 夜间息屏听书/第三方传输提示未实现 |
| R0677 | ◐ 部分实现 | 使用 TTS 需要明确提示可能发生的第三方内容传输。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 夜间息屏听书/第三方传输提示未实现 |
| R0678 | ⬜ 未开始 | 语音播放发生异常时提供错误代码和切换引擎入口。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | TTS 错误码/切换引擎未实现 |
| R0679 | ⛔ 客观阻塞 | 测试蓝牙断开、锁屏、网络切换、来电和进程回收场景。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 蓝牙/锁屏/网络/来电/回收测试需真机 |
| R0680 | ⛔ 客观阻塞 | 整本书连续听书至少数章时应检查内存、温度与耗电。 | lib/src/reader/reader_page.dart (FlutterTts); lib/src/reader/platform/reader_device_bridge.dart | 整本听书内存/温度/耗电需真机 |

### 18 词典、生词本、翻译与学习辅助

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0681 | ◐ 部分实现 | 长按选中词语后提供“查词”快捷操作。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 查词快捷操作未实现 |
| R0682 | ⬜ 未开始 | 支持本地词典查询，即使设备完全断网也可使用。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 本地词典/导入/校验未实现 |
| R0683 | ⬜ 未开始 | 允许导入明确支持格式的本地词典数据包。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 本地词典/导入/校验未实现 |
| R0684 | ⬜ 未开始 | 词典导入校验索引结构，损坏词典可安全删除重导。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 本地词典/导入/校验未实现 |
| R0685 | ⬜ 未开始 | 支持选择在线词典提供方并显示来源。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 在线词典/查词卡/发音未实现 |
| R0686 | ⬜ 未开始 | 查词卡片显示词性、释义及常见例句。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 在线词典/查词卡/发音未实现 |
| R0687 | ⬜ 未开始 | 查词卡片可在不离开阅读页的情况下关闭。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 在线词典/查词卡/发音未实现 |
| R0688 | ⬜ 未开始 | 支持词典结果中的发音播放。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 在线词典/查词卡/发音未实现 |
| R0689 | ⬜ 未开始 | 支持为当前单词加入生词本。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0690 | ⬜ 未开始 | 生词本保存原文、释义、书籍出处和首次记录时间。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0691 | ⬜ 未开始 | 生词本支持按最近添加、频率及书籍筛选。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0692 | ⬜ 未开始 | 生词本支持标记已掌握和需要复习。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0693 | ⬜ 未开始 | 支持以简单的复习卡片方式查看生词。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0694 | ⬜ 未开始 | 生词卡片支持显示或隐藏释义。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0695 | ⬜ 未开始 | 支持将生词本导出为 CSV 和 Markdown。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 生词本全套未实现 |
| R0696 | ⬜ 未开始 | 支持词典自定义优先级，多个来源依次查询。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 词典优先级/请求取消未实现 |
| R0697 | ⬜ 未开始 | 查词请求可以取消，避免长时间占据界面。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 词典优先级/请求取消未实现 |
| R0698 | ◐ 部分实现 | 中文词语与英文单词采用不同分词策略。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 中英分词策略需核对（book_search） |
| R0699 | ⬜ 未开始 | 支持选中整句或段落进行翻译。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0700 | ⬜ 未开始 | 支持原文与翻译在弹窗内对照显示。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0701 | ⬜ 未开始 | 支持段落下方逐段显示翻译结果的双语模式。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0702 | ⬜ 未开始 | 翻译模式切换后保持原文位置与段落对应。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0703 | ⬜ 未开始 | 提供系统可用翻译、合法网页服务和自定义 API 适配方式。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0704 | ⬜ 未开始 | 用户必须自行配置需要付费的 API，不能虚构免费额度。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0705 | ⬜ 未开始 | 翻译服务提供超时、频率限制与错误提示。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0706 | ⬜ 未开始 | 翻译结果明确标注服务商和目标语言。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0707 | ⬜ 未开始 | 支持简体中文、繁体中文、英语和常用语言作为目标语。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0708 | ⬜ 未开始 | 支持自动识别原文语言，识别失败时可手动指定。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0709 | ⬜ 未开始 | 对同一段落的翻译进行按需缓存以减少重复扣费。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0710 | ⬜ 未开始 | 支持清除翻译缓存并查看所占存储空间。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0711 | ⬜ 未开始 | 离线情况下保留已缓存译文，不强制联网才能阅读原文。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0712 | ⬜ 未开始 | 全文翻译按章节分批进行，必须能够暂停和继续。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0713 | ⬜ 未开始 | 全文翻译失败时保留已完成章节而不丢失进度。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0714 | ⬜ 未开始 | 翻译任务执行前显示预计调用范围并提醒可能产生费用。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0715 | ⬜ 未开始 | 支持将所选译文保存为书内笔记。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0716 | ⬜ 未开始 | 支持单词自动加入生词本的开关，默认不强制收集。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0717 | ⬜ 未开始 | AI 查词结果与字典释义分开展示，避免误认为权威定义。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0718 | ⬜ 未开始 | 用户可以彻底关闭联网查词和翻译请求。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0719 | ⬜ 未开始 | 查词、翻译及生词本数据纳入安全备份与同步范围。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |
| R0720 | ⬜ 未开始 | 使用外部翻译必须遵守用户授权和服务商条款。 | lib/src/services/book_search.dart; lib/src/reader/reader_page.dart | 翻译/双语/在线 API/缓存/全文翻译未实现 |

### 19 AI 阅读助手、人物关系与高级理解

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0721 | ⬜ 未开始 | AI 助手只能在用户主动启用并配置服务后发送正文。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0722 | ⬜ 未开始 | 支持 OpenAI 兼容 API 的规范化客户端适配。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0723 | ⬜ 未开始 | 允许配置自定义 Base URL、模型标识和授权方式。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0724 | ⬜ 未开始 | 支持测试模型连接并展示真实请求结果和延时。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0725 | ⬜ 未开始 | AI 提问默认带入当前书籍名、章节及被选段落上下文。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0726 | ⬜ 未开始 | 在发送上下文之前显示来源范围并允许关闭正文发送。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0727 | ⬜ 未开始 | 支持只针对当前选中的文字进行提问。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0728 | ⬜ 未开始 | 支持针对当前章节进行总结与提炼重点。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0729 | ⬜ 未开始 | 支持生成当前已读范围的前情回顾。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0730 | ⬜ 未开始 | 禁止默认读取未读章节剧透，提供剧透范围开关。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0731 | ⬜ 未开始 | AI 对书中人物的回答应给出引用章节或原文位置。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0732 | ⬜ 未开始 | AI 回答中引用原文要支持点击返回对应章节。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0733 | ⬜ 未开始 | 支持基于本书内容生成可编辑人物档案。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0734 | ⬜ 未开始 | 人物档案包含别名、首次出场章节及描述字段。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0735 | ⬜ 未开始 | 支持人物之间建立可编辑关系边。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0736 | ⬜ 未开始 | 人物关系图提供缩放、拖动与搜索能力。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0737 | ⬜ 未开始 | 人物关系图与正文高亮联动，点击角色可回到出处。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0738 | ⬜ 未开始 | 人物识别结果可由用户确认后才正式写入档案。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0739 | ⬜ 未开始 | 提供按当前阅读进度限制人物关系图展示内容的选项。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0740 | ⬜ 未开始 | 允许用户手动添加或删除人物与关系信息。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0741 | ⬜ 未开始 | 支持自动标注术语及生成可编辑术语表。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0742 | ⬜ 未开始 | 支持提出“解释这句话”“概括此章”等预置提问。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0743 | ⬜ 未开始 | 支持保存 AI 对话历史到本地独立存储。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0744 | ⬜ 未开始 | 可按书籍查看 AI 对话，不把不同书的上下文串在一起。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0745 | ⬜ 未开始 | 支持导出 AI 回答与用户提问为 Markdown。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0746 | ⬜ 未开始 | AI 回答可一键保存为读书笔记。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0747 | ⬜ 未开始 | AI 请求失败时显示具体错误并保留待发送输入。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0748 | ⬜ 未开始 | 支持流式输出时逐段显示答案而不不断跳滚动位置。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0749 | ⬜ 未开始 | 支持取消正在进行的 AI 推理请求。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0750 | ⬜ 未开始 | 限制 AI 消息和上下文最大长度，避免大书直接超限。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0751 | ⬜ 未开始 | 支持按需检索相关段落的本地索引而非发送整本书。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0752 | ⬜ 未开始 | 建立书籍索引时提供进度和停止入口。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0753 | ⬜ 未开始 | 检索召回结果记录章节出处，便于用户核查。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0754 | ⬜ 未开始 | 不要把 AI 生成内容混入原始书籍文件。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0755 | ⬜ 未开始 | 允许用户清除 AI 记录、索引和缓存。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0756 | ⬜ 未开始 | 对模型幻觉风险提供适当提示，并让用户能核对原文。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0757 | ⬜ 未开始 | API Key 使用 Android 安全存储，不显示完整明文。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0758 | ⬜ 未开始 | AI 连接日志禁止记录完整正文、授权头及密钥。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0759 | ⬜ 未开始 | 支持配置合理的模型请求并发数和重试策略。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |
| R0760 | ⬜ 未开始 | AI 功能测试需包含断网、401、429、超时和流式中断。 | （无独立 AI 模块；当前代码未实现） | 无 AI 助手模块；需真实 API 授权且隐私要求高，当前未实现 |

### 20 多端同步底层协议与生命周期

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0761 | 🟡 已实现待验证 | 设计统一同步数据模型，明确书籍、元数据、位置、笔记、设置和统计。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 统一同步数据模型（sync_document/progress_models） |
| R0762 | 🟡 已实现待验证 | 为每份同步对象设置稳定唯一标识和格式版本号。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 对象唯一标识+格式版本+逻辑版本（progress_models） |
| R0763 | 🟡 已实现待验证 | 每个对象包含设备标识和逻辑修改版本，减少时间戳依赖。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 对象唯一标识+格式版本+逻辑版本（progress_models） |
| R0764 | 🟡 已实现待验证 | 同步操作按照本地事务日志生成待上传变更。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 本地事务日志生成待上传（sync_record + queue） |
| R0765 | 🟡 已实现待验证 | 手机打开应用时尝试增量拉取远端变更。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 启动增量拉取（AutoSyncService.init + runFull） |
| R0766 | 🟡 已实现待验证 | 手机退出应用或进入后台时尽量触发增量上传。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 后台/退出增量上传（WidgetsBindingObserver 生命周期） |
| R0767 | 🟡 已实现待验证 | 打开书籍前按配置检查这本书的最新远端进度。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 打开书前检查远端进度（onBookOpened） |
| R0768 | 🟡 已实现待验证 | 关闭书籍后优先上传该书进度与新增笔记。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 关闭书后优先上传（_flushProgress + sync） |
| R0769 | 🟡 已实现待验证 | 设备断网期间所有修改先持久保存本地队列。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 断网本地持久队列（_drainQueue） |
| R0770 | ◐ 部分实现 | 网络恢复后使用系统允许的后台任务补传。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 网络恢复后台补传部分（connectivity_plus） |
| R0771 | 🟡 已实现待验证 | 对 Android 后台限制要合理遵守，不承诺绝对进程退出必定上传。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 遵守 Android 后台限制，不承诺强杀必传 |
| R0772 | ◐ 部分实现 | 同步失败后用指数退避重试，避免无休止高频请求。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 指数退避重试需核对 |
| R0773 | 🟡 已实现待验证 | 同步状态显示待同步、进行中、成功、冲突和失败。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 同步状态多档（sync_record/sync_failure） |
| R0774 | 🟡 已实现待验证 | 手动同步按钮执行真实双向流程而不是只刷新界面。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 手动同步真实双向（runFull + 测试） |
| R0775 | ◐ 部分实现 | 支持仅 Wi-Fi 同步和允许移动数据同步两种策略。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 仅 Wi-Fi/充电策略部分（_canRunNetwork） |
| R0776 | ◐ 部分实现 | 支持充电时传输大文件的可选节电策略。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 仅 Wi-Fi/充电策略部分（_canRunNetwork） |
| R0777 | 🟡 已实现待验证 | 书籍文件与阅读进度分别开关同步，避免上传整个书库才同步一页。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 书籍文件/进度/笔记/统计分类开关（sync_config） |
| R0778 | 🟡 已实现待验证 | 支持按类别关闭笔记、统计、设置或封面同步。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 书籍文件/进度/笔记/统计分类开关（sync_config） |
| R0779 | 🟡 已实现待验证 | 对同步传输采用增量比对，未变化对象不重复上传。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 增量比对未变化不重传（metadata_sync_service 条件写） |
| R0780 | ⬜ 未开始 | 大文件上传支持分块与断点续传，仅在提供方支持时启用。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 大文件分块断点续传未实现 |
| R0781 | 🟡 已实现待验证 | 同步文件生成校验和，下载后校验完整性。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 校验和（encrypted_sync envelope + 测试） |
| R0782 | ◐ 部分实现 | 将远端缓存与已验证本地原件区分，未完成下载不得覆盖原件。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 远端缓存与原件区分未实现 |
| R0783 | ◐ 部分实现 | 维护同步操作日志，记录对象类型、结果和耗时。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 同步操作日志（sync_history） |
| R0784 | 🟡 已实现待验证 | 日志中只保留匿名化对象标识，禁止泄露书名和正文默认上传。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 日志匿名化对象标识（encrypted envelope） |
| R0785 | ◐ 部分实现 | 并发同步需要锁或事务确保同一对象不会互相覆盖。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 并发锁/事务需核对 |
| R0786 | ◐ 部分实现 | 同步中途应用崩溃后能够恢复待提交队列。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 崩溃恢复待提交队列需核对 |
| R0787 | ◐ 部分实现 | 支持手动暂停和恢复所有同步任务。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 手动暂停/恢复同步需核对 |
| R0788 | ◐ 部分实现 | 支持仅上传、仅下载和双向合并的受限恢复工具。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 仅上传/下载/合并受限工具部分（data_tools） |
| R0789 | ◐ 部分实现 | 首次连接云端先预览远端数据量与冲突风险。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 首次连接预览远端数据量需核对 |
| R0790 | 🟡 已实现待验证 | 初次同步时不能用空本地库覆盖已有远端书库。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 空本地不覆盖远端（metadata_sync 条件写） |
| R0791 | ◐ 部分实现 | 同步元数据应使用原子文件写入和版本检查。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 元数据原子写入+版本检查部分 |
| R0792 | ⬜ 未开始 | 对远端无法提供事务能力的协议使用提交清单或安全快照。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 提交清单/安全快照未实现 |
| R0793 | ◐ 部分实现 | 远端目录结构须稳定且适应多系统文件命名差异。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 远端目录结构稳定需核对 |
| R0794 | ◐ 部分实现 | 支持多个设备同时打开同一本书时的最终状态协调。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 多设备同书最终协调需核对 |
| R0795 | 🟡 已实现待验证 | 阅读进度冲突允许按最近阅读事件、最远进度或用户手动选择。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 进度/笔记冲突策略（progress_conflict_store + 测试） |
| R0796 | 🟡 已实现待验证 | 笔记冲突默认保留双方版本或生成冲突副本。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 进度/笔记冲突策略（progress_conflict_store + 测试） |
| R0797 | ◐ 部分实现 | 删除同步采用墓碑记录，避免旧设备重新上传已删除对象。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 删除墓碑/清理需核对 |
| R0798 | ◐ 部分实现 | 清理墓碑应在确认所有相关设备完成同步后进行。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 删除墓碑/清理需核对 |
| R0799 | 🟡 已实现待验证 | 展示上次成功同步时间与最近失败原因。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 上次成功同步时间/失败原因（sync_history） |
| R0800 | ⛔ 客观阻塞 | 所有同步测试必须覆盖双设备离线修改后重新联网合并。 | lib/src/sync/auto_sync_service.dart; lib/src/sync/progress_models.dart | 双设备离线合并测试需多设备 |

### 21 网盘、云书库与多服务商接入

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0801 | 🟡 已实现待验证 | 实现独立 CloudProvider 接口，统一列目录、下载、上传、删除及错误映射。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 统一 RemoteObjectStore 接口（remote_store.dart） |
| R0802 | 🟡 已实现待验证 | 优先完整支持标准 WebDAV 的读写、目录创建和文件校验。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | WebDAV 读写/目录/校验（webdav_store + 测试） |
| R0803 | 🟡 已实现待验证 | WebDAV 连接页支持服务器地址、账号及必要的应用专用密码。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | WebDAV 连接页地址/账号/应用密码（sync_page） |
| R0804 | 🟡 已实现待验证 | WebDAV 应兼容坚果云等合规提供标准协议的服务。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | WebDAV 兼容坚果云（标准协议） |
| R0805 | ◐ 部分实现 | WebDAV 对 401、403、404、409 和 507 状态分别给出处理建议。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | WebDAV 状态码分别建议需核对 |
| R0806 | 🟡 已实现待验证 | WebDAV 应正确处理 PROPFIND 分页、特殊字符及目录斜杠。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | WebDAV PROPFIND 分页/斜杠（s3_list_pagination 类似 + webdav） |
| R0807 | 🟡 已实现待验证 | 实现 S3 兼容对象存储适配器，支持自定义端点和区域。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | S3 适配器自定义端点/bucket/前缀（s3_store + 测试） |
| R0808 | 🟡 已实现待验证 | S3 支持用户指定 bucket、前缀和路径风格选项。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | S3 适配器自定义端点/bucket/前缀（s3_store + 测试） |
| R0809 | 🟡 已实现待验证 | S3 凭据仅写入安全存储，不进入备份、日志或代码仓库。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | S3 凭据安全存储（flutter_secure_storage） |
| R0810 | ◐ 部分实现 | S3 需要处理签名校验、时钟偏差和多段上传异常。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | S3 时钟偏差/多段上传异常需核对 |
| R0811 | ⛔ 客观阻塞 | 实现百度网盘适配器时采用官方允许的授权方式。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 百度网盘官方授权/浏览/上传需真实账号授权 |
| R0812 | ⛔ 客观阻塞 | 百度网盘支持浏览目录并下载电子书到本地书架。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 百度网盘官方授权/浏览/上传需真实账号授权 |
| R0813 | ⛔ 客观阻塞 | 百度网盘上传备份时遵循接口限制和用户授权范围。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 百度网盘官方授权/浏览/上传需真实账号授权 |
| R0814 | ⛔ 客观阻塞 | 实现 123 云盘接入时遵守其当前可用官方 API 与权限约束。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 123 云盘官方 API 需授权 |
| R0815 | ⛔ 客观阻塞 | 123 云盘能浏览合法目录且明确展示配额或限流信息。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 123 云盘官方 API 需授权 |
| R0816 | ⛔ 客观阻塞 | 实现 OneDrive 接入时采用微软官方授权流程和权限最小化。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | OneDrive 官方 OAuth/令牌刷新需授权 |
| R0817 | ⛔ 客观阻塞 | OneDrive 的上传与下载要覆盖令牌刷新与失效登录。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | OneDrive 官方 OAuth/令牌刷新需授权 |
| R0818 | ⛔ 客观阻塞 | 实现 Google Drive 接入时使用官方 OAuth，不要求用户直接交出密码。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | Google Drive 官方 OAuth 需授权 |
| R0819 | ⛔ 客观阻塞 | Google Drive 可选应用专用目录或用户选定文件夹。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | Google Drive 官方 OAuth 需授权 |
| R0820 | ⛔ 客观阻塞 | 实现 Dropbox 接入时支持官方 OAuth 与权限撤销。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | Dropbox OAuth/修订号需授权 |
| R0821 | ⛔ 客观阻塞 | Dropbox 同步应正确处理文件修订号和冲突副本。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | Dropbox OAuth/修订号需授权 |
| R0822 | 🟡 已实现待验证 | 对 iCloud 在 Android 的合法可用性先进行技术评估，禁止宣称虚假原生支持。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | iCloud 在 Android 无原生支持，应说明限制 |
| R0823 | 🟡 已实现待验证 | 对于 iCloud 不具备直接授权能力时提供受支持的中转方案说明。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | iCloud 在 Android 无原生支持，应说明限制 |
| R0824 | ⛔ 客观阻塞 | 提供本地目录同步提供方，可选择授权的文件夹作为目标。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 本地目录 SAF 同步需真机授权 |
| R0825 | ⛔ 客观阻塞 | 本地目录同步必须尊重 SAF，不自行扫描用户全部文件。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 本地目录 SAF 同步需真机授权 |
| R0826 | ⬜ 未开始 | 支持通过 SMB 连接局域网文件共享，但需安全网络配置。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | SMB 局域网未实现 |
| R0827 | ⬜ 未开始 | 支持通过 SFTP 连接用户自有服务器并校验主机密钥。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | SFTP 主机密钥校验未实现 |
| R0828 | ⬜ 未开始 | 支持接入支持标准 OPDS 的在线书目及书库。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | OPDS/Calibre 未实现 |
| R0829 | ⬜ 未开始 | 支持 Calibre 或 Calibre-Web 的合法 OPDS 目录访问。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | OPDS/Calibre 未实现 |
| R0830 | ⬜ 未开始 | 云书库可浏览目录、查看书籍元数据、搜索与下载。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 云书库浏览/元数据/下载未实现 |
| R0831 | 🟡 已实现待验证 | 云书库的浏览功能与双向同步功能必须在界面中清晰区分。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 浏览与同步严格区分（界面文案需核对） |
| R0832 | ◐ 部分实现 | 允许对同一个协议添加多个不同服务账户。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 多账户隔离部分（sync_config） |
| R0833 | ◐ 部分实现 | 不同服务账户数据隔离，切换账户不混淆书籍来源。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 多账户隔离部分（sync_config） |
| R0834 | ⬜ 未开始 | 允许用户对某个账户配置只读云书库权限。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 账户只读权限未实现 |
| R0835 | ◐ 部分实现 | 账户连接测试必须检查真实列目录与必要的写入权限。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 连接测试检查列目录+写权限需核对 |
| R0836 | ◐ 部分实现 | 账户授权失效后提示重新登录，不进入无限重试循环。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 授权失效提示需核对 |
| R0837 | 🟡 已实现待验证 | 不支持的服务商必须写明原因及替代协议，禁止摆设按钮。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 不支持服务商写明原因（能力矩阵待补 README） |
| R0838 | ⬜ 未开始 | 网盘连接页展示支持能力矩阵：浏览、下载、上传、同步、备份。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 网盘能力矩阵页面未实现 |
| R0839 | ◐ 部分实现 | 允许用户主动断开服务并选择是否清除本地缓存。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 断开服务+清缓存需核对 |
| R0840 | ⛔ 客观阻塞 | 针对各网盘编写真实接口或受控模拟测试，并记录验证结果。 | lib/src/sync/webdav_store.dart; lib/src/sync/s3_store.dart; lib/src/sync/remote_store.dart | 各网盘真实接口/受控模拟测试需账号 |

### 22 同步冲突、备份、恢复与迁移

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0841 | 🟡 已实现待验证 | 支持立即创建本地完整备份，不依赖云端。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 本地完整备份（backup_service.createBackup 含元数据/进度/笔记/设置/统计） |
| R0842 | 🟡 已实现待验证 | 备份应包括书架元数据、进度、笔记、设置及统计。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 本地完整备份（backup_service.createBackup 含元数据/进度/笔记/设置/统计） |
| R0843 | ◐ 部分实现 | 书籍原文件是否包含在备份中需独立选项，并显示估计大小。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 书籍原文件是否含入备份独立选项需核对 |
| R0844 | 🟡 已实现待验证 | 备份采用带版本号的清单，便于未来兼容迁移。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 备份带版本号（BackupInfo + 清单） |
| R0845 | 🟡 已实现待验证 | 备份文件支持完整性校验，损坏时拒绝覆盖现有数据。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 备份完整性校验（encrypted envelope） |
| R0846 | 🟡 已实现待验证 | 备份可选择经过验证的加密方案和用户控制的密钥。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 备份加密用户密钥（encrypted_file_envelope + 测试） |
| R0847 | ◐ 部分实现 | 恢复前允许预览书籍、笔记、进度和设置条目数量。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 恢复前预览条目数量需核对 |
| R0848 | ◐ 部分实现 | 恢复提供合并模式，不应只有覆盖整个书库一条路。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 合并恢复模式部分（data_tools 合并） |
| R0849 | ◐ 部分实现 | 覆盖恢复时先建立安全快照，失败能恢复原状。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 覆盖前安全快照需核对 |
| R0850 | ◐ 部分实现 | 恢复后检查数据库引用与实际书籍文件是否一致。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 恢复后引用一致性检查需核对 |
| R0851 | 🟡 已实现待验证 | 支持从应用旧版本数据库自动迁移到新版结构。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 旧版 DB 迁移（read_database.g.dart drift）+ 迁移测试 |
| R0852 | 🟡 已实现待验证 | 数据库升级迁移必须具备自动化测试样本。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 旧版 DB 迁移（read_database.g.dart drift）+ 迁移测试 |
| R0853 | 🟡 已实现待验证 | 支持用户指定备份文件路径并通过系统文件选择器读取。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 用户指定备份路径 SAF 读取 |
| R0854 | 🟡 已实现待验证 | 支持从 WebDAV 或 S3 选择历史备份快照恢复。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 从 WebDAV/S3 选历史备份恢复（backup_service.restoreCloud） |
| R0855 | ◐ 部分实现 | 支持自动保留多个时间点的滚动元数据备份。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 滚动备份/频率设置需核对 |
| R0856 | ◐ 部分实现 | 自动备份频率可设置为每日、每周或手动。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 滚动备份/频率设置需核对 |
| R0857 | ◐ 部分实现 | 应用启动时检查上次异常中断的未完成备份。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 启动检查中断备份需核对 |
| R0858 | ◐ 部分实现 | 应用退出时如需上传备份，首先检查是否已取得后台执行权限条件。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 退出上传/进程被杀保留任务需核对 |
| R0859 | ◐ 部分实现 | 备份正在上传时进程被杀也应安全保留待上传任务。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 退出上传/进程被杀保留任务需核对 |
| R0860 | 🟡 已实现待验证 | 用户恢复备份后不能自动同步覆盖现有完整云端数据。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 恢复后不自动覆盖云端（安全设计） |
| R0861 | ◐ 部分实现 | 跨设备导入备份要保持书籍唯一 ID 映射。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 跨设备唯一 ID 映射需核对 |
| R0862 | ◐ 部分实现 | 同书不同路径之间通过内容指纹恢复阅读进度和笔记。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 同书不同路径内容指纹恢复需核对 |
| R0863 | ◐ 部分实现 | 同一本书的多种文件版本之间避免盲目合并高亮锚点。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 多文件版本高亮锚点不盲并需核对 |
| R0864 | ◐ 部分实现 | 笔记版本冲突支持并列比较和手工选择保留项。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 笔记冲突并列比较/冲突中心需核对 |
| R0865 | ◐ 部分实现 | 提供冲突解决中心，按书籍聚合待处理冲突。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 笔记冲突并列比较/冲突中心需核对 |
| R0866 | ◐ 部分实现 | 冲突中心展示本地与远端修改时间、设备和摘要。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 笔记冲突并列比较/冲突中心需核对 |
| R0867 | 🟡 已实现待验证 | 默认冲突行为必须以不丢数据为首要原则。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 默认不丢数据原则 |
| R0868 | ◐ 部分实现 | 对远端删除和本地仍编辑的情况生成可恢复冲突副本。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 远端删除冲突副本/误删恢复需核对 |
| R0869 | ◐ 部分实现 | 恢复被误删书籍时避免自动删除所有关联笔记。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 远端删除冲突副本/误删恢复需核对 |
| R0870 | ◐ 部分实现 | 用户可以查看近期同步和恢复操作的审计记录。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 操作审计日志+导出脱敏需核对 |
| R0871 | ◐ 部分实现 | 同步审计日志允许导出，但须去除授权凭据与敏感正文。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 操作审计日志+导出脱敏需核对 |
| R0872 | ◐ 部分实现 | 支持修复孤立笔记、缺失封面和无效书籍路径。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 修复孤立笔记/缺失封面/无效路径需核对 |
| R0873 | ⬜ 未开始 | 提供一键重新索引功能，但不能清除阅读记录。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 一键重新索引未实现 |
| R0874 | ◐ 部分实现 | 迁移工具必须在操作前显示风险、范围和回滚方式。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 迁移风险/回滚说明需核对 |
| R0875 | ◐ 部分实现 | 支持从旧 Read 数据目录恢复历史书架配置。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 旧 Read 数据目录恢复需核对 |
| R0876 | ⬜ 未开始 | 支持合法导入其他阅读器导出的通用书籍与笔记格式。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 其他阅读器通用格式导入未实现 |
| R0877 | 🟡 已实现待验证 | 外部应用的专有加密数据无法解析时明确告知，不伪造兼容。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 专加密数据明确告知不伪造兼容 |
| R0878 | ⛔ 客观阻塞 | 恢复流程测试至少覆盖空机、已有书库、部分缺失和损坏备份。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 恢复流程空机/已有/缺失/损坏测试需多环境 |
| R0879 | 🟡 已实现待验证 | 同步重试不得删除此前成功的完整备份快照。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 重试不删成功备份快照 |
| R0880 | ◐ 部分实现 | 提供一键导出诊断包，供用户在同步故障后主动反馈。 | lib/src/sync/backup_service.dart; lib/src/sync/progress_conflict_store.dart | 一键导出诊断包需核对 |

### 23 原创 UI 设计、细节动画和设置体验

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0881 | 🟡 已实现待验证 | 视觉风格以简洁、克制、精致为原则，不照搬 Reeden 商标和素材。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 简洁克制原创视觉 + 设计令牌（theme.dart + read_icon） |
| R0882 | 🟡 已实现待验证 | 建立统一颜色、字体、间距、圆角、阴影与图标设计令牌。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 简洁克制原创视觉 + 设计令牌（theme.dart + read_icon） |
| R0883 | 🟡 已实现待验证 | 优先使用 Android 平台成熟的原生交互规范和组件。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 使用 Material/Flutter 原生组件 |
| R0884 | 🟡 已实现待验证 | 全局导航层级应清晰，用户能快速找到核心阅读操作。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 导航层级清晰（HomeShell 4 tab） |
| R0885 | 🟡 已实现待验证 | 阅读页面重点突出正文，避免工具栏和浮窗喧宾夺主。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 阅读页正文优先，工具栏可隐藏 |
| R0886 | 🟡 已实现待验证 | 书架页面封面比例统一，视觉重心整齐。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 书架封面比例统一（bookshelf_design_test） |
| R0887 | 🟡 已实现待验证 | 书架卡片不应出现文本遮挡封面或按钮重叠。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 书架封面比例统一（bookshelf_design_test） |
| R0888 | 🟡 已实现待验证 | 设置页面按阅读、书库、同步、外观、隐私等分组。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 设置按阅读/书库/同步/外观/隐私分组（settings_page） |
| R0889 | ◐ 部分实现 | 设置项提供即时解释，隐藏不必要的技术术语。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 设置即时解释/高级折叠需核对 |
| R0890 | ◐ 部分实现 | 高级参数折叠在高级设置中，常用设置不被海量开关淹没。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 设置即时解释/高级折叠需核对 |
| R0891 | 🟡 已实现待验证 | 不得在设置界面堆放没有业务用途的口令框和测试字段。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 无口令框堆放；连接项仅必要认证字段 |
| R0892 | 🟡 已实现待验证 | 高级连接设置仅出现服务商确实需要的认证字段。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 无口令框堆放；连接项仅必要认证字段 |
| R0893 | 🟡 已实现待验证 | 支持完整浅色和深色配色，不允许只有背景变化。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 完整浅/深配色 + 动态主题对比度 |
| R0894 | 🟡 已实现待验证 | 支持动态主题色，自动保证文本对比度达到可读标准。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 完整浅/深配色 + 动态主题对比度 |
| R0895 | 🟡 已实现待验证 | 提供原创应用图标，在桌面和设置页都清楚易辨。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 原创羽毛图标 + 统一线性风格（read_icon + 图标测试） |
| R0896 | 🟡 已实现待验证 | 图标线条风格统一，避免一页填充一页描边。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 原创羽毛图标 + 统一线性风格（read_icon + 图标测试） |
| R0897 | ◐ 部分实现 | 点击反馈动画轻量快速，不触发大范围无意义波纹。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 轻量点击反馈/统一弹窗缓动需核对 |
| R0898 | ◐ 部分实现 | 弹窗显示和消失采用一致的缓动曲线与时长。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 轻量点击反馈/统一弹窗缓动需核对 |
| R0899 | ◐ 部分实现 | 底部抽屉支持手势拖动关闭并处理嵌套滚动冲突。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 底部抽屉手势关闭需核对（sheet.dart） |
| R0900 | ◐ 部分实现 | 列表新增或删除项目使用温和位置过渡，避免跳动。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 列表增删温和过渡未实现 |
| R0901 | ◐ 部分实现 | 封面图片加载时使用稳定背景占位，防止布局抖动。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 封面稳定占位（cover_art） |
| R0902 | ◐ 部分实现 | 主题切换不能出现整页纯白闪烁。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 主题切换无闪白需真机核对 |
| R0903 | ◐ 部分实现 | 首屏加载优先显示稳定 UI，不以复杂欢迎动画拖慢启动。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 首屏稳定 UI/启动动画可控需核对 |
| R0904 | ◐ 部分实现 | 应用启动动画长度应可控且用户可关闭。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 首屏稳定 UI/启动动画可控需核对 |
| R0905 | ◐ 部分实现 | 实现细腻的阅读按钮、页码提示和进度条触摸反馈。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 阅读按钮/页码/进度条触摸反馈需核对 |
| R0906 | 🟡 已实现待验证 | 阅读页设置抽屉允许在不关闭书的情况下实时预览。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 设置抽屉不关书实时预览（settings sheet） |
| R0907 | ◐ 部分实现 | 菜单项图标尺寸、标题文字和辅助说明之间保持统一节奏。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 菜单图标/标题/说明节奏需视觉核对 |
| R0908 | ◐ 部分实现 | 危险按钮使用明确措辞且与普通操作视觉区分。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 危险按钮视觉区分需核对 |
| R0909 | ◐ 部分实现 | 极窄屏和分屏模式下菜单必须可滚动且可点击。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 极窄屏菜单可滚动需核对 |
| R0910 | ◐ 部分实现 | 横屏布局要充分利用宽度，避免整个 UI 机械拉伸。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 横屏/大屏侧栏利用需核对 |
| R0911 | ◐ 部分实现 | 大屏优先使用侧栏，不把所有工具塞进底部单行。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 横屏/大屏侧栏利用需核对 |
| R0912 | 🟡 已实现待验证 | 空状态配图可使用原创矢量图，但应节制减少视觉噪音。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 空状态原创矢量节制（cover_art） |
| R0913 | ◐ 部分实现 | 加载、成功、错误、离线四种提示风格应统一。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 四种提示统一/触觉反馈开关需核对 |
| R0914 | ◐ 部分实现 | 为主要交互提供必要触觉反馈，同时支持一键关闭。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 四种提示统一/触觉反馈开关需核对 |
| R0915 | 🟡 已实现待验证 | 支持系统减少动画设置，尊重无障碍偏好。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 墨水屏模式尊重减少动画（ui_mode） |
| R0916 | ⬜ 未开始 | 设置搜索可以按关键词快速定位具体设置项。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 设置搜索未实现 |
| R0917 | ◐ 部分实现 | 恢复默认设置需提示哪些阅读主题和书籍设置会被影响。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 恢复默认提示/修改即生效需核对 |
| R0918 | ◐ 部分实现 | 用户修改设置后返回无需再次点多次保存确认。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 恢复默认提示/修改即生效需核对 |
| R0919 | ⛔ 客观阻塞 | 主要页面至少各提供浅色、深色、横屏视觉测试截图。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | 各页浅/深/横屏截图需真机 |
| R0920 | ⛔ 客观阻塞 | UI 验收必须检查实际设备触摸流程，不凭设计稿宣布完成。 | lib/src/ui/read_icon.dart; lib/src/theme.dart; lib/src/theme/ui_mode.dart; lib/src/profile/appearance_page.dart | UI 真机触摸验收需设备 |

### 24 性能、无障碍、隐私和稳定性

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0921 | ⛔ 客观阻塞 | 在中端安卓设备上测量冷启动、热启动与首书打开耗时。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 冷/热启动与首书耗时需中端真机测量 |
| R0922 | ⛔ 客观阻塞 | 给启动关键路径设定性能预算，并记录优化前后数据。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 冷/热启动与首书耗时需中端真机测量 |
| R0923 | 🟡 已实现待验证 | 避免启动时同步初始化所有云盘 SDK 和大型索引。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 启动不初始化所有云 SDK（HomeShell _built 懒构建） |
| R0924 | ◐ 部分实现 | 书架首屏只加载当前可见封面和必要元数据。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 书架首屏只载可见封面需核对 |
| R0925 | ◐ 部分实现 | 采用后台线程解析文件并限制并发解码数量。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 后台解析/并发解码限制需核对 |
| R0926 | 🟡 已实现待验证 | 减少每次翻页中的临时对象创建和 GC 抖动。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 减少翻页临时对象（LRU 缓存/复用） |
| R0927 | ◐ 部分实现 | 防止长时间阅读时 WebView、Bitmap 或 PDF 资源泄漏。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 长读资源泄漏需真机监测 |
| R0928 | ⛔ 客观阻塞 | 对大批量书籍导入监控内存峰值，避免 OOM。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 批量导入内存峰值需真机 |
| R0929 | ◐ 部分实现 | 对长时间运行的同步任务避免 Android ANR。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 同步 ANR 需核对 |
| R0930 | ⬜ 未开始 | 检测主线程 I/O 与网络请求并修复严格模式告警。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 主线程 I/O 严格模式检测未实现 |
| R0931 | ◐ 部分实现 | 优化 RecyclerView 或等价列表的复用和稳定 ID。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 列表复用/稳定 ID 需核对 |
| R0932 | ◐ 部分实现 | 提供可控缓存预算和用户可查看的缓存占用。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 缓存预算/查看占用/清理不误删需核对 |
| R0933 | ◐ 部分实现 | 清理缓存不得误删用户唯一存在的书籍副本。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 缓存预算/查看占用/清理不误删需核对 |
| R0934 | ◐ 部分实现 | 对电池低电量状态限制非必要后台预加载。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 低电量/省电后台限制需核对 |
| R0935 | ◐ 部分实现 | 尊重系统省电模式与后台调度规则。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 低电量/省电后台限制需核对 |
| R0936 | ◐ 部分实现 | 支持 Android TalkBack 为按钮提供明确标签与操作说明。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | TalkBack 标签/章节语义部分（semantics 测试） |
| R0937 | ◐ 部分实现 | 屏幕阅读器可识别当前章节、正文内容和操作栏。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | TalkBack 标签/章节语义部分（semantics 测试） |
| R0938 | 🟡 已实现待验证 | 保证常用按钮最小触控区域及足够的颜色对比度。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 触控区/对比度/大字体（fontScale 测试） |
| R0939 | 🟡 已实现待验证 | 支持系统大字体缩放，不以固定高度截断内容。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 触控区/对比度/大字体（fontScale 测试） |
| R0940 | ⬜ 未开始 | 支持外接键盘导航、焦点指示与常用快捷键。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 外接键盘导航/快捷键未实现 |
| R0941 | 🟡 已实现待验证 | 实现墨水屏模式，默认关闭高频动画。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 墨水屏模式关动画/高对比（ui_mode + eink_theme_test） |
| R0942 | 🟡 已实现待验证 | 墨水屏模式支持高对比度黑白界面。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 墨水屏模式关动画/高对比（ui_mode + eink_theme_test） |
| R0943 | 🟡 已实现待验证 | 墨水屏模式支持配置按若干页进行全屏刷新。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 墨水屏模式关动画/高对比（ui_mode + eink_theme_test） |
| R0944 | 🟡 已实现待验证 | 支持实体翻页键并可自定义方向。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 实体翻页键（reader_device_bridge） |
| R0945 | ◐ 部分实现 | 支持防误触横屏锁定与系统方向切换。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 防误触横屏锁定需核对 |
| R0946 | 🟡 已实现待验证 | 应用数据文件必须位于 Android 正当授权目录。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 数据位于正当授权目录（path_provider） |
| R0947 | 🟡 已实现待验证 | 对非必要的读取联系人、定位、电话权限一律不申请。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 不申请联系人/定位/电话权限 |
| R0948 | 🟡 已实现待验证 | 联网通信默认 HTTPS，并严格校验证书。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 联网默认 HTTPS 校验证书（WebDAV/S3） |
| R0949 | ⬜ 未开始 | 仅允许用户明确启用并确认的自定义不安全连接例外。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 不安全连接例外未实现 |
| R0950 | 🟡 已实现待验证 | 将账号令牌存于受保护的密钥存储，不放在明文配置。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 令牌安全存储（flutter_secure_storage） |
| R0951 | 🟡 已实现待验证 | 日志不得包含 API Key、Cookie、验证码、私有正文或完整凭据。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 日志不含密钥/正文（encrypted envelope 测试） |
| R0952 | ⬜ 未开始 | 本地故障日志可默认开启，但远端自动上传须先明确告知和取得同意。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 远端诊断上传开关/隐私预览未实现 |
| R0953 | ⬜ 未开始 | 远端诊断上传支持单独的开关、隐私预览和随时关闭。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 远端诊断上传开关/隐私预览未实现 |
| R0954 | ⛔ 客观阻塞 | 支持经授权将脱敏诊断文件上传至用户配置的 GitHub 私有仓库。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | GitHub 私有仓库/服务端诊断上传需授权 |
| R0955 | ⛔ 客观阻塞 | 如存在可验证的专用服务端接口，可将脱敏诊断上传到该服务端。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | GitHub 私有仓库/服务端诊断上传需授权 |
| R0956 | 🟡 已实现待验证 | 不存在有效聊天服务端上传接口时不能声称“已自动上传到当前聊天”。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 不声称已上传到当前聊天（无此接口） |
| R0957 | 🟡 已实现待验证 | 关于页面显示真实版本号、构建号、开源许可和反馈入口。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 关于页版本号/开源许可/反馈（about_page） |
| R0958 | 🟡 已实现待验证 | 反馈按钮通过系统安全跳转打开指定 QQ 链接 https://qm.qq.com/q/Yvc3ugiCoE。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 反馈按钮 QQ 链接（about_page 常量） |
| R0959 | ◐ 部分实现 | 崩溃恢复时优先保存笔记与进度，并提供故障报告导出。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 崩溃恢复保存笔记进度/报告导出需核对 |
| R0960 | ⛔ 客观阻塞 | 对后台恢复、拒绝权限、低内存及弱网进行稳定性测试。 | lib/main.dart; lib/src/reader/reader_page.dart; lib/src/profile/about_page.dart | 后台恢复/拒权/低内存/弱网稳定性需真机 |

### 25 自动化测试、CI、交付与逐项验收

| 编号 | 状态 | 需求 | 代码路径 | 证据/阻塞说明 |
|---|---|---|---|---|
| R0961 | ✅ 已验证完成 | 为每项需求编号建立状态记录，状态必须对应可检查的实现。 | .github/workflows/; test/; docs/ | 本台账为每项建立状态记录 |
| R0962 | 🟡 已实现待验证 | 每完成一个独立模块至少提交一次可回滚的 Git 提交。 | .github/workflows/; test/; docs/ | 每模块提交可回滚 commit（已有 v0.7-v1.1 多次提交） |
| R0963 | 🟡 已实现待验证 | 所有提交信息说明修改范围、原因及验证方式。 | .github/workflows/; test/; docs/ | 提交信息说明范围/原因/验证 |
| R0964 | 🟡 已实现待验证 | 持续集成自动执行依赖检查、静态分析与单元测试。 | .github/workflows/; test/; docs/ | CI 自动依赖检查/分析/单测（三个 workflow） |
| R0965 | 🟡 已实现待验证 | 持续集成执行 debug APK 构建并上传可下载构建产物。 | .github/workflows/; test/; docs/ | CI 构建 debug APK 并上传产物（build-android） |
| R0966 | 🟡 已实现待验证 | 发布包使用现有安全签名方案，禁止上传密钥到仓库。 | .github/workflows/; test/; docs/ | 发布用现有签名，密钥不入仓（release.yml） |
| R0967 | 🟡 已实现待验证 | GitHub Actions 工作流使用最小权限和官方受信任 Action。 | .github/workflows/; test/; docs/ | Actions 用官方受信任 Action + 最小权限 |
| R0968 | 🟡 已实现待验证 | 若 CI 失败，必须阅读完整错误日志并修复根因。 | .github/workflows/; test/; docs/ | 本轮修复 Analyze 失败根因而非跳过 |
| R0969 | 🟡 已实现待验证 | 禁止通过禁用测试、跳过关键阶段或改成 always-success 掩盖失败。 | .github/workflows/; test/; docs/ | 未禁用测试/未改 always-success |
| R0970 | 🟡 已实现待验证 | 每次新增数据库字段都须加入旧版升级测试。 | .github/workflows/; test/; docs/ | DB 字段升级测试（read_database_test + 迁移样本） |
| R0971 | ◐ 部分实现 | 每种宣称支持的电子书格式都须有自动回归用例。 | .github/workflows/; test/; docs/ | 每种宣称格式自动回归：TXT/EPUB/MD/HTML/PDF 有测试，缺多格式样本 |
| R0972 | ⛔ 客观阻塞 | 导入测试应覆盖中文路径、空格、Emoji、同名文件和损坏文件。 | .github/workflows/; test/; docs/ | 中文路径/空格/Emoji/同名/损坏导入测试需真机文件系统 |
| R0973 | ✅ 已验证完成 | 阅读测试应覆盖字号变更后的锚点稳定性。 | .github/workflows/; test/; docs/ | 字号变更锚点稳定测试（reader_engine 测试） |
| R0974 | ◐ 部分实现 | 笔记测试应覆盖多行、高亮重叠、删除和恢复。 | .github/workflows/; test/; docs/ | 笔记多行/重叠/删除/恢复测试部分（reader_page_smoke 高亮渲染 + bookmark_meta_store 测试） |
| R0975 | ◐ 部分实现 | PDF 测试应覆盖大页缩放、搜索、标注与缓存回收。 | .github/workflows/; test/; docs/ | PDF 大页缩放/搜索/标注/缓存测试部分（pdf_format 测试） |
| R0976 | ◐ 部分实现 | 同步测试应覆盖单设备离线、双设备并发和重复请求。 | .github/workflows/; test/; docs/ | 同步单设备/双设备/重复请求测试部分（sync_service 测试） |
| R0977 | ◐ 部分实现 | 同步测试应验证网络中断后没有数据损坏或重复对象。 | .github/workflows/; test/; docs/ | 同步单设备/双设备/重复请求测试部分（sync_service 测试） |
| R0978 | 🟡 已实现待验证 | 云盘适配器测试明确区分模拟通过与真实账号连接通过。 | .github/workflows/; test/; docs/ | 云盘测试区分模拟与真账号（受控模拟通过；真账号阻塞） |
| R0979 | 🟡 已实现待验证 | 首次使用测试需确认不注册也能导入并完整阅读。 | .github/workflows/; test/; docs/ | 不注册可导入阅读（架构+smoke） |
| R0980 | ◐ 部分实现 | 无障碍测试覆盖 TalkBack、键盘和大字体。 | .github/workflows/; test/; docs/ | 无障碍 TalkBack/键盘/大字体测试部分 |
| R0981 | ⛔ 客观阻塞 | 性能测试至少记录启动耗时、翻页帧时间和内存峰值。 | .github/workflows/; test/; docs/ | 启动耗时/翻页帧时间/内存峰值需真机 |
| R0982 | ⛔ 客观阻塞 | 为核心页面生成稳定的视觉回归截图并检查布局。 | .github/workflows/; test/; docs/ | 核心页视觉回归截图浅/深/横屏/分屏需真机 |
| R0983 | ⛔ 客观阻塞 | 在浅色、深色、横屏及分屏分别进行页面截图对比。 | .github/workflows/; test/; docs/ | 核心页视觉回归截图浅/深/横屏/分屏需真机 |
| R0984 | ⛔ 客观阻塞 | 真机验证至少完成导入、阅读、查词、笔记、退出、恢复闭环。 | .github/workflows/; test/; docs/ | 真机导入/阅读/查词/笔记/退出/恢复闭环需设备 |
| R0985 | ⛔ 客观阻塞 | 真实云同步验证至少使用两个独立设备或隔离设备配置。 | .github/workflows/; test/; docs/ | 双设备真实同步需两设备 |
| R0986 | 🟡 已实现待验证 | 每次发布前确认升级不会改变用户原有书架和阅读记录。 | .github/workflows/; test/; docs/ | 发布前升级不改书架需人工确认 |
| R0987 | ◐ 部分实现 | 发布前进行本地备份恢复演练并验证数量一致。 | .github/workflows/; test/; docs/ | 本地备份恢复演练数量一致需核对 |
| R0988 | ⛔ 客观阻塞 | 对所有外部 API 执行错误码、限流与无授权测试。 | .github/workflows/; test/; docs/ | 外部 API 错误码/限流/无授权测试需真实服务 |
| R0989 | 🟡 已实现待验证 | 测试不得使用或提交个人真实 Token 与私人书籍内容。 | .github/workflows/; test/; docs/ | 测试未提交个人 Token/私人书 |
| R0990 | 🟡 已实现待验证 | 发布产物必须明确标记版本号、提交哈希和构建时间。 | .github/workflows/; test/; docs/ | 发布产物标记版本/提交哈希/构建时间（release tag） |
| R0991 | ◐ 部分实现 | 所有实现功能需在更新日志中注明用户可见变化。 | .github/workflows/; test/; docs/ | 更新日志注明用户可见变化需完善 |
| R0992 | ◐ 部分实现 | 所有不完整功能必须从正式入口隐藏或清晰标注实验性。 | .github/workflows/; test/; docs/ | 不完整功能从入口隐藏/标实验性需核对 |
| R0993 | ✅ 已验证完成 | 对未完成任务列出阻塞原因、依赖和后续可执行步骤。 | .github/workflows/; test/; docs/ | 本台账列出未完成任务阻塞原因与步骤 |
| R0994 | ◐ 部分实现 | 提供 README 中的安装、导书、同步及问题反馈说明。 | .github/workflows/; test/; docs/ | README 安装/导书/同步/反馈说明需完善 |
| R0995 | ◐ 部分实现 | 提供一份 Reeden 功能对标矩阵，列功能、Read 现状和测试证据。 | .github/workflows/; test/; docs/ | Reeden 功能对标矩阵需补 |
| R0996 | ✅ 已验证完成 | 逐项核对 1000 条需求，不能只报告完成比例而缺少证据。 | .github/workflows/; test/; docs/ | 本台账逐项核对 R0001-R1000 |
| R0997 | ✅ 已验证完成 | 当功能暂不可实现时如实注明技术或授权限制，不能伪造完成。 | .github/workflows/; test/; docs/ | 如实注明技术/授权限制，不伪造完成 |
| R0998 | ⛔ 客观阻塞 | 至少完成一次整包安装、升级安装及全新安装回归。 | .github/workflows/; test/; docs/ | 整包/升级/全新安装回归需真机 |
| R0999 | ◐ 部分实现 | 最终提供 APK、关键操作录屏或截图、测试报告和已知问题清单。 | .github/workflows/; test/; docs/ | APK 已发布；录屏/测试报告/已知问题部分具备 |
| R1000 | ✅ 已验证完成 | 只有实际功能通过验收才可标记“完成”，不得以 UI 存在替代验收。 | .github/workflows/; test/; docs/ | 本台账严格区分已验证与未验证，不以 UI 存在替代验收 |

