# Read 唯一发布与溯源规范

- `main` 为唯一发布主线；所有 AI 通过从最新 main 派生分支及经过 CI 的 PR 完成修改。
- 正式预览包只能从 main 的最新提交创建 `vX.Y.Z-preview` tag；Release 工作流核验标签、pubspec.yaml 版本、应用内更新日志、main 祖先关系及 main 最新 SHA。
- 自动测试工件不等于已经发布的 APK；Release 只在这些检查以及 Flutter 分析、单测、构建、包名和签名检查全通过后发布。
- 每次 Android 构建均写入源码提交的完整 SHA，APP“关于”页显示 SHA 前 7 位，`READ_BUILD_PROVENANCE.json` 记录构建时来源及 APK SHA-256；正式 Release 附 `READ_RELEASE_PROVENANCE.json`。
- 每次发新版本：先完成改动并合并 main，再提升 pubspec.yaml 的版本号和 build number、同步 `lib/src/version.dart`、将简短记录加入 `lib/src/profile/changelog_page.dart`，完成 CI 后才创建发布标签。
- 不能用旧标签关联新 APK；不能在标签没有进主线时发布；不要在构建后手工替换附件。
- Read 当前使用内部预览签名，发布门禁确保该签名校验通过，但它不是秘密的正式生产签名方案；以后应更换为受保护的正式 keystore，同时规划可验证的安装迁移，不能直接让旧版覆盖升级失败。
- 仍需用户在安卓手机上确认可覆盖安装及书架、阅读、备份、WebDAV/S3 等功能；GitHub Actions 绿色只是自动门禁，不等于全部用户验收。
