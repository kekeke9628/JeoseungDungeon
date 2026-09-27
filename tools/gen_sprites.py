"""Generates the game's pixel art (16x16 PNGs) from ASCII templates.
Run:  python tools/gen_sprites.py"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_tiles  # noqa: E402
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
    "satgat": (T.HAT, (205, 175, 115), (150, 110, 65)),
    "heungnip": (T.HAT, (55, 50, 65), (170, 45, 55)),
    "jurip": (T.HAT, (185, 50, 50), (240, 200, 60)),
    "aengmagi_norigae": (T.NORIGAE, (225, 205, 160), (200, 40, 50)),
    "bichwi_norigae": (T.NORIGAE, (80, 190, 140), (200, 40, 70)),
    "samjak_norigae": (T.NORIGAE, (240, 205, 80), (210, 50, 170)),
    "eun_garakji": (T.RING, (200, 205, 220), (245, 245, 255)),
    "ok_garakji": (T.RING, (110, 195, 150), (225, 250, 230)),
    "geum_garakji": (T.RING, (240, 200, 70), (230, 60, 60)),
    "jipsin": (T.SHOES, (205, 175, 115), (150, 110, 65)),
    "mokhwa": (T.SHOES, (55, 50, 65), (200, 200, 210)),
    "unhye": (T.SHOES, (130, 90, 190), (240, 200, 80)),
    "gotgam": (T.PERSIMMON, (215, 115, 45), (95, 120, 55)),
    "jumeokbap": (T.RICEBALL, (240, 238, 228), (40, 62, 48)),
    "sajatbap": (T.RICEBOWL, (200, 160, 70), (246, 244, 236)),
}


def save(img, *parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    gen_tiles.build()
    sheet = []
    for mid, (tpl, color, eye, accent, extra) in MONSTERS.items():
        img = render(tpl, palette(rgb(color), eye=eye, accent=accent), extra)
        save(img, "actors", mid + ".png")
        sheet.append(img)
    for hid, h in HEROES.items():
        img = render(T.HERO, palette(h["base"], accent=h["accent"], sash=h["sash"]))
        save(img, "actors", hid + ".png")
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
