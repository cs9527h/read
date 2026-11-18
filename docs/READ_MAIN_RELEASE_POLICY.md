# Read：唯一发布主线和安装包追溯

- GitHub 默认 `main` 是唯一正式预览版发布来源，所有 AI 从最新 main 创建功能分支，经过 PR、Flutter analyze/test、APK 构建和签名校验后才合并。
- `tools/android/check_release_source.py` 会在发布工作流校验：tag 为 `vX.Y.Z-preview`、指向当前 `main` HEAD，`pubspec.yaml`、`lib/src/version.dart`、应用内更新日志第一项一致。旧标签、其他分支和重复 Release 直接失败。
- `tools/android/check_version_consistency.py` 会在普通 Android 构建中预先发现漏改版本/日志；发布前要升级 `pubspec.yaml` 的版本名称及 build number。
- 所有 Android CI 构建通过 `--dart-define=BUILD_GIT_SHA=$GITHUB_SHA` 嵌入源码提交。关于页面显示构建 SHA 前七位，正式 Release 附 `BUILD_METADATA.json` 与 SHA256 校验文件，可核对安装包是否来自对应代码。
- 不能用工作流绿色冒充手机上已安装最新 APK；正式更新仍须发布 GitHub Release APK，由用户在安卓手机覆盖安装并验证同步、阅读、翻页、启动和设置。
- 保留原包名 `app.readen.read`、已安装版签名与本地数据库，不以卸载重装当作升级。
- 现有 Read Preview 签名方式需要后续安全审计，切换正式签名需单独制定迁移方案，不能随意换钥匙导致无法覆盖。
- 旧 PR 不批量盲合并：先核实是否已经由新实现替代，并记录未合并的功能差距。现有并行的 #56 发布溯源 PR 与 #57 功能重叠，需审核、合并有效差异后再关闭重复。
