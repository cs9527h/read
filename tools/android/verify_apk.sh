#!/usr/bin/env bash
# 构建产物硬校验：任何一项不满足都必须让 CI 失败，不能只打印信息。
#
# 校验项：
#   1. APK 存在且非空
#   2. 包名必须是 app.readen.read（覆盖升级兼容）
#   3. minSdk 必须为 24（Android 7.0，Flutter 3.50 官方下限）
#   4. 必须同时包含 armeabi-v7a 与 arm64-v8a
#   5. versionCode 不低于上一版（15）
#   6. 签名可验证（apksigner）
#   7. 输出 SHA-256
set -euo pipefail

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
EXPECTED_PACKAGE="app.readen.read"
EXPECTED_MIN_SDK=24
MIN_VERSION_CODE=15

fail() {
  echo "APK 校验失败：$*" >&2
  exit 1
}

[ -f "$APK" ] || fail "找不到 $APK"
[ -s "$APK" ] || fail "$APK 为空文件"
echo "=== 产物 ==="
ls -lh "$APK"

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$SDK_ROOT" ] || fail "ANDROID_HOME / ANDROID_SDK_ROOT 未设置"

AAPT="$(find "$SDK_ROOT/build-tools" -name aapt -type f | sort | tail -1)"
APKSIGNER="$(find "$SDK_ROOT/build-tools" -name apksigner -type f | sort | tail -1)"
[ -x "$AAPT" ] || fail "找不到 aapt"
BADGING="$("$AAPT" dump badging "$APK")"

PACKAGE="$(printf '%s\n' "$BADGING" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
[ "$PACKAGE" = "$EXPECTED_PACKAGE" ] || fail "包名是 $PACKAGE，应为 $EXPECTED_PACKAGE"

MIN_SDK="$(printf '%s\n' "$BADGING" | sed -n "s/.*sdkVersion:'\([0-9]*\)'.*/\1/p" | head -1)"
[ -n "$MIN_SDK" ] || fail "无法读取 minSdkVersion"
[ "$MIN_SDK" = "$EXPECTED_MIN_SDK" ] || fail "minSdk 是 $MIN_SDK，应为 $EXPECTED_MIN_SDK"

VERSION_CODE="$(printf '%s\n' "$BADGING" | sed -n "s/^package:.*versionCode='\([0-9]*\)'.*/\1/p" | head -1)"
[ -n "$VERSION_CODE" ] || fail "无法读取 versionCode"
[ "$VERSION_CODE" -ge "$MIN_VERSION_CODE" ] || fail "versionCode 是 $VERSION_CODE，低于 $MIN_VERSION_CODE"

ABIS="$(unzip -l "$APK" | grep -oE 'lib/(armeabi-v7a|arm64-v8a)' | sort -u || true)"
printf '%s\n' "$ABIS"
printf '%s\n' "$ABIS" | grep -q 'lib/armeabi-v7a' || fail "缺少 armeabi-v7a"
printf '%s\n' "$ABIS" | grep -q 'lib/arm64-v8a' || fail "缺少 arm64-v8a"

if [ -x "$APKSIGNER" ]; then
  "$APKSIGNER" verify --print-certs "$APK" > /tmp/apk-certs.txt || fail "签名校验失败"
  head -3 /tmp/apk-certs.txt
else
  fail "找不到 apksigner，无法验证签名"
fi

echo "=== SHA-256 ==="
sha256sum "$APK"

echo "APK 校验通过：package=$PACKAGE minSdk=$MIN_SDK versionCode=$VERSION_CODE abi=32/64"
