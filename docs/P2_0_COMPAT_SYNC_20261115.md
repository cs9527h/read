# Read P2.0 · 阅读兼容 + 同步内核首轮实现（2026-11-15）

## 实施范围

本项目对标 Reeden 的**有用阅读能力**，不复制闭源源码或资源。优先级：阅读格式兼容、稳定的阅读位置、无丢失的多设备同步。Mate 项目保持独立，Read 仓库保持 private。

### 这轮已提交代码（尚待 CI 和真机证明）

1. `lib/src/formats/format_engine.dart`：TXT、Markdown、HTML 和 EPUB 的**文字模式导入**。EPUB 按 container.xml → OPF manifest/spine 的顺序提取 XHTML 文字，拒绝危险相对路径、异常 ZIP/过大的压缩包。HTML/Markdown 转**不可执行的纯文本**，不执行网页脚本，也不远程加载资源。
2. `lib/src/services/library_store.dart`：导入时保存原始字节（而不是把 EPUB 结构破坏为 TXT），后续从本地副本解析，书架记录真正的 `format`、标题和作者。对不支持的文件立即报错；异常不能把原始书籍替换为空数据。
3. `lib/src/bookshelf/bookshelf_page.dart`：将不支持格式、损坏文件等错误展示给用户，避免未捕获异常崩溃。
4. `lib/src/sync/sync_record.dart`：提供稳定 ID、递增 revision、设备 ID、updated_at、deleted 墓碑和 JSON 编码、纯内存合并规则；**还没有 WebDAV/Dropbox/S3、端到端加密、SQLite 事务和设备配对**。
5. `test/format_engine_test.dart` / `test/sync_record_test.dart`：覆盖文字导入、HTML 安全处理、格式拒绝、删除墓碑、时钟偏差、同版本冲突的确定性处理、笔记同时修改的两份内容保留。

### 明确未完成，不做虚假验收

- EPUB3 固定版式、图文混排、图片显示、脚注弹窗、CSS 排版、DRM 以及图片型 EPUB 仍不支持。当前 EPUB 被转换成阅读页能读的文字章节。
- PDF 原生渲染、搜索文字层和图片型 PDF OCR 尚未实现。
- `SyncMerger` 只是**同步协议/冲突规则的起点**，尚未接入书架和 SQLite，不具备任何跨设备上传/下载功能。并发多轮笔记冲突需要长期稳定设备 ID 和持久化 conflict journal；该原型不能直接在生产中启用。
- 字符偏移锚点、超大 TXT 分块分页、SQLite/drift 迁移、EPUB 图像、WebDAV 原子写和 AES-GCM 加密均须下一轮继续做。
- 上传 ZIP 中两个 APK 均是旧构建，不能证明新功能工作；即使 CI 成功，也只能宣称构建和单测通过，不能宣称手机/墨水屏真机已验证。

### 后续推荐顺序（不删最终功能要求）

1. **首先**确保现有 PR #1 构建通过；验证独立 Android/E-Ink applicationId 和签名。新功能 CI 失败不得合并。
2. 引入 drift/SQLite、版本化迁移、备份快照、字符偏移进度，解决掉库和排版漂移风险。
3. EPUB 丰富版式/资源寻址、PDF 原生渲染；随后补充 MOBI/AZW3、DOCX、CBZ/CBR、CHM。
4. WebDAV 首发双向同步：每次远端下载→本地快照→合并冲突→事务写入→原子上传，读写均以可靠实体修订、内容 SHA-256、墓碑和可恢复 journal 为基础；独立密码加密；断网/冲突/双设备同时删除等用例必须测试。
5. Windows 客户端与手机共享同步协议，支持阅读进度/书签/笔记/书籍的安全同步。其他后端逐步加入。

### 本阶段质量闸门

- PR 构建、静态分析和单元测试（包括所有原 P1 用例）通过。
- 对实际文件导入、阅读顺序、重启后恢复等行为需要安卓实机验收才可标记「已完成」。
- 不发布未经测试的 Release；不碰 Mate；不要求在对话里复制 Token、私钥或 WebDAV 密码。
