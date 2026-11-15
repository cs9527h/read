# Read drift SQLite 首轮数据层

**当前为独立数据库初始化与单向安全快照，不是正式替代旧书架。**

- `read_database.dart` 定义：本地书籍、章节/字符位置、书签、笔记、同步操作 journal，包含 stable id、rev、device id 与 tombstone。
- `importLegacySnapshot()` 在 SQLite 事务内执行 `INSERT OR IGNORE`，不会清除或覆盖原 SharedPreferences；重复运行不能覆盖较新的数据库记录。
- 首次引入需要 build_runner 生成 `read_database.g.dart`；GitHub Actions 增加代码生成与测试。SQLite 由 sqlite3 3.x 原生资产提供。
- **未完成：** 实际启动时迁移/旧库备份文件、数据库双写切换、Windows 写入验证、真正事务型 WebDAV 合并/备份恢复。不得宣称数据层已经安全切换。
- 切换前必须确保原先 JSON/书籍文件有一致性备份、迁移后数据数量和阅读位置验证、任意失败一键恢复。
