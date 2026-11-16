# Read 1.1.1-preview — 对标 Reeden 1000 项基线 + 阅读内核 P0 修复

本版本启动《READ 阅读器：全面对标 Reeden 的 1000 条详细开发与验收要求》的逐条落地。
**所有改动均为真实源码修改并有自动化测试证据；未完成/受环境限制的项目在台账中如实标注，不以界面占位冒充完成。**

## 一、1000 项逐条验收台账（R0001–R1000）

- 新建 `docs/READ_REEDEN_1000_STATUS.md` / `.csv`，完整覆盖 25 模块 × 40 条 = 1000 条，逐条含状态、代码路径、证据/阻塞说明。
- 保守标注（基线 main@d23c86b）：39 已验证完成 / 260 已实现待验证 / 302 部分实现 / 52 客观阻塞 / 347 未开始。
- 判定严格：只有「真实源码 + 本环境可运行测试通过」才标记 ✅ 已验证完成；真机、多设备、第三方授权项一律如实标注阻塞。
- 新增机器可恢复检查点 `docs/REEDEN_1000_CHECKPOINT.md`，记录环境、批次进度、恢复命令与阻塞清单。

## 二、阅读内核 P0 修复

### EPUB spine 正文不再被误作重复标题（同源 PR #46）
- `lib/src/formats/format_engine.dart`：只有显式 HTML 标题（h1–h6）或编号标题（第X章 / Chapter N）才成为章名；开篇正文保持为正文，不再复制成假标题。
- `test/format_engine_test.dart`：新增真实 ZIP EPUB spine 回归用例，验证正文只出现一次、显式标题只渲染一次。

### 分章标题不再跨行吞掉正文
- `lib/src/services/chapter_splitter.dart`：自动标题正则中的 `\\s`（含换行 `\\n`）收紧为同行 `[ \\t]`。修复「第一章\\n正文无标点」被识别为单个章名、吞掉下一行正文、污染章节名与进度显示的问题。
- `test/chapter_splitter_test.dart`：新增中文/英文两条回归用例，验证章名不含换行、原文零丢失、章节连续覆盖。

## 三、能力对标矩阵（真实状态，不摆设按钮）

- `docs/REEDEN_PARITY_MATRIX.md`：Reeden 功能逐模块对标与差距。
- `docs/FORMAT_CAPABILITY_MATRIX.md`：格式支持分级（TXT/EPUB/MD/HTML/PDF 的文本/原生渲染能力与安全边界）。
- `docs/CLOUD_CAPABILITY_MATRIX.md`：云盘能力矩阵。仅 WebDAV / S3 为真实实现；百度网盘、123、OneDrive、Google Drive、Dropbox、iCloud、SMB/SFTP/OPDS 等均如实标注未实现/需授权，**界面不给未接入服务摆按钮或显示「已连接」**。

## 四、验证证据

- `flutter analyze --no-fatal-infos`：**0 error / 0 warning**（仅 info 级 lint 提示）。
- `flutter test`：**152/152 通过**（基线 149 → +EPUB spine 1 + 分章跨行 2）。
- GitHub Actions：PR #47 触发 `build-android` 与 `build-windows-experimental`，均 success；生成可下载 `read-apks` 构建产物（约 87MB）。

## 五、数据与安全

- 未改动 applicationId、签名方案、数据库 schema 与旧版升级兼容。
- 未提交任何 Token、私钥、凭据或私人书籍；令牌继续存于 flutter_secure_storage。
- 未修改 GitHub 仓库可见性、协作者与权限。

## 六、如实标注的未完成/阻塞项

- 需 Android 真机：录屏、帧率/内存性能测试、安装升级回归、TalkBack/大字体验收。
- 需真实账号/多设备：百度网盘等云盘接入、双设备同步合并、真实备份恢复演练。
- 需第三方授权与样本：在线 TTS/翻译/AI API、多语言/漫画/复杂排版真实样本。
- 详见台账中 52 条「客观阻塞」与 347 条「未开始」。

完整逐条证据见 `docs/READ_REEDEN_1000_STATUS.md`；下一批恢复步骤见 `docs/REEDEN_1000_CHECKPOINT.md`。
