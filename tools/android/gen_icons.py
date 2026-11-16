#!/usr/bin/env python3
"""参数化生成 Read 桌面图标（普通版 / 墨水屏版）。

设计目标（任务书 407-409）：
- 保留"羽毛"品牌识别元素，但改为一段式优雅羽形，去掉廉价渐变与杂乱鱼骨叶脉。
- 普通版：克制的墨绿底 + 象牙白实心羽片，内部以背景色细羽枝刻出纹理，小尺寸也清晰。
- 墨水屏版：纯黑底 + 白色线稿羽毛，低装饰、高对比、与彩色版造型区别明显。
- 自适应前景层：透明底，羽毛限制在中心 66dp 安全区内，避免被系统形状裁切。

可复现：从仓库根目录运行 `python3 tools/android/gen_icons.py` 即可重生成全部 PNG。
"""
from __future__ import annotations

import math
import os
import sys

import cairosvg

# ---- 羽毛几何（0..100 局部坐标）--------------------------------------------
P0 = (40.0, 83.0)   # 羽根（笔尖）
P1 = (46.0, 45.0)   # 控制点
P2 = (60.0, 17.0)   # 羽尖
W_MAX = 16.5        # 最大羽片半宽
LEFT = 1.0          # 左羽片系数
RIGHT = 0.80        # 右羽片系数（不对称更自然）


def bez(t: float) -> tuple[float, float]:
    u = 1 - t
    return (u * u * P0[0] + 2 * u * t * P1[0] + t * t * P2[0],
            u * u * P0[1] + 2 * u * t * P1[1] + t * t * P2[1])


def tang(t: float) -> tuple[float, float]:
    dx = 2 * (1 - t) * (P1[0] - P0[0]) + 2 * t * (P2[0] - P1[0])
    dy = 2 * (1 - t) * (P1[1] - P0[1]) + 2 * t * (P2[1] - P1[1])
    n = math.hypot(dx, dy) or 1.0
    return dx / n, dy / n


def half_width(t: float) -> float:
    # 两端收尖，中上段最饱满；指数让顶部更尖、底部略钝。
    return W_MAX * (math.sin(math.pi * (t ** 0.92)) ** 0.85)


def outline_points() -> list[tuple[float, float]]:
    """返回闭合轮廓点：左缘自顶到底，再沿右缘回顶。"""
    n = 48
    left_pts, right_pts = [], []
    for i in range(n + 1):
        t = 1 - i / n  # 顶 -> 底
        x, y = bez(t)
        tx, ty = tang(t)
        nx, ny = -ty, tx  # 左法向
        w = half_width(t)
        left_pts.append((x + nx * w * LEFT, y + ny * w * LEFT))
        rx, ry = bez(t)
        right_pts.append((rx - nx * w * RIGHT, ry - ny * w * RIGHT))
    # right_pts 目前是 顶->底，需要 底->顶 闭合
    return left_pts + list(reversed(right_pts))


def fmt(pts: list[tuple[float, float]]) -> str:
    return " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)


def barb_lines() -> list[str]:
    """羽枝：自羽轴向外、略朝羽尖倾斜的细线。"""
    out: list[str] = []
    for i in range(1, 26):
        t = 0.10 + i * 0.032
        if t > 0.94:
            break
        x, y = bez(t)
        tx, ty = tang(t)
        nx, ny = -ty, tx
        w = half_width(t)
        # 左
        lx, ly = x + nx * w * LEFT * 0.86 + tx * 3.0, y + ny * w * LEFT * 0.86 + ty * 3.0
        out.append(f'<line x1="{x:.2f}" y1="{y:.2f}" x2="{lx:.2f}" y2="{ly:.2f}"/>')
        # 右
        rx, ry = x - nx * w * RIGHT * 0.86 + tx * 3.0, y - ny * w * RIGHT * 0.86 + ty * 3.0
        out.append(f'<line x1="{x:.2f}" y1="{y:.2f}" x2="{rx:.2f}" y2="{ry:.2f}"/>')
    return out


def shaft_path() -> str:
    """羽轴：从羽根略伸出羽片形成笔尖。"""
    # 从 t=-0.06 外推一点点
    tail = (P0[0] - (P1[0] - P0[0]) * 0.10, P0[1] - (P1[1] - P0[1]) * 0.10)
    bx, by = bez(1.0)
    return (f'M {tail[0]:.2f} {tail[1]:.2f} '
            f'Q {P1[0]:.2f} {P1[1]:.2f} {bx:.2f} {by:.2f}')


def bbox(pts: list[tuple[float, float]]) -> tuple[float, float, float, float]:
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def fit_transform(target_h: float, cx: float = 50.0, cy: float = 50.0) -> str:
    """把羽毛自然 bbox 等比缩放并居中到 (cx, cy)，目标高度 target_h。"""
    x0, y0, x1, y1 = bbox(outline_points())
    h = y1 - y0
    s = target_h / h
    w = x1 - x0
    tx = cx - (x0 + x1) / 2 * s
    ty = cy - (y0 + y1) / 2 * s
    return f'translate({tx:.3f} {ty:.3f}) scale({s:.4f})'


BARBS = "\n      ".join(barb_lines())
OUTLINE = fmt(outline_points())
SHAFT = shaft_path()


def svg(variant: str, foreground: bool) -> str:
    eink = variant == "eink"
    if foreground:
        bg = '<rect width="100" height="100" fill="none"/>'
        feather_h = 58.0
    else:
        bg = ('<rect width="100" height="100" fill="#000000"/>' if eink
              else '<rect width="100" height="100" fill="#1E3A2F"/>')
        feather_h = 76.0
    tf = fit_transform(feather_h)

    if eink:
        # 线稿羽毛：白描轮廓 + 白色羽轴 + 少量羽枝，低装饰高对比。
        feather = f'''<g transform="{tf}" fill="none" stroke="#FFFFFF"
        stroke-linecap="round" stroke-linejoin="round">
      <polygon points="{OUTLINE}" stroke-width="1.9"/>
      <g stroke-width="0.85" opacity="0.9">
        {BARBS}
      </g>
      <path d="{SHAFT}" stroke-width="2.0"/>
    </g>'''
    else:
        # 实心象牙白羽片 + 背景色羽枝纹理 + 背景色羽轴。
        feather = f'''<g transform="{tf}">
      <polygon points="{OUTLINE}" fill="#F4EFE1"/>
      <g stroke="#1E3A2F" stroke-width="0.72" stroke-linecap="round" opacity="0.92">
        {BARBS}
      </g>
      <path d="{SHAFT}" fill="none" stroke="#1E3A2F" stroke-width="1.25"
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
