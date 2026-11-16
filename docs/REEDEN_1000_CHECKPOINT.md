# READ × Reeden 1000 · 执行检查点（机器可恢复）

> 本文件供上下文/额度耗尽后下一轮精确恢复。每批结束必须更新本文件。
> 最近更新：本轮「全面大改 v2.0」（用户新指令：单手机版 + 低版本安卓 + 对标 Reeden 重做）

## 环境与仓库
- 仓库：cs9527h/read（default branch `main`）
- GitHub token：存于 `/root/.gh_token`（用户提供，勿提交仓库）
- **当前工作分支：`work/reeden-v2`**，基线 = GitHub main `7bd405d`（v1.1.1-preview 已合并）
- 旧分支 `work/reeden-1000` 已完成历史交付，勿再用
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

## 1000 项台账状态（本轮第 2 批后）
- ✅ 已验证完成 V：41
- 🟡 已实现待验证 I：261
- ◐ 部分实现 P：302
- ⛔ 客观阻塞 B：52（真机/真网盘账号/多设备/第三方授权）
- ⬜ 未开始 N：344
- 合计 1000。**绝不虚报完成。**（V+I=302 有源码支撑，P/B/N=698 如实标注缺口）

## 本轮逐批进度
| 批次 | 范围 | 状态 | commit | 说明 |
|---|---|---|---|---|
| v2-1 | 单一手机版 + 低版本安卓适配 | 已推送+CI绿 | 9623fa1 | 移除 eink 独立包；patch_android.py 统一适配（minSdk24/ABI/明文同步/权限/lint）；APK 断言；CI build-android success |
| v2-2 | 书内搜索历史（R0316/R0317）+ 台账纠错 | 已推送 | 7f55f3e | SearchHistoryStore 4/4 测试；UI 接入；R0466 置顶误判纠正；全量 156/156 |
| v2-3 | 待定（草稿） | 未开始 | - | 见下方建议 |
| v2-4 | 发布 2.0 + tag | 未开始 | - | - |

## GitHub 状态
- 工作分支 `work/reeden-v2` 已推送；**PR #48**（→ main）已创建，等待合并
- PR #48：v2-1 CI 绿（build-android 9623fa1 success）；v2-2 提交 7f55f3e 的 CI 进行中
- 尚未合并 main、尚未打 2.0 tag。合并/发布前确认 7f55f3e 的 apk+windows 均 success

## 下一轮恢复命令
```bash
cd /workspace/read-app
git checkout work/reeden-v2 && git pull --rebase
/opt/flutter350/bin/flutter analyze --no-fatal-infos
/opt/flutter350/bin/flutter test
head -20 docs/READ_REEDEN_1000_STATUS.md
```

## 下一批建议（按真实缺口，均已核对代码，非台账臆测）
1. **笔记导出/书摘分享（模块 15，34 未开始）**：读取 highlight_store/bookmark_meta_store，做 Markdown/TXT 导出 + 分享，可本地测试。价值高、风险低。
2. **阅读统计补充（模块 16）**：目标（分钟/字数/年度本数），基于 reading_stats_store 扩展 + 单测。
3. **书籍元数据导出（R0465/R0479）**：书架多选导出元数据 JSON + 整库备份，可测。
4. 逐批把「已实现待验证」中有本地测试可行的条目升为已验证。
> 已核对确认为**已实现**（勿重复做）：R0466 置顶（Book.pinned+setPinned+完整UI）、
> R0172 位置返回（_positionHistory 栈 + _goBackPosition + UI 入口 2074）、
> R0239 排版防抖（180ms Timer）、R0316/R0317 搜索历史（本轮新增）。

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
