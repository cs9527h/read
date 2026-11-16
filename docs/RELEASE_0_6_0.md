# Read 0.6.0+8 预览版发布记录

日期：2026-11-16（UTC+8）
版本：`0.6.0+8`，包名 `app.readen.read`

## 本批真实改动（V2 第一阶段：同步安全与正确性）

1. **图书原文件加密上传**
   - 新增 `lib/src/sync/encrypted_file_envelope.dart`，二进制格式 `READFILE1 | salt(16) | nonce(12) | mac(16) | ciphertext`，AES-256-GCM，PBKDF2-HMAC-SHA256 210000 次。
   - `MetadataSyncService` 默认上传 `files/<sha256>.<ext>.enc`，不再把原始电子书明文字节写入云端。
   - 下载优先读 `.enc`，先认证解密，再对解密后的原始字节校验 SHA-256；密码错误、篡改或损坏一律拒绝导入。
2. **旧明文云文件保护**
   - 发现 `files/<sha256>.<ext>` 明文对象时，默认拒绝自动下载并写失败历史；必须在同步选项显式开启“允许读取旧明文云文件”。
   - 旧明文对象不会自动删除，避免未经确认破坏用户云端数据。
3. **重试队列绑定书籍**
   - `PendingSyncTask` 增加 `book_hash`、`target_id`、`permanently_failed`。
   - 进度任务按书籍哈希查找目标书，不再使用“当前书或书架第一本书”；云目标变化会暂停任务。
4. **失败不再静默丢失**
   - 重试 8 次后任务保留为持久失败，同步历史显示书籍哈希与错误，可手动“重试”。
   - 新增 `SyncFailure` 分类：认证、超时、限流、存储不足、冲突、损坏、网络、取消，并给出下一步建议。
5. **询问策略不静默覆盖**
   - 新增 `ProgressConflictStore`，`ask` 策略在后台保存本地/云端两条记录并通知历史，不选边、不写云端。
   - 同步选项页展示待解决冲突：书名、本机/云端设备、章节或页码、进度比例、更新时间；用户选择后生成新修订并清除冲突。
   - 未解决冲突只跳过当前书，不阻塞其他书。
6. **测试**
   - 新增 `test/encrypted_file_test.dart`、`test/sync_task_queue_test.dart`、`test/progress_conflict_store_test.dart`、`test/sync_failure_test.dart`。
   - 扩展 `test/sync_service_test.dart`：断言上传对象为 `.enc`、云端不存在明文图书文件、解密结果与原字节一致。
   - 本机 `flutter analyze --no-fatal-infos`：0 error / 0 warning / 106 info。
   - 本机 `flutter test --no-test-assets`：**103/103 通过**。

## 200 项台账

- `docs/V2_200_STATUS.csv`：200 行逐项记录。
- `docs/V2_200_STATUS.md`：人类可读版与状态汇总。
- 当前：代码完成·单测 21、部分完成 128、未开始 50、阻塞 1。**未把部分/未开始/阻塞算作完成。**

## 未完成与阻塞

- 云端占位书库、单书/批量下载、断点分片、只移除本机文件（V2 131—137）未实现。
- EPUB 结构化渲染、PDF 搜索/适宽/页内定位、TXT 100MB 磁盘索引（V2 023—024、031—040）未实现。
- 真实坚果云 WebDAV、真实 S3/MinIO/R2 联调（V2 161—170、197）无账号，标阻塞。
- Android↔Android、Android↔Windows、Android↔墨水屏真机双端验收（V2 098、120、171—178、190、198）无第二台设备/模拟器，未做。
- 数据库事务迁移、三设备并发自动化、断网/429/损坏回放（V2 192—196）未做。
