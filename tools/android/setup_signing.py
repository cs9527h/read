#!/usr/bin/env python3
"""把固定的预览签名写进 Android 壳。

Flutter 模板默认让 release 用 debug 签名，而 debug.keystore 是每个 runner 临时生成的，
于是每次 CI 产出的 APK 签名都不一样，用户覆盖安装会被系统拒绝。
这里改用仓库内保存的固定预览密钥（仅用于预览版，不是正式签名）。
"""
from pathlib import Path
import base64
import sys

ROOT = Path(__file__).resolve().parents[2]
B64 = ROOT / "tools/android/read-preview.jks.b64"
GRADLE = ROOT / "android/app/build.gradle.kts"

keystore_dir = ROOT / "android/keystore"
keystore_dir.mkdir(parents=True, exist_ok=True)
(keystore_dir / "read-preview.jks").write_bytes(base64.b64decode(B64.read_text().strip()))

body = GRADLE.read_text(encoding="utf-8")

if "read-preview.jks" not in body:
    if "    buildTypes {" not in body:
        sys.exit("unexpected build.gradle.kts: buildTypes block missing")
    body = body.replace(
        "    buildTypes {",
        '''    signingConfigs {
        create("release") {
            storeFile = file("keystore/read-preview.jks")
            storePassword = "read-preview-2026"
            keyAlias = "read-preview"
            keyPassword = "read-preview-2026"
        }
    }

    buildTypes {''',
        1,
    )
    before = 'signingConfig = signingConfigs.getByName("debug")'
    if before not in body:
        sys.exit("unexpected build.gradle.kts: release signing line missing")
    body = body.replace(before, 'signingConfig = signingConfigs.getByName("release")', 1)
    GRADLE.write_text(body, encoding="utf-8")

print("preview signing configured:", keystore_dir / "read-preview.jks")
