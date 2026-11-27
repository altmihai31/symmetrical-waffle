#!/usr/bin/env python3
"""Draws the Daybook app icon and launch logo: a dark calendar card with a blue
header and rows of tiles with coloured top bars, like the app's week view.
Run from the repo root: python3 scripts/make_icon.py"""
from PIL import Image, ImageDraw
import os

S = 4  # supersampling factor
BLUE, GREEN, ORANGE, RED, PURPLE = "#4d82ff", "#2fb35a", "#ff9500", "#ff2d55", "#a259e6"
CARD, EMPTY = "#23262b", "#2e3137"

def hex2rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def mix(a, b, t):
    a, b = hex2rgb(a), hex2rgb(b)
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))

ROWS = [
    [RED, BLUE, BLUE, None],
    ["task:" + ORANGE, GREEN, PURPLE, BLUE],
    [BLUE, None, GREEN, ORANGE],
]

def draw_card(d, x0, y0, w, h, s):
    r = 0.115 * w
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=r, fill=hex2rgb(CARD))
    head = 0.2 * h
    # Blue header with square bottom corners.
    d.rounded_rectangle([x0, y0, x0 + w, y0 + head], radius=r, fill=hex2rgb(BLUE),
                        corners=(True, True, False, False))
    # Today marker: a white pill on the header.
    pw, ph = 0.22 * w, 0.055 * h
    d.rounded_rectangle([x0 + 0.08 * w, y0 + head / 2 - ph / 2, x0 + 0.08 * w + pw, y0 + head / 2 + ph / 2],
                        radius=ph / 2, fill=(255, 255, 255))
    pad, gap = 0.06 * w, 0.025 * w
    gx0, gy0 = x0 + pad, y0 + head + pad * 0.9
    gw, gh = w - 2 * pad, (y0 + h - pad) - gy0
    cols, rows = 4, len(ROWS)
    tw, th = (gw - gap * (cols - 1)) / cols, (gh - gap * (rows - 1)) / rows
    bar = 0.13 * th
    for ri, row in enumerate(ROWS):
        for ci, spec in enumerate(row):
            tx, ty = gx0 + ci * (tw + gap), gy0 + ri * (th + gap)
            rad = 0.08 * tw
            if spec is None:
                d.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=rad, fill=hex2rgb(EMPTY))
                continue
            task = spec.startswith("task:")
            col = spec.split(":")[-1]
            fill = hex2rgb(EMPTY) if task else mix(CARD, col, 0.38)
            tx, ty, tw_, th_ = round(tx), round(ty), round(tw), round(th)
            d.rounded_rectangle([tx, ty, tx + tw_, ty + th_], radius=rad, fill=hex2rgb(col))
            d.rounded_rectangle([tx, ty + round(bar), tx + tw_, ty + th_], radius=rad, fill=fill,
                                corners=(False, False, True, True))
            if task:  # checkbox outline
                cb = 0.34 * tw
                cx, cy = tx + 0.16 * tw, ty + bar + 0.16 * th
                d.rounded_rectangle([cx, cy, cx + cb, cy + cb], radius=cb * 0.28,
                                    outline=hex2rgb(col), width=round(0.06 * tw))

def icon(path, size=1024):
    W = size * S
    img = Image.new("RGB", (W, W))
    d = ImageDraw.Draw(img)
    top, bot = hex2rgb("#2b2e35"), hex2rgb("#121316")
    for y in range(W):
        t = y / (W - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
    w = 0.74 * W
    draw_card(d, (W - w) / 2, 0.15 * W, w, 0.72 * W, S)
    img.resize((size, size), Image.LANCZOS).save(path)

def logo(path, size=600):
    W = size * S
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_card(d, 0, 0.0257 * W, W, 0.973 * W * 0.973, S)
    img.resize((size, size), Image.LANCZOS).save(path)

base = "Daybook/Resources/Assets.xcassets"
icon(f"{base}/AppIcon.appiconset/AppIcon.png")
os.makedirs(f"{base}/LaunchLogo.imageset", exist_ok=True)
logo(f"{base}/LaunchLogo.imageset/LaunchLogo.png")
