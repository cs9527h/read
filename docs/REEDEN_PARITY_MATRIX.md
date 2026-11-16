# Read × Reeden 功能对标矩阵

> 对标 Reeden 公开功能与体验，保持 Read 独立品牌与原创视觉，不复制其闭源代码/素材。
> 本矩阵状态与 `docs/READ_REEDEN_1000_STATUS.md` 的 1000 项逐条台账一致；此处为模块级摘要。
> 更新：2026-11-16，基线 main@d23c86b。

| 能力模块 | Reeden 具备 | Read 现状 | 证据 | 差距 |
|---|---|---|---|---|
| TXT/EPUB/MD/HTML 文本阅读 | ✅ | ✅ 文本模式 | format_engine_test、reader_engine_test | EPUB 富文本/图片有限 |
| PDF 阅读 | ✅ | ◐ 原生渲染基础 | pdf_format_test | 标注/导出未实现 |
| 漫画 CBZ/CBR | ✅ | ⛔ 未实现 | — | 需新建图像阅读器 |
| 翻页动画（覆盖/仿真/淡入） | ✅ | ◐ 覆盖/无动画/自动翻页 | reader_settings、smoke test | 仿真折角未实现 |
| 排版（字号/行距/段距/缩进/边距/主题） | ✅ | ✅ 丰富 | reader_settings、eink_theme_test、screen_preset_test | 竖排/繁简/主题管理未实现 |
| 目录/搜索/进度定位 | ✅ | ◐ 分章+全文搜索+锚点 | chapter_splitter_test、book_search_test、锚点测试 | 索引后台构建/正则搜索未实现 |
| 书签/高亮/笔记 | ✅ | ◐ 本地完整、渲染修复 | reader_page_smoke、bookmark_meta_store | 导出/富文本笔记未实现 |
| 书单/分类/批量管理 | ✅ | ◐ 分类/书单基础 | collection_store | 系列分组/字母索引未实现 |
| 阅读统计/目标/年报 | ✅ | ◐ 统计基础 | reading_stats_store、stats_page | 目标/年度报告未实现 |
| 听书 TTS | ✅ | ◐ 系统 TTS 基础 | reader_page (FlutterTts) | 后台播放/多角色未实现 |
| 词典/翻译/生词本 | ✅ | ⛔ 未实现 | — | 需词条数据与 API 授权 |
| AI 阅读助手/人物关系 | ✅ | ⛔ 未实现 | — | 需 API 授权 + 隐私设计 |
| 多端同步（WebDAV/S3） | ✅ | ✅ 双向+冲突+备份 | sync_service_test、backup/envelope 测试 | 其它网盘需授权 |
| 网盘云书库 | ✅ | ⛔ 未实现 | — | 仅同步，无云书库浏览 |
| 墨水屏/无障碍/隐私 | ✅ | ◐ 墨水屏+安全存储 | eink_theme_test、secure_storage | TalkBack/诊断上传未完善 |

图例：✅ 具备并有证据　◐ 部分/有限　⛔ 未实现或客观阻塞。

**总体结论**：核心阅读闭环（导入→阅读→翻页→排版→书签高亮→进度恢复→同步备份）已具备真实实现与自动化测试证据；
漫画、词典翻译、AI、云书库、PDF 标注、多角色听书等为重差距模块，如实标注为未开始/阻塞，未以界面占位冒充完成。
