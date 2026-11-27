#!/usr/bin/env python3
"""Draws the Daybook app icon and launch logo in the same language as Stash's icon:
dark gradient, a dark card with a thick light outline, coloured dots and a grey title bar,
centred with equal spacing throughout.
Run from the repo root: python3 scripts/make_icon.py"""
from PIL import Image, ImageDraw
import os

S = 4  # supersampling
TOP, BOTTOM = "#39393b", "#141416"
CARD, OUTLINE, BAR, DIM = "#2c2c2e", "#ebebf0", "#8e8e93", "#48484a"
BLUE, PURPLE, ORANGE, GREEN, RED = "#5ea2ff", "#bf9bff", "#ff9f0a", "#30d158", "#ff453a"

# Day dots, 4 columns x 3 rows. None = an empty day.
GRID = [
    [BLUE, None, PURPLE, None],
    [None, "today", None, GREEN],
    [ORANGE, None, BLUE, None],
]

def rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

# Layout in a 1024-unit square. The card fills 192..832 on both axes, so the gap to the
# icon's edge is the same on all four sides. Every gap inside is equal too:
# - dots: the space between dots, and between the outer dots and the card's inner edge,
#   is the same across and down;
# - header: the grey bar sits with equal space above it and below it.
L, T, R, B = 192, 192, 832, 832
LINE = 34                      # outline weight
DOT = 42                       # dot radius
IN_L, IN_R, IN_B = L + LINE, R - LINE, B - LINE      # the outline is drawn inwards
GAP = (IN_R - IN_L - 8 * DOT) / 5                    # 4 dots, 5 equal gaps across
BODY_H = 4 * GAP + 6 * DOT                           # 3 rows, 4 equal gaps down
DIVIDER_B = IN_B - BODY_H                            # bottom edge of the header line
DIVIDER_T = DIVIDER_B - LINE
BAR_H, BAR_W = 28, 280

def draw_calendar(d, ox, oy, k):
    """Draws the card in the 1024-unit design space, scaled by k and offset by (ox, oy)."""
    P = lambda x, y: (ox + x * k, oy + y * k)
    def rrect(x0, y0, x1, y1, r, **kw):
        if "width" in kw: kw["width"] = round(kw["width"] * k)
        d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=r * k, **kw)
    def dot(cx, cy, r, **kw):
        if "width" in kw: kw["width"] = round(kw["width"] * k)
        d.ellipse([*P(cx - r, cy - r), *P(cx + r, cy + r)], **kw)

    rrect(L, T, R, B, 116, fill=rgb(CARD), outline=rgb(OUTLINE), width=LINE)
    rrect(L, DIVIDER_T, R, DIVIDER_B, 0, fill=rgb(OUTLINE))
    bar_mid = (T + LINE + DIVIDER_T) / 2
    rrect(512 - BAR_W / 2, bar_mid - BAR_H / 2, 512 + BAR_W / 2, bar_mid + BAR_H / 2, BAR_H / 2, fill=rgb(BAR))
    for ri, row in enumerate(GRID):
        for ci, c in enumerate(row):
            cx = IN_L + GAP + DOT + ci * (2 * DOT + GAP)
            cy = DIVIDER_B + GAP + DOT + ri * (2 * DOT + GAP)
            if c is None:
                dot(cx, cy, DOT, fill=rgb(DIM))
            elif c == "today":
                # A solid light ring hugging the red dot, with no dark gap between them.
                dot(cx, cy, DOT + 14, fill=rgb(OUTLINE))
                dot(cx, cy, DOT, fill=rgb(RED))
            else:
                dot(cx, cy, DOT, fill=rgb(c))

def icon(path, size=1024):
    W = size * S
    img = Image.new("RGB", (W, W))
    d = ImageDraw.Draw(img)
    t, b = rgb(TOP), rgb(BOTTOM)
    for y in range(W):
        f = y / (W - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(t[i] * (1 - f) + b[i] * f) for i in range(3)))
    draw_calendar(d, 0, 0, S)
    img.resize((size, size), Image.LANCZOS).save(path)

def logo(path, size=600):
    # The card alone on transparency, for the launch screen (cropped to the card's bounds).
    W = size * S
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = W / (R - L + 120)
    draw_calendar(d, -(L - 60) * k, -(T - 60) * k, k)
    img.resize((size, size), Image.LANCZOS).save(path)

import sys
if len(sys.argv) > 1:  # preview only: python3 scripts/make_icon.py out.png
    icon(sys.argv[1]); sys.exit()
base = "Daybook/Resources/Assets.xcassets"
icon(f"{base}/AppIcon.appiconset/AppIcon.png")
os.makedirs(f"{base}/LaunchLogo.imageset", exist_ok=True)
logo(f"{base}/LaunchLogo.imageset/LaunchLogo.png")
