#!/usr/bin/env python3
"""确保 release 主清单包含 INTERNET，否则 WebDAV/S3 与 WiFi 传书都无法联网。"""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
body = manifest.read_text(encoding="utf-8")
if "android.permission.INTERNET" not in body:
    if "<application" not in body:
        raise SystemExit("应用清单缺少 <application>，请检查 Flutter 模板")
    body = body.replace(
        "<application",
        '    <uses-permission android:name="android.permission.INTERNET"/>\n\n    <application',
        1,
    )
    manifest.write_text(body, encoding="utf-8")
    print("已写入 INTERNET 权限")
else:
    print("INTERNET 权限已存在")
