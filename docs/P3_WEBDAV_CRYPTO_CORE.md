# Read 安全同步基础模块（尚未接入云账号）

新增 `EncryptedSyncEnvelope`、`WebDavEncryptedObject`。

- PBKDF2-HMAC-SHA256（21 万次）、AES-256-GCM、每次随机 salt 和 nonce；错误密码或内容篡改会拒绝导入。
- WebDAV 仅接受 HTTPS，使用 HTTP ETag / If-Match / If-None-Match 防止静默覆盖；对下载大小设置 16MB 限制。
- 这些都是**未接入书架的基础类**，尚未提供账号设置 UI、任务调度、冲突状态持久化、上传/下载实体、SQLite 迁移、Windows 同步等；不存在自动上传数据。
- 云端密码不得写入 GitHub、APK 或明文 SharedPreferences。密码/账户配置的 Android Keystore 与 Windows Credential Manager 接入属于待实现项。
- 未来真正双向同步必须先做 SQLite 事务/本地快照、完整 tombstone 生命周期及断线测试；不能仅用传输层表示同步完成。
