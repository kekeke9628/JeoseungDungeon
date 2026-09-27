"""Generates the game's pixel art. Run:  python tools/gen_sprites.py

- tile atlases, one per depth band (tools/gen_tiles.py)
- characters: 24x24, two idle frames side by side (tools/actors24.py); heroes
  also as <id>_bare.png, the body that worn gear is layered on
- worn-gear layers, one per piece of equipment (tools/gear24.py)
- item icons: 16x16 from the ASCII templates in tools/sprite_templates.py
- UI skins, button icons and the title backdrop (tools/gen_ui.py)
All of it is drawn at 2x in the game, so every sprite has the same pixel size."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import actors24  # noqa: E402
import gear24  # noqa: E402
import gen_tiles  # noqa: E402
import gen_ui  # noqa: E402
import sprite_templates as T  # noqa: E402
from pixel_kit import canvas, shade, sheet  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
OUTLINE = (20, 16, 28)


def palette(base, accent=(240, 200, 60)):
    """Template letters: O outline, B body, S shade, H highlight, A accent,
    F face (the body colour on items). Shade and highlight shift hue as well
    as brightness (pixel_kit.shade)."""
    return {"O": OUTLINE, "B": base, "S": shade(base, -0.4), "H": shade(base, 0.45), "F": base, "A": accent}


def render(template, pal):
    rows = template.strip("\n").split("\n")
    img = canvas(16, 16)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                img.putpixel((x, y), tuple(pal[ch]) + (255,))
    return img


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
    gen_ui.build()
    previews = []
    for aid in actors24.ACTORS:
        if aid in gear24.HEROES:
            save(actors24.strip(aid), "actors", aid + "_bare.png")
            strip = actors24.join(gear24.dressed(aid, gear24.starting_gear(aid)))
        else:
            strip = actors24.strip(aid)
        save(strip, "actors", aid + ".png")
        previews.append(strip)
    for gid in gear24.GEAR:
        save(actors24.join(gear24.gear_frames(gid)), "gear", gid + ".png")
    icons = []
    for iid, (tpl, base, accent) in ITEM_ICONS.items():
        img = render(tpl, palette(base, accent))
        save(img, "items", iid + ".png")
        icons.append(img)
    if os.environ.get("SHEET_DIR"):
        sheet(previews, 4, 5).save(os.path.join(os.environ["SHEET_DIR"], "actors.png"))
        sheet(icons, 11, 6).save(os.path.join(os.environ["SHEET_DIR"], "items.png"))
    print("actors: %d, gear layers: %d, item icons: %d" % (len(previews), len(gear24.GEAR), len(icons)))


if __name__ == "__main__":
    main()
