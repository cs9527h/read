# Read 1000 项执行状态台账

更新：2026-11-16 · 本轮提交 `f97c1d6` · 版本 `0.6.2+10`

> 状态严格区分 PASS / PARTIAL / BLOCKED / FAIL / NOT_STARTED。**PASS 仅用于已有源码与测试证据的项目；其余不冒充完成。本轮新增 `0216` 为 PASS，其余改动只更新证据，不批量提升状态。** 标记 PARTIAL 的 944 项表示所属模块已有代码，但未逐项独立验收；42 项保持 NOT_STARTED，下一轮从最小未处理编号继续。

## 汇总

- 总数：1000
- PASS：23
- PARTIAL：934
- BLOCKED：1
- NOT_STARTED：42
- FAIL：0

机器可读台账：`docs/READ_1000_EXECUTION_STATUS.csv`（1000 行，含原始需求、状态、证据、阻塞、下一步）。

## 0.6.2 批次证据

- 提交：`f97c1d6`，版本 `0.6.2+10`。
- 静态分析：`flutter analyze --no-fatal-infos` → 0 error / 0 warning / 126 info。
- 单元与组件测试：`flutter test --no-test-assets` → 110/110。
- 已落地：底部四栏（书架/统计/同步/设置）、删除“我的”与继续阅读卡片、书架/单书完整菜单、编辑信息页、云端书库真实索引、设置导出/导入/从其他设备恢复/云端数据对比、普通版与墨水屏独立图标、WiFi 传书、分页缓存与相邻章节预加载、翻页页码改用 ValueNotifier。
- 边界：WiFi 传书未真机端到端验收；系统分享仍是剪贴板；AI 封面/搜图明确未接入；私密书不加密内容；未完成 1000 项全量验收。


## A01 项目基线、架构与反半成品准则

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0001 | 以现有公开 Read 仓库为唯一开发起点，核查真实默认分支、活跃 PR、标签与最近成功构建，禁止重新生成空项目。 | PASS | 已核查仓库/分支/PR #26；基线 cfa386b |
| 0002 | 把当前 Flutter 版本、Dart SDK、Android Gradle Plugin、原生插件和锁文件版本写入基线报告。 | PARTIAL | Flutter 3.50/Dart 3.14 已记录；AGP/插件矩阵未成文 |
| 0003 | 列出已实现、仅有界面、仅有接口、未实现、已验证五类状态，不将按钮存在视为功能完成。 | PARTIAL | docs/V1_100_STATUS.md 已分状态；1000 项未逐项审计 |
| 0004 | 对现有阅读器 TXT、EPUB、PDF 分别录制可复现的打开、翻页、退出和恢复路径。 | PARTIAL | 阅读冒烟测试存在；TXT/EPUB/PDF 三格式路径未录像 |
| 0005 | 建立从导入图书到阅读到关闭到重启的最小端到端冒烟测试。 | PASS | test/reader_page_smoke_test.dart 导入→阅读→退出路径 |
| 0006 | 在开发前备份现有数据库 schema、迁移脚本和兼容格式，禁止删库重来。 | NOT_STARTED | 无数据库 schema/迁移备份脚本 |
| 0007 | 保留 Read 品牌、现有 Flutter 工程和用户确认的黑白极简方向，禁止改为网页套壳。 | PASS | 保留 Flutter 工程与黑白羽毛 |
| 0008 | 保留现有书架、封面、个人页结构，仅在明确解决问题时调整信息架构。 | PASS | 书架/统计/我的三栏保留 |
| 0009 | 先合并无冲突且测试通过的既有修复，避免重复实现相同功能。 | PARTIAL | 已合并 #25；#23/#24/#21 未整合 |
| 0010 | 检查并消除未合并 PR 对相同阅读状态模型的重复定义。 | PARTIAL | 已审计 PR 重复项；未逐条关闭 |
| 0011 | 每个优化项映射到源码文件、测试文件及一次人工可复现操作。 | PARTIAL | V1 表有文件证据；1000 项未逐条映射 |
| 0012 | 为阅读模式、字体、进度、云同步定义单一事实来源，避免多个状态副本争夺控制权。 | PASS | ReaderSettingsStore/SyncConfig/LibraryStore 单一来源 |
| 0013 | 将阅读器核心逻辑从页面 Widget 分离成可单测的服务与模型。 | PASS | ReaderEngine 独立于 ReaderPage，测试覆盖 |
| 0014 | 清理只用于演示而不读写真数据的假书籍、假进度和占位功能入口。 | PARTIAL | 未发现演示书架；仍缺全量假入口扫描 |
| 0015 | 所有设置开关必须可持久化、可反映到实际阅读页、重启后不回退。 | PASS | ReaderSettings 持久化与三层合并测试 |
| 0016 | 各功能异常时允许回退到安全阅读模式，不能因为高级特效失效无法打开书。 | PARTIAL | 异常设置回退逻辑存在；未逐特效验证 |
| 0017 | 对每项新增功能注明生效格式范围，不能宣称 PDF 和 EPUB 全部等价。 | PARTIAL | README 标注 TXT/EPUB/PDF 差异；逐功能未标 |
| 0018 | 定义本地优先原则：断网可打开已导入图书、继续翻页和添加笔记。 | PASS | 本地导入/阅读不依赖网络 |
| 0019 | 后台联网不得阻塞文字绘制或翻页主线程。 | PARTIAL | 同步异步化；无主线程帧时间证据 |
| 0020 | 对断电、进程被杀和应用强退设置统一的状态持久化策略。 | PARTIAL | 进度防抖落盘/队列持久化；未统一所有写入 |
| 0021 | 所有读写操作采用明确错误分类，不将所有异常吞成“操作成功”。 | PARTIAL | 同步/导入有错误提示；仍有异常吞掉路径 |
| 0022 | 禁止将测试中的 Mock 数据、假的下载进度或假的同步成功文案写进正式页面。 | PARTIAL | 无演示同步成功；错误分支仍不完整 |
| 0023 | 每项需求必须至少有一条可执行的通过判据，无法执行则写明阻塞证据。 | PARTIAL | 92 项测试；1000 项通过判据未逐条建立 |
| 0024 | 保证升级不改变已有书籍身份，历史阅读进度需完成迁移或自动回退。 | PARTIAL | 书籍内容哈希稳定；进度迁移无专项测试 |
| 0025 | 实行功能开关治理：实验特性默认关闭，稳定后才提升为正式能力。 | PARTIAL | 自动同步/文件同步默认关闭；无统一实验开关 |
| 0026 | 任何读写云端的破坏性变更先备份、演练回滚，禁止自动清空用户文件夹。 | PARTIAL | 备份与恢复前快照；无云端破坏性变更演练 |
| 0027 | 将需求清单落成机器可读 JSON/CSV 台账，带编号、模块、状态和证据链接。 | PASS | 本文件 + READ_1000_EXECUTION_STATUS.csv |
| 0028 | 以阅读页和同步为主要时间预算，不为凑数优先开发无关社交、商城或广告。 | PASS | 本轮优先同步/阅读，无社交商城 |
| 0029 | 对复杂书籍准备可公开使用的测试样本，避免提交带版权的测试图书。 | PARTIAL | 测试文本为合成内容；无公开样本集 |
| 0030 | 正确处理 Android 11+ 的文件权限和 SAF，不要求用户全盘存储权限。 | NOT_STARTED | 无 SAF/Android 11 文件权限专项 |
| 0031 | 维护 Android 与桌面端兼容目标矩阵，未真实构建的平台不得标完成。 | PARTIAL | README 标 Android/Windows/墨水屏；Windows 无真机 |
| 0032 | Flutter UI 与系统手势、状态栏、键盘安全区分别建测试基线。 | PARTIAL | 有 390×844 组件渲染；系统手势/键盘基线未建 |
| 0033 | 检查现有导入、搜索、书签、同步功能是否真的连接持久化层。 | PARTIAL | 导入/书签/高亮已连存储；搜索/同步部分 |
| 0034 | 关闭书籍时先本地落盘再发起后台同步，不让网络决定本地数据可靠性。 | PASS | 关闭前写本地，再后台同步 |
| 0035 | 每次构建固定依赖解析结果，阻止未经验证的自动大版本升级。 | PASS | pubspec.lock 已提交 |
| 0036 | 各模块统一使用可读错误提示、重试入口和必要的诊断详情。 | PARTIAL | SnackBar/错误文本存在；统一诊断详情未做 |
| 0037 | 所有性能改进先测基线再对比，不许通过删除功能制造虚假提速。 | BLOCKED | 无真机/KVM，无帧时间基线；不伪造指标 |
| 0038 | 建立适合手机用户操作的 APK 下载、校验与保数据覆盖安装流程。 | PARTIAL | CI APK 流程存在；保数据覆盖安装未真机验证 |
| 0039 | 对未知 Reeden 私有内部格式不声称兼容，只追求用户可见功能与同步行为对标。 | PASS | README/状态表声明不兼容 Reeden 私有格式 |
| 0040 | 001—1000 全部逐项处理：完成则提交证据，阻塞则登记并立即进入下一项。 | PARTIAL | 1000 台账已建；仅部分编号处理 |

## A02 阅读界面基础与沉浸体验

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0041 | 阅读正文区域默认优先展示内容，未呼出菜单时不常驻大面积工具栏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0042 | 阅读页顶部安全避开挖孔、刘海与状态栏，内容不被系统区域遮住。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0043 | 阅读页底部正确处理手势导航条，允许用户调节文字与导航区间距。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0044 | 点击屏幕中区唤出菜单时不得改变正文当前位置和分页锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0045 | 阅读菜单收起后恢复原本沉浸状态，不残留遮罩、半透明条或焦点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0046 | 首次进入阅读页提供可关闭的简短操作引导，不反复弹窗。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0047 | 页面四周留白以书籍阅读舒适度为准，不机械套用普通设置页面间距。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0048 | 适配不同手机宽高比，文字不应出现极窄列和大片无效留白。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0049 | 横屏状态单独允许设置最大正文宽度，不让一行跨越整个宽屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0050 | 竖屏、横屏切换时保持同一语义文本锚点，不跳回章节头。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0051 | 适配系统大字体和显示缩放，避免正文与控制按钮溢出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0052 | 提供可隐藏的阅读页顶部书名或章名显示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0053 | 提供可隐藏的底部页码、百分比、时间、电量信息。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0054 | 统一正文选中、菜单弹出、弹窗关闭的焦点处理，避免误翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0055 | 透明状态栏与阅读背景要正确融合，深浅主题下图标始终可辨。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0056 | 阅读页背景切换要覆盖整屏，不露白边或黑边闪烁。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0057 | 书内插图与正文保持合理间距，不出现像普通图片列表的巨大空白。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0058 | 打开目录后返回阅读页必须精确恢复段落位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0059 | 从书架进入一本书时优先恢复上次读到的位置而不是默认第一页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0060 | 提供阅读中快速返回书架入口，动作清晰且不遮挡正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0061 | 长按正文进入选择模式时暂时禁用翻页触控，防止选择范围错乱。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0062 | 所有按钮的视觉层级明确，主要操作易找，次要操作不占阅读主界面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0063 | 支持隐藏阅读页背景装饰，提供真正纯文本极简模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0064 | 阅读页主题切换后布局稳定，避免页面先亮后暗的闪屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0065 | 支持单书锁定阅读方向，不改变系统其他应用方向。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0066 | 进入系统最近任务再返回时恢复阅读沉浸状态与菜单开关状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0067 | 切到分屏再返回时正确重新布局，进度不因宽度变化错乱。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0068 | Android 返回键优先关闭弹层、菜单和目录，再退出书籍。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0069 | 触控目标保持足够尺寸，即使采用紧凑视觉也不可点不中。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0070 | 以可辨认文字标签或提示解释重要图标，不用晦涩的无文字符号。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0071 | 可选保持屏幕常亮，仅阅读时生效并在离开后撤销。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0072 | 允许配置阅读状态栏显示或隐藏，避免强迫全屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0073 | 阅读过程中可以一键临时隐藏所有页眉页脚，仅保留正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0074 | 页面边缘的返回系统手势和自定义翻页手势不冲突。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0075 | 底部进度条呼出时不覆盖当前段落或造成阅读页整体上移。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0076 | 无图书状态展示清晰导入入口，不使用无意义空白页面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0077 | 阅读页图片加载失败显示轻量占位和重试，不让整章崩溃。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0078 | 长标题或超长章节名省略得当，点击可查看全文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0079 | 单页末尾避免只剩一行标题或明显孤行，提高视觉排版质量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0080 | 对阅读页建立黑白、暖白、深色三套截图基线，确保版式一致。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |

## A03 字体、字形与文字排版自定义

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0081 | 正文字号支持连续细粒度调节，实时预览实际行数变化。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0082 | 标题字号可独立设置，避免和正文共用单一缩放值。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0083 | 正文字重允许使用系统字体支持的等级，不能只通过重复绘制伪加粗。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0084 | 提供中文字体、英文字体、数字字体的合理后备字体链。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0085 | 支持从 Android 文件选择器导入合法 TTF/OTF 字体文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0086 | 导入字体后生成可识别名称、预览示例并可安全删除。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0087 | 字体文件异常或损坏时自动退回默认字体，不导致书籍打不开。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0088 | 支持为当前书与全局分别指定字体，优先级清晰。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0089 | 支持自定义字体的实时对比预览和一键恢复默认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0090 | 中文标点挤压、行首禁则和行尾禁则要尽量遵循排版规范。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0091 | 保持中英文混排基线对齐，避免英文字符上下跳动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0092 | 为数字、括号、破折号、省略号验证不同字体的字宽行为。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0093 | 字间距支持正负微调但设置安全下限，防止文字重叠。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0094 | 中文与西文分别允许调整字间距，并提供统一开关。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0095 | 行距按实际字体尺寸计算，不使用固定像素造成不同字号比例失真。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0096 | 提供行高倍数模式和具体间距模式，两者不能互相覆盖异常值。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0097 | 段落间距可独立控制首段、普通段与章节分隔。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0098 | 首行缩进支持以汉字宽度或数值比例表示，跨字体表现稳定。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0099 | 允许关闭首行缩进，适配技术书、英文书和对话式内容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0100 | 中文段前后空白清洗可选，默认不擅自删作者的有意义换行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0101 | 西文长词和 URL 断行正确，不产生水平溢出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0102 | 支持文字两端对齐、左对齐及原书样式优先等模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0103 | 对过大字号提供布局边界检查，保证仍能翻页与选字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0104 | 字体渲染启用亚像素或抗锯齿时依据平台能力选择，不冒充跨平台完全相同。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0105 | 针对中文引号、书名号和全角空格增加专项截图测试。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0106 | 支持正文字体颜色自定义，提供对比度不足时的温和提醒。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0107 | 支持黑白模式下极细字体关闭选项，保证低亮度可读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0108 | 对强调、粗体、斜体保留 EPUB 作者语义，不粗暴覆盖成同一字重。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0109 | 正文中上标、下标、脚注符号保持相对大小与基线。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0110 | 正文中强调标注不应因调整字距而覆盖相邻文字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0111 | 全局排版参数可保存成命名预设并支持复制。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0112 | 每书独立排版覆盖应在设置页面标明“仅此书生效”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0113 | 提供全局预设继承与本书局部覆盖的一键对比。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0114 | 切换字体应基于文本锚点重新分页，不把旧页索引当语义位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0115 | 字体预览与实际阅读必须共用相同排版组件，防止预览失真。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0116 | 应对字体切换时的页面跳动提供轻量遮罩而非白屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0117 | 把已用字体的缺失状态反馈给用户，保留原选择并提供替换。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0118 | 同步字体选项时区别字体名称元数据与字体文件，避免另一设备直接显示方框字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0119 | 通过中文小说、英文段落、数学符号和混合标点四类文本验收字体参数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0120 | 排版设置恢复默认时准确清除覆盖字段，不误删用户命名预设。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |

## A04 页面间距、布局和特殊文本

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0121 | 阅读页上边距可独立调整，不强迫与下边距相同。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0122 | 阅读页下边距可独立调整，并与页脚显示模式协调。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0123 | 阅读页左右边距可分别调整，允许设置对称锁定。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0124 | 书籍正文最大宽度可设置，适配平板阅读长行问题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0125 | 提供段落顶端缩进选项，不与首行缩进混淆。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0126 | 章节前后留白可单独设置，避免章节页过空。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0127 | 标题与正文之间的距离可选紧凑、舒适、自定义。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0128 | 每段首行缩进与章首第一段独立处理，避免重复缩进。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0129 | 连续空行的压缩强度可选关闭、轻度、标准，默认保护原文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0130 | 对纯 TXT 的全角空格缩进识别可以按书单独开关。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0131 | 允许显示阅读辅助基线或横线纸，不改变书籍正文文本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0132 | 辅助横线支持实线、虚线、点线和透明度调节。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0133 | 可设置页内文字垂直排布策略，防止页面底端孤行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0134 | 段落分页时避免把同一短句断成上下页孤行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0135 | 长段落翻页时保持精确字符边界，不丢字或重字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0136 | 章节标题跨页时与紧随的首段至少保留合理行数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0137 | 章节分割线的显示样式可配置为无、细线或留白。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0138 | 对连续制表符与多个空格保留代码区域语义。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0139 | TXT 小说中连续对话行的空行策略可单书覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0140 | EPUB 引用块与普通段落有独立缩进和边框选项。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0141 | EPUB 列表缩进正确，序号/项目符号不能覆盖正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0142 | EPUB 诗歌文本保留必要换行并允许横向浏览长诗行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0143 | EPUB 表格优先保留列结构，不擅自拆成难读单字列。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0144 | 宽表格可横向滚动并提供回正文的明确交互。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0145 | 长代码段使用等宽字体并可横向滚动，不由正文对齐规则挤变形。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0146 | 支持可关闭的段落首字下沉表现，仅用于源书支持情形。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0147 | 插图居中、宽度比例和上下距离可有全局偏好。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0148 | 小图不强制拉伸至屏宽，避免模糊。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0149 | 极大图按需缩放与延迟解码，保证正文稳定。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0150 | 内联数学公式保持基线，过宽时提供可查看完整公式的交互。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0151 | 块级公式按宽度缩放或横向浏览，禁止直接裁切结果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0152 | 脚注编号和尾注标识可点开实际内容，不能只是有下划线。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0153 | 注释弹层支持返回前阅读位置且不会错误翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0154 | 引用书内锚点链接后可一键返回跳转前位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0155 | 允许禁用 EPUB 作者颜色但保留强调结构。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0156 | 允许仅覆盖字号和行距，保留 EPUB 其他作者 CSS。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0157 | 提供“尊重原书样式 / 智能简化 / 强制统一排版”三级策略。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0158 | 自定义内容替换仅作用显示层，默认不改原书文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0159 | 内容替换启用后搜索与书签仍指向原始语义位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0160 | 对 20 种典型特殊段落截图回归，检查文字遮挡和越界。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |

## A05 阅读主题、背景与护眼调节

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0161 | 预置纯白、暖纸、米黄、灰纸、黑底灰字等低干扰阅读主题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0162 | 允许用户创建、重命名、复制、删除自定义阅读主题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0163 | 阅读主题可独立保存背景色、字体颜色、强调色和边距组合。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0164 | 主题编辑支持实时预览，点击取消应恢复修改前状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0165 | 允许通过颜色选择器设置背景色，同时支持十六进制精确输入。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0166 | 支持自定义背景图片，使用 Android 文件选择器导入。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0167 | 背景图片提供平铺、居中、铺满、适应四种模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0168 | 背景图独立调整亮度和遮罩透明度，不直接修改原图。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0169 | 背景图缺失时使用主题后备色，不弹出阻止阅读的错误。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0170 | 可单独设置阅读正文、顶部菜单和底部工具栏的背景色。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0171 | 深色主题下链接和高亮应保持清晰区分，避免荧光刺眼。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0172 | 提供低对比度提示但允许用户明确继续自定义。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0173 | 阅读主题切换支持即时应用，避免先加载旧主题闪烁。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0174 | 支持按系统深浅模式自动切换指定阅读主题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0175 | 可选按本地时间自动切换日间与夜间主题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0176 | 自动主题切换不要在用户正在选字时突然重排内容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0177 | 每本书可覆盖全局主题，覆盖优先级必须明确。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0178 | 可保存“白天主题”和“夜间主题”两个一键快捷入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0179 | 支持可关闭的屏幕暖色辅助层，明确不是系统级色温调节。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0180 | 主题与文字颜色同步更新页眉页脚，避免颜色不一致。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0181 | 允许隐藏或降低页眉页脚对比度，让正文更突出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0182 | 提供简单纸张纹理但默认关闭，避免在低端机造成卡顿。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0183 | 纸张纹理不随文字滚动产生不自然的视差漂移。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0184 | 背景过渡动画可关闭，尊重系统减少动画设置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0185 | 支持导入导出开放 JSON 主题配置，进行版本字段校验。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0186 | 导入未知主题属性时安全忽略并给出可见提示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0187 | 主题列表显示实际文本预览，不仅显示一块纯色。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0188 | 允许长按主题预览其完整排版，而不是先应用再撤销。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0189 | 自定义主题删除后已使用该主题的书籍应回退可用预设。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0190 | 已同步但缺背景文件的主题应标“资源待下载”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0191 | 主题切换要保留当前书锚点，不因字号变化跳章。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0192 | 手机横竖屏可以选择同主题不同边距覆写。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0193 | 墨水屏或电子纸设备提供高对比纯色主题，禁用多余纹理。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0194 | 对 OLED 纯黑主题提供可选防文字残影配置但不宣称绝对防烧屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0195 | 主题云同步应以稳定 UUID 区分重名主题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0196 | 多设备同时改同一主题时保留冲突副本，不静默丢修改。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0197 | 未保存的主题编辑在返回时弹出保留或放弃确认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0198 | 页面截图基线覆盖五种主题、三档字号及两种屏幕方向。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0199 | 颜色选择器开启时不让当前阅读滚动位置丢失。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |
| 0200 | 默认主题必须开箱即用、舒服，不强迫用户先调十几个参数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/settings |

## A06 翻页引擎、分页精度和阅读模式

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0201 | 实现无动画直接翻页，确保点按后立即显示正确下一页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0202 | 实现左右覆盖翻页，上一页与下一页方向逻辑一致。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0203 | 实现左右平移翻页，过渡结束后文本位置不偏移。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0204 | 实现左右滑动翻页，滑动阈值与速度可调。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0205 | 实现竖向滚动阅读，支持连续滚动不强制每屏吸附。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0206 | 实现竖向分页阅读，翻屏时停留在完整段落边界。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0207 | 可选仿真翻页，在设备性能不足时安全切回普通翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0208 | 可选卷页或纸张翻折效果，不以高耗电特效作为默认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0209 | 允许分别设置触摸点击、水平滑动、垂直滑动翻页行为。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0210 | 支持翻页方向反转，适合单手左手或右手操作。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0211 | 提供翻页动画时长调整，并明确实际毫秒范围。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0212 | 翻页过程手势中断时正确回弹，不出现半页卡住。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0213 | 快速连续点击下一页时按序处理，不能跳页、重页、丢页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0214 | 快速连续反向翻页时取消过期动画，避免画面抖动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0215 | 分页算法要根据实际文本高度，避免底部被遮挡一行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0216 | 分页缓存以内容版本、字体、边距和屏幕尺寸为键自动失效。 | PASS | f97c1d6 · 缓存键含内容哈希/排版设置/尺寸/章节长度/文本缩放，最多 6 章；reader_page_smoke_test 3/3；全量测试 110/110 |
| 0217 | 章节过长时按需分页，不一次性创建整本书所有页面 Widget。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0218 | 改变字号后重新计算分页，但恢复同一语义阅读锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0219 | 改变设备宽度后以内容锚点重定位，不使用旧页数直接换算。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0220 | 屏幕短暂旋转后避免同一页内容重复或丢失。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0221 | 翻页前预先加载相邻页面的文本和插图资源。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0222 | 预加载距离可根据可用内存与书籍类型动态调整。 | PARTIAL | f97c1d6 · 相邻章节 ±1 预加载已实现；距离仍固定，未按内存/书籍类型动态调整 |
| 0223 | 最后一页翻下一章时保持自然连续，不出现空白中间页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0224 | 上一章最后一页反向翻回时正确保留末段内容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0225 | 章节边界的页码、百分比与目录状态实时一致。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0226 | 支持页面底部横向进度滑杆，不触发正文错误滚动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0227 | 进度滑杆拖动时提供章节和位置预览，而非盲跳。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0228 | 拖动进度后可以返回拖动前阅读位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0229 | 允许用音量键翻页并提供开关与方向反转。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0230 | 支持兼容可识别蓝牙翻页器按键，未授权不接管所有键盘输入。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0231 | 支持自动滚动模式，速度可调且暂停行为明确。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0232 | 支持定时翻页模式，设定间隔后可暂停与停止。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0233 | 支持阅读中防误翻页锁定开关，解除方式明确。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0234 | 通过后台恢复后翻页动作不会被重复执行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0235 | 在 30 万字 TXT 上验证连续前后各 100 页无漏字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0236 | 在图片与文字混排 EPUB 上验证 100 次反复翻页布局稳定。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0237 | PDF 的翻页状态与文本型阅读器独立，不强行共用字符分页算法。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0238 | 阅读模式切换时通过稳定锚点保留位置并记住每本书偏好。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0239 | 全部翻页模式具备关闭动画的降级路径和相同的进度持久化结果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |
| 0240 | 低刷新率与省电模式下减少不必要动画帧，保证稳定可读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/engine |

## A07 点击区域、手势与触控细节

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0241 | 可自定义屏幕左中右三块点击区域对应的上一页、菜单、下一页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0242 | 支持九宫格点击区域配置，允许每格指定动作或禁用。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0243 | 点击区域编辑器用直观区域示意，保存后即刻生效。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0244 | 支持分别设置单击、双击和长按的动作映射。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0245 | 双击正文触发的操作不能误触发两次单击翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0246 | 允许设置向左和向右滑动的翻页方向。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0247 | 允许设置向上和向下滑动的操作，包括菜单、亮度或翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0248 | 页面左右边缘手势优先尊重系统返回手势安全区域。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0249 | 可以选择关闭所有手势翻页，仅用按钮操作。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0250 | 提供左手模式和右手模式的常用手势预设。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0251 | 长按选字阈值可按系统默认或自定义，不影响系统无障碍操作。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0252 | 文本选择手柄拖动必须优先于翻页手势识别。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0253 | 放大图片时水平拖拽不触发下一页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0254 | 批注、笔记弹窗中手势不应穿透到底下的阅读页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0255 | 列表滚动到边缘时避免意外跳整章。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0256 | 点击页眉页脚自定义操作，不强制把状态条当翻页区。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0257 | 支持单击菜单空白处关闭菜单而非误翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0258 | 对手指轻微抖动设置触控容错，减少误识别滑动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0259 | 对大幅快速划动设定最大翻页步数，避免一次穿越数十页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0260 | 用户拖动进度滑杆时暂停手势翻页识别。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0261 | 在竖向滚动模式提供滚动惯性强度或系统默认两档。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0262 | 夜间或单手模式下可选屏幕边缘浮动翻页按钮。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0263 | 浮动按钮位置、大小、透明度可调且可彻底关闭。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0264 | 提供系统触感反馈开关，并在不支持设备安全忽略。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0265 | 点击目录项目后重置触控锁存状态，避免返回后首次触控失效。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0266 | 多点触控只在缩放等明确场景启用，不让普通双指误翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0267 | 支持常用外接键盘 PageUp/PageDown 翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0268 | 支持外接键盘方向键翻页开关，不抢夺输入框编辑键。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0269 | 横屏分栏时点击区域应按当前阅读列重新映射。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0270 | 可一键恢复默认手势方案，不清除其他自定义设置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0271 | 显示各手势的当前绑定摘要，避免多个动作占同一触发器而无提示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0272 | 检测手势冲突并让用户明确选择覆盖规则。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0273 | 双击缩放图片后单指拖动画面要保持缩放状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0274 | 长按章节标题和正文的菜单行为保持一致但尊重不可选择区域。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0275 | 在阅读中使用 Android 系统截图手势不应被应用拦截。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0276 | 验证 TalkBack 开启后双击动作不会误触发自定义翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0277 | 手势设置的不同机型触控密度换算按 dp 执行，不能写死像素。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0278 | 翻页时关闭重复震动，避免高频操作影响电池和阅读体验。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0279 | 为手势提供独立测试页，用户可先试再保存。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0280 | 记录误翻页典型回归：双击、长按、拖选、返回、缩放、触控边缘。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |

## A08 菜单、工具栏与阅读设置交互

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0281 | 阅读页菜单采用明确的上栏与下栏结构，减少一次性铺满屏幕的入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0282 | 默认底栏突出目录、进度、主题、排版与更多五类核心能力。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0283 | 允许自定义阅读顶部工具栏按钮顺序。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0284 | 允许隐藏不常用的阅读工具按钮而不删除功能本身。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0285 | 允许设置底栏快捷入口的数量，超出自动收纳到更多菜单。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0286 | 排版面板的常用字号与行距调整应一层可达。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0287 | 字体选择面板支持先预览后应用，不让用户多次退出菜单。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0288 | 主题列表支持横向快捷切换并展示真实颜色预览。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0289 | 阅读进度面板展示本章进度、全文进度和可跳转章节。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0290 | 所有滑杆的当前数值可见，避免纯图形无法准确复现设置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0291 | 滑杆支持点击数值后精确输入，兼顾小幅调节。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0292 | “恢复默认”只影响当前面板，提供独立的全局重置确认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0293 | 阅读设置按排版、主题、翻页、手势、页眉页脚分类，不混排。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0294 | 当前书覆写与全局设置入口视觉区分，避免意外改所有书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0295 | 面板关闭重开后保持最后一级位置，可选每次返回顶层。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0296 | 弹窗背景使用轻量遮罩，不采用过强毛玻璃影响流畅。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0297 | 设置页面长标题自动换行但行高稳定，不切字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0298 | 菜单图标、说明、开关状态保持一一对应，不出现假已开启。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0299 | 需要授权或未实现的操作隐藏或明确禁用，不允许点击无反应。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0300 | 点击“同步当前书进度”显示真实上传、成功和失败状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0301 | 阅读工具栏可配置显示当前网络或云同步指示，但默认低干扰。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0302 | 快捷菜单允许收藏常用的“回到上次位置”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0303 | 搜索、笔记、书签面板支持从阅读页一步进入且一步返回。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0304 | 阅读菜单在横屏时采用紧凑左右面板，避免占据半页内容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0305 | 阅读菜单弹出与关闭过程不应触发正文重新分页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0306 | 设置面板切换时使用轻量转场，不做重复整页重绘。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0307 | 交互使用统一系统返回行为，弹层按后进先出关闭。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0308 | 保存设置失败时不显示成功图标并保留待重试改动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0309 | 对需要重新分页的操作显示简短进度状态，避免看似卡死。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0310 | 多项排版修改合并成一次重排，停止拖动后触发。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0311 | 预设快捷项支持收藏三种常用阅读排版方案。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0312 | 目录、进度与书签之间可切换，但不会丢失各自滚动位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0313 | 用户打开阅读面板时记录返回前正文锚点，退出准确复原。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0314 | 所有图标优先使用统一线性风格和同一线宽。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0315 | 设置行高满足可触控要求，即使字体小也不能让按钮挤在一起。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0316 | 长文本说明放入二级帮助，不让设置页像说明书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0317 | 为深色阅读页设计独立菜单对比度，避免深背景上灰字看不清。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0318 | 可选在标题栏显示阅读进度百分比，而不是固定显示全部状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0319 | 菜单自定义结果要参与云同步分组策略，允许设备各自布局。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |
| 0320 | 首次触发陌生操作展示一句话说明，用户可关闭提示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/widgets/reader_settings_sheet.dart |

## A09 页眉页脚、进度与可靠恢复

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0321 | 页眉可选择显示书名、章节名或自定义模板。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0322 | 页脚可选择显示章节页码、全文百分比或当前章节进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0323 | 页眉页脚模板支持时间、电量、已读字数的占位符。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0324 | 对未知模板变量显示错误说明，不把花括号原样误当有效数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0325 | 页眉与页脚字号、字重、颜色、对齐方式分别可调。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0326 | 页眉页脚距边缘距离可独立调整且不挤压正文可读区域。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0327 | 支持显示当前章总页数，但分页未完成时明确显示正在计算。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0328 | 不因全书页数后台计算而阻塞进入阅读页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0329 | 阅读进度保存精确到文本锚点，百分比只是显示派生值。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0330 | TXT 进度包含原始字节区间、编码与标准化文本位置以备恢复。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0331 | EPUB 进度保存稳定 spine、CFI 或等价可验证锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0332 | PDF 进度保存文档稳定标识、页码、视口相对坐标和缩放模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0333 | 退出阅读页立即本地保存进度并写入持久化事务。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0334 | 翻页后采用节流合并写入，既降低磁盘压力又防止进度丢失。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0335 | 应用进入后台时强制刷新当前进度到本地数据库。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0336 | 进程被系统杀死重启后恢复上次阅读位置而不要求手动保存。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0337 | 读取到无效旧进度时安全回退最近有效章节并告知用户。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0338 | 修改正文排版后依旧恢复到同一句附近而非同一数字页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0339 | 用户手动跳章节前保存一个“返回跳转前位置”锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0340 | 提供最近阅读位置历史，允许在有限记录间前进或后退。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0341 | 用户退回上一位置后不应把该操作误当成新的云端最高进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0342 | 阅读进度允许主动标记已读、未读与重新阅读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0343 | 重新阅读模式的进度同步需用户明确选择覆盖还是保留旧位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0344 | 显示“最近同步到云端的阅读位置”，并标记设备与时间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0345 | 当前设备进度比云端旧时询问是否跳转，不静默抹掉本机位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0346 | 允许设置打开图书时是否自动检测云端当前书进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0347 | 云端不可用时应立即进入本机阅读，不无限等待网络超时。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0348 | 启用“等待云端进度后跳转”时提供超时退出与取消入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0349 | 阅读页显示未同步的进度状态时采用低干扰图标。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0350 | 书籍导入后先建立稳定文件身份，避免换名字就丢进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0351 | 复制同一本书文件两份时提示是否视为同一作品。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0352 | 改了文件内容后检测版本并提示定位可能偏差。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0353 | 进度格式升级必须具备旧格式迁移与回退验证。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0354 | 快速跨章连续阅读时同步任务只读取已提交的最新位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0355 | 同一书的多窗口阅读进度写入以版本号协调，不乱序覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0356 | 提供阅读进度手动校准和重建入口，不直接清空历史。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0357 | 全文百分比要基于可读内容长度，不因封面和目录偏差过大。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0358 | 纯图片 EPUB 和 PDF 的百分比按页面权重独立计算并注明近似。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0359 | 进度恢复回归覆盖字号变更、旋转、文件更名、换设备、版本迁移。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0360 | 校验在重启、断网、云端冲突后“本机最后读到哪里”始终可查。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |

## A10 目录、章节导航与书内搜索

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0361 | TXT 自动目录识别章节号、中文数字、常见卷名和番外格式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0362 | EPUB 优先使用原书 nav/NCX 目录并保留层级。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0363 | PDF 使用书内 outline 目录，没有时显示可用页码跳转。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0364 | 目录树支持多级展开折叠，并记住上次展开状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0365 | 目录界面标注当前阅读章节并自动滚动到附近位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0366 | 搜索目录标题时支持拼音首字母但不误改书内正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0367 | 目录超长时分批构建列表，不一次性绘制数万项。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0368 | 点击目录章节进入阅读页时精确对齐章节开头。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0369 | 支持“上一章”“下一章”快速跳转且保持章节历史。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0370 | 支持“返回跳转前”按钮防止误点目录后找不回位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0371 | 书内搜索支持跨章节全文查找，不限制当前已渲染段落。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0372 | 搜索结果显示关键词所在章节与上下文片段。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0373 | 关键词在搜索结果和正文中高亮，且不改变原文字符串。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0374 | 搜索支持忽略大小写的英文查询和中文精确匹配。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0375 | 可选择全词匹配，主要针对英文和有分词边界的语言。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0376 | 搜索支持多关键字但需清楚说明 AND/OR 规则。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0377 | 搜索索引应增量构建，首屏可立即阅读无需等全文索引。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0378 | 大型 TXT 搜索通过后台 isolate 执行，输入时不阻塞滚动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0379 | 搜索结果能按书内位置排序，不只按生成时间排列。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0380 | 搜索结果跳转后提供上一匹配、下一匹配操作。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0381 | 搜索框清空时恢复正文原有高亮状态，不误删用户划线。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0382 | 书内搜索历史本机保存，可一键清除且不强制云同步。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0383 | EPUB 注释与目录链接跳转后仍保留返回锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0384 | EPUB 跨章节锚点如果不存在要提示并保留原位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0385 | 支持手动给 TXT 增加章节分割点但不修改原文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0386 | 支持合并误识别 TXT 小节，保留原内容位置关系。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0387 | 支持从某章起重新分章而无需重新导入整本书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0388 | 分章规则修改后迁移书签和笔记的位置锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0389 | 大纲树支持当前书章节数量与全文总字数的概览。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0390 | 目录层级超过四层时仍可缩进展开，不出现无限过窄。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0391 | 支持目录长按复制章节标题或跳转链接。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0392 | 可选显示每章进度与已读标记，不能靠 UI 随机判断已读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0393 | 章节列表中的阅读位置更新应及时但不每次翻页全表重建。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0394 | 书内搜索无结果时展示有意义提示而不是空白页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0395 | 搜索遇到损坏章节应跳过并提示受影响范围，不整书报错。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0396 | 支持仅搜索标题、仅搜索正文和全部搜索三种范围。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0397 | 搜索数据可在本机重建，避免作为云同步必传的大文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0398 | 支持搜索结果批量转为书签或笔记入口，但需要逐项确认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0399 | 检查目录快速跳转 100 次后无进度漂移和页面泄漏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |
| 0400 | 对 1000 章 TXT、嵌套 EPUB 和复杂 PDF 分别进行目录与搜索验收。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/reader_page.dart |

## A11 TXT 解析、编码与分章

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0401 | TXT 导入支持 UTF-8、UTF-8 BOM、GBK、GB18030 和 UTF-16 的可靠探测。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0402 | 编码探测不确定时提供预览和用户手动选择编码。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0403 | 导入后保存所选编码，重新打开时不重复猜测。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0404 | 兼容 CRLF、LF、CR 混合换行，避免出现多余空白行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0405 | 处理超长单行 TXT 时按可读位置分块，不申请巨大临时字符串。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0406 | 以流式方式解析百兆级 TXT，不一次性把全部字节常驻内存。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0407 | 自动识别“第一章”“第1章”“第〇一章”等常见章节标题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0408 | 自动识别“卷一”“正文”“序章”“尾声”“后记”“番外”层级。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0409 | 自定义分章正则提供测试预览和超时限制，防止灾难性回溯。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0410 | 分章结果显示识别章节数、疑似误识别数和可编辑目录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0411 | 没有章节的 TXT 支持按字数生成虚拟分段目录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0412 | 分章时对章节标题重复问题提供合并或保留选择。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0413 | 误判正文对话为章节时支持手动屏蔽该位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0414 | 从文件重建目录不应删除已有笔记和阅读进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0415 | 保留 TXT 原始文件副本，不因排版清洗直接覆盖文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0416 | TXT 特殊字符缺字时高亮定位而非整段变成问号。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0417 | Emoji、扩展汉字、异体字按 Unicode 组合字符正确分页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0418 | 文件末尾无换行时最后一个段落必须完整显示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0419 | 空文件与全空格文件要有可理解的导入失败提示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0420 | 非文本二进制伪装 TXT 时拒绝乱码导入并保留源文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0421 | TXT 文件被外部修改时通过大小、mtime 与内容指纹校验。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0422 | 外部修改前后提供重新索引与保留旧记录的选择。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0423 | TXT 正文全局查找支持逐段结果预览和点击定位。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0424 | 可设置每段的最大空行压缩规则，避免清除诗歌换行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0425 | 根据语言智能默认首行缩进，但允许用户完整覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0426 | 大章节跨页翻动不得重复截取字符导致丢字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0427 | TXT 阅读位置以原始字符偏移和锚点联合保存。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0428 | 重新分章后尽量将旧进度映射到相同文本片段。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0429 | 对 UTF-16 代理对、组合变体字符使用正确字符边界。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0430 | 解析时保留章节标题原字形，不强制自动纠错章节名。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0431 | 超大 TXT 首次打开应优先展示第一可读页再后台建索引。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0432 | TXT 分段缓存可按需清理但不丢书签及已保存进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0433 | 支持 TXT 文本替换规则单书与全局继承。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0434 | 替换规则可预览影响片段，防止误删大范围内容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0435 | 替换规则禁止无限循环，限制替换次数和正则耗时。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0436 | 使用纯本地测试样本验证十万、百万、千万字符的读取行为。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0437 | 分章规则切换后目录、总进度和章节页码一致更新。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0438 | 提供 TXT 段落原文复制，不能复制排版加的虚拟缩进字符。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0439 | 重新打开已导入 TXT 时避免全文件重复拷贝造成启动变慢。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |
| 0440 | TXT 引擎与 EPUB 的阅读共用主题 UI，但保持各自语义位置映射。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/chapter_splitter.dart |

## A12 EPUB 正文渲染与标准兼容

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0441 | EPUB 导入校验 ZIP 结构，拒绝路径穿越与压缩炸弹资源。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0442 | 解析 container.xml 和 OPF 清单，正确定位 spine 的阅读顺序。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0443 | 支持 EPUB 2 NCX 与 EPUB 3 nav 目录，保持嵌套层级。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0444 | 逐章解析 XHTML，避免将全书合并成长字符串破坏结构。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0445 | 支持书内图片、SVG 或合法资源的安全显示与尺寸约束。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0446 | 正确保留段落、标题、引用、列表等基础语义结构。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0447 | CSS 支持常见 font-family、font-size、line-height、margin 等合法规则。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0448 | 对作者 CSS 中不受支持的样式安全降级，不让全书白屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0449 | 允许按书选择尊重作者 CSS 或以用户样式覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0450 | 书内粗体、斜体、强调、下划线应保留语义。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0451 | EPUB 表格保持列布局并支持横向滚动。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0452 | EPUB 内嵌字体需检查声明和资源有效性，失效时安全回退。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0453 | CSS 资源路径按 EPUB 相对目录解析，禁止外部脚本执行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0454 | EPUB 链接按内部锚点和外部链接分流处理。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0455 | 点击脚注引用显示内容预览，再可选择跳转正文注释。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0456 | 脚注弹层支持至少两种简洁样式且保留当前位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0457 | EPUB 3 固定版式使用独立缩放和分页策略，不套用流式字号设置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0458 | 固定版式双页跨页保留左右逻辑和安全缩放比例。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0459 | 对图文绘本保持图片清晰度和文字位置，不强制重排成小说。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0460 | 阅读器内外链必须请求明确跳转确认，不静默发起第三方请求。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0461 | EPUB 中潜在恶意 JS、iframe 和远程内容默认不执行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0462 | EPUB 中相同资源的重复引用共享缓存，避免多次解码。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0463 | 支持章节内部带 ID 的锚点跳转，并可返回前位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0464 | 跨章节脚注跳转失败时保留原阅读页并给出轻提示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0465 | EPUB CFI 或等价锚点支持因用户字号调整后定位稳定。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0466 | CSS 大小单位 em、rem、pt、百分比转换以正确上下文计算。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0467 | 插图尺寸超过屏幕时适配宽度，允许点开手势缩放。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0468 | 正文内小图不强制独占一整页，保留图文关系。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0469 | EPUB 页面中连续空 div 与空 p 应按选择策略处理。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0470 | 基础 Ruby 注音文字在可用字体下不覆盖正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0471 | 支持图片替代文本的无障碍朗读和图片缺失提示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0472 | 排版缓存包含书籍版本与 CSS 配置哈希，避免旧布局残留。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0473 | EPUB 重新导入同一文件时复用书籍身份和已有笔记。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0474 | EPUB 内含目录而正文缺失的损坏包应明确报错。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0475 | 用合法样本检查 RTL 与双向混排，暂不支持时明确告知。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0476 | HTML 标签白名单与链接 URL 校验覆盖注入和超长属性边界。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0477 | 对不同宽度和字号校验 EPUB 注释、表格、插图不发生覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0478 | 书内文字选择需从真实 DOM/文本位置映射到稳定笔记锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0479 | EPUB 渲染失败允许按章节回退到简化文本，而非整本书不可读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |
| 0480 | 对 EPUB 2 普通小说、EPUB 3 复杂图文、固定版式分别建立自动化样本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/book_import_service.dart |

## A13 PDF 阅读器独立体验

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0481 | PDF 打开时使用独立文档视图，不伪装成 TXT 分页模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0482 | PDF 按页懒加载，避免打开千页文档时一次性光栅化。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0483 | 支持单页模式和连续竖向滚动模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0484 | 支持水平翻页模式，页间距可调。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0485 | 支持适合宽度、适合页面、实际尺寸三种缩放策略。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0486 | 双指缩放保持手指中心位置，不在松手后突然跳回页面顶部。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0487 | 双击缩放支持可开关及倍率设定。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0488 | 支持裁除 PDF 页面白边预览，裁剪不改源文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0489 | 支持自动白边检测但需手动确认应用结果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0490 | 支持按左、右、上、下分别微调裁边。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0491 | PDF 夜间模式支持反色或低亮度模式，并可对图片保留原色。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0492 | 支持 PDF 对比度、亮度的合理范围调整。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0493 | PDF 页码输入支持直接跳页和历史回退。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0494 | 显示 PDF 缩略图导航列表并异步加载缩略图。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0495 | 支持读取 PDF outline 目录并正确跳转页目标。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0496 | 有文本层的 PDF 支持跨页搜索和高亮搜索结果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0497 | 无文本层的扫描 PDF 明确提示不可搜索，不假称 OCR 已实现。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0498 | PDF 文本层支持选择、复制与引用，不因图片层导致点不中。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0499 | PDF 高亮和笔记坐标以归一化页面坐标保存，缩放后位置准确。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0500 | PDF 批注支持可选择独立侧车文件或原文件副本导出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0501 | PDF 批注删除应可撤销，不直接重写原文档造成风险。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0502 | 密码保护 PDF 支持用户输入密码并在本次会话解锁。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0503 | PDF 密码不得明文写入云同步元数据或调试日志。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0504 | 遇到损坏 PDF 页面显示页级错误，允许继续看其他页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0505 | 页面渲染分辨率根据缩放倍率渐进提高，避免先大图卡死。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0506 | PDF 图片缓存有大小上限，切出阅读时回收非必要位图。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0507 | 文字型 PDF 与固定版式 PDF 的进度分别记录页码与视口坐标。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0508 | 旋转屏幕后保持同一页的相近可视区域。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0509 | 书签定位到 PDF 页码及可视区域，不只存页码整数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0510 | PDF 链接跳转内部目标后支持返回前视口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0511 | PDF 页面中注释与链接弹窗不能穿透触发翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0512 | 可配置 PDF 页间空白颜色与页阴影，默认为低干扰风格。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0513 | 支持 PDF 单页居中及双页显示（宽屏且设备可用时）。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0514 | 有目录 PDF 与无目录 PDF 都要能通过页码和缩略图导航。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0515 | PDF 搜索长文档时后台增量索引，不冻结阅读页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0516 | 阅读器切后台再返回时不无故重新渲染所有已缓存页面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0517 | PDF 第 1、100、1000 页随机跳转时内存和耗时保持受控。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0518 | 若添加 OCR/重排，必须作为可选真实功能而非空入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0519 | PDF 格式差异在排版设置页面明确展示不可用选项原因。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |
| 0520 | PDF 云端进度必须跨设备对应同一文档指纹和页内相对位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/reader/pdf_reader_page.dart |

## A14 书籍导入、本地书架和文件管理

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0521 | 支持 Android 系统文件选择器单文件和多文件导入。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0522 | 支持从系统“用 Read 打开”和分享菜单导入本地图书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0523 | 导入后创建本机受管理副本或持久 URI 引用，并说明存储策略。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0524 | 文件选择器撤销授权时提示重新授权而不是直接删书籍记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0525 | 导入任务支持进度展示、取消和失败重试。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0526 | 多个文件导入时单本失败不得回滚其余成功图书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0527 | 对同文件哈希识别重复导入，允许跳过或保留独立副本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0528 | 书籍名称优先使用可读元数据，解析失败退回文件名。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0529 | EPUB 封面优先使用内置封面并在失败时生成文本封面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0530 | TXT 无封面时生成统一风格的排版占位封面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0531 | PDF 封面可取首页缩略图，异步生成不阻塞书架。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0532 | 支持手动修改书名、作者、封面和简介且保留原文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0533 | 书架支持网格视图、列表视图和紧凑列表视图。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0534 | 书架网格列数随屏宽变化，并允许手动选择两列或三列。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0535 | 封面比例统一但保留原图主体，避免粗暴裁剪图书标题。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0536 | 支持按最近阅读、最近导入、书名、作者和进度排序。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0537 | 支持按已读、在读、未读和已完成筛选。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0538 | 支持书架本地全文书名与作者搜索。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0539 | 支持按标签、分类和自定义书单整理图书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0540 | 图书可批量移动分类、添加标签和移出书架。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0541 | 删除操作明确区分移除书架、删除本地副本和同步删除。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0542 | 删除图书时默认保留阅读进度和笔记的可恢复记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0543 | 云端图书未下载时标记云朵图标，点击可确认下载。 | PARTIAL | f97c1d6 · CloudLibraryIndex 只读云端索引，仅真实云端书显示云朵；点击确认下载仍未实现 |
| 0544 | 云端图书列表读取失败时不删除本地书架显示。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0545 | 支持对书籍记录合并重复项但展示将合并的数据清单。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0546 | 书架封面滚动使用缩略图缓存，不同步解码高清原图。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0547 | 批量导入完成后以简洁通知展示成功、跳过与失败数量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0548 | 本地扫描文件夹采用用户授权目录，不偷偷扫描全部存储。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0549 | 文件夹扫描时根据路径、大小和指纹识别已导入文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0550 | 文件移动或重命名后可通过内容指纹重连原阅读记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0551 | 已删除书籍提供可恢复列表及清理策略。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0552 | 支持按书籍大小和最近打开时间查看占用空间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0553 | 缓存清理先展示预计释放空间，不删除原书和重要元数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0554 | 用户修改元数据后云同步保留修改来源与版本号。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0555 | 书架删除和恢复行为在另一设备同步时有明确对应结果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0556 | 书籍缺文件时支持重新绑定本地文件而不新建重复记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0557 | 在 1000 本书的书架上验证封面滑动与搜索响应。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0558 | 应用重启后保持书架排序、布局与筛选偏好。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0559 | 书架黑白极简设计保持统一，避免花哨推荐广告入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0560 | 不引入网络书源、书源解析、在线抓取或小说站聚合功能。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |

## A15 划线、书签、批注与知识沉淀

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0561 | 支持 TXT、EPUB 文字划线并以稳定正文锚点持久化。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0562 | 文字选择菜单提供复制、划线、笔记、词典和系统分享。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0563 | 用户可以调整划线颜色、样式和透明度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0564 | 支持实线、波浪线、背景色等可读划线样式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0565 | 划线必须在改变字号与翻页模式后准确贴合原文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0566 | 跨页选择文字不能因为翻页释放选择区而丢失范围。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0567 | 选中文本跨章节时提供明确限制或真实多章支持。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0568 | 在选中片段添加自由文本备注并允许后续编辑。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0569 | 备注保存失败时保留编辑草稿并提供重试。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0570 | 阅读中一键添加当前页书签，并避免重复书签堆叠。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0571 | 书签支持重命名、标签和备注。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0572 | 书签列表显示章节、摘录、创建时间及来源书籍。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0573 | 书签点击后使用内容锚点精确返回原文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0574 | 修改 TXT 分章规则后书签尽量自动重新定位。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0575 | 替换 EPUB 文件版本时为失效书签提供重新匹配入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0576 | 笔记列表按书籍、标签、时间和正文顺序筛选。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0577 | 支持搜索全部本地笔记而不联网泄露私人摘录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0578 | 支持复制单条摘录与多条摘录的纯文本导出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0579 | 笔记导出支持 Markdown，保留书名、章节与位置元数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0580 | 笔记导入遵循稳定 ID 去重，避免重复生成同一划线。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0581 | 删除笔记提供短时撤销并记录待同步删除墓碑。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0582 | 本机离线新增的笔记在恢复网络后参与增量同步。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0583 | 同步冲突不能简单按最后写入整条覆盖，必要时生成冲突副本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0584 | 支持对划线增加多个标签，不让重命名标签破坏关联。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0585 | 笔记图书内跳转应保留离开前阅读锚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0586 | 支持按章节聚合显示该章所有书签和划线。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0587 | 阅读页正文高亮与搜索结果高亮使用不同视觉层级。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0588 | 文字划线与系统文本选择菜单互不遮挡。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0589 | 支持本地词典查词入口，但不强制登录第三方 AI。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0590 | 查词失败不影响复制或划线操作，且不能锁住阅读界面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0591 | 书摘分享卡片使用 Read 原创简约布局，不复制第三方素材。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0592 | 批量导出笔记前提供实际条数与内容预览。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0593 | 同步到新设备时恢复笔记正文、锚点、标签和修改历史。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0594 | 被删除书籍的笔记继续保留为孤立记录并支持重新关联。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0595 | PDF 批注独立标明页面坐标，不复用 EPUB 字符范围结构。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0596 | 可选显示阅读页中的笔记数量标识，不强制每段都亮色标记。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0597 | 为笔记添加创建与最后修改时间，不只存当前时间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0598 | 针对跨时区设备使用标准 UTC 时间与逻辑版本辅助冲突合并。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0599 | 测试 1000 条划线和 1000 条书签列表是否仍然流畅。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |
| 0600 | 笔记、书签、划线必须能在离线状态创建、修改与删除。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/highlight_store.dart |

## A16 WebDAV 协议、连接与云端存储

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0601 | 将 WebDAV 作为 Read 多设备同步首要协议，优先实测坚果云兼容性。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0602 | WebDAV 设置支持 HTTPS 地址、账号、应用专用密码与同步目录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0603 | 连接测试必须进行真实授权请求，不将 URL 格式正确误报为成功。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0604 | 支持 DAV PROPFIND 深度 0/1 并正确解析 XML 命名空间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0605 | 解析 WebDAV XML 时禁用外部实体、DTD 与危险实体扩展。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0606 | 处理服务端返回 301/302 跳转时禁止将凭据发送到未知域名。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0607 | 正确处理 401、403 并提示账号或权限问题，不自动无限重试。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0608 | 正确处理 404 的目录不存在与资源不存在两种不同情形。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0609 | 使用 MKCOL 逐级创建 Read 独立同步目录，支持已存在返回。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0610 | 支持服务端不允许自定义根目录时安全提示而非强行写根目录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0611 | 不读写或覆盖 Reeden 自身的专有同步目录与文件格式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0612 | 不把普通网盘中与 Read 无关的文件当成需要删除的同步垃圾。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0613 | 处理 URL 编码、中文文件名、空格与特殊字符路径。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0614 | 对路径进行规范化校验，禁止通过 ../ 跳出 Read 自己的目录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0615 | 支持 HTTP GET、PUT、HEAD、DELETE 的必要协议语义。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0616 | 尽可能通过 ETag 和 If-Match 保护已存在云端元数据写入。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0617 | 在服务端支持时使用临时文件 + MOVE 形成近似原子提交。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0618 | 服务端不支持 MOVE 时使用版本化对象与提交清单降低损坏风险。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0619 | 上传较大文件采用分块流式读取，避免全部读入内存。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0620 | 读取大文件采用流式写入临时文件并校验长度与摘要。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0621 | 下载到中途失败时不替换已有完整本地文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0622 | 处理 409 Conflict 并区分目录层级冲突和版本冲突。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0623 | 处理 412 Precondition Failed 后先重新拉取再进入合并流程。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0624 | 处理 423 Locked 提供有限退避，不直接提示“文件永久损坏”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0625 | 处理 429 Too Many Requests 使用指数退避和服务端 Retry-After。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0626 | 处理 500、502、503、504 网络错误时有限重试并保留本地待传队列。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0627 | 处理 507 Insufficient Storage 时显示空间不足且停止危险清理。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0628 | 配置服务器读写超时与取消，不让同步任务长时间悬挂。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0629 | 连接改动后先验证新端点，再允许用户选择替换旧配置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0630 | 同步文件命名采用稳定 ID 和明确版本号，避免由显示书名决定路径。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0631 | 每个云端数据类型分别指定大小上限，拒绝可疑超大清单。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0632 | WebDAV 服务证书必须走系统 TLS 验证，不能关闭证书校验求成功。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0633 | 支持基础认证并兼容主流云盘的应用密码，不保存明文日志。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0634 | 在服务端允许时记录 ETag 和 Last-Modified，但不单靠时钟判定数据胜负。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0635 | WebDAV 连接信息保存到平台安全存储，导出备份默认不包含凭据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0636 | 同步目录结构中分离元数据、书籍文件、附件和版本快照。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0637 | 上传前校验本地剩余空间和源文件可读性，不因上传失败删除原件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0638 | 提供真正的“列出云端当前版本和对象数”诊断入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0639 | 用本地 WebDAV 测试服务器模拟正常、限流、断线和权限不足场景。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |
| 0640 | WebDAV 页面展示最后一次成功连接与最后一次完整同步的不同时间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/webdav_store.dart |

## A17 自动同步、进度快车道和离线队列

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0641 | 允许手动立即同步并展示各阶段真实进度和可取消按钮。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0642 | 自动同步提供启动时触发，避免应用打开就阻塞书架首屏。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0643 | 自动同步提供打开书时触发，但默认不做昂贵的全书库阻塞拉取。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0644 | 自动同步提供关闭书时触发，优先立即本地保存当前书进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0645 | 自动同步提供书架、笔记、主题数据变化后防抖触发。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0646 | 自动同步提供从离线恢复在线后触发，可单独关闭。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0647 | 允许设置自动同步防抖延迟 30 秒、1 分、2 分、5 分及自定义。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0648 | 提供周期性同步间隔设置，受 Android 后台执行限制约束。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0649 | 自动同步可以设置仅 Wi-Fi 或允许移动数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0650 | 大文件同步可独立设置仅 Wi-Fi，不阻止小型进度元数据同步。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0651 | 阅读进度单独同步开关与完整元数据同步分离。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0652 | 当前书停止翻页约 8 秒后可快速上传单书进度，延迟可调整。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0653 | 关闭书时立即提交当前书最新进度到待同步队列。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0654 | 打开书时优先小请求拉取该书云端进度，不能等待整库同步完成。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0655 | 从云端跳转前比较本地位置，允许用户选择保持本机或采用云端。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0656 | 读取云端进度超时后继续使用本地进度，通知轻量且不阻断。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0657 | 同一本书短时间大量翻页时合并待上传进度，减少 WebDAV 请求次数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0658 | 编辑多个设置项时合并一次元数据上传，避免每按一次按钮都发请求。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0659 | 云同步在离线时写入持久队列，网络恢复后续传。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0660 | 队列重放必须幂等，同一操作重试不会重复新增书签或笔记。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0661 | 同步任务支持全局互斥锁，避免多个触发时机互相覆盖云端状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0662 | 前台同步显示真实状态，后台同步以低频通知或系统任务记录为准。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0663 | 用户主动取消同步后保留待传数据，不能标记为“已同步”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0664 | 数据变化发生在同步进行中时安排下一轮，不丢后续变化。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0665 | 上传完成后不应将另一个设备更新的旧进度回写覆盖当前正在读的进度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0666 | 同步状态区分“未配置”“等待网络”“排队”“同步中”“冲突”“完成”“失败”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0667 | 关闭自动同步只停止自动任务，不清空已建立的本地队列。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0668 | 网络类型从 Wi-Fi 切蜂窝时按用户策略暂停大文件同步。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0669 | 进入省电模式按 Android 调度限制执行，不启动违规常驻服务。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0670 | 高优先级进度同步与低优先级书籍文件同步互不阻塞。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0671 | 定义阅读进度上传的最大请求频率以适应坚果云限流。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0672 | 自动重试设置最大次数与退避，不无限占用网络。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0673 | 在应用冷启动时恢复上次未完成事务而不重复提交已经确认的版本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0674 | 读写双端同步完成后刷新相应本地书架与阅读状态，但不打断当前翻页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0675 | 如果设备 A 正在读书，设备 B 上传新进度时 A 不能突然自动跳页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0676 | 手动同步完成反馈本次上传、下载、合并、跳过与冲突数量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0677 | 云端同步成功后更新已确认 revision，不能仅根据 HTTP 200 认定完整成功。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0678 | 允许在阅读界面显示极简进度同步状态图标并可点击查看详情。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0679 | 通过断网 1 小时后连续离线写 50 条笔记的场景验证队列全部恢复。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |
| 0680 | 双设备交替阅读 20 次检验最新书内锚点能够可靠接续。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/auto_sync_service.dart |

## A18 元数据模型、冲突合并与防丢失

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0681 | 给每本书建立稳定 UUID 与内容指纹，避免仅以文件名合并。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0682 | 书架项目、分类、标签、书签、划线、笔记都有独立稳定 ID。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0683 | 所有同步记录具备 schemaVersion、revision、deviceId 与逻辑更新时间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0684 | 云端 manifest 用版本化结构记录对象与校验摘要。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0685 | 同步前确认本地数据库事务完成，读取一致性快照生成变更。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0686 | 增量同步使用变更日志而不是每次覆盖整库 JSON。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0687 | 同步第一次启用时明确选择当前设备或云端作为基准，不自动清空任一方。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0688 | 云端已有数据时先列出本地和云端数量差异供确认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0689 | 两台设备新增不同书籍时应合并为并集而非保留最后上传的一边。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0690 | 两台设备新增不同笔记时应保留两条，不按书籍整体覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0691 | 同条笔记双端编辑冲突时保留原版本和冲突副本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0692 | 同条书签移动冲突时显示双方锚点和修改设备供选择。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0693 | 同一主题双端编辑时按字段合并或提供冲突副本，不盲选时间较晚者。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0694 | 阅读进度冲突允许用户选本机、云端或最近一次有效位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0695 | 不以进度百分比更大就自动判定一定更新，支持用户主动回读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0696 | 用户明确标记重新阅读时防止另一设备自动把进度推进到结尾。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0697 | 增量删除使用墓碑和删除时间，不靠“清单里缺失”判断必须删除。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0698 | 删除墓碑只传播到经过授权的相同同步空间，不能误删其他账号数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0699 | 云端删除操作进入可恢复保留期，不允许首次同步就大批清空。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0700 | 首次发现大比例数据减少时暂停写回并提示异常差异。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0701 | 设备时钟不准确时依靠 revision、ETag 和冲突机制而不是绝对时间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0702 | 本地与远端版本不一致时进入显式合并流程，避免后写覆盖前写。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0703 | 网络失败后同一个提交可安全重放，不重复生成新记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0704 | 两台设备并发 PUT 同一个 manifest 时通过条件写阻止丢更新。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0705 | 处理 WebDAV 服务器不支持 ETag 的场景，采用只增版本清单及冲突审查。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0706 | 同步事务采用先上传对象、再确认 manifest 的提交顺序。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0707 | 下载 manifest 后验证所有必要对象存在且哈希正确再应用本地合并。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0708 | 半途上传的临时对象可后续回收，但不得误删仍被引用的版本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0709 | 合并到本地时使用数据库事务，一条失败不能造成半套标签状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0710 | 单书元数据与本地文件指纹冲突时保留书架条目并提示重新关联。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0711 | 本地笔记的文字锚点与书籍新版本不匹配时保留原摘录而不是删除。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0712 | 云同步规则变更时进行从旧同步清单到新 schema 的无损迁移。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0713 | 当旧版客户端与新版客户端同时同步时阻止旧版抹掉未知字段。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0714 | 数据库迁移要保证重复执行安全，不因断点恢复重复建表。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0715 | 同步过程保存可审计结果摘要，但不得在日志里写完整书摘正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0716 | 错误的云端时间戳不能导致旧书架信息覆盖较新本地信息。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0717 | 对同名但不同内容书籍显示可合并提示而非默认合并。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0718 | 对完全相同内容但不同文件名书籍保留单一身份或用户选择。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0719 | 制作双设备 1000 次随机增删改合并测试，断言记录不丢失且没有重复。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |
| 0720 | 对冲突恢复界面提供前后差异和撤销入口，而非只有“同步成功”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/sync_document.dart |

## A19 设备协同、同步内容选择与资源传输

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0721 | 支持在手机与平板或第二部安卓设备使用同一 WebDAV 目录同步。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0722 | 同步设置界面区分“元数据同步”与“图书文件同步”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0723 | 元数据至少包含书架、进度、书签、笔记、标签、分类、主题和统计。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0724 | 允许单独开关是否上传原始图书文件，默认清楚提示云空间占用。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0725 | 允许同步用户字体文件，但不能仅同步字体名称而没有资源。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0726 | 允许同步用户背景图片文件并在目标设备正确恢复。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0727 | 封面缩略图可选择同步或目标设备自行重建。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0728 | 只同步文件元数据时新设备书籍显示“缺少原文件”，可选择关联或下载。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0729 | 云端文件下载完成后核验哈希，失败时不覆盖原先可读副本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0730 | 文件与元数据分开排队，避免百兆文件阻塞进度上传。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0731 | 同一本书的重复上传通过内容哈希去重，减少流量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0732 | 文件重名但指纹不同的情况用稳定 ID 存储避免冲突。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0733 | 书籍下载前显示真实文件大小并可选择仅 Wi-Fi 下载。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0734 | 网盘空间不足时可以继续同步小型进度而暂停大文件上传。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0735 | 设备列表显示最近同步设备标识和时间，避免展示易泄露硬件序列号。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0736 | 允许为设备自定义名称，方便识别“手机”“平板”等。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0737 | 退出一个设备的同步关系不得删除其他设备共享数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0738 | 停用同步后本机书籍与笔记仍保持可用，不强制云授权才能读书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0739 | 更改 WebDAV 账号时明确提示两个同步空间独立。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0740 | 不允许新账号未经确认就继承旧账号的上传目标目录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0741 | 跨设备同步可以选择阅读页排版配置是否跟随云端。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0742 | 跨设备同步可以选择书架布局和排序偏好是否跟随云端。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0743 | 跨设备同步可以选择主题元数据共享，但当前激活主题按本机保持。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0744 | 跨设备同步可以选择触控手势配置是否只在当前设备生效。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0745 | 设备独有的屏幕亮度与按键映射永不强制覆盖其他设备。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0746 | 同步内容开关需要清楚展示“本机上传”“本机接收”的影响。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0747 | 关闭某类设置同步不能删除云端之前已经保存的配置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0748 | 切换字体或图片同步策略时展示待补齐文件数量和容量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0749 | 云端图书文件可按需下载而非第一次绑定就全量拉取。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0750 | 换设备首次同步允许先拉元数据后选书下载。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0751 | 换设备后书籍没有原文件时不应假装阅读进度可直接打开正文。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0752 | 支持对新设备本地现有图书做指纹匹配并连接云端书籍 ID。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0753 | 云端文件下载后自动恢复对应书签、笔记与阅读位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0754 | 网络缓慢时同步详情能准确显示传输字节与失败项。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0755 | 若后续有 Windows 版，使用同一开放的同步 schema 并做实测互通。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0756 | 若后续有 Linux/macOS 版，适配文件路径差异而不重写书籍 UUID。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0757 | 同步时允许取消单个大文件任务，不导致整批元数据回滚。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0758 | 对多网盘功能仅在真正实现独立元数据与文件目标后显示入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0759 | 对未实现的 iCloud、S3 等网盘只列未来规划，不提供可点击假同步按钮。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |
| 0760 | 新设备从零恢复要能在没有历史本地缓存的情况下重建完整书架元数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/metadata_sync_service.dart |

## A20 云备份、恢复、加密与容灾

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0761 | 将“实时多端同步”与“时间点备份”明确分开，页面术语不得混淆。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0762 | 提供可手动导出的本地完整元数据备份，覆盖书架、进度与笔记。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0763 | 备份包含 schemaVersion、创建时间、设备标识、记录计数和校验摘要。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0764 | 支持备份前预览包含的图书记录、笔记与设置范围。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0765 | 备份默认不包含云盘应用密码、私钥或系统安全存储内容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0766 | 可选将用户书籍文件一起打包，但预先显示真实容量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0767 | 大体积备份使用流式 ZIP 或兼容容器，不将全库放入内存。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0768 | 备份文件可加密，优先采用标准认证加密算法和安全随机数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0769 | 跨设备加密恢复采用用户掌握的密码派生密钥，不错误依赖原设备密钥。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0770 | 备份密码忘记时明确不可恢复风险，不设置假“万能解密”。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0771 | 加密文件每次使用独立随机 nonce，拒绝重复使用。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0772 | 解密失败要区分密码错误、文件损坏与版本不支持。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0773 | WebDAV 上保留多份元数据快照，默认至少提供最近几个可回滚版本。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0774 | 备份轮换只作用 Read 自己的备份前缀，不清理其他网盘文件。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0775 | 删除旧备份前核验至少有一份新备份已成功下载和解密验证。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0776 | 云同步前可选择生成本机安全快照，防止错误合并不可逆。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0777 | 恢复前显示将新增、合并和冲突的数据条数，不直接覆盖所有记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0778 | 默认采用非破坏合并恢复，覆盖恢复必须二次确认并先保存回滚点。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0779 | 恢复过程使用事务与临时目录，失败时保留恢复前可用数据库。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0780 | 恢复结束后校验笔记、书签、主题与进度计数和引用完整性。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0781 | 从旧 Read 版本备份导入时执行 schema 迁移并记录转换结果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0782 | 导入未知未来版本备份时拒绝破坏性写入并提示版本不兼容。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0783 | 允许从备份只恢复某一本书的笔记或进度，避免全库重灌。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0784 | 可以查看本地和云端备份的时间、大小、类型与可验证状态。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0785 | 云端备份上传后下载回读随机样本或完整校验确认可靠。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0786 | 断网时本地备份仍能运行，不强制联网才能导出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0787 | 本地空间不足时拒绝开始超大备份并展示所需空间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0788 | 备份期间允许读书，但重要写入需事务一致性保证。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0789 | 用户切换云盘目录前提供旧目录备份状态和新目录选择。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0790 | 删除全部同步数据必须有范围预览和再次输入确认机制。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0791 | 发现云端对象大量消失时冻结远端删除传播并引导从快照恢复。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0792 | 备份恢复不能将旧设备的绝对文件路径直接写到新设备造成失效。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0793 | 恢复字体和背景资源前先验证文件指纹与大小限制。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0794 | 备份记录中可选清除书名隐私信息的诊断导出模式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0795 | 云端加密选项页面需要说明哪些数据仍可能暴露长度和同步时间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0796 | 兼容升级用户已有的手动同步格式，不允许简单删除旧云数据。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0797 | 准备同步状态模拟损坏、内容被篡改、错误密码、磁盘写满的回归用例。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0798 | 通过两设备“备份—清除测试设备—恢复—接续阅读”完整验收。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0799 | 失败操作必须提供安全重试或恢复路径，避免提示用户卸载重装。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |
| 0800 | 任何自动删除或覆盖操作都要先证明备份可恢复，不得以凑完工牺牲资料。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/sync/backup_service.dart |

## A21 书架、统计、我的三栏 UI 美化

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0801 | 首页维持“书架 / 统计 / 我的”三栏信息结构，避免凭空新增杂乱导航。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0802 | 全局界面延续黑白灰极简风格，严格控制点缀颜色数量。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0803 | 头像使用与整体匹配的黑白风格，不添加花哨渐变和立体装饰。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0804 | 设置统一字体体系，页面标题、卡片标题、正文与说明有稳定层级。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0805 | 统一圆角、边框粗细、间距和图标线宽，避免每个页面各画各的。 | PARTIAL | f97c1d6 · ReadIcons 双套语义图标；编辑页/阅读器尚未全部迁移 |
| 0806 | 页面顶部标题缩短无意义说明，给图书内容和操作留空间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0807 | 书架提供三列封面布局，并按手机宽度保持合理间距。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0808 | 两列和三列封面切换时保持书籍稳定排序和滚动位置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0809 | 书封下标题最多两行且适当省略，不挤压整个网格高度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0810 | 书封底部阅读进度使用细线或微小数字，避免大面积彩色进度条。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0811 | 书籍封面阴影柔和克制，深色模式下不出现脏灰边缘。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0812 | 没有封面的书使用排版精美的文字占位，不用默认彩虹背景。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0813 | 书架顶部突出最近阅读入口，但不要覆盖普通书籍筛选操作。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0814 | “继续阅读”卡片展示书名、已读百分比和上次阅读时间。 | PARTIAL | f97c1d6 · 0.6.2 任务书要求删除该卡片与中转页，已删除；旧需求与现行方向冲突，不复原 |
| 0815 | 添加书籍入口设计清晰、容易点按，隐藏无用的书源相关图标。 | PARTIAL | f97c1d6 · 完整书架/单书菜单与空态导入入口；真机触控未验收 |
| 0816 | 批量管理模式以多选和底部操作条呈现，不能挤进每张封面。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0817 | 书架搜索使用简洁展开式输入框，返回后恢复原书架布局。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0818 | 书架筛选和排序控制一行内简洁呈现，状态改变能一眼识别。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0819 | 书架空状态使用原创极简插画或简短文字，不滥用大图占位。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0820 | 统计首页优先显示本周时长、最近阅读、连续阅读和趋势。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0821 | 统计图表使用少量中性色阶，不能靠十几种艳色区分信息。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0822 | 统计图表必须有数据含义标签，不能只画漂亮的虚假曲线。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0823 | 统计日历热力图兼顾小屏可读性与触控选日。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0824 | “我的”页面只展示有用的同步、主题、备份、存储与关于入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0825 | 个人页顶端头像和用户名留白适度，不搞占据半屏的大横幅。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0826 | 云同步状态在“我的”页突出但不成为整个首页的警告条。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0827 | 设置行保持一眼可扫清楚的标题、说明和右侧状态布局。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0828 | 禁止使用大量重复图标解释同类设置，避免视觉噪音。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0829 | 对不可用功能明确写条件或隐藏，不放会直接失败的空按钮。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0830 | 首页深色主题使用真正分层灰度，避免所有卡片混成黑块。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0831 | 统一页面切换导航条选中态，不能使用毫无逻辑的动画高亮。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0832 | 书架卡片长按菜单样式与系统交互一致且支持无障碍。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0833 | 每张封面优先显示书籍真实封面，不做影响识别的视觉二次加工。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0834 | 小屏幕上保证三栏底部导航按钮不被系统手势条遮挡。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0835 | 平板及横屏下采用响应式网格和适当信息密度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0836 | 导入图书后的新书突出方式应克制且可关闭。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0837 | 所有页面支持滑动位置恢复，切 Tab 不从头加载整页。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0838 | 原型稿与实际运行截图必须逐屏对比字号、边距和控件高度。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0839 | 默认界面必须真正可用，不需通过打开大量隐藏设置才能开始读书。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |
| 0840 | 所有 UI 美化都以已实现交互为前提，不把展示图当成交付成果。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/bookshelf |

## A22 阅读统计、设置体系和无障碍体验

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0841 | 阅读统计以真实前台阅读活动计时，后台静止不继续累加。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0842 | 阅读时长剔除长时间无操作且已熄屏的空闲区间。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0843 | 同一时间多个阅读窗口只计算一次有效阅读时长。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0844 | 可按日、周、月、年查看阅读时长与阅读书籍数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0845 | 支持阅读字数统计并标注对 PDF/图片格式的估算限制。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0846 | 连续阅读天数根据用户选择的时区和跨午夜规则计算。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0847 | 每日阅读目标可设置、编辑和关闭，不强制开启打卡。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0848 | 阅读目标完成状态不得通过过期统计缓存假装即时更新。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0849 | 统计支持按书籍查看累计阅读时间与完成情况。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0850 | 阅读热力图月份切换保持日期可读和无障碍描述。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0851 | 阅读统计在跨设备同步时避免重复累加同一阅读会话。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0852 | 设备时钟偏移和重复上报会话应去重并可重算统计。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0853 | 统计删除或重新计算前保留来源数据，不直接清空记录。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0854 | 提供统计数据本机导出供用户核对，不必须依赖云端分析。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0855 | 阅读目标提醒默认关闭，并尊重 Android 通知权限。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0856 | 全局设置提供搜索功能，搜索结果直接跳转真实设置项。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0857 | 设置分组优先阅读、外观、书架、同步、数据与关于，不堆重复入口。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0858 | 每个设置项明确标明全局、单书、单设备或可云同步范围。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0859 | 核心设置具有默认值说明，用户能一键恢复指定组默认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0860 | 设置保存应通过事务或统一状态模型，避免快速操作互相覆盖。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0861 | 危险重置、数据清除与同步删除功能必须明确说明影响范围。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0862 | 手机屏幕阅读器能正确朗读书籍标题、按钮名称与页码。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0863 | 尊重系统字体缩放、对比度与减少动画偏好。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0864 | 大字号模式下设置按钮不裁切，必要时自动换行。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0865 | 图标点击区至少满足平台可访问性建议，不因视觉紧凑牺牲触控。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0866 | 深色、浅色以及阅读主题与系统界面主题分别可选。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0867 | 简体中文文案统一，避免中文设置中大量英文开发术语。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0868 | 日期、时间、文件大小与阅读时长使用明确单位和本地格式。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0869 | 支持横屏与折叠屏布局变化，设置页不出现左右溢出。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0870 | 对不支持的设备能力解释原因，禁止让按钮点了毫无反应。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0871 | 电子墨水屏模式提供减动画、高对比和刷新友好设置。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0872 | 阅读器默认不申请与本地阅读无关的位置、联系人等权限。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0873 | 误触清空筛选、删除图书等操作提供撤销入口或确认。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0874 | 使用时长、字体大小等数值设置允许通过键盘输入具体数字。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0875 | 备份与同步入口提供明显区别，减少用户误以为两者等价。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0876 | 跨设备设置同步选项要解释哪些设置只在本机生效。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0877 | 在统计页面没有记录时不生成假的连续阅读天数。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0878 | 设置页点击后页面返回层级合理，不绕三四层才回到书架。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0879 | 为主要功能提供首次提示和帮助入口，但可关闭不打断正常阅读。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |
| 0880 | 所有设置变更均需在关闭重开 App 后验证仍按用户意图生效。 | PARTIAL | 存在模块级代码，未逐项验收：lib/src/services/reading_stats_store.dart |

## A23 流畅度、内存、启动与动画工程

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0881 | 建立 Debug/Profile 模式性能基线，分别记录冷启动与热启动耗时。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0882 | 在 Flutter DevTools 中记录 UI 线程和 Raster 线程帧耗时。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0883 | 在目标 60Hz 手机上按帧预算评估掉帧，120Hz 设备另测更严格预算。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0884 | 不把设置高刷新率请求等同于实际稳定 120fps。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0885 | 阅读页首屏先展示可读正文，再异步加载目录、总页数等辅助数据。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0886 | 超大 TXT 解析放到 isolate 或后台任务，禁止阻塞 UI 线程。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0887 | EPUB HTML/CSS 解析建立可取消后台任务，避免离开书后仍占 CPU。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0888 | PDF 图像解码按视口和缩放倍率进行，减少峰值内存占用。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0889 | 书架只对可见范围和附近封面解码缩略图，避免全部解码原图。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0890 | 用 RepaintBoundary 或等效优化隔离进度动画与整页文字重绘。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0891 | 提供可量化的 Widget rebuild 统计，找出翻页时不必要的重建。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0892 | 阅读页滚动列表采用按需创建与回收，不构造万段文本常驻 Widget 树。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0893 | 新增章节缓存 LRU 策略，并按设备内存级别调整容量。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0894 | 页面切换过程中禁止重复初始化数据库和云同步服务。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0895 | 字体实时调整采用防抖合并排版重算，不每拖动一个像素就整书重排。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0896 | 正文 Markdown/HTML 复杂节点缓存只针对内容版本有效，不保留陈旧引用。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0897 | 大图片加载采用低分辨率预览再渐进替换，避免瞬时白屏。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0898 | 阅读页进入与退出动画时长保持短而一致，允许完全关闭。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0899 | 翻页动画必须可打断，快速反向操作不排队堆积。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0900 | 底部菜单和目录抽屉动画保持连续，不让页面布局反复跳动。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0901 | Tab 切换保留已有页面状态，避免重复执行大型查询。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0902 | 页面 Hero 动画仅在封面和阅读器能稳定对应时启用。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0903 | 减少动画模式下禁用翻折、缩放和多层模糊等高成本效果。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0904 | 避免多个透明/模糊背景叠加造成长时间 GPU 压力。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0905 | 阅读时后台同步使用低优先级 I/O，不阻塞数据库进度提交。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0906 | 输入书内搜索时使用防抖与可取消查询，避免键入卡顿。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0907 | 目录 10000 项滚动只构建可见行，保持快速定位。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0908 | 统计页重计算使用缓存和增量聚合，不在首帧执行全历史扫描。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0909 | 内存紧张时优先清理可重建页面缓存，不丢原书和用户笔记。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0910 | 图片查看器关闭后释放大位图引用，持续翻阅不累积内存。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0911 | 检查 StreamSubscription、Timer、Controller 生命周期，不离开页面后持续监听。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0912 | 避免书籍切换时并发旧请求更新新书 UI，引入请求代际编号。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0913 | 使用动画曲线与持续时间的一致设计 token，避免不同页面动作割裂。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0914 | 添加流畅滚动下的边界回弹处理，尊重 Android 系统触感。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0915 | 低端机或省电模式自动关闭高开销视觉效果，不降低文本可读性。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0916 | 使用大书、复杂 EPUB 和千页 PDF 分别记录最高内存与首次可读时间。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0917 | 冷启动不得因为 WebDAV 配置错误而长时间停留启动画面。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0918 | 网络同步失败时只更新同步状态，不重绘整个书架网格。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0919 | 每个性能提交必须提供修改前后同设备、同样本的指标或轨迹。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |
| 0920 | 至少完成连续阅读半小时、百次翻页及多次后台恢复的稳定性测试。 | NOT_STARTED | 无性能基线/真机指标，未逐项处理 |

## A24 自动化测试、兼容性和发布质量

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0921 | 为所有 1000 个编号建立进度台账，可追踪完成、部分、阻塞与未开始。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0922 | 每条已完成项填写具体源码提交、测试或运行录像证据。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0923 | 以可公开分发的 TXT、EPUB、PDF 样本建立稳定测试库。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0924 | 为每种阅读格式增加导入、打开、翻页、退出、重进的自动化测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0925 | 为 TXT 编码探测提供不同编码与混合换行测试用例。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0926 | 为 EPUB 导航、复杂 CSS、图片与损坏包添加回归测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0927 | 为 PDF 缩放、裁边、跳页和选择文本添加集成测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0928 | 为阅读进度提供字号改变、旋转和强退恢复测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0929 | 为书签、笔记提供离线增删改与跨版本迁移测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0930 | 为 WebDAV 增加成功、401、404、409、412、429、507 的模拟服务器测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0931 | 真实 WebDAV 实测需用户本人通过安全方式配置账号，不能提交密码。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0932 | 两设备模拟器测试：A 写入进度，B 拉取后续读，A 再恢复并合并。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0933 | 双设备断网并行编辑相同笔记后恢复，验证冲突副本与无损合并。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0934 | 双设备删除墓碑传播必须验证撤销/回滚，不能误删其他资料。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0935 | 备份导出后用隔离测试环境进行解密恢复与计数一致性验证。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0936 | SQLite 或 Isar/Hive 等现有本地数据库每次 schema 升级必须做兼容测试。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0937 | Android 版本差异至少覆盖项目支持的最低版本与最新可用模拟器版本。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0938 | 开启系统深色模式、大字体、手势导航与横屏分别做 UI 截图回归。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0939 | 阅读页主题、字号、间距的黄金截图覆盖重点组合而非每次人工猜测。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0940 | GitHub Actions 增加 Flutter analyze、format check、test 与 Android debug 构建。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0941 | 有条件时加入 Android 模拟器集成测试与自动截图工件上传。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0942 | 构建产物记录 commit SHA、版本号、包名、签名摘要和 APK SHA-256。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0943 | 若有既有签名策略，不得用随机新证书破坏覆盖升级能力。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0944 | 云同步功能切换为真正可用前通过端到端数据传输测试，而非只靠单测。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0945 | 对每次新增权限执行 Android Manifest 审查，禁止为本地阅读申请无关敏感权限。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0946 | 依赖漏洞审查聚焦真实可利用问题，不盲目升级破坏 Flutter 构建。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0947 | 对运行时崩溃生成不包含书籍正文与云盘密码的本地诊断。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0948 | 每个崩溃修复新增对应回归测试，避免反复出现。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0949 | 书籍样本版权状态要可确认，不把收费电子书放进公开仓库。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0950 | 对跨平台支持只展示已真实构建的平台，不能用 Flutter 理论支持冒充已上线。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0951 | UI 对照参考仅用于功能体验，不复制 Reeden 私有代码、付费资源和图标。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0952 | 重构操作保留已有 PR 改动并执行冲突审查，禁止直接强推覆盖他人提交。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0953 | 每批提交包含清楚的功能范围、影响面和回滚说明。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0954 | 编译失败必须标记失败并修复或回退，不准上传无法安装 APK 冒充完成。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0955 | 构建后 APK 在模拟器实际安装启动并核验主页面与阅读页可打开。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0956 | 升级测试应覆盖旧数据仍存在、书架不重复、书签不丢、同步配置可迁移。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0957 | 实际手机验收不能被模拟器截图替代，明确机型、刷新率和系统版本。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0958 | 对无法访问的私人账号、真机或服务器仅记录阻塞，不编造测试结果。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0959 | 发布前生成可机器校验的已实现要求、未完成要求及测试矩阵。 | PARTIAL | 存在模块级代码，未逐项验收：test |
| 0960 | Release 必须附带 APK、校验和、变更说明及明确的 Preview/正式标识。 | PARTIAL | 存在模块级代码，未逐项验收：test |

## A00 未分类

| # | 原始需求 | 状态 | 证据/说明 |
|---|---|---|---|
| 0961 | 从第 001 条连续处理到第 1000 条，不在完成某一模块后停下索取“继续”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0962 | 对每条要求先查现有实现，再决定修复、增量增强、验证或阻塞。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0963 | 已实现且已验证的要求无需重复改代码，但需记录具体证据。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0964 | 可实现的项目必须实际提交源码，禁止只写 TODO、注释或设计稿。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0965 | 遇到当前权限、账号、平台或工具客观限制时记录阻塞原因并转下一条。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0966 | 遇到复杂需求不得因工作量大就直接判为阻塞，需先做可交付的独立子项。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0967 | 若两个任务互相依赖，记录依赖并优先补基础能力后回到原任务。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0968 | 不允许把功能模块静态显示、Mock 成功或离线单测当成真实云同步验收。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0969 | 每 40 条做一次代码与测试核验，失败项修复或隔离后继续下一批。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0970 | 每 200 条回查重复实现、架构偏差、用户数据保护和任务台账遗漏。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0971 | 保留已有阅读历史、数据库、书籍文件、用户主题与 WebDAV 配置。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0972 | 未经具体授权不得接触用户真实网盘、删除云端资源或上传私人图书。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0973 | 不引入在线书源、抓取引擎、小说网站搜索或书源管理模块。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0974 | 不为了模仿 Reeden 而复制它的私有源码、资产、私有同步格式。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0975 | 重点验收“调整字号后同一句仍在附近”，而不是仅有字号滑杆。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0976 | 重点验收“上次读到哪里重启仍记得”，而不是仅显示百分比。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0977 | 重点验收“手机 A 翻页后手机 B 接续”，而不是仅上传一个 JSON。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0978 | 重点验收“手机 A 修改笔记、B 断网修改、恢复后两边内容都可找回”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0979 | 重点验收“删除书籍与资料不误传到其他同步账号或无关目录”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0980 | 重点验收“新设备可恢复书架、笔记、主题及可选图书文件”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0981 | 重点验收“只同步元数据时没有原文件也能清楚提示并补关联”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0982 | 重点验收“离线一整天继续读书，恢复网络后队列不丢操作”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0983 | 重点验收“TXT、EPUB、PDF 对应进度锚点跨设备准确恢复”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0984 | 重点验收“千章目录、千本书架、千条书签”滚动稳定。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0985 | 重点验收“图片多、CSS 复杂的 EPUB”不白屏、不乱码、不无限加载。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0986 | 重点验收“翻页动画可中断且不会漏页、错页、重页”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0987 | 重点验收“阅读时弹出设置菜单不导致正文整页跳动”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0988 | 重点验收“云同步出错只影响同步，不阻止正常本地阅读”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0989 | 重点验收“云端损坏或错误数据可从快照恢复，不自动覆盖好数据”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0990 | 重点验收“高刷手机真实帧率稳定”，不能仅凭截图或代码注释确认。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0991 | 重点验收“旧版覆盖升级后阅读记录和自定义主题保持完整”。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0992 | 最终任务台账中每条只能标 已验证、已实现待实测、部分、阻塞或未处理。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0993 | 最终报告单独列出需要用户操作的授权和真机测试，不要求用户贴密钥。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0994 | 所有分支合并前检查当前 HEAD 是否前移，不强制覆盖并行开发代码。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0995 | 已合并到主开发分支的功能要包含在最终 APK，不只存在单独 PR 里。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0996 | 对没有真实代码证据的功能宁可标未完成，也不得凭聊天描述猜测完成。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0997 | 若出现阻塞但不影响其他要求，立即跳过并继续后续未处理任务。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0998 | 只有全部 1000 条得到真实状态记录后，才能给出“逐项处理完毕”的总结。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 0999 | “全部处理完毕”不等于“1000 条全部实现”；最终必须分别统计完成和阻塞数量。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |
| 1000 | 最终交付可安装 APK、源码提交、双设备同步测试报告、截图和完整未解决清单。 | PARTIAL | 存在模块级代码，未逐项验收：docs/V1_100_STATUS.md |