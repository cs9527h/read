#!/usr/bin/env python3
"""生成两套可区分的启动图标：普通版实底精致羽毛，墨水屏版白底细线羽毛。"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "app_icon"
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def bezier(p0, p1, p2, steps=40):
    points = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        points.append((x, y))
    return points


def draw_icon(eink: bool, size: int) -> Image.Image:
    scale = 8
    canvas = size * scale
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = int(canvas * 0.18)

    if eink:
        background = (255, 255, 255, 255)
        ink = (10, 10, 10, 255)
        draw.rounded_rectangle(
            [0, 0, canvas - 1, canvas - 1], radius=radius, fill=background
        )
        width = max(2, int(canvas * 0.012))
        draw.rounded_rectangle(
            [width, width, canvas - 1 - width, canvas - 1 - width],
            radius=max(0, radius - width),
            outline=ink,
            width=width,
        )
    else:
        background = (18, 18, 18, 255)
        ink = (246, 246, 242, 255)
        draw.rounded_rectangle(
            [0, 0, canvas - 1, canvas - 1], radius=radius, fill=background
        )
        width = max(3, int(canvas * 0.020))
        draw.rounded_rectangle(
            [int(canvas * 0.035), int(canvas * 0.035),
             canvas - int(canvas * 0.035), canvas - int(canvas * 0.035)],
            radius=max(0, radius - int(canvas * 0.035)),
            outline=(255, 255, 255, 48),
            width=max(1, int(canvas * 0.006)),
        )

    # 羽毛：主羽轴 + 两侧弧线，形状在小尺寸下仍可辨认。
    shaft_start = (canvas * 0.28, canvas * 0.76)
    shaft_end = (canvas * 0.71, canvas * 0.24)
    vane_top = (canvas * 0.40, canvas * 0.30)
    vane_left = (canvas * 0.24, canvas * 0.56)
    vane_right = (canvas * 0.62, canvas * 0.70)

    shaft = bezier(shaft_start, (canvas * 0.48, canvas * 0.52), shaft_end)
    draw.line(shaft, fill=ink, width=width)
    draw.line(bezier(shaft_start, vane_left, (canvas * 0.43, canvas * 0.38)),
              fill=ink, width=width)
    draw.line(bezier((canvas * 0.43, canvas * 0.38), vane_top, shaft_end),
              fill=ink, width=width)
    draw.line(bezier((canvas * 0.42, canvas * 0.52), vane_right, shaft_end),
              fill=ink, width=max(2, width - 1))
    # 羽毛中部的细羽枝，普通版更密，墨水屏更克制。
    for t in (0.22, 0.36, 0.50, 0.64):
        if eink and t > 0.5:
            continue
        x = (1 - t) ** 2 * shaft_start[0] + 2 * (1 - t) * t * (canvas * 0.48) + t * t * shaft_end[0]
        y = (1 - t) ** 2 * shaft_start[1] + 2 * (1 - t) * t * (canvas * 0.52) + t * t * shaft_end[1]
        dx = canvas * 0.075
        draw.line([(x, y), (x - dx, y + dx * 0.55)],
                  fill=ink, width=max(1, width - 2))

    if not eink:
        # 普通版右下角一个极小的留白圆点，增加层次。
        dot = canvas * 0.018
        draw.ellipse(
            [canvas * 0.80 - dot, canvas * 0.80 - dot,
             canvas * 0.80 + dot, canvas * 0.80 + dot],
            fill=(246, 246, 242, 180),
        )

    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    for variant in ("", "_eink"):
        for dpi, size in SIZES.items():
            path = OUT / f"ic_launcher{variant}_{dpi}.png"
            draw_icon(bool(variant), size).save(path, optimize=True)
            print(path, size)


if __name__ == "__main__":
    main()
