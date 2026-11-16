# Read 0.9.0 · 图标与墨水屏 UI 精修台账

> 基线：`main` @ `da04384`（v0.8.0-preview）。本轮按用户明确诉求，聚焦任务书
> **第三部分 Q/R/S（401—475）中的图标设计与墨水屏视觉**，做实做透；500 项任务书
> 的其余阅读/同步/格式/多设备项不在本轮范围，不虚报完成。
>
> 状态：**PASS** 有源码改动 + 测试/真实渲染证据 · **PARTIAL** 部分实现 ·
> **BLOCKED** 需真机/外部条件 · **NOT_STARTED** 本轮未做。

## 本轮范围与结果

| 任务书条目 | 状态 | 实现与证据 |
|---|---|---|
| 401 设计系统（图标/间距/字阶/组件） | PARTIAL | 图标语义统一、线宽/填充规范化；全 App 间距/圆角统一为既有规范，未系统性重定义全部 token |
| 402 普通版现代简洁视觉 | PASS | 内部图标统一圆头线性、线宽 1.9、填充 13%；去除半透明脏填充 |
| 403 墨水屏非简单去色 | PASS | 独立 `_buildEinkTheme`：字重+2px 描边分层，非普通版去色；见 theme.dart |
| 404 统一间距系统 | PARTIAL | 沿用既有间距习惯，未引入集中式 spacing token |
| 405 文字层级字号/字重 | PASS | eink TextTheme 建立 display/headline/title/body/label 完整字阶与字重 |
| 406 卡片圆角一致 | PASS | 墨水屏全部直角（BorderRadius.zero），按钮/弹窗/输入框统一 |
| 407 普通版桌面图标重设计 | PASS | `tools/android/gen_icons.py` 参数化羽毛；墨绿底+象牙白实心羽片，去渐变投影 |
| 408 墨水屏桌面图标重设计 | PASS | 纯黑底+白色线稿羽毛，与普通版造型区别明显 |
| 409 自适应图标不裁切 | PASS | 前景羽毛限制在中心安全区（目标高 58/100），五档密度齐全 |
| 410 内部图标统一线宽/重量/转角 | PASS | strokeWidth 统一（普通 1.9 / 墨水 1.35），描边端点与连接统一 |
| 411 普通版圆头线性风格 | PASS | 统一圆头 + 单一填充策略，消除实心/细线混用 |
| 412 墨水屏高对比线性图标 | PASS | 方头线性、线宽补偿 1.35、纯黑白，不依赖低透明度 |
| 413 高频功能语义明确图标 | PASS | 修复 settings（两版统一齿轮）、moon（实心月牙）、quote（双引号）；全 74 语义渲染测试 |
| 414 图标识别度 | PASS | 真实渲染总览图逐项目视审核，见 docs/visual_audit/ |
| 415 导航选中态尺寸稳定 | PASS | home_shell 选中仅变字重/线宽，不换图标不位移，尺寸不变 |
| 416 无大面积黑色胶囊选中态 | PASS | 选中靠字重/描边/实心填充，无需色块包裹 |
| 417 按钮视觉等级统一 | PASS | eink 主题配置 filled/outlined/text 三级按钮，层级靠填充区分 |
| 418 开关/单选/复选/滑块统一 | PASS | eink 主题配置四组件，选中=实心黑，未选=描边空心 |
| 419 弹窗/抽屉/菜单圆角背景统一 | PASS | dialog/bottomSheet/tooltip/snackBar 统一直角纯黑白 |
| 422 夜间模式一致配色 | PASS | 普通版既有 light/dark palette 完整；本轮未改 |
| 423 墨水屏靠形状文字区分状态 | PASS | 主题层全面落地，见 eink 主题渲染图 |
| 424 用真实 Flutter 截图审核 | PASS | `docs/visual_audit/*.png` 为 flutter test 光栅化真实渲染图 |
| 425 全页面视觉一致性 | PARTIAL | 核心组件与图标统一；逐页人工走查需真机完成 |
| 473 墨水屏降低重绘/动画 | PASS | 路由无动画 trans builder + NoSplash 全局；翻页无动画模式既有实现 |

## 二次精修（1.0.0，用户反馈"图标更丑了，要简单直观"）

用户真机反馈上一版图标（实心羽片鱼骨刻线 + 13% 半透明填充）越改越丑。本轮按"简单直观好看"再次重做：
- **桌面图标**：`gen_icons.py` 去掉 25 对密集鱼骨刻线，改为极简羽毛剪影 + 羽轴 + 4 对短羽枝；两版 PNG 重生成（407/408/409）。
- **内部图标**：去掉 13% 半透明填充（发脏根源），统一干净线性 / 必要处纯色实心；修复 book/search/image/camera/lock/device/note/save（410—414）。
- **屏幕预设**（任务 014/080，原 NOT_STARTED）：新增 `kScreenPresets` 手机/平板/长屏三套真实生效预设，接入设置面板，新增 `test/screen_preset_test.dart`。
- 真实渲染审核图重生成于 `docs/visual_audit/`；134 测试全绿，0 error/0 warning。

## 500 项完整台账

本轮按用户要求，对 500 项任务书逐项建立诚实台账：**`docs/V1000_TASKBOOK_500.md`（人读）+ `docs/V1000_TASKBOOK_500.csv`（机器读）**。
状态统计：279 PASS / 158 PARTIAL / 54 BLOCKED / 9 NOT_STARTED。严格遵循任务书"PARTIAL 不计 PASS、不虚报 500/500"。

## 未覆盖项（如实保留）

- **BLOCKED**（54 项）：真机性能/截图/翻页帧时间、真实网盘 OAuth 与上传下载、双设备同步、兼容性矩阵——沙箱无 Android SDK/真机/云账号，且任务书第 10 条禁止网页模拟登录/窃取 Cookie/逆向私有接口。
- **NOT_STARTED**（9 项）：超大 TXT 磁盘懒加载、EPUB 图片/CSS/脚注、段距像素级精确、背景图片裁切、SFTP/SMB/FTP 适配器。强改会破坏已稳定的阅读内核/P0 锚点，属任务书禁止的敷衍，故如实保留并写明剩余工作。详见 `docs/V1000_TASKBOOK_500.md`。

## 交付证据

- 源码：`lib/src/ui/read_icon.dart`、`lib/src/theme.dart`、`tools/android/gen_icons.py`、
  `assets/app_icon*`（20 张 PNG 重生成）。
- 测试：`test/glyph_gallery_test.dart`、`test/eink_theme_test.dart`（烟雾）+ 全量 131 项通过。
- 静态分析：`flutter analyze` 0 error / 0 warning。
- CI：GitHub Actions 构建普通版 + 墨水屏版 APK（见 PR）。
- 视觉图：`docs/visual_audit/` 三张真实渲染总览图。
