#!/usr/bin/env bash
# 把启动图标写进各个 mipmap，覆盖 Flutter 模板自带的图标。
#
# 两个变体对应两套图：
#   classic —— 原版：墨绿渐变底 + 象牙羽毛 + 柔和投影（assets/app_icon_classic）
#   eink    —— 墨水屏版：纯黑底 + 白色细线羽毛（assets/app_icon）
#
# 除完整图标（Android 7 及以下的 fallback）外，还写入 Android 8+ 的
# 自适应图标：前景层（透明底羽毛，居中 66dp 安全区）+ 背景色，避免系统
# 裁切形状时切到羽毛（任务 109）。
#
# 两个 workflow（build-android / release）里的每次 flutter build apk 之前都要执行，
# 并且要在构建对应变体之前调用，否则普通版和墨水屏版会共用同一张桌面图标。
set -euo pipefail

variant="${1:-classic}"

case "$variant" in
  classic) src="assets/app_icon_classic"; bg="#1E3A2F" ;;
  eink)    src="assets/app_icon";         bg="#000000" ;;
  *)
    echo "用法: bash tools/android/apply_icons.sh [classic|eink]" >&2
    exit 2
    ;;
esac

if [ ! -d "$src" ]; then
  echo "缺少图标目录: $src" >&2
  exit 1
fi

res="android/app/src/main/res"

# 1) 完整图标（Android 7 及以下 fallback）
for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  dpi="${spec%%:*}"
  cp "$src/ic_launcher_${dpi}.png" "$res/mipmap-${dpi}/ic_launcher.png"
done

# 2) 自适应图标前景层（各密度）
for dpi in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  if [ -f "$src/ic_launcher_foreground_${dpi}.png" ]; then
    cp "$src/ic_launcher_foreground_${dpi}.png" \
      "$res/mipmap-${dpi}/ic_launcher_foreground.png"
  fi
done

# 3) 背景色
mkdir -p "$res/values"
cat > "$res/values/ic_launcher_background.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">$bg</color>
</resources>
XML

# 4) 自适应图标描述（Android 8+）
mkdir -p "$res/mipmap-anydpi-v26"
cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML

echo "已应用 ${variant} 图标（${src}，含自适应图标）"
ls -l "$res/mipmap-xxxhdpi/ic_launcher.png" "$res/mipmap-anydpi-v26/ic_launcher.xml"
