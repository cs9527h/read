#!/usr/bin/env bash
# 把黑白羽毛图标写进各个 mipmap，覆盖 Flutter 模板自带的图标。
# 用法：apply_icons.sh [eink]
# 不带参数 = 普通版实底图标；带 eink = 白底细线图标。必须与随后构建的
# --dart-define=EINK 保持一致，否则两个 APK 的桌面图标会一样。
set -euo pipefail

variant=""
if [[ "${1:-}" == "eink" ]]; then
  variant="_eink"
fi

for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  dpi="${spec%%:*}"
  src="assets/app_icon/ic_launcher${variant}_${dpi}.png"
  test -f "$src" || { echo "缺少图标：$src" >&2; exit 1; }
  cp "$src" "android/app/src/main/res/mipmap-${dpi}/ic_launcher.png"
done

echo "已应用图标：${variant:-普通版}"
ls -l android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
