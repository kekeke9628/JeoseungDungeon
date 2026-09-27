"""Worn-gear overlays: one 24x24 layer per piece of equipment, drawn to sit on
the heroes of tools/actors24.py (they share one body: hands at (6.8, 18.2) and
(17.2, 18.2), head centred at (12, 7), feet at rows 21-22). The game stacks
them on the bare hero, so what the player wears shows on the map and in the
bag. Each is saved like a character: two idle frames side by side, breathing
with the body (rows above 13 sink a pixel in the second frame).

Heroes are saved twice: <id>_bare.png, the body that gear is layered on, and
<id>.png with the class's starting gear on, for the title and class screens."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import actors24 as A  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WAIST = 13
HEROES = ("mudang", "hwarang", "dosa")


def _fist(f):
    """The right hand, drawn over the grip so the weapon is held, not pasted on."""
    f.ell(17.2, 18.2, 1.3, 1.1, "skin")


def _blade(f, tip, width=1):
    """A straight blade rising from the right fist to tip, with a guard."""
    f.line(16, 20, 16, 20, "hilt", 2)  # pommel below the fist
    f.line(17, 16, 20, 16, "guard", 3)
    f.line(18, 15, tip[0], tip[1], "blade", 3)
    if width > 1:
        f.line(19, 15, tip[0] + 1, tip[1], "blade", 1)
    f.dot(tip[0], tip[1], "blade", 4)
    _fist(f)


def spirit_dagger(f):
    _blade(f, (21, 11))


def rusty_sword(f):
    _blade(f, (22, 5), width=2)
    for x, y in ((19, 12), (21, 8)):
        f.dot(x, y, "rust", 1)


def soul_blade(f):
    _blade(f, (22, 4), width=2)
    for x, y in ((20, 10), (21, 7), (22, 5)):
        f.dot(x, y, "glow", 4)


def ghost_blade(f):
    _blade(f, (22, 4), width=2)
    for x, y in ((19, 12), (21, 8)):
        f.dot(x, y, "glow", 4)


def dokkaebi_club(f):
    f.poly([(17, 17), (19, 16), (23, 5), (20, 4)], "blade")
    for x, y in ((20, 7), (22, 9), (21, 12), (21, 5)):
        f.dot(x, y, "guard", 3)
    _fist(f)


def _torso(f):
    """Plate over the robe from the shoulders to the hips, and shoulder guards."""
    f.poly([(8, 11), (16, 11), (16.8, 17), (7.2, 17)], "armor")
    f.ell(7.6, 12.1, 2.1, 1.5, "armor", bias=0.15)
    f.ell(16.4, 12.1, 2.1, 1.5, "armor", bias=-0.1)
    f.box(8, 15, 16, 15, "trim", fade=0)


def hemp_garment(f):
    _torso(f)
    f.line(10, 11, 12, 13, "trim", 2)  # crossed collar
    f.line(14, 11, 12, 13, "trim", 1)
    for x, y in ((9, 13), (11, 14), (14, 13), (10, 16), (13, 16), (15, 14)):
        f.dot(x, y, "armor", 1)


def soul_armor(f):
    _torso(f)
    for y in (13, 16):
        f.line(8, y, 16, y, "armor", 1)
    f.dot(12, 12, "trim", 4)


def diamond_armor(f):
    _torso(f)
    for x, y in ((10, 12), (14, 13), (11, 16), (15, 16), (8, 14)):
        f.dot(x, y, "armor", 4)


def dragon_armor(f):
    _torso(f)
    for y in (12, 14, 16):
        for x in range(9 + (y // 2) % 2, 16, 2):
            f.dot(x, y, "armor", 1)
    f.line(10, 11, 14, 11, "trim", 3)


def _gat(f, band_mat="band", beads=False):
    """A horsehair gat at the same place as the sage's own, so it covers his."""
    f.box(9, 1, 14, 4, "hat")
    f.ell(12, 5.2, 7.6, 1.3, "hat", bias=0.05)
    f.line(9, 4, 14, 4, band_mat, 2)
    if beads:
        for y in range(6, 11):
            f.dot(18, y, "bead", 3 if y % 2 else 2)
            f.dot(6, y, "bead", 3 if y % 2 else 2)


def satgat(f):
    """A wide conical straw hat, low over the brow."""
    f.poly([(3, 7), (21, 7), (12, 0)], "hat")
    for x in range(5, 20, 3):
        f.dot(x, 6, "hat", 1)
    f.line(4, 6, 20, 6, "hat", 1)


def heungnip(f):
    _gat(f)


def jurip(f):
    _gat(f, beads=True)


def _norigae(f):
    """Hangs from the belt on the right hip: knot, stone, tassel."""
    f.dot(14, 15, "knot", 3)
    f.dot(15, 15, "knot", 2)
    f.ell(14.6, 17.2, 1.4, 1.6, "stone")
    f.line(14, 19, 14, 21, "knot", 2)
    f.line(15, 19, 15, 21, "knot", 1)


def _ring(f):
    """On the left hand: a band and a bright stone."""
    f.dot(6, 18, "band", 3)
    f.dot(7, 18, "band", 2)
    f.dot(6, 17, "stone", 4)
    f.dot(7, 17, "stone", 3)


def _shoes(f, top=21):
    f.box(8, top, 10, 22, "shoe")
    f.box(13, top, 15, 22, "shoe", bias=-0.2)


def jipsin(f):
    _shoes(f)
    for x in (8, 10, 13, 15):
        f.dot(x, 21, "shoe", 1)


def mokhwa(f):
    _shoes(f, top=19)
    f.line(8, 22, 10, 22, "sole", 3)
    f.line(13, 22, 15, 22, "sole", 2)


def unhye(f):
    _shoes(f)
    f.dot(8, 22, "tip", 3)
    f.dot(15, 22, "tip", 3)


SKIN = {"skin": A.SKIN}
GEAR = {
    # weapons
    "spirit_dagger": (spirit_dagger, dict(SKIN, blade=(206, 216, 236), guard=(240, 200, 60), hilt=(110, 70, 40))),
    "rusty_sword": (rusty_sword, dict(SKIN, blade=(176, 150, 128), guard=(120, 84, 50), hilt=(90, 60, 36),
                                      rust=(150, 80, 40))),
    "dokkaebi_club": (dokkaebi_club, dict(SKIN, blade=(156, 108, 62), guard=(200, 200, 210))),
    "soul_blade": (soul_blade, dict(SKIN, blade=(150, 120, 214), guard=(90, 70, 140), hilt=(60, 44, 90),
                                    glow=(220, 200, 255))),
    "ghost_blade": (ghost_blade, dict(SKIN, blade=(176, 236, 246), guard=(100, 180, 200), hilt=(60, 110, 130),
                                      glow=(240, 255, 255))),
    # clothes
    "hemp_garment": (hemp_garment, dict(armor=(196, 176, 126), trim=(140, 110, 70))),
    "soul_armor": (soul_armor, dict(armor=(106, 118, 176), trim=(200, 210, 255))),
    "diamond_armor": (diamond_armor, dict(armor=(154, 194, 210), trim=(236, 242, 250))),
    "dragon_armor": (dragon_armor, dict(armor=(62, 166, 120), trim=(240, 200, 60))),
    # hats
    "satgat": (satgat, dict(hat=(208, 178, 116))),
    "heungnip": (heungnip, dict(hat=(56, 50, 66), band=(176, 46, 56))),
    "jurip": (jurip, dict(hat=(188, 50, 52), band=(240, 200, 60), bead=(240, 200, 60))),
    # norigae
    "aengmagi_norigae": (_norigae, dict(stone=(226, 206, 160), knot=(200, 40, 50))),
    "bichwi_norigae": (_norigae, dict(stone=(80, 192, 142), knot=(200, 40, 70))),
    "samjak_norigae": (_norigae, dict(stone=(242, 206, 80), knot=(210, 50, 170))),
    # rings
    "eun_garakji": (_ring, dict(band=(206, 210, 224), stone=(250, 250, 255))),
    "ok_garakji": (_ring, dict(band=(206, 210, 224), stone=(110, 196, 150))),
    "geum_garakji": (_ring, dict(band=(240, 200, 70), stone=(230, 60, 60))),
    # shoes
    "jipsin": (jipsin, dict(shoe=(206, 176, 116))),
    "mokhwa": (mokhwa, dict(shoe=(56, 50, 66), sole=(220, 220, 226))),
    "unhye": (unhye, dict(shoe=(132, 92, 192), tip=(240, 200, 80))),
}
# Layer order, bottom to top (the game stacks them the same way).
SLOT_ORDER = ("boots", "armor", "amulet", "ring", "head", "weapon")


def gear_frames(item_id):
    draw, pal = GEAR[item_id]
    f = A.Fig()
    draw(f)
    return [f.render(pal), f.shifted("breath", WAIST).render(pal)]


def starting_gear(hero):
    """The class's starting_equip_ids, read from its .tres."""
    path = os.path.join(ROOT, "resources", "classes", hero + ".tres")
    with open(path, encoding="utf-8") as fh:
        m = re.search(r"starting_equip_ids = Array\[String\]\(\[(.*?)\]\)", fh.read())
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def dressed(hero, gear_ids):
    """The hero's idle frames with the given gear stacked on."""
    base = A.frames(hero)
    for gid in gear_ids:
        layer = gear_frames(gid)
        for i in range(len(base)):
            img = base[i].copy()
            img.alpha_composite(layer[i])
            base[i] = img
    return base
