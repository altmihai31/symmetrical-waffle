#!/usr/bin/env python3
"""Draws the Daybook app icon and launch logo in the same language as Stash's icon:
dark gradient, a dark card with a thick light outline, coloured dots and grey text bars.
Run from the repo root: python3 scripts/make_icon.py"""
from PIL import Image, ImageDraw
import os

S = 4  # supersampling
TOP, BOTTOM = "#39393b", "#141416"
CARD, OUTLINE, BAR, DIM = "#2c2c2e", "#ebebf0", "#8e8e93", "#48484a"
BLUE, PURPLE, ORANGE, GREEN = "#5ea2ff", "#bf9bff", "#ff9f0a", "#30d158"

# Day dots, 4 columns x 3 rows. None = an empty day.
GRID = [
    [BLUE, None, PURPLE, None],
    [None, "today", None, GREEN],
    [ORANGE, None, BLUE, None],
]

def rgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def draw_calendar(d, ox, oy, k):
    """Draws the card in a 1024-unit design space, scaled by k and offset by (ox, oy)."""
    P = lambda x, y: (ox + x * k, oy + y * k)
    def rrect(x0, y0, x1, y1, r, **kw):
        if "width" in kw: kw["width"] = round(kw["width"] * k)
        d.rounded_rectangle([*P(x0, y0), *P(x1, y1)], radius=r * k, **kw)
    def dot(cx, cy, r, **kw):
        if "width" in kw: kw["width"] = round(kw["width"] * k)
        d.ellipse([*P(cx - r, cy - r), *P(cx + r, cy + r)], **kw)

    # Card with the same 20-unit light outline as Stash's cards.
    rrect(192, 212, 832, 852, 110, fill=rgb(CARD), outline=rgb(OUTLINE), width=20)
    # Header: a divider line, like a calendar page's top.
    rrect(202, 352, 822, 372, 0, fill=rgb(OUTLINE))
    # Binder tabs over the top edge.
    for x in (372, 652):
        rrect(x - 20, 158, x + 20, 268, 20, fill=rgb(OUTLINE))
    # Month title: a coloured dot and a grey bar, as on Stash's cards.
    dot(282, 290, 30, fill=rgb(BLUE))
    rrect(338, 280, 560, 300, 10, fill=rgb(BAR))
    # Days.
    xs, ys, r = [287 + i * 150 for i in range(4)], [470, 600, 730], 34
    for ri, row in enumerate(GRID):
        for ci, c in enumerate(row):
            cx, cy = xs[ci], ys[ri]
            if c is None:
                dot(cx, cy, r, fill=rgb(DIM))
            elif c == "today":
                dot(cx, cy, r, fill=rgb(DIM))
                dot(cx, cy, r + 16, outline=rgb(OUTLINE), width=12)
            else:
                dot(cx, cy, r, fill=rgb(c))

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
    k = W / 760
    draw_calendar(d, -132 * k, -126 * k, k)
    img.resize((size, size), Image.LANCZOS).save(path)

base = "Daybook/Resources/Assets.xcassets"
icon(f"{base}/AppIcon.appiconset/AppIcon.png")
os.makedirs(f"{base}/LaunchLogo.imageset", exist_ok=True)
logo(f"{base}/LaunchLogo.imageset/LaunchLogo.png")
