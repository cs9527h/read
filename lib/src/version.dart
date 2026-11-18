/// 应用版本号（与 pubspec.yaml 的 version 前缀保持一致，发布时同步修改）。
const String appVersion = '2.3.0';
const String appChannel = 'preview';
/// Immutable source commit embedded by the release workflow.
const String buildCommitSha = String.fromEnvironment('BUILD_GIT_SHA', defaultValue: 'local');
String get buildCommitShort => buildCommitSha.length >= 7 ? buildCommitSha.substring(0, 7) : buildCommitSha;
String get appVersionLabel => 'v$appVersion $appChannel';
