/// 应用版本号（与 pubspec.yaml 的 version 前缀保持一致，发布时同步修改）。
const String appVersion = '2.3.1';
const String appChannel = 'preview';
/// Embedded at build time; compare with the source SHA of the GitHub Release.
const String appBuildSha = String.fromEnvironment('READ_SOURCE_SHA', defaultValue: 'local');
String get appVersionLabel => 'v$appVersion $appChannel';
