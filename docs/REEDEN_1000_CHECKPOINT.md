# READ × Reeden 1000 · 执行检查点（机器可恢复）

> 本文件供上下文/额度耗尽后下一轮精确恢复。每批结束必须更新本文件。

## 环境与仓库
- 仓库：cs9527h/read（default branch `main`）
- GitHub token：存于 `/root/.gh_token`（用户提供，勿提交仓库）
- 本地工作分支：`work/reeden-1000`，基线 = GitHub main `d23c86b`
- Flutter：`/opt/flutter350/bin/flutter`（3.50.0 / Dart 3.14.0）。系统默认 flutter 是 3.0.0，不可用！
- 基线验证：analyze 0 error/0 warning（149 infos）；flutter test 149/149 通过

## 任务包与中间产物
- 任务书原文：`/root/.codebuddy/artifact/2f8a7d30-9c21-4f0b-1d73-8da1ff5e8000/task1000/READ_Reeden_1000_混元Flash_开发任务书.md`
- 解析脚本：`.../parse_requirements.py`（→ requirements.json）
- 分类表：`.../classify.py`（→ classified.json）
- 台账生成：`.../gen_ledger.py`（→ docs/READ_REEDEN_1000_STATUS.md + .csv）
- 更新某条状态：编辑 classify.py 的 OVERRIDE，重跑 classify.py + gen_ledger.py

## 1000 项台账状态（第 3 批后）
- ✅ 已验证完成 V：39
- 🟡 已实现待验证 I：260
- ◐ 部分实现 P：302
- ⛔ 客观阻塞 B：52（真机/真网盘账号/多设备/第三方授权）
- ⬜ 未开始 N：347
- 合计 1000。**绝不虚报完成。**

## 逐批进度
| 批次 | 范围 | 状态 | commit | 说明 |
|---|---|---|---|---|
| 1 | R0001-R0040（审计+台账基线） | 已推送 | 14a82b0 | 建保护分支、基线测试、生成1000台账 |
| 2 | 阅读内核 P0（EPUB spine）+ 对标矩阵 | 已推送+CI绿 | bef009e(+a5b137d,22db52d) | 合入 PR#46 同源修复；3 份能力矩阵；CI build-android/windows success |
| 3 | 分章跨行吞正文 bug | 已推送 | bd56614 | 标题正则 \s→[ \t]；chapter_splitter 8/8；全量 152/152 |
| 4 | 待定 | 未开始 | - | - |

## GitHub 状态
- 工作分支：`work/reeden-1000`（已推送 origin）
- PR：#47（work/reeden-1000 → main），CI：build-android success、build-windows success（bef009e）
- 尚未合并 main、尚未发布新 tag。合并/发布前需确认 bd56614 的 CI 也通过。

## 下一轮恢复命令
```bash
cd /workspace/read-app
git checkout work/reeden-1000
/opt/flutter350/bin/flutter analyze --no-fatal-infos
/opt/flutter350/bin/flutter test
cat docs/READ_REEDEN_1000_STATUS.md | head -20
```

## 已识别的真实高价值修复候选（按优先级）
1. **EPUB spine 开篇正文被误当作重复标题** —— PR #46（fix/read-epub-chapter-content-20261116-0723, commits c6a55fa+7a7af5c5）已修好且 CI 绿，未合并。涉及 R0125/R0126/R0219。可 cherry-pick 或按 diff 手工移植。
2. **format_engine 40MB 上限**:超大 TXT 直接抛错（R0124），需分段索引。
3. **空开关/半成品入口扫描**:逐项核对 R0021/R0891/R0992。

## 客观阻塞（本环境无法满足，如实记录）
- 所有需 Android 真机录屏/性能测试/安装回归项（R0015/R0200/R0280/R0397/R0984 等）
- 所有需真实网盘账号授权的云盘接入（百度/123/OneDrive/GDrive/Dropbox，R0811-R0821）
- 双设备同步验证（R0800/R0985）
- 第三方付费 API（在线 TTS/翻译/AI，需用户提供密钥）

## 不可触碰
- 包名、签名、用户数据库、旧版 data schema 必须保持升级兼容
- 不得提交 token / 私钥 / 私人书籍 / 真实凭据
- 不得修改 GitHub 仓库可见性与权限
