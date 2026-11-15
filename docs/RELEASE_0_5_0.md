# Release 0.5.0-preview 交付记录

- 版本：`0.5.0+6`
- 标签：`v0.5.0-preview`
- 提交：`8fca69f`
- PR：https://github.com/cs9527h/read/pull/26
- Release：https://github.com/cs9527h/read/releases/tag/v0.5.0-preview

## 构建结果

| 工作流 | 运行 | 结果 | 用时 |
|---|---|---|---|
| build-android | #200 | Success | 10m 19s |
| build-windows-experimental | #163 | Success | 7m 52s |
| release | #5 | Success | 见 Actions |

产物：

- `read-android.apk`：88,204,121 字节，SHA-256 `31e2323df77c4ce205237cecee23b7681d4b0b288ea87af7ae6bc7872393ac64`
- `read-eink.apk`：88,122,201 字节，SHA-256 `b6f80ec94993de25da6111aeca350f22428144e0560f7a39fc6171eb722b96c5`
- 包名：`app.readen.read`
- 签名：CI 使用仓库固定预览密钥 `tools/android/read-preview.jks.b64`，与既有预览版保持同一配置；本地环境无 `apksigner`，未独立解签比对证书指纹。

## 自动化

- `flutter analyze --no-fatal-infos`：0 error，0 warning，106 info。
- `flutter test --no-test-assets`：92/92 通过。

## 1000 项台账

- `docs/READ_1000_EXECUTION_STATUS.csv`：1000 行完整编号、原始需求、状态、证据、阻塞、下一步。
- `docs/READ_1000_EXECUTION_STATUS.md`：同一数据的人类可读版。
- 当前统计：PASS 13、PARTIAL 944、BLOCKED 1、NOT_STARTED 42、FAIL 0。
- **PARTIAL 944 表示对应模块已有代码但该项目未逐条独立验收，不等于完成。**

## 未通过/阻塞

- 双 Android 真机、Android↔Windows、墨水屏真机同步未执行。
- 坚果云 WebDAV、真实 S3 账号未联调。
- Windows 只有 CI 构建成功，无真实 Windows 主机验收。
- 性能帧时间、超大 TXT、EPUB 图片/CSS、跨页选择、标签/字体/封面同步等仍未完成。
- 1000 项中 944 项只是模块级 PARTIAL，42 项未开始，不能宣称 1000 项全部通过。
