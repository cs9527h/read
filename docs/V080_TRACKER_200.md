# Read 0.8.0 · 200 项需求执行台账

> 状态取值：**PASS** 已实现且有测试/构建证据 · **PARTIAL** 已有实现但缺真机/完整验证 · **BLOCKED** 需真机/真实云账号等外部条件 · **NOT_STARTED** 未开始。
> 本台账随开发持续更新，最终交付时以本文为准，禁止把「理论支持/部分实现/尚待联调」算作 PASS。

## A. 阅读核心故障（001—020）

| # | 状态 | 说明与证据 |
|---|---|---|
| 001 | PARTIAL | 已审计 reader_engine.dart / reader_page.dart；标题重复、cover 缩放、anchor 漂移已定位并修复，其余项见各条 |
| 002 | PASS | cover 翻页移除 Transform.scale，正文不再被压成竖条（reader_page.dart _buildPageArea） |
| 003 | PARTIAL | scale 已移除；边缘裁切是否残留需真机截图验证 |
| 004 | PASS | 标题去重：buildDisplay 跳过与原文首行一致的整行标题；reader_engine_test 覆盖 |
| 005 | PARTIAL | 有邻章预取 + 120ms 短锁 + 真实相邻章正文页；跨章白屏未真机验证 |
| 006 | PARTIAL | 分页高度与 Expanded 区域一致，理论不裁切；视觉裁切未真机验证 |
| 007 | PASS | _onStoreChanged 改存相对偏移，修字号跳页；reader_page_smoke_test 通过 |
| 008 | PARTIAL | 行距/边距重排走 signature 失效；段距仍按整行换算（见 064） |
| 009 | PARTIAL | charOffset/章节/页恢复逻辑存在，library_progress_recovery_test 覆盖；真机未验 |
| 010 | PARTIAL | 目录跳转按绝对偏移→章节→锚点；真机未验 |
| 011 | PARTIAL | _chapterTransition 短锁防连跳；连续点击组件测试未建 |
| 012 | PARTIAL | 快速滑动未建组件测试 |
| 013 | PARTIAL | 标题高度用 TextPainter 实测；极端字号溢出未验 |
| 014 | PASS | 分页缓存 key = 排版签名+章节，参数不变复用 |
| 015 | PARTIAL | 分页签名含宽高/字号/scale；横竖屏未真机验 |
| 016 | PARTIAL | 点击层用 translucent 避免拦截；选词/翻页冲突未验 |
| 017 | PARTIAL | 设置改动用 anchor 恢复；面板开合跳转未真机验 |
| 018 | PARTIAL | 退出/切后台 flushProgress；前台恢复未真机验 |
| 019 | PARTIAL | flutter analyze 0 error/0 warning；运行时 overflow 未真机验 |
| 020 | PARTIAL | 已加标题去重、分页完整性测试；覆盖不全 |

## B. 专业分页引擎（021—040）

| # | 状态 | 说明与证据 |
|---|---|---|
| 021 | PASS | 真实 TextPainter 测量二分分页，非固定字数 |
| 022 | PASS | DisplayChapter.map 显示串↔原文偏移双向映射 |
| 023 | PASS | 分页考虑字号/字重/字距/行高/宽高/标题高度 |
| 024 | PASS | 分页连续不重不漏；reader_engine_test「分页不遗漏不重复」 |
| 025 | PASS | 标题单独测量 titleBlockHeight，与正文区分页 |
| 026 | PASS | 原文首行即标题时正文跳过、锚点保留（本轮修复） |
| 027 | PARTIAL | 无章节 TXT 显示「全文」；是否过度需按实际观感调整 |
| 028 | NOT_STARTED | 超长章节分块/isolate 未做，目前同步测量 |
| 029 | PASS | 缓存键 = 签名+章节 |
| 030 | PASS | 仅排版参数变化失效缓存 |
| 031 | PASS | 邻章预取 _prefetchNeighbors |
| 032 | PARTIAL | 缓存上限 9 章，无按优先级淘汰 |
| 033 | PARTIAL | 无显式并发去重，靠 _scheduleLayout 的 key 判断 |
| 034 | PARTIAL | 退书 dispose 清 timer；取消进行中任务未显式处理 |
| 035 | PARTIAL | 过期结果覆盖未显式防，靠签名匹配 |
| 036 | PASS | 设置改动按 anchor 恢复（本轮修复） |
| 037 | PASS | buildDisplay 末尾去空白行 |
| 038 | PARTIAL | 长行/无段落/英文混排有基本处理，未专项测 |
| 039 | PASS | 代理对边界 _isHighSurrogate/_isLowSurrogate 处理 |
| 040 | PARTIAL | 不同字号/尺寸/章节长度完整性测试仅部分 |

## C. 翻页手势与章节切换（041—060）

| # | 状态 | 说明与证据 |
|---|---|---|
| 041 | PARTIAL | cover 默认平移；需真机确认流畅 |
| 042 | PASS | 移除 Transform.scale/translate 组合 |
| 043 | PASS | 动画期间正文宽度/排版不变（仅透明度） |
| 044 | PASS | 滑动方向自然，未加反向位移 |
| 045 | PASS | 左/中/右点击热区 _buildTapLayer |
| 046 | PASS | 热区在设置可调（tapLeft/Center/Right） |
| 047 | PARTIAL | 点击/拖动/长按/选择区分，未专项组件测试 |
| 048 | PARTIAL | 短锁防冲突，连续点击组件测试未建 |
| 049 | PARTIAL | 翻页中再滑动的状态一致性未测 |
| 050 | PARTIAL | 拖动跟手由 PageView 提供，未真机验 |
| 051 | PASS | 翻页完成 _markProgress 防抖落盘 |
| 052 | PARTIAL | 无动画 jumpToPage；无多余位移（scale 已移除） |
| 053 | PASS | scroll 模式独立 ScrollController + 进度映射 |
| 054 | PARTIAL | 分页↔滚动切换保留位置，未专项测 |
| 055 | PARTIAL | 滚动→分页定位，未专项测 |
| 056 | PASS | 章末向后自动进下一章 |
| 057 | PASS | 章首向前自动进上一章末页 |
| 058 | PARTIAL | 过渡页仅在预取未命中时兜底（有标题非空白）；严格无过渡页未达成 |
| 059 | PASS | 书末只提示一次 |
| 060 | PARTIAL | 慢/快滑动、连点、反向、边界、长按未系统测 |

## D. 正文排版专业化（061—080）

| # | 状态 | 说明与证据 |
|---|---|---|
| 061 | PARTIAL | 默认排版已优化，未真机走查 |
| 062 | PASS | 默认字号 18sp |
| 063 | PASS | 默认行高 1.6（本轮改） |
| 064 | NOT_STARTED | 段距仍按整行换算，未做真正段落间距 |
| 065 | PASS | 默认 em 缩进 2 全角空格 = 两个汉字宽（本轮改） |
| 066 | PASS | 无缩进/两字符/自定义 indentChars 支持 |
| 067 | PASS | 左/中/右/两端对齐选项齐全 |
| 068 | PARTIAL | 默认边距 20/20，未真机观感验 |
| 069 | PARTIAL | 上下边距 + 页眉页脚空间，未真机验 |
| 070 | PARTIAL | 标题与正文间距 chapterStartBlank，未真机验 |
| 071 | PASS | 标题略大稍粗，不夸张 |
| 072 | PARTIAL | 长标题 TextPainter 换行测量；视觉未验 |
| 073 | PARTIAL | 章内页风格一致（同一 display）；未截图验 |
| 074 | PARTIAL | preserveBlankLines/ignoreExtraBlankLines 控制 |
| 075 | PARTIAL | 空格/CRLF/BOM 基本处理，BOM 未专项测 |
| 076 | PARTIAL | 中文标点/英文/数字换行由 TextPainter；未专项测 |
| 077 | PARTIAL | 字体导入存在；成功/失败态未验 |
| 078 | PARTIAL | 滑块 180ms 防抖；实际卡顿未 profile |
| 079 | PARTIAL | 日/夜/墨对比度未逐一验 |
| 080 | NOT_STARTED | 手机/长屏/平板预设未建立 |

## E. 阅读操作与设置面板（081—100）

| # | 状态 | 说明与证据 |
|---|---|---|
| 081 | PASS | 非阅读时隐藏控件（minimalMode/沉浸） |
| 082 | PASS | 点中显示工具栏，再点收起 |
| 083 | PARTIAL | 顶栏已精简；是否仍堆图标未逐一核对 |
| 084 | PARTIAL | 朗读/同步/历史归「更多」；组织未审 |
| 085 | PARTIAL | 底栏含进度/目录/排版/主题 |
| 086 | PARTIAL | 窄屏挤压未真机验 |
| 087 | PARTIAL | 拖动预览 _scrubPreview；松手跳转是否落地未核 |
| 088 | PARTIAL | 跳转按整书字符位置（reader_page_smoke_test 有），未真机 |
| 089 | PARTIAL | 目录搜索/定位/跳转存在；未逐一验 |
| 090 | PARTIAL | 目录打开定位当前章；未验 |
| 091 | NOT_STARTED | 设置面板仍一次展示较多项，未重排 |
| 092 | PARTIAL | 常用项在前；是否简化未审 |
| 093 | PARTIAL | 高级设置收纳存在；未核 |
| 094 | PARTIAL | 字号加减+滑块存在；未验 |
| 095 | PARTIAL | 行距段距范围有 clamp；极端值未验 |
| 096 | PARTIAL | 主题色预览存在；未验 |
| 097 | PARTIAL | 实时更新 + 关闭保位；未真机 |
| 098 | PARTIAL | 恢复默认不清理数据；未验 |
| 099 | PARTIAL | 全局/本书分层存在；未验 |
| 100 | PARTIAL | 小屏/字体放大适配未验 |

## F. 整体 UI 与图标重新设计（101—120）

| # | 状态 | 说明与证据 |
|---|---|---|
| 101 | PARTIAL | 已有 ReadGlyph 体系 + 配色，统一规范未成文 |
| 102 | PARTIAL | 原版暖白配色 + 圆角图标；精修未完成 |
| 103 | PASS | 墨水屏独立视觉（细线/直角/低动画） |
| 104 | PASS | 图标统一走 ReadIcon |
| 105 | PARTIAL | 原版 1.7 圆角线；个别未接入（见 078 前） |
| 106 | PASS | 墨水屏无透明度表达 |
| 107 | PARTIAL | 原版桌面图标已重画；是否仍显廉价需目检 |
| 108 | PARTIAL | 墨水屏图标沿用旧设计，平衡度未精修 |
| 109 | NOT_STARTED | 自适应图标前景/背景/安全区未配 |
| 110 | PARTIAL | 20/24dp 辨识度未系统测 |
| 111 | PASS | 四底栏图标 ReadGlyph |
| 112 | PARTIAL | 选中态颜色字重，未目检 |
| 113 | PARTIAL | 标题字号统一未全面核对 |
| 114 | PARTIAL | 卡片间距未系统调 |
| 115 | PARTIAL | 大圆角/描边/嵌套未清理 |
| 116 | PARTIAL | 按钮规范未统一 |
| 117 | PARTIAL | 弹层统一 showReadSheet；细节未审 |
| 118 | PARTIAL | 分割线使用未审 |
| 119 | PARTIAL | 三主题视觉检查未逐一做 |
| 120 | BLOCKED | 需真机运行截图，沙箱无 Android SDK 无法渲染 |

## G. 书架与书籍操作（121—140）

| # | 状态 | 说明与证据 |
|---|---|---|
| 121 | PASS | 点封面直进阅读器 |
| 122 | PASS | 恢复上次位置，无中转页 |
| 123 | PASS | 详情降级为菜单「信息」 |
| 124 | PARTIAL | 网格按单元格宽高算比例；视觉未验 |
| 125 | PARTIAL | 书名 ellipsis 截断；未验 |
| 126 | PARTIAL | 视觉重点封面/书名；云朵等是否过多未审 |
| 127 | PASS | 本地/云端三态区分 |
| 128 | PASS | 仅经 CloudPresence 验证才显示云标 |
| 129 | PASS | cloudOnly 显示可下载态 |
| 130 | PARTIAL | 下载失败错误信息与重试入口未核 |
| 131 | PARTIAL | 排序稳定不闪烁未验 |
| 132 | PARTIAL | 网格/列表质量一致性未验 |
| 133 | PASS | 长按多选 |
| 134 | PARTIAL | 高频/低频归类未逐一审 |
| 135 | PARTIAL | 编辑页字段分组未重排 |
| 136 | PARTIAL | 编辑保存即时更新（有测试），未真机 |
| 137 | PASS | AI 封面标注未接入 |
| 138 | PARTIAL | 删除区分本地文件/记录/云端未逐一核 |
| 139 | PARTIAL | 删除不误清书签笔记，未专项测 |
| 140 | PARTIAL | 大量书籍滚动性能未 profile |

## H. 多端同步与备份体验（141—160）

| # | 状态 | 说明与证据 |
|---|---|---|
| 141 | PARTIAL | 同步页连接状态/时间展示未核 |
| 142 | PASS | WebDAV 主要同步入口 |
| 143 | PARTIAL | 坚果云配置说明未核 |
| 144 | PARTIAL | S3 高级配置区域未核 |
| 145 | PASS | 密钥不写入导出文件，密码不明文 |
| 146 | PARTIAL | 连接测试结果分类未核 |
| 147 | PARTIAL | 手动同步阶段/结果展示未核 |
| 148 | PARTIAL | 同步页查看状态未核 |
| 149 | PASS | 条件写/墓碑合并不覆盖（sync_service_test） |
| 150 | PARTIAL | 进度冲突选择界面存在；未真机 |
| 151 | PARTIAL | 云端对比分组已有；未真机 |
| 152 | PARTIAL | 恢复说明文案未核 |
| 153 | PASS | 凭据安全存储 |
| 154 | PARTIAL | 完整性校验未核 |
| 155 | PARTIAL | 离线队列存在；未真机 |
| 156 | PARTIAL | 网络恢复重试未真机 |
| 157 | PASS | 哈希去重上传 |
| 158 | PARTIAL | 大文件重试；断点续传未支持（已声明限制） |
| 159 | BLOCKED | 需双 Android 真机 + 云账号 |
| 160 | PASS | 不声称兼容 Reeden 私有协议 |

## I. 性能、稳定性与无障碍（161—180）

| # | 状态 | 说明与证据 |
|---|---|---|
| 161 | BLOCKED | 需真机 profile |
| 162 | BLOCKED | 需真机 profile |
| 163 | PASS | 翻页不 setState，页眉页脚 ValueNotifier |
| 164 | PASS | 进度变化只刷页眉页脚 |
| 165 | PARTIAL | 缓存上限 9，无按量淘汰 |
| 166 | PARTIAL | dispose 清 timer/controller；未逐一核 |
| 167 | PASS | 翻页不重解析文件 |
| 168 | PARTIAL | 主线程同步分页；超长章节未迁移 |
| 169 | NOT_STARTED | 超大 TXT 懒加载未做 |
| 170 | NOT_STARTED | EPUB 图片/CSS 未做 |
| 171 | PASS | PDF 独立 pdfrx，不套 TXT 分页 |
| 172 | PARTIAL | 异常记录脱敏未核 |
| 173 | PARTIAL | 恢复路径未核 |
| 174 | BLOCKED | 需真机基准 |
| 175 | PARTIAL | 低内存预取/解码限制未做 |
| 176 | PARTIAL | 墨水屏关动画阴影未系统核 |
| 177 | PARTIAL | 系统字号放大适配未验 |
| 178 | PARTIAL | 点击区域未系统核 |
| 179 | NOT_STARTED | 无障碍语义标签未做 |
| 180 | PARTIAL | 深色/高对比/尺寸未逐一验 |

## J. 自动化测试、真实验收与交付（181—200）

| # | 状态 | 说明与证据 |
|---|---|---|
| 181 | PASS | 本台账即独立台账，逐条记录状态 |
| 182 | PARTIAL | 视频回归场景仅部分落为测试 |
| 183 | PASS | 标题去重测试（reader_engine_test） |
| 184 | PASS | 分页完整性测试（不漏不重） |
| 185 | PARTIAL | 跨章翻页测试仅 smoke，正/反/边界未系统化 |
| 186 | NOT_STARTED | 快速点击/连续滑动组件测试未建 |
| 187 | PASS | 设置切换后位置恢复（anchor 修复 + smoke） |
| 188 | PARTIAL | 不同字号/行高/边距/横竖屏测试不全 |
| 189 | PARTIAL | 单章/超长/空章/中英混排/异常边界测试不全 |
| 190 | PARTIAL | 书架点击直读流程测试存在，恢复位置未完整测 |
| 191 | PARTIAL | WebDAV 冲突/离线/错误凭据/损坏测试部分 |
| 192 | BLOCKED | 需真机 100 次翻页 |
| 193 | BLOCKED | 需分别构建/检查两变体 |
| 194 | PASS | flutter analyze 0 error 0 warning |
| 195 | PASS | flutter test --no-pub 123/123 通过 |
| 196 | PARTIAL | CI 构建待触发 |
| 197 | PARTIAL | 版本/包名/签名/升级兼容待核 |
| 198 | PARTIAL | PR 待提交 |
| 199 | PARTIAL | 0.8.0 Preview 发布待完成 |
| 200 | PARTIAL | 最终审计待完成 |
