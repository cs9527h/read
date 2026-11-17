#!/usr/bin/env python3
"""统一修补 CI 动态生成的 Android 壳，保证单包、低版本兼容与同步可靠性。

背景：本仓库不把 android/ 入库，build-android.yml / release.yml 每次用
`flutter create` 生成壳，再注入原生代码、图标、签名。过去这些补丁散落在
YAML 内联脚本里，容易漂移。这里集中管理，且保证幂等（可重复执行）。

做的几件真实的事：
1. 显式固定 minSdk = 24（Flutter 3.50 官方 Android 下限，Android 7.0）。
   Flutter 3.50 起 flutter.minSdkVersion 就是 24，API 23 及以下是引擎
   Unsupported 区间；写死 24 让"最低支持版本"成为可审计的确定值，避免
   某个插件把 minSdk 悄悄抬高导致老机型装不上。
2. 显式声明 ABI 包含 armeabi-v7a（32 位）+ arm64-v8a（64 位），覆盖老机型。
3. AndroidManifest 加 usesCleartextTraffic：targetSdk 36 下，Android 9+
   默认禁止明文 http。WebDAV/局域网 NAS 常用 http://，不加会同步失败。
4. 补齐 INTERNET / POST_NOTIFICATIONS 权限，供网盘同步与听书通知使用。
5. 规避 url_launcher_android / webview_flutter_android 的
   lintVitalAnalyzeRelease 解析崩溃（上游 bug，新 JDK 下 List.removeLast
   NoSuchMethodError），仅禁用这些插件的 lint 任务，flutter analyze /
   flutter test 全部保留。

用法：
    python3 tools/android/patch_android.py [项目根目录，默认仓库根]
"""
from pathlib import Path
import sys

MIN_SDK = 24  # Flutter 3.50 官方 Android 支持下限（Android 7.0 / API 24）

root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
app_gradle = root / "android/app/build.gradle.kts"
root_gradle = root / "android/build.gradle.kts"
manifest = root / "android/app/src/main/AndroidManifest.xml"

for f in (app_gradle, root_gradle, manifest):
    if not f.exists():
        sys.exit(f"缺少文件: {f}（请先运行 flutter create 生成 Android 壳）")

# ---------------------------------------------------------------------------
# 1) app/build.gradle.kts：显式 minSdk + ABI
# ---------------------------------------------------------------------------
body = app_gradle.read_text(encoding="utf-8")

if "minSdk = flutter.minSdkVersion" in body:
    body = body.replace(
        "minSdk = flutter.minSdkVersion",
        f"minSdk = {MIN_SDK}  // 显式固定：Flutter 3.50 官方 Android 下限（API 24 / Android 7.0）",
        1,
    )
elif f"minSdk = {MIN_SDK}" not in body:
    # 兼容其它模板写法：minSdkVersion = xx / minSdk = xx
    import re
    body, n = re.subn(r"minSdk(?:Version)?\s*=\s*\d+", f"minSdk = {MIN_SDK}", body, count=1)
    if n == 0:
        sys.exit("未能定位 minSdk 定义，拒绝继续（避免低版本适配失效）")

# ABI：只在 defaultConfig 块内首次插入，覆盖 32/64 位 ARM 设备
if "abiFilters" not in body:
    marker = '        applicationId = "app.readen.read"'
    if marker not in body:
        sys.exit("未能定位 applicationId，拒绝注入 ABI 过滤")
    body = body.replace(
        marker,
        marker
        + "\n        // 显式覆盖老机型（32 位）与主流机型（64 位）\n"
        + '        ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a") }',
        1,
    )

app_gradle.write_text(body, encoding="utf-8")

# ---------------------------------------------------------------------------
# 2) root/build.gradle.kts：上游插件 lint 规避（幂等）
# ---------------------------------------------------------------------------
# url_launcher_android / webview_flutter_android 的 lint 解析器在较新 JDK 下
# 触发 NoSuchMethodError (List.removeLast)，属上游 bug。仅禁用这些插件的
# Release lint 任务；flutter analyze 与全部单元测试不受影响。
rbody = root_gradle.read_text(encoding="utf-8")
if "lintVitalAnalyzeRelease" not in rbody:
    rbody += """

// 规避上游插件（url_launcher_android / webview_flutter_android）的 lint 解析器崩溃。
// 仅禁用这些插件的 Release lint 任务；flutter analyze 与全部单元测试不受影响。
subprojects {
    if (name in ["url_launcher_android", "webview_flutter_android"]) {
        tasks.configureEach {
            if (name == "lintVitalAnalyzeRelease") {
                enabled = false
            }
        }
    }
}
"""
    root_gradle.write_text(rbody, encoding="utf-8")

# ---------------------------------------------------------------------------
# 3) AndroidManifest.xml：明文流量 + 权限
# ---------------------------------------------------------------------------
m = manifest.read_text(encoding="utf-8")

# 权限（放在 <manifest ...> 之后、<application 之前）
perms = []
if "android.permission.INTERNET" not in m:
    perms.append('<uses-permission android:name="android.permission.INTERNET"/>')
if "android.permission.POST_NOTIFICATIONS" not in m:
    perms.append('<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>')
if perms:
    app_idx = m.find("<application")
    if app_idx == -1:
        sys.exit("未能定位 <application>，拒绝注入权限")
    m = m[:app_idx] + "\n".join(perms) + "\n    " + m[app_idx:]

# Android 11+ 包可见性：url_launcher 打开 QQ/浏览器链接需要声明 VIEW intent。
if "<queries>" not in m:
    app_idx = m.find("<application")
    if app_idx == -1:
        sys.exit("未能定位 <application>，拒绝注入 queries")
    queries = (
        "    <queries>\n"
        "        <intent>\n"
        "            <action android:name=\"android.intent.action.VIEW\" />\n"
        "            <data android:scheme=\"https\" />\n"
        "        </intent>\n"
        "    </queries>\n\n    "
    )
    m = m[:app_idx] + queries + m[app_idx:]

# usesCleartextTraffic：targetSdk 36 下 Android 9+ 默认禁止明文 http，
# WebDAV / 局域网 NAS 自签或 http 同步会失败。
if 'android:usesCleartextTraffic' not in m:
    m = m.replace(
        '<application\n',
        '<application\n        android:usesCleartextTraffic="true"\n',
        1,
    )

manifest.write_text(m, encoding="utf-8")

print("android patched:", {
    "minSdk": MIN_SDK,
    "abi": ["armeabi-v7a", "arm64-v8a"],
    "cleartext": True,
    "permissions": ["INTERNET", "POST_NOTIFICATIONS"],
})
