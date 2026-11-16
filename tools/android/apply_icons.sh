#!/usr/bin/env bash
# 把启动图标写进各个 mipmap，覆盖 Flutter 模板自带的图标。
#
# 两个变体对应两套图：
#   classic —— 原版：墨绿渐变底 + 象牙羽毛 + 柔和投影（assets/app_icon_classic）
#   eink    —— 墨水屏版：纯黑底 + 白色细线羽毛（assets/app_icon）
#
# 两个 workflow（build-android / release）里的每次 flutter build apk 之前都要执行，
# 并且要在构建对应变体之前调用，否则普通版和墨水屏版会共用同一张桌面图标。
set -euo pipefail

variant="${1:-classic}"

case "$variant" in
  classic) src="assets/app_icon_classic" ;;
  eink)    src="assets/app_icon" ;;
  *)
    echo "用法: bash tools/android/apply_icons.sh [classic|eink]" >&2
    exit 2
    ;;
esac

if [ ! -d "$src" ]; then
  echo "缺少图标目录: $src" >&2
  exit 1
fi

for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  dpi="${spec%%:*}"
  cp "$src/ic_launcher_${dpi}.png" "android/app/src/main/res/mipmap-${dpi}/ic_launcher.png"
done

echo "已应用 ${variant} 图标（${src}）"
ls -l android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
