# READ × Reeden 1000 · 执行检查点（机器可恢复）

> 本文件供上下文/额度耗尽后下一轮精确恢复。每批结束必须更新本文件。
> 最近更新：本轮「全面大改 v2.0」（用户新指令：单手机版 + 低版本安卓 + 对标 Reeden 重做）

## 环境与仓库
- 仓库：cs9527h/read（default branch `main`）
- GitHub token：存于 `/root/.gh_token`（用户提供，勿提交仓库）
- **main 已更新到 v2.0.0**（`456647e`）；下一轮从 `main` 切新分支 `work/reeden-v3`
- 历史分支：`work/reeden-v2`（v2.0 来源，已合并）、`work/reeden-1000`（v1.1.1 来源，已合并），勿再用
- Flutter：`/opt/flutter350/bin/flutter`（3.50.0 / Dart 3.14.0）。系统默认 flutter 是 3.0.0，不可用！
- 验证基准：analyze 0 error/0 warning（146 infos）；flutter test 156/156 通过

## 用户本轮新指令（最高优先级）
1. 手机版已内置墨水屏模式 → **去掉独立 eink APK**，只发一个手机版。
2. **尽可能覆盖低版本安卓**：Flutter 3.50 官方下限 = API 24（Android 7.0），
   API 23 及以下属引擎 Unsupported（强行改 minSdk 会运行时崩溃，属虚报）。故以 24 为下限做完整兼容。
3. 之前要求的功能「全面详细重新大改对标 Reeden」——持续逐批做真实代码，不虚报。

## 任务包与中间产物
- 任务书原文：`/root/.codebuddy/artifact/2f8a7d30-9c21-4f0b-1d73-8da1ff5e8000/task1000/READ_Reeden_1000_混元Flash_开发任务书.md`
- 解析脚本 `parse_requirements.py` → requirements.json；分类表 `classify.py` → classified.json
- 台账生成 `gen_ledger.py` → docs/READ_REEDEN_1000_STATUS.md + .csv
- 更新某条：编辑 classify.py，重跑 `classify.py` + `gen_ledger.py`

## 1000 项台账状态（本轮发布后）
- ✅ 已验证完成 V：43
- 🟡 已实现待验证 I：261
- ◐ 部分实现 P：302
- ⛔ 客观阻塞 B：52（真机/真网盘账号/多设备/第三方授权）
- ⬜ 未开始 N：342
- 合计 1000。**绝不虚报完成。**（V+I=304 有源码支撑，P/B/N=696 如实标注缺口）

## 本轮逐批进度
| 批次 | 范围 | 状态 | commit | 说明 |
|---|---|---|---|---|
| v2-1 | 单一手机版 + 低版本安卓适配 | 完成+CI绿 | 9623fa1 | 移除 eink 独立包；patch_android.py 统一适配（minSdk24/ABI/明文同步/权限/lint）；APK 断言 |
| v2-2 | 书内搜索历史（R0316/R0317）+ 台账纠错 | 完成 | 7f55f3e | SearchHistoryStore 4/4 测试；UI 接入；R0466 置顶误判纠正；全量 156/156 |
| v2-3 | README/版本 2.0.0+14/检查点 | 完成+CI绿 | cb5a943 | README 从过时 0.7.0 双包更新到 2.0 单包真实状态 |
| v2-4 | 单书笔记导出 Markdown（R0561/R0575） | 完成+CI绿 | 0e0a1af | NoteExporter + 阅读器导出按钮 + 4 测试；全量 160/160 |
| v2-5 | 合并 main + 打 tag v2.0.0-preview | 完成 | 456647e | PR #48 squash 合并；release 仅产单一手机版 APK |

## GitHub 状态
- **PR #48 已合并 main**（squash `456647e`）；合并前最终 head 0e0a1af 的 apk+windows CI 全绿
- 已打 tag `v2.0.0-preview` @ `456647e`，release workflow 仅构建 `read-android.apk` + `APK_SHA256.txt`（无 eink 包）
- 版本 2.0.0+14，包名 `app.readen.read` 不变，支持覆盖安装
- PR #48：v2-1 CI 绿（build-android 9623fa1 success）；v2-2 提交 7f55f3e 的 CI 进行中
- 尚未合并 main、尚未打 2.0 tag。合并/发布前确认 7f55f3e 的 apk+windows 均 success

## v2.1 批次（2026-11-17，分支 work/reeden-v3）

**完成（有代码 + 自动化证据）**
1. WiFi 传书安全（R0104–R0108）：`lib/src/services/wifi_transfer_service.dart` 新增；页面改为默认关闭、显示配对码；17 条真实 loopback HTTP 测试覆盖未认证、过期、错码锁定、超大、伪装扩展名、路径穿越、并发、限速、公网拒绝、停止清理。
2. 备份完整性（R0841–R0852）：`backup_service.dart` 重写清单/校验/预览/选择性恢复；9 条测试覆盖丢失文件、篡改哈希、损坏包、旧版兼容、部分失败与幂等重跑。
3. SQLite 核心存储（R0011/R0851/R0852）：`read_database.dart` v2（高亮/队列/冲突 + 索引 + 迁移），`core_store.dart` 事务读写与旧数据迁移；5 条测试含 v1→v2 升级。
4. 启动与内存（R0041）：启动只读元数据，`ensureContent` 按需解析；单书失败隔离 + 重试；500 本性能测试。
5. 阅读统计（R0601/R0611/R0640）：`reading_session_tracker.dart`，区分新读/回看、空闲与后台暂停；6 条测试。
6. 反馈与诊断（R0957/R0958/R0032/R0389/R0880）：QQ 链接 + 失败复制；`diagnostics_service.dart` 脱敏/轮转/导出；5 条测试。

**测试基线**：`flutter analyze` 0 error/warning；`flutter test` **209/209**。
**台账**：V 64 / I 251 / P 291 / B 52 / N 342。

## 下一轮恢复命令
```bash
cd /workspace/read-app
git checkout work/reeden-v3 && git pull --rebase
/opt/flutter350/bin/flutter analyze --no-fatal-infos
/opt/flutter350/bin/flutter test
head -20 docs/READ_REEDEN_1000_STATUS.md
```

## 下一批建议（按真实缺口，均已核对代码，非台账臆测）
1. **笔记导出扩展（模块 15）**：本轮已做 Markdown；剩余 R0562 TXT / R0563 JSON / R0564 CSV / R0577 筛选导出 / R0575 已做。可基于 NoteExporter 扩展，纯函数+测试，风险低。
2. **阅读统计补充（模块 16）**：目标（分钟/字数/年度本数），基于 reading_stats_store 扩展 + 单测。
3. **书籍元数据导出（R0465/R0479）**：书架多选导出元数据 JSON + 整库备份，可测。
4. **同步可靠性测试补强**：sync_service_test 仅 2 项，可为冲突/墓碑/断点补测，不改动逻辑。
5. 逐批把「已实现待验证」中有本地测试可行的条目升为已验证。
> 已核对确认为**已实现**（勿重复做）：R0466 置顶（Book.pinned+setPinned+完整UI）、
> R0172 位置返回（_positionHistory 栈 + _goBackPosition + UI 入口）、
> R0239 排版防抖（180ms Timer）、R0316/R0317 搜索历史、R0561/R0575 笔记 Markdown 导出（均本轮新增）。

## 客观阻塞（本环境无法满足，如实记录）
- 需 Android 真机录屏/性能/安装回归的项（R0015/R0200/R0280/R0397/R0984 等）
- 需真实网盘账号授权的云盘接入（百度/123/OneDrive/GDrive/Dropbox，R0811-R0821）
- 双设备同步验证（R0800/R0985）
- 第三方付费 API（在线 TTS/翻译/AI，需用户提供密钥）

## 不可触碰
- 包名（app.readen.read）、固定预览签名、用户数据库 schema、旧版升级兼容必须保持
- **注意**：本轮已移除 app.readen.read.eink 独立包；若用户反悔需恢复独立包，参考 git 历史 v1.1.1
- 不得提交 token / 私钥 / 私人书籍 / 真实凭据
- 不得修改 GitHub 仓库可见性与权限
