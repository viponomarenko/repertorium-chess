"""Google Play graphics from the App Store screenshots and the app icon.

- icon-512.png: hi-res icon, 512x512 PNG.
- feature-graphic-{uk,en}.png: 1024x500, navy as the icon, glyph + name + tagline.
- phone/*.png: iPhone screenshots without the iOS status bar, scaled to
  1080x2160. Play wants the long side at most twice the short one; the
  iPhone originals (1206x2622) are 2.17:1.
- tablet/*.png: iPad screenshots without the status bar.

Usage (from the repo root): python3 store/google-play/build_graphics.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SHOTS = ROOT / "store" / "screenshots"

NAVY = (0x1B, 0x22, 0x33)
CREAM = (0xEC, 0xE8, 0xDF)
GOLD = (0xC9, 0xA4, 0x5C)
FONT = ROOT / "assets" / "fonts" / "exo2" / "Exo2[wght].ttf"

TAGLINE = {
    "uk": "Вивчайте дебюти – хід за ходом, позиція за позицією.",
    "en": "Learn your openings – move by move, position by position.",
}


def font(size, weight):
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_name(weight)
    return f


def icon():
    img = Image.open(ROOT / "assets" / "icon" / "icon.png").convert("RGB")
    img.resize((512, 512), Image.LANCZOS).save(OUT / "icon-512.png", optimize=True)


def feature_graphic(lang):
    w, h = 1024, 500
    img = Image.new("RGB", (w, h), NAVY)
    glyph = Image.open(ROOT / "assets" / "icon" / "icon_foreground.png").convert("RGBA")
    # The adaptive foreground keeps the glyph in the middle 2/3; crop to it.
    glyph = glyph.crop((176, 176, 848, 848)).resize((336, 336), Image.LANCZOS)
    img.paste(glyph, (56, (h - 336) // 2), glyph)

    d = ImageDraw.Draw(img)
    x = 420
    title = font(76, b"Bold")
    d.text((x, 150), "Repertorium", font=title, fill=CREAM)
    d.text((x, 232), "chess", font=title, fill=GOLD)
    # Wrap the tagline into the space right of the glyph.
    sub = font(30, b"Medium")
    words, lines, line = TAGLINE[lang].split(), [], ""
    for word in words:
        probe = f"{line} {word}".strip()
        if d.textlength(probe, font=sub) > w - x - 48:
            lines.append(line)
            line = word
        else:
            line = probe
    lines.append(line)
    for i, text in enumerate(lines):
        d.text((x, 342 + i * 40), text, font=sub, fill=(0xB8, 0xBC, 0xC6))
    img.save(OUT / f"feature-graphic-{lang}.png", optimize=True)


def phone():
    dst = OUT / "phone"
    dst.mkdir(exist_ok=True)
    for src in sorted((SHOTS / "raw").glob("*.png")):
        img = Image.open(src).convert("RGB")  # 1206x2622
        img = img.crop((0, 170, 1206, 170 + 2400))  # no status bar, 2400 high
        img = img.resize((1080, round(2400 * 1080 / 1206)), Image.LANCZOS)
        img.save(dst / src.name, optimize=True)


def tablet():
    dst = OUT / "tablet"
    dst.mkdir(exist_ok=True)
    for src in sorted((SHOTS / "raw-ipad").glob("*.png")):
        img = Image.open(src).convert("RGB")  # 2064x2752
        img = img.crop((0, 64, img.width, img.height))
        img = img.resize((1536, round(img.height * 1536 / img.width)), Image.LANCZOS)
        img.save(dst / src.name, optimize=True)


if __name__ == "__main__":
    icon()
    for lang in TAGLINE:
        feature_graphic(lang)
    phone()
    tablet()
    for p in sorted(OUT.rglob("*.png")):
        print(p.relative_to(OUT), Image.open(p).size, f"{p.stat().st_size // 1024} KB")
