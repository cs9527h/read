#!/usr/bin/env bash
# 把黑白羽毛图标写进各个 mipmap，覆盖 Flutter 模板自带的图标。
# 两个 workflow（build-android / release）都必须执行这一步，否则 APK 里还是默认蓝标。
set -euo pipefail

for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  dpi="${spec%%:*}"
  cp "assets/app_icon/ic_launcher_${dpi}.png" "android/app/src/main/res/mipmap-${dpi}/ic_launcher.png"
done

ls -l android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
