# Read 2.1 批次交付说明（2026-11-17）

> 分支 `work/reeden-v3` → PR [#49](https://github.com/cs9527h/read/pull/49)
> 基线 `main@a2a6874`；本批 10 个提交；`flutter analyze` 0 error/warning；`flutter test` **209/209**。
> 只记录有代码与自动化证据的改动；未做的一律列入“未完成/阻塞”。

## 一、本批完成的需求

| 批次 | 需求编号 | 状态变化 | 核心交付 |
|---|---|---|---|
| P0-1 WiFi 传书安全 | R0104–R0106 | ◐/🟡 → ✅ | 配对码 + 令牌 + 过期 + 锁定 + 私有网段 + 限速 + 并发 + 白名单 + 文件头 + 临时文件清理 |
| | R0107–R0108 | ◐ → 🟡 | 进度/成功/失败反馈已做；失败自动重试、长时间空闲自动停止未做 |
| P0-2 备份完整性 | R0841/R0842/R0844/R0845/R0847/R0848/R0849/R0851/R0852 | 🟡/◐ → ✅ | 逐书清单、回读校验、预览、逐本选择、保护快照、幂等重跑、旧版兼容 |
| P0-3 数据库 | R0011 | 🟡 → ✅ | schema v2 + onUpgrade + 索引 + 唯一约束 + 增量迁移 |
| P0-4 启动内存 | R0041 | 🟡 → ✅ | 元数据先行、正文按需解析、单书故障隔离、500 本性能测试 |
| P1 统计纠错 | R0601/R0611/R0640 | 🟡/◐ → ✅ | 新读/回看分离、跳转重置、空闲与后台暂停 |
| 笔记导出 | R0562–R0564 | ◐ → 🟡 | 新增 TXT/JSON/CSV，CSV 按 RFC 4180 转义（复制到剪贴板，落盘待做） |
| 第六阶段反馈诊断 | R0032/R0389/R0957/R0958 | ◐/🟡 → ✅ | QQ 链接跳转 + 失败复制；本地诊断脱敏/轮转/导出 |
| | R0880 | ◐ → 🟡 | 报告可复制；导出为文件未做 |
| CI 硬校验 | R0851/R0852 相关 | 强化 | Flutter 3.50.0 固定；APK 包名/minSdk/ABI/versionCode/签名断言 |

台账总数仍为 1000：**V 64 / I 251 / P 291 / B 52 / N 342**。

## 二、修改的文件

**新增**
- `lib/src/services/wifi_transfer_service.dart`：传书服务内核（HTTP + 认证 + 限速 + 校验）
- `lib/src/database/core_store.dart`：SQLite 门面（事务/迁移/队列镜像）
- `lib/src/services/reading_session_tracker.dart`：真实阅读增量
- `lib/src/services/diagnostics_service.dart`：本地诊断
- `tools/android/verify_apk.sh`：构建产物硬断言
- `test/wifi_transfer_service_test.dart`（17）、`test/backup_service_test.dart`（9）、
  `test/core_store_test.dart`（5）、`test/library_lazy_content_test.dart`（4）、
  `test/reading_session_tracker_test.dart`（6）、`test/diagnostics_service_test.dart`（5）

**修改**
- `lib/src/more/wifi_transfer_page.dart`：默认关闭、配对码 UI、事件流、后台停止策略
- `lib/src/sync/backup_service.dart`：重构为清单 + 校验 + 预览 + 选择性恢复
- `lib/src/sync/sync_page.dart`：部分备份/部分恢复提示、逐本勾选弹窗
- `lib/src/database/read_database.dart` + `.g.dart`：v2 表、索引、迁移策略
- `lib/src/services/library_store.dart`：启动不解析正文、`ensureContent`、故障隔离、双写
- `lib/src/services/bookmark_store.dart` / `highlight_store.dart`：SQLite 优先读取 + 双写
- `lib/src/sync/sync_history.dart`：队列镜像、失败进诊断
- `lib/src/services/reading_stats_store.dart`、`lib/src/stats/stats_page.dart`：reread 维度
- `lib/src/reader/reader_page.dart`：正文错误重试、统计接入
- `lib/src/bookshelf/book_detail_page.dart`：打开前确保正文
- `lib/src/sync/progress_sync_service.dart`：同步前确保正文
- `lib/main.dart`：分段启动、诊断安装、SQLite 迁移、imageCache 上限
- `lib/src/profile/about_page.dart`：反馈入口、诊断面板
- `.github/workflows/build-android.yml`、`release.yml`、`tools/android/patch_android.py`
- `docs/READ_REEDEN_1000_STATUS.md/.csv`、`docs/REEDEN_1000_CHECKPOINT.md`、`README.md`

## 三、修复前后

| 问题 | 修复前 | 修复后 |
|---|---|---|
| 传书无认证 | 页面一打开即监听 0.0.0.0:8765，任何同网段设备可上传 | 默认关闭；配对码换令牌；10 分钟过期；错 5 次锁定；公网 403 |
| 传书无边界 | 仅扩展名 + 40MB | 令牌 + 私有网段 + 每 IP 限速 + 并发 2 + PDF/EPUB 文件头 + 文件名清洗 |
| 备份静默跳过 | 文件丢失/超限直接 `continue`，仍显示“备份成功” | 逐书 `metadata_only + reason`；`complete=false`；UI 明确“部分备份” |
| 备份不校验 | 只写不读回 | 写后回读逐文件 SHA-256，失败删除并抛错 |
| 恢复无预览 | 直接确认即恢复 | 预览数量 + 逐本勾选 + 仅元数据 + 保护快照 |
| 业务数据在 prefs | 无事务、无索引、无唯一约束 | SQLite v2 + 事务 + 索引 + 唯一约束 + 迁移测试 |
| 启动解析整库 | 每本书都读文件并解析，内存随时爆 | 只读元数据；打开时解析；单书失败隔离 |
| 统计虚高 | `abs(offset-last)` 累加，往回翻也算新字数 | 越过最远位置才算新读；回看计重复；空闲/后台不累计 |
| 诊断缺失 | 无全局异常记录 | 本地环形日志、脱敏、可导出、不自动上传 |
| CI 只打印 | ABI/minSdk 仅 echo | `verify_apk.sh` 断言包名/minSdk/ABI/versionCode/签名 |

## 四、测试证据

```
flutter analyze                     → 150 issues, 0 error / 0 warning
flutter test                        → 209/209 All tests passed
wifi_transfer_service_test.dart     → 17 passed（真实 loopback HTTP）
backup_service_test.dart            → 9 passed（含损坏包/旧版/中断重跑）
core_store_test.dart                → 5 passed（含 v1→v2 升级）
library_lazy_content_test.dart      → 4 passed（含 500 本性能）
reading_session_tracker_test.dart   → 6 passed
note_exporter_test.dart             → 7 passed（含 TXT/JSON/CSV）
diagnostics_service_test.dart       → 5 passed
```

## 五、提交与 PR

- `9a43429` WiFi 传书安全 + 备份完整性
- `a349ae3` SQLite 核心存储 + 启动按需解析
- `7dee436` 阅读统计纠错
- `8a78a87` QQ 反馈 + 本地诊断
- `c3b8229` 台账与检查点
- `0e2ccfa` Manifest queries（Android 11+ 链接跳转）
- `b8003dd` CI 固定版本 + APK 硬断言
- `81d3bbe` 上传清理顺序竞态修复（Windows CI）
- `19517f8` 笔记导出 TXT/JSON/CSV
- PR：https://github.com/cs9527h/read/pull/49

## 六、仍未完成 / 客观阻塞

1. **大文件分块索引**（R0270+）：目前单本 40MB 上限 + 整本解析；分块读取/可取消布局未实现。
2. **跨页选择与重新排版后高亮锚点**：绝对偏移锚点已有，跨页拖选未做。
3. **PDF 标注/裁边/文字选择**：仅基础阅读与书签。
4. **EPUB CSS/脚注/图片**：仅文字版解析。
5. **漫画 CBZ/CBR、FB2/MOBI/AZW3**：未实现。
6. **词典/翻译/AI/云书库**：未开始。
7. **真机验收**：录屏、帧率、低版本实机、双设备同步——本环境无真机与第二台设备。
8. **真实网盘账号**：百度/123/OneDrive/Dropbox 需授权，维持客观阻塞。
9. **正式签名**：仍用公开预览签名，正式分发前必须替换并规划升级路径。

## 七、下一批建议

1. 阅读内核：分块读取 + 章节级索引缓存 + 可取消布局（R0270 段）。
2. 跨页选字与高亮锚点重排校验（R0345 段）。
3. 笔记导出 TXT/JSON/CSV（R0562–R0564）。
4. 书籍元数据导出与整库 JSON（R0465/R0479）。
5. 同步冲突补测：两设备/三设备/一端删除另一端编辑（R0790 段）。
