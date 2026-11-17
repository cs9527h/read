/// 应用版本号（与 pubspec.yaml 的 version 前缀保持一致，发布时同步修改）。
const String appVersion = '2.1.0';
const String appChannel = 'preview';
String get appVersionLabel => 'v$appVersion $appChannel';
