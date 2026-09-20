"""Generates the game's pixel art (16x16 PNGs) from ASCII templates.
Run:  python tools/gen_sprites.py"""
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprite_templates as T  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
OUTLINE = (20, 16, 28)
SKIN = (232, 200, 170)


def mix(c, target, t):
    return tuple(int(c[i] + (target[i] - c[i]) * t) for i in range(3))


def palette(base, eye=(250, 250, 250), accent=(240, 200, 60), face=SKIN, sash=(190, 40, 50)):
    return {
        "O": OUTLINE, "B": base, "S": mix(base, (0, 0, 0), 0.35), "H": mix(base, (255, 255, 255), 0.4),
        "F": face, "E": eye, "A": accent, "C": sash,
    }


def render(template, pal, extra=()):
    rows = template.strip("\n").split("\n")
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                img.putpixel((x, y), pal[ch] + (255,))
    for x, y, color in extra:
        img.putpixel((x, y), color + (255,))
    return img


def rgb(t):
    return tuple(int(v * 255) for v in t)


W = (250, 250, 250)
TAIL = [(1, 4, W), (2, 3, W), (0, 5, W), (1, 6, W), (2, 7, W)]
# id: (template, base color (0-1), eye, accent, extra pixels)
MONSTERS = {
    "mongdal": (T.GHOST, (0.75, 0.75, 0.85), (30, 30, 60), (150, 150, 200), ()),
    "dokkaebi": (T.DEMON, (0.85, 0.30, 0.30), (255, 240, 120), (250, 220, 90), ()),
    "jeoseung_dog": (T.BEAST, (0.25, 0.25, 0.30), (255, 60, 60), (120, 120, 140), ()),
    "mulgwisin": (T.GHOST, (0.25, 0.55, 0.75), (240, 250, 255), (60, 140, 90), ()),
    "gumiho": (T.BEAST, (0.95, 0.75, 0.35), (40, 20, 20), W, TAIL),
    "sangyeo_gwi": (T.GOLEM, (0.55, 0.45, 0.35), (255, 200, 80), (200, 200, 200), ()),
    "jeoseung_saja": (T.ROBED, (0.10, 0.10, 0.10), (255, 50, 50), (35, 35, 45), ()),
    "cheonyeo_gwisin": (T.GHOST, (0.95, 0.95, 1.0), (20, 20, 20), (30, 30, 40), ()),
    "dalgyal_gwisin": (T.GHOST, (0.90, 0.88, 0.75), (230, 224, 190), (200, 190, 150), ()),
    "duoksini": (T.DEMON, (0.45, 0.20, 0.20), (255, 200, 60), (180, 180, 180), ()),
    "yacha": (T.DEMON, (0.30, 0.55, 0.35), (255, 255, 120), (240, 200, 60), ()),
    "bulgasari": (T.GOLEM, (0.40, 0.40, 0.45), (255, 140, 40), (255, 140, 40), ()),
    "imugi": (T.SERPENT, (0.20, 0.45, 0.30), (255, 230, 80), (230, 50, 60), ()),
    "jangsanbeom": (T.BEAST, (0.85, 0.85, 0.85), (240, 190, 40), (180, 180, 200), ()),
    "okjol": (T.ROBED, (0.35, 0.10, 0.10), (255, 220, 60), (30, 20, 20), ()),
    "gangnim": (T.ROBED, (0.15, 0.15, 0.55), (255, 255, 255), (240, 200, 60), ()),
    "yeomra": (T.ROBED, (0.70, 0.10, 0.10), (255, 230, 90), (250, 210, 60), ()),
}
HEROES = {
    "mudang": dict(base=(235, 235, 245), accent=(30, 25, 35), sash=(200, 40, 50)),
    "hwarang": dict(base=(80, 130, 210), accent=(200, 200, 215), sash=(230, 190, 60)),
    "dosa": dict(base=(90, 170, 100), accent=(50, 50, 60), sash=(240, 240, 240)),
}
ITEM_ICONS = {
    "spirit_dagger": (T.SWORD, (200, 210, 230), (240, 200, 60)),
    "rusty_sword": (T.SWORD, (170, 110, 70), (110, 70, 40)),
    "dokkaebi_club": (T.SWORD, (150, 105, 60), (90, 60, 30)),
    "soul_blade": (T.SWORD, (90, 70, 140), (200, 180, 255)),
    "ghost_blade": (T.SWORD, (170, 240, 250), (100, 180, 200)),
    "hemp_garment": (T.ARMOR, (190, 170, 120), (140, 110, 70)),
    "soul_armor": (T.ARMOR, (110, 120, 170), (200, 210, 255)),
    "diamond_armor": (T.ARMOR, (150, 190, 205), (255, 255, 255)),
    "dragon_armor": (T.ARMOR, (60, 165, 120), (240, 200, 60)),
    "flower_wine": (T.POTION, (205, 50, 65), (140, 100, 60)),
    "immortal_wine": (T.POTION, (235, 195, 60), (140, 100, 60)),
    "elixir": (T.POTION, (90, 225, 240), (255, 255, 255)),
    "antidote_herb": (T.POTION, (90, 190, 90), (120, 90, 50)),
    "talisman": (T.SCROLL, (238, 222, 150), (210, 40, 40)),
    "ledger_fragment": (T.SCROLL, (225, 225, 225), (90, 90, 110)),
    "teleport_talisman": (T.SCROLL, (150, 190, 245), (40, 70, 170)),
    "clairvoyance_talisman": (T.SCROLL, (195, 150, 235), (90, 40, 150)),
    "gold": (T.COIN, (245, 205, 60), (245, 205, 60)),
}


def tile_floor(rng, spent=False):
    img = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            n = rng.randint(-7, 7)
            img.putpixel((x, y), (61 + n, 54 + n, 71 + n, 255))
    for _ in range(3):
        x, y = rng.randint(1, 11), rng.randint(1, 13)
        for i in range(rng.randint(2, 4)):
            img.putpixel((x + i, y), (40, 34, 50, 255))
    if spent:
        for x in (3, 7, 11):
            for y in (10, 11, 12):
                img.putpixel((x, y), (200, 60, 60, 255))
            img.putpixel((x, 9), (240, 130, 130, 255))
    return img


def tile_trap_spotted(rng):
    """Armed trap the player has noticed: floor with the plate seams showing."""
    img = tile_floor(rng)
    seam = (120, 96, 40, 255)
    for i in range(3, 13):
        for x, y in ((i, 3), (i, 12), (3, i), (12, i)):
            img.putpixel((x, y), seam)
    for x, y in ((6, 7), (9, 7), (6, 9), (9, 9)):
        img.putpixel((x, y), (215, 175, 70, 255))
    return img


def tile_wall(rng):
    img = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            n = rng.randint(-4, 4)
            img.putpixel((x, y), (34 + n, 27 + n, 44 + n, 255))
    for y in (0, 5, 10, 15):
        for x in range(16):
            img.putpixel((x, y), (16, 12, 22, 255))
    for row, y0 in enumerate((0, 5, 10)):
        off = 0 if row % 2 == 0 else 4
        for x in range(off, 16, 8):
            for y in range(y0, y0 + 5):
                img.putpixel((x, y), (16, 12, 22, 255))
    return img


def tile_door():
    img = Image.new("RGBA", (16, 16))
    for x in range(16):
        for y in range(16):
            shade = -14 if x % 4 == 0 else (8 if x % 4 == 2 else 0)
            img.putpixel((x, y), (110 + shade, 72 + shade, 32 + shade // 2, 255))
    for i in range(16):
        for xy in ((0, i), (15, i), (i, 0), (i, 15)):
            img.putpixel(xy, OUTLINE + (255,))
    for xy in ((11, 8), (12, 8), (11, 9), (12, 9)):
        img.putpixel(xy, (240, 200, 60, 255))
    return img


def tile_stairs():
    img = Image.new("RGBA", (16, 16), (45, 38, 52, 255))
    for i in range(4):
        c = (150 + i * 25, 115 + i * 22, 30 + i * 10, 255)
        for x in range(2 + i, 14 - i):
            for y in range(2 + i * 3, 5 + i * 3):
                img.putpixel((x, y), c)
    return img


def tile_well(rng):
    img = tile_floor(rng)
    for y in range(16):
        for x in range(16):
            d = (x - 7.5) ** 2 + (y - 7.5) ** 2
            if d <= 30:
                img.putpixel((x, y), (60, 130, 210, 255) if d > 12 else (120, 190, 250, 255))
            if 30 < d <= 42:
                img.putpixel((x, y), (110, 100, 125, 255))
    return img


def tile_altar(rng):
    img = tile_floor(rng)
    for y in range(9, 14):
        for x in range(3, 13):
            img.putpixel((x, y), (120, 110, 135, 255) if y > 9 else (160, 150, 175, 255))
    for y in range(4, 9):
        for x in (7, 8):
            img.putpixel((x, y), (250, 190, 60, 255))
    img.putpixel((7, 3), (255, 230, 120, 255))
    img.putpixel((8, 3), (255, 230, 120, 255))
    return img


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    rng = random.Random(7)
    sheet = []
    for mid, (tpl, color, eye, accent, extra) in MONSTERS.items():
        img = render(tpl, palette(rgb(color), eye=eye, accent=accent), extra)
        save(img, "actors", mid + ".png")
        sheet.append(img)
    for hid, h in HEROES.items():
        img = render(T.HERO, palette(h["base"], accent=h["accent"], sash=h["sash"]))
        save(img, "actors", hid + ".png")
        sheet.append(img)
    tiles = {"floor": tile_floor(rng), "trap_spent": tile_floor(rng, True), "wall": tile_wall(rng),
             "door": tile_door(), "stairs": tile_stairs(), "well": tile_well(rng), "altar": tile_altar(rng),
             "trap_spotted": tile_trap_spotted(rng)}
    for name, img in tiles.items():
        save(img, "tiles", name + ".png")
        sheet.append(img)
    for iid, (tpl, base, accent) in ITEM_ICONS.items():
        img = render(tpl, palette(base, accent=accent, face=base))
        save(img, "items", iid + ".png")
        sheet.append(img)
    cols = 10
    rows = (len(sheet) + cols - 1) // cols
    contact = Image.new("RGBA", (cols * 16, rows * 16), (60, 60, 70, 255))
    for i, img in enumerate(sheet):
        contact.alpha_composite(img, ((i % cols) * 16, (i // cols) * 16))
    contact = contact.resize((contact.width * 6, contact.height * 6), Image.NEAREST)
    if os.environ.get("SHEET_DIR"):
        contact.save(os.path.join(os.environ["SHEET_DIR"], "contact_sheet.png"))
    print("sprites:", len(sheet))


if __name__ == "__main__":
    main()
