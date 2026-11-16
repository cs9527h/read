#!/usr/bin/env python3
"""参数化生成 Read 桌面图标（普通版 / 墨水屏版）。

设计原则（简单、直观、好看）：
- 保留"羽毛"这一 Read 品牌识别元素，但只画剪影轮廓 + 一根羽轴 + 极少量短羽枝，
  绝不塞入密集鱼骨刻线（小尺寸下会糊成一团、像叶脉）。
- 普通版：克制的墨绿圆角底 + 象牙白实心羽毛，羽轴与羽枝用背景色，干净利落。
- 墨水屏版：纯黑底 + 白色线稿羽毛（轮廓 + 羽轴 + 少量羽枝），高对比、低装饰。
- 自适应前景层：透明底，羽毛限制在中心 66dp 安全区内，避免被系统形状裁切。

可复现：从仓库根目录运行 `python3 tools/android/gen_icons.py` 即可重生成全部 PNG。
"""
from __future__ import annotations

import math
import os
import sys

import cairosvg

# ---- 羽毛几何（0..100 局部坐标）--------------------------------------------
P0 = (38.0, 84.0)   # 羽根（左下）
P1 = (48.0, 44.0)   # 控制点
P2 = (62.0, 16.0)   # 羽尖（右上）
W_MAX = 15.5        # 最大羽片半宽
LEFT = 1.0          # 左羽片系数
RIGHT = 0.90        # 右羽片系数（轻微不对称更自然）


def bez(t: float) -> tuple[float, float]:
    u = 1 - t
    return (u * u * P0[0] + 2 * u * t * P1[0] + t * t * P2[0],
            u * u * P0[1] + 2 * u * t * P1[1] + t * t * P2[1])


def tang(t: float) -> tuple[float, float]:
    dx = 2 * (1 - t) * (P1[0] - P0[0]) + 2 * t * (P2[0] - P1[0])
    dy = 2 * (1 - t) * (P1[1] - P0[1]) + 2 * t * (P2[1] - P0[1])
    n = math.hypot(dx, dy) or 1.0
    return dx / n, dy / n


def half_width(t: float) -> float:
    # 两端收尖、中上段饱满；指数让羽尖更利落。
    return W_MAX * (math.sin(math.pi * (t ** 0.9)) ** 0.9)


def outline_points() -> list[tuple[float, float]]:
    """闭合轮廓：左缘自顶到底，再沿右缘回顶。"""
    n = 44
    left_pts, right_pts = [], []
    for i in range(n + 1):
        t = 1 - i / n  # 顶 -> 底
        x, y = bez(t)
        tx, ty = tang(t)
        nx, ny = -ty, tx
        w = half_width(t)
        left_pts.append((x + nx * w * LEFT, y + ny * w * LEFT))
        right_pts.append((x - nx * w * RIGHT, y - ny * w * RIGHT))
    return left_pts + list(reversed(right_pts))


def fmt(pts: list[tuple[float, float]]) -> str:
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)


def spare_barbs() -> list[str]:
    """极少量短羽枝：仅 4 对、长度到羽片宽度的 52%，朝羽尖轻微倾斜。"""
    out: list[str] = []
    for t in (0.30, 0.46, 0.62, 0.78):
        x, y = bez(t)
        tx, ty = tang(t)
        nx, ny = -ty, tx
        w = half_width(t)
        # 左
        lx, ly = x + nx * w * LEFT * 0.52 + tx * 2.2, y + ny * w * LEFT * 0.52 + ty * 2.2
        out.append(f'<line x1="{x:.2f}" y1="{y:.2f}" x2="{lx:.2f}" y2="{ly:.2f}"/>')
        # 右
        rx, ry = x - nx * w * RIGHT * 0.52 + tx * 2.2, y - ny * w * RIGHT * 0.52 + ty * 2.2
        out.append(f'<line x1="{x:.2f}" y1="{y:.2f}" x2="{rx:.2f}" y2="{ry:.2f}"/>')
    return out


def shaft_path() -> str:
    """羽轴：沿羽毛中轴从羽根到羽尖，稍微出头形成自然的尖。"""
    tail = (P0[0] - (P1[0] - P0[0]) * 0.06, P0[1] - (P1[1] - P0[1]) * 0.06)
    bx, by = bez(1.0)
    return (f'M {tail[0]:.2f} {tail[1]:.2f} '
            f'Q {P1[0]:.2f} {P1[1]:.2f} {bx:.2f} {by:.2f}')


def bbox(pts: list[tuple[float, float]]) -> tuple[float, float, float, float]:
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def fit_transform(target_h: float, cx: float = 50.0, cy: float = 50.0) -> str:
    x0, y0, x1, y1 = bbox(outline_points())
    h = y1 - y0
    s = target_h / h
    w = x1 - x0
    tx = cx - (x0 + x1) / 2 * s
    ty = cy - (y0 + y1) / 2 * s
    return f'translate({tx:.3f} {ty:.3f}) scale({s:.4f})'


BARBS = "\n      ".join(spare_barbs())
OUTLINE = fmt(outline_points())
SHAFT = shaft_path()


def svg(variant: str, foreground: bool) -> str:
    eink = variant == "eink"
    if foreground:
        bg = '<rect width="100" height="100" fill="none"/>'
        feather_h = 56.0
    else:
        bg = ('<rect width="100" height="100" fill="#000000"/>' if eink
              else '<rect width="100" height="100" fill="#1E3A2F"/>')
        feather_h = 72.0
    tf = fit_transform(feather_h)

    if eink:
        # 线稿羽毛：白描轮廓 + 羽轴 + 4 对短羽枝，高对比、低装饰。
        feather = f'''<g transform="{tf}" fill="none" stroke="#FFFFFF"
        stroke-linecap="round" stroke-linejoin="round">
      <polygon points="{OUTLINE}" stroke-width="2.1"/>
      <g stroke-width="1.25">
        {BARBS}
      </g>
      <path d="{SHAFT}" stroke-width="2.1"/>
    </g>'''
    else:
        # 象牙白实心羽毛 + 背景色羽轴与少量羽枝剪出层次，干净利落。
        feather = f'''<g transform="{tf}">
      <polygon points="{OUTLINE}" fill="#F4EFE1"/>
      <g stroke="#1E3A2F" stroke-width="1.15" stroke-linecap="round">
        {BARBS}
      </g>
      <path d="{SHAFT}" fill="none" stroke="#1E3A2F" stroke-width="1.5"
        stroke-linecap="round"/>
    </g>'''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" '
            f'width="100" height="100">\n  {bg}\n  {feather}\n</svg>')


FULL_SPECS = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]
FORE_SPECS = [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]


def write_png(svg_str: str, path: str, size: int) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cairosvg.svg2png(bytestring=svg_str.encode("utf-8"), write_to=path,
                     output_width=size, output_height=size)


def main() -> int:
    root = os.getcwd()
    if not os.path.isdir(os.path.join(root, "assets")):
        print("请在仓库根目录运行本脚本", file=sys.stderr)
        return 2
    for variant, folder in [("classic", "app_icon_classic"), ("eink", "app_icon")]:
        full = svg(variant, foreground=False)
        fore = svg(variant, foreground=True)
        for dpi, size in FULL_SPECS:
            write_png(full, os.path.join(root, "assets", folder, f"ic_launcher_{dpi}.png"), size)
        for dpi, size in FORE_SPECS:
            write_png(fore, os.path.join(root, "assets", folder, f"ic_launcher_foreground_{dpi}.png"), size)
        print(f"已生成 {folder}: {len(FULL_SPECS)} 完整图标 + {len(FORE_SPECS)} 前景层")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
