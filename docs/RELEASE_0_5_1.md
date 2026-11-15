# Release 0.5.1-preview 交付记录

- 版本：`0.5.1+7`
- 标签：`v0.5.1-preview`
- 发布提交：`97f29bb`
- PR：https://github.com/cs9527h/read/pull/28
- 合并提交：`11aa15f`
- Release：https://github.com/cs9527h/read/releases/tag/v0.5.1-preview

## 构建结果

| 工作流 | 运行 | 结果 | 用时 |
|---|---|---|---|
| build-android | #206 | Success | 9m 55s |
| build-windows-experimental | #168 | Success | 7m 0s |
| release | #6 | Success | 9m 9s |

## APK

- `read-android.apk`：88,319,125 字节，SHA-256 `f6315a4f79a9328aa82cf69fae9b664b890a07979806fc8954a75b5ef1076f46`
- `read-eink.apk`：88,253,585 字节，SHA-256 `b03906b37488c826096ff4c4173575715019866f058a31e4194f7e19206fbe20`
- 包名：`app.readen.read`
- 新 APK 的 `libapp.so` 已确认包含 `bookmark_meta_store.dart`、`manual_chapter_store.dart`、`read.bookmark_meta.v1.*`、`read.manual_chapters.v1.*`，不是旧包。

## 自动化

- `flutter analyze --no-fatal-infos`：0 error、0 warning、106 info
- `flutter test --no-test-assets`：**97/97 通过**

## 本批真实改动

- 书签备注、创建时间、编辑、删除清理；同步记录增加 `note/created_at`，备份恢复包含备注。
- 修复“远端书签全部删除时本地不清空”的同步缺陷；高亮墓碑同样按记录 ID 清理。
- 书籍标签：模型、详情页增删、书架按标签筛选、同步 payload、备份恢复、云端缺书下载后保留标签。
- 手动目录修正：按当前绝对偏移新增章节、删除手动章节、叠加自动分章，不改原文。
- 书内搜索命中词加粗高亮。
- TTS 开始/暂停/停止保存当前章节/页/字符偏移。
- 定时同步增加 5/10 分钟与 1–10080 分钟自定义。

## 仍未完成

- 后台 TTS、系统音频中断恢复未真机验收。
- 坚果云 WebDAV、真实 S3 账号未联调。
- Windows 仅 CI 构建成功，无真实 Windows 主机验收。
- 100 项台账中的多层目录树、标签管理页、选择性恢复、封面/字体/词典同步等仍未完成。
