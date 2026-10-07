"""Rasterizes the Tabiya icon (assets/icon/tabiya_icon.svg) into the PNGs used
by flutter_launcher_icons. No SVG library is needed: the glyph is two strokes
(lines + quadratic curves, round caps/joins) and a rounded square, drawn here
with 4x supersampling. Keep the geometry in sync with the SVG.

Usage: python3 tool/icon/build_icon.py && dart run flutter_launcher_icons
"""
from pathlib import Path

from PIL import Image, ImageDraw

NAVY = (0x1B, 0x22, 0x33)
CREAM = (0xEC, 0xE8, 0xDF)
GOLD = (0xC9, 0xA4, 0x5C)
SIZE = 1024
SS = 4  # supersampling
STROKE = 96

# Branch path from the SVG, as polyline segments: ("L", end) or ("Q", ctrl, end).
PATHS = [
    [(512, 576), ("L", (512, 426)), ("Q", (512, 276), (362, 276)), ("L", (280, 276))],
    [(512, 426), ("Q", (512, 276), (662, 276)), ("L", (744, 276))],
]
SQUARE = (444, 660, 136, 136, 22)  # x, y, w, h, rx

OUT = Path(__file__).resolve().parents[2] / "assets" / "icon"


def _points(path):
    pts = [path[0]]
    cur = path[0]
    for seg in path[1:]:
        if seg[0] == "L":
            end = seg[1]
            n = 200
            pts += [(cur[0] + (end[0] - cur[0]) * t / n, cur[1] + (end[1] - cur[1]) * t / n) for t in range(1, n + 1)]
        else:
            c, end = seg[1], seg[2]
            n = 400
            for i in range(1, n + 1):
                t = i / n
                x = (1 - t) ** 2 * cur[0] + 2 * (1 - t) * t * c[0] + t * t * end[0]
                y = (1 - t) ** 2 * cur[1] + 2 * (1 - t) * t * c[1] + t * t * end[1]
                pts.append((x, y))
        cur = end
    return pts


def draw_glyph(img, scale, stroke_color, square_color):
    """Draws the glyph scaled around the centre (like the SVG's scale())."""
    d = ImageDraw.Draw(img)
    k = SS
    c = SIZE / 2

    def tr(p):
        return ((c + (p[0] - c) * scale) * k, (c + (p[1] - c) * scale) * k)

    r = STROKE / 2 * scale * k
    for path in PATHS:
        pts = [tr(p) for p in _points(path)]
        # Round caps and joins: the stroke is the union of discs along the path.
        d.line(pts, fill=stroke_color, width=int(round(2 * r)), joint="curve")
        for x, y in pts[:: 4] + [pts[-1]]:
            d.ellipse((x - r, y - r, x + r, y + r), fill=stroke_color)
    x, y, w, h, rx = SQUARE
    x0, y0 = tr((x, y))
    x1, y1 = tr((x + w, y + h))
    d.rounded_rectangle((x0, y0, x1, y1), radius=rx * scale * k, fill=square_color)


def render(background, scale, stroke_color=CREAM, square_color=GOLD, mode="RGB"):
    big = Image.new(mode, (SIZE * SS, SIZE * SS), background)
    draw_glyph(big, scale, stroke_color, square_color)
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    # iOS / legacy Android: full-bleed icon exactly as the reference.
    render(NAVY, 1.0).save(OUT / "icon.png")
    # Android adaptive: flutter_launcher_icons insets the layer by 16 % on each
    # side, so at scale 1.0 the glyph (radius ~379 of 512) ends at ~27 dp from
    # the centre, inside the 33 dp safe zone of the 108 dp layer.
    Image.new("RGB", (SIZE, SIZE), NAVY).save(OUT / "icon_background.png")
    render((0, 0, 0, 0), 1.0, CREAM + (255,), GOLD + (255,), mode="RGBA").save(OUT / "icon_foreground.png")
    # Android 13 themed icon: one colour on transparent.
    white = (255, 255, 255, 255)
    render((0, 0, 0, 0), 1.0, white, white, mode="RGBA").save(OUT / "icon_monochrome.png")


if __name__ == "__main__":
    main()
