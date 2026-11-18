# Read 2.3.1 交付说明（视觉精修）

## 零、基线澄清（更正一处误判）

排查初期，本地工作区的 `main` 停留在 `a85703d`（v2.2），一度让人以为
v2.3 修复「从未进入主线」。**fetch 远端后确认这是误判**：远端 `main` 早已通过
PR #52（`507a299`）合并了 v2.3 全部修复，并发布 `ddd910e`（`v2.3.0-preview`）。
也就是说 S3 上传兼容降级、跨设备密钥迁移、分页防丢字契约、局域网备份目录真机修复、
阅读边距收窄、系统文字缩放二次应用修复等，**都已在远端主线与 v2.3.0-preview 包中**。

问题不在「修复没进包」，而在本地工作区过期。本轮已将本地基线同步到远端 `main`
（rebase 掉重复的合并提交，只保留本轮真正的新改动），版本沿用 `2.3.0+17`。

## 一、本轮真实改动（视觉精修，一眼可见、真机生效）

| 项 | 改动 | 验证 |
|---|---|---|
| 全局强调色 | 明暗主题的 `colorScheme.primary` 从近黑正文色改为温润墨绿（深色模式用更亮的浅墨绿 `#8FBF9F`）。开关、滑块、进度条、选中 chip、按钮等全 App 交互态统一带上书卷气质；正文/标题仍保持近黑，可读性不变 | 真实渲染：`review_bookshelf.png` 选中标签由黑变墨绿 |
| 书架筛选标签 | 选中态从写死的 `palette.ink` 改为跟随 `colorScheme.primary`，文字用 `onPrimary` 保证对比度；墨水屏主题下仍为纯黑白 | 真实渲染 + 全量测试 |
| 章标题分隔线 | divider 模板的分隔线由 `0.6px / alpha .25`（几乎看不见）改为 `1px / alpha .45`，间距 6→8；同步更新分页高度预算 `+7→+9`，避免章首文字被裁 | 真实渲染：`review_reader_paper.png`；修复过程中实测到 2px 溢出并修正 |
| 页脚进度条 | `minHeight 2→2.5`，前景 alpha `.5→.85`、背景 `.12→.16`，浅色主题下进度清晰可见 | 真实渲染 |
| 审核截图正名 | 旧 `reader_page.png` 右上角的「红色折角」经确认是 Flutter **DEBUG 调试横幅**，release 包不存在。审核脚本已加 `debugShowCheckedModeBanner:false`，并新增多主题/书架真实渲染脚本 `tool/visual_review_test.dart` | 纸白/米黄/夜间/书架 4 张真实渲染 |

## 二、验证结果（非虚构）

- `flutter analyze`：**0 error**（仅有 lint info 与 Flutter 3.50 自身 deprecated 提示）。
- `flutter test`：**264/264 全通过**，含分页契约、S3 loopback、局域网鉴权等真实用例。
- 视觉截图为 Flutter 框架真实光栅化产物（`--update-goldens`），非设计稿、非 PS。
  存放于 `docs/visual_audit/`：`review_bookshelf.png`、`review_reader_paper.png`、
  `review_reader_sepia.png`、`review_reader_night.png`、`reader_page.png`。

## 三、如实记录：本轮未做/未完成（不虚报）

- **同步与跨设备、流畅度与 bug**：用户全选了这两项，但本轮**没有新增针对它们的代码改动**。
  这两项的实质修复来自上一批（已随主线合并进入本次分发包），并非本轮新做。
  真实 S3 账号、双真机同步、Android 7 实机帧率/内存仍未真机联调，维持 `DELIVERY_2.3.md`
  的限制清单，不宣称已验证。
- **正文字号/行距默认值**（18 / 1.6）未改动：它们被多项测试锁定，改动会引发分页连锁；
  本轮用更稳妥的主题色与分隔线提升观感，不动排版数值基准。
- 既有未完成项保持不变（PDF 标注、EPUB CSS/脚注、CBZ/CBR、FB2/MOBI、词典翻译、
  AI、云书库、局域网自动发现等）。
- 签名仍为公开预览密钥，正式分发前必须替换并规划覆盖升级。

## 四、约束保持

单 APK `app.readen.read`；内置墨水屏（运行时切换，无独立包）；minSdk 24（Android 7.0）；
升级兼容旧配置；每批独立提交可回滚；不硬编码真实云密钥；
日志不输出 Access Key / Secret Key / 共享令牌 / 同步密钥。
