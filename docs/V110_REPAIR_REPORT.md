# Read 1.1.0 整改执行报告

> 本报告对应「Read 阅读器全面整改执行指令」。只记录**真实发生的代码改动与可验证结果**，
> 不写未验证的结论。基线为 `main@6b8e686`（含 PR #42/#43 与工具栏透字修复）。

## 一、基线核实

| 项目 | 实际状态 |
|---|---|
| `main` 最新提交 | `6b8e6868f87fa011688db272f5c1967f9ef4130f`（工具栏透字修复，未覆盖） |
| PR #42 | 已合并（`8b97685`，S3 分页列表 + SigV4 自定义端口） |
| PR #43 | 已合并（`3908f0c`、`6b8e686`，紧凑工具栏） |
| PR #41 | **仍开放**，base 停留在 `c1f1b10`。未直接合并过期分支，而是把其中有效修复**手工移植**到当前 main 并重跑测试。 |

## 二、P0 故障：定位与修复

### 1. 章节名错乱、标题重复、邻章预览错位（根因级）

**真实问题**：`lib/src/services/chapter_splitter.dart` 的章节正则只要求行首是「第X章」，
其后任意文本都算标题。于是正文段落 `第一章正文。`、`第二章正文。` 被各自切成独立章节。
四行文本被拆成 4 章，章节名为「第一章正文。」「第二章正文。」。

这同时解释了用户看到的三类症状：
- 章节名称错误（标题变成正文句子）
- 章节标题重复（正文句子被当作标题再画一次）
- 前后章节预览错乱（"下一章"其实是当前章的第二段）

**修复**：新增两条硬判据——标题行不得以句末标点结尾（`。！？…，、；：` 等），
长度上限由 100 字收紧到 60 字。

**验证**：`test/reader_engine_test.dart` 与 `test/reader_page_smoke_test.dart` 中
`第一章 起点/第一章正文。/第二章 远行/第二章正文。` 现正确解析为 2 章。

### 2. 已保存的高亮从不渲染

**真实问题**：`_highlightedSpan` 用两个平行数组 `starts` / `ends`，但填充时把
`localStart` 与 `localEnd` 同时写进了 `starts`、又同时写进 `ends`，索引完全错位，
任意高亮都变成零长度区间，背景色永远不生效。用户看到的是"能保存、看不到"。

**修复**：改为按 `(start, end, color)` 三元组绘制，边界点用 Set 去重排序。

**验证**：新增测试 `保存的正文高亮在阅读页真正显示背景颜色`，直接断言
对应文字片段的 `TextStyle.backgroundColor != null`。

### 3. 跨章滑动后回弹到上一章 / 显示上一章标题

**真实问题**：
- `PageController` 未禁用 `keepPage`，`PageStorage` 可能把旧的虚拟页恢复回来，覆盖 `initialPage`；
- 控制器替换与章节切换不在同一 state 事务内，PageView 会先用新章节 + 旧索引重建一帧；
- 邻章预览绘制时用当前章的 `chapterIndex`/`pagination.titleHeight`，标题与高亮映射全部错位；
- 双栏判定用上一轮缓存的列宽，翻转/改字号后判断错误；
- 点击分区按单列宽度计算，双栏时右半屏不响应。

**修复**：`keepPage: false`；控制器与章节同事务替换；`_chapterTick` 使 PageView 子树失效；
postFrame 校正目标页（带 epoch 校验）；邻章标题/高度/高亮改用被绘制章节的索引；
双栏改用 `MediaQuery.sizeOf` 视口判断；点击分区按整页宽度；接入 `reverse` 翻页方向。

**验证**：`滑动跨章后显示下一章标题并且原章标题消失`、`章首向前翻页进入上一章末页`、
`快速连续点击翻页不产生控制器冲突` 全部通过。

### 4. 段落间距过大（8px 设置变成 28.8px 留白）

**真实问题**：`paragraphSpacingAfter` 默认 8px，引擎用
`max(1, (8 / (18 × 1.6)).round())` 换算，结果恒为 1 个整行空行 = 28.8px，
是用户设定值的 3.6 倍。设置面板却显示 "8 px"，属于"假精度"。
叠加 `preserveBlankLines` 保留的原文空行后，留白进一步放大。

**修复**：
- 引擎改为按「整行」换算，且去掉 `max(1, …)`，不足半行即为 0；
- 新增 `paragraphSpacingLines`（0/1/2 行），设置面板从两个 px 滑块改为三档段距；
- 默认段距 0 行，靠首行缩进 2 字区分段落（纸书式中文排版）；
- 默认忽略原文多余空行，避免与段距叠加。

**验证**：新增 `默认排版忽略原文空行，段间不产生额外留白`、
`段距按整行生效：0 行无空行，1 行插一行，2 行插两行`。

## 三、书架

**真实问题**：网格卡片只显示书名与进度，**完全不显示作者**；且书名直接取文件名，
`书名 作者：张三.txt` 会把作者拼进书名。

**修复**：
- 新增 `lib/src/services/book_name_parser.dart`，支持四种常见命名，
  并剔除 `[精校]` 一类版本噪声；作者名 > 20 字不拆分，避免把副标题当作者；
- 导入 TXT/EPUB 时书名、作者分别落库；
- 网格补作者行，格子高度按书名两行 + 作者一行 + 进度条真实行高预留。

**验证**：`test/book_name_parser_test.dart` 8 条用例全通过。

## 四、已核实无需改动的部分

| 需求 | 核实结论 |
|---|---|
| 阅读菜单不挤标题 | PR #43 已实现：返回 + 可点章节名 + 搜索 + 设置 + 更多（低频项带中文标签）；顶栏为不透明 `Container(color: background)` |
| 底栏分组 | 进度滑块与快捷操作已在两行；滑块 `onChanged` 写 `_scrubPreview`，`_overallProgress` 读取预览值，拖动跟手 |
| 点击/长按分工 | 书单击直接进阅读、长按进多选，已实现 |
| 空书架引导 | 已有「书架还空着 / 从本机导入，或用 WiFi 传书」+ 导入按钮 |
| 自动同步 | 启动 `syncOnStart`、前台后台切换、断网恢复、进度防抖、20 秒重试队列均已实现 |
| 分页高度 | `_scheduleLayout` 已扣除页眉页脚高度，`SafeArea` + 页边距生效 |

## 五、验证结果

| 项目 | 结果 |
|---|---|
| `flutter analyze` | **0 error / 0 warning** |
| `flutter test` | **149 / 149 通过** |
| 新增回归测试 | 分章、段距×2、高亮渲染、跨章标题、文件名解析×8 |

## 六、未完成与真实限制

| 项目 | 状态 | 原因 |
|---|---|---|
| 真机帧率 / 冷启动 / 100 次翻页 | 未验证 | 沙箱无 Android SDK 与真机，`flutter test` 不能替代真机性能采集 |
| 实际运行截图 / 录屏 | 未提供 | 同上，无法运行 Android 应用 |
| 各网盘真实读写、双设备同步 | 未验证 | 无真实网盘开发者账号；任务书禁止网页模拟登录与逆向接口 |
| EPUB 图片 / CSS / 脚注 | 未实现 | 当前是文字模式解析，需引入富文本 span 模型，会牵动锚点映射 |
| 超大 TXT 磁盘懒加载 | 未实现 | 需重构 `Book.content` 全内存模型 |
| 滚动模式的真机手感 | 未验证 | 需真机触摸采样 |

## 七、改动文件清单

```
lib/src/services/chapter_splitter.dart        分章判据（P0）
lib/src/services/book_name_parser.dart        新增：文件名 → 书名/作者
lib/src/services/library_store.dart           导入时书名作者分别落库
lib/src/reader/reader_page.dart               高亮渲染、跨章切换、邻章索引、点击分区、reverse
lib/src/reader/engine/reader_engine.dart      段距按整行换算
lib/src/reader/settings/reader_settings.dart  段距行档位、默认排版
lib/src/reader/widgets/reader_settings_sheet.dart  段距三档控件
lib/src/version.dart / pubspec.yaml           1.1.0
test/reader_engine_test.dart                  段距与默认排版回归
test/reader_page_smoke_test.dart              跨章标题、高亮渲染回归
test/book_name_parser_test.dart               文件名解析用例
```
