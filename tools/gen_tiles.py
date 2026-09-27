"""Generates the dungeon tile atlases: one 24x24-cell sheet per depth band
(assets/sprites/tiles/<band>.png) plus scripts/generation/TileAtlas.gd, which
tells the renderer where each tile sits. Run:  python tools/gen_tiles.py
(python tools/gen_sprites.py runs it too).

Cells are 24x24 and drawn at exactly 2x into the game's 48px tiles, the same
pixel size as the actor sprites, so nothing on the map mixes pixel sizes."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_kit import Noise, canvas, jitter, put, rect, shade, sheet  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sprites", "tiles")
GD_OUT = os.path.join(ROOT, "scripts", "generation", "TileAtlas.gd")
C = 24
COLS = 8
FLOOR_VARIANTS = 4
BONE = (226, 216, 192)
FLAME = [(255, 244, 170), (255, 190, 70), (230, 100, 40)]

BANDS = {
    # 저승길: grey-violet flagstones, the road of the dead.
    "path": dict(floor=(86, 78, 100), mortar=(34, 28, 44), wall=(78, 70, 96), top=(42, 36, 56), trim=(128, 118, 150)),
    # 황천강: cold blue-green stone, wet and mossy.
    "river": dict(floor=(64, 88, 104), mortar=(24, 36, 48), wall=(60, 84, 102), top=(28, 42, 58), trim=(104, 150, 170),
                  moss=(74, 128, 84)),
    # 지옥문: red-brown basalt with glowing seams.
    "gate": dict(floor=(98, 62, 56), mortar=(38, 18, 20), wall=(94, 56, 52), top=(46, 24, 26), trim=(160, 92, 70),
                 glow=(255, 128, 44)),
    # 염라전: the palace: wooden floors, red lacquer walls under painted beams.
    "palace": dict(floor=(128, 86, 54), mortar=(58, 36, 24), wall=(160, 42, 40), top=(54, 32, 32), trim=(228, 182, 82)),
}
# Decor per band: (name, frames). Frames > 1 animate.
DECOR = {
    "path": [("bones", 1), ("skull", 1), ("crack", 1), ("pebbles", 1), ("grass", 1), ("paper", 1), ("candle", 2)],
    "river": [("bones", 1), ("crack", 1), ("pebbles", 1), ("puddle", 1), ("reeds", 1), ("lotus", 1), ("candle", 2)],
    "gate": [("bones", 1), ("skull", 1), ("crack", 1), ("chain", 1), ("ember", 2), ("lava", 2), ("candle", 2)],
    "palace": [("crack", 1), ("coins", 1), ("cushion", 1), ("scroll", 1), ("incense", 2), ("candle", 2)],
}
# Decor that gives off light (warms the tiles around it in the light map).
LIGHTS = ["candle", "ember", "lava", "incense"]


def rng_for(*key):
    return random.Random("-".join(str(k) for k in key))


# ---------------------------------------------------------------- floors

STONE_LAYOUTS = [
    [(1, 1, 11, 11), (13, 1, 23, 11), (1, 13, 11, 23), (13, 13, 23, 23)],
    [(1, 1, 23, 11), (1, 13, 11, 23), (13, 13, 23, 23)],
    [(1, 1, 11, 23), (13, 1, 23, 11), (13, 13, 23, 23)],
    [(1, 1, 15, 9), (17, 1, 23, 9), (1, 11, 8, 23), (10, 11, 23, 23)],
]


def stone(img, box, base, noise, rng, bevel=True):
    x0, y0, x1, y1 = box
    base = jitter(base, rng.randint(-7, 7))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            t = (noise.at(x, y) - 0.5) * 0.35
            c = shade(base, t)
            if bevel:
                if y == y0 or x == x0:
                    c = shade(base, 0.2 + t * 0.5)
                elif y == y1 or x == x1:
                    c = shade(base, -0.22 + t * 0.5)
            if rng.random() < 0.05:
                c = shade(c, -0.18)
            put(img, x, y, c)
    for cx, cy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        put(img, cx, cy, shade(base, -0.38))


def crack_line(img, rng, color, start, steps):
    x, y = start
    for _ in range(steps):
        put(img, x, y, color)
        x += rng.choice((-1, 0, 1, 1))
        y += rng.choice((0, 1, 1))


def floor_tile(band, v):
    pal = BANDS[band]
    if band == "palace":
        return plank_floor(pal, v)
    img = canvas(C, C, pal["mortar"] + (255,))
    rng = rng_for(band, "floor", v)
    noise = Noise(("floor", band, v), C, 6)
    for box in STONE_LAYOUTS[v]:
        stone(img, box, pal["floor"], noise, rng)
    if v == 3:
        crack_line(img, rng, shade(pal["mortar"], 0.1), (rng.randint(3, 8), rng.randint(13, 15)), 6)
    return img


def plank_floor(pal, v):
    """Maru: long boards with staggered joints and a little grain."""
    img = canvas(C, C)
    rng = rng_for("palace", "floor", v)
    for row in range(4):
        y0 = row * 6
        joint = (row * 9 + v * 5 + 3) % C
        base = jitter(pal["floor"], rng.randint(-8, 8))
        grain = [rng.random() for _ in range(C)]
        for y in range(y0, y0 + 6):
            for x in range(C):
                t = math.sin(x * 0.45 + row * 2.1 + v) * 0.06 + (grain[x] - 0.5) * 0.08
                c = shade(base, t)
                if y == y0:
                    c = shade(pal["floor"], -0.5)
                elif y == y0 + 1:
                    c = shade(base, 0.18)
                elif y == y0 + 5:
                    c = shade(base, -0.15)
                if x == joint and y != y0:
                    c = shade(pal["floor"], -0.45)
                put(img, x, y, c)
        for y in (y0 + 2, y0 + 4):  # pegs
            if rng.random() < 0.5:
                put(img, (joint + 2) % C, y0 + 3, shade(base, -0.35))
    return img


# ---------------------------------------------------------------- walls

def bricks(img, pal, band, v, y_from):
    rng = rng_for(band, "bricks", v)
    noise = Noise(("brick", band, v), C, 6)
    for course, y0 in enumerate(range(y_from, C, 6)):
        off = 0 if course % 2 == 0 else 4
        for bx in range(off - 8, C, 8):
            base = jitter(pal["wall"], rng.randint(-8, 8))
            for y in range(y0, min(C, y0 + 6)):
                for x in range(max(0, bx), min(C, bx + 8)):
                    t = (noise.at(x, y) - 0.5) * 0.3
                    if x == bx or y == y0 + 5:
                        c = pal["mortar"]
                    elif y == y0:
                        c = shade(base, 0.22 + t)
                    elif y == y0 + 4:
                        c = shade(base, -0.2 + t)
                    else:
                        c = shade(base, t)
                    put(img, x, y, c)


def wall_top_fill(img, pal, band, v, y1):
    noise = Noise(("top", band, v), C, 8)
    rng = rng_for(band, "top", v)
    for y in range(0, y1 + 1):
        for x in range(C):
            c = shade(pal["top"], (noise.at(x, y) - 0.5) * 0.4)
            if rng.random() < 0.04:
                c = shade(c, 0.15)
            put(img, x, y, c)


def wall_face(band, v):
    """A wall with open floor below it, seen from the front: its top surface,
    a lit edge, then the face down to the floor."""
    pal = BANDS[band]
    img = canvas(C, C)
    if band == "palace":
        return palace_face(pal, v)
    wall_top_fill(img, pal, band, v, 4)
    for x in range(C):
        put(img, x, 5, pal["trim"])
    bricks(img, pal, band, v, 6)
    for x in range(C):  # grime where the wall meets the floor
        put(img, x, 23, shade(pal["wall"], -0.5))
    rng = rng_for(band, "face", v)
    if band == "river":
        for x in range(C):
            if rng.random() < 0.35:
                length = rng.choice((1, 1, 2, 3))
                for y in range(6, 6 + length):
                    put(img, x, y, shade(pal["moss"], -0.1 * (y - 6)))
    return img


def wall_face_special(band):
    """A rarer wall face with something on it, so long walls do not repeat."""
    pal = BANDS[band]
    img = wall_face(band, 0)
    if band == "path":  # a talisman pasted on the wall
        rect(img, 10, 8, 14, 18, (226, 200, 116))
        for y in range(9, 18, 2):
            put(img, 12, y, (196, 48, 48))
        put(img, 11, 11, (196, 48, 48))
        put(img, 13, 14, (196, 48, 48))
        rect(img, 10, 19, 14, 19, shade((226, 200, 116), -0.3))
    elif band == "river":  # a dark water stain running down from the top
        for y in range(6, 23):
            for x in range(9, 15):
                if abs(x - 11.5) < 2.6 - (y - 6) * 0.08:
                    put(img, x, y, shade(img.getpixel((x, y)), -0.3))
        for y in range(6, 9):
            put(img, 11, y, shade(pal["moss"], 0.1))
    elif band == "gate":  # a seam glowing with the fire behind the wall
        crack = rng_for("gate", "glow")
        x, y = 11, 6
        while y <= 21:
            put(img, x, y, pal["glow"])
            put(img, x + 1, y, shade(pal["glow"], -0.35))
            x = max(6, min(17, x + crack.choice((-1, 0, 1))))
            y += 1
    else:  # a red and blue lantern hanging from the beam
        rect(img, 11, 9, 12, 10, (60, 40, 30))
        rect(img, 9, 11, 14, 13, (196, 40, 44))
        rect(img, 9, 14, 14, 16, (48, 70, 160))
        for y in range(11, 17):
            put(img, 9, y, shade(img.getpixel((9, y)), 0.25))
            put(img, 14, y, shade(img.getpixel((14, y)), -0.3))
        rect(img, 11, 17, 12, 18, pal["trim"])
    return img


def palace_face(pal, v):
    img = canvas(C, C)
    wall_top_fill(img, pal, "palace", v, 3)
    # painted beam (dancheong): green and blue bands with white dots
    green, blue, white = (56, 140, 112), (58, 90, 168), (236, 232, 220)
    for x in range(C):
        put(img, x, 4, pal["trim"])
        put(img, x, 5, green)
        put(img, x, 6, green if x % 6 not in (2, 3) else white)
        put(img, x, 7, blue)
        put(img, x, 8, shade(blue, -0.3))
    # red lacquer panel with a wooden pillar
    for y in range(9, 20):
        for x in range(C):
            c = shade(pal["wall"], math.sin(y * 0.9 + x * 0.2) * 0.04)
            if x in (0, 1, 2) if v == 0 else x in (21, 22, 23):
                c = (104, 62, 40) if x not in (0, 23) else (70, 40, 26)
            put(img, x, y, c)
    for x in range(C):
        put(img, x, 9, shade(pal["wall"], 0.25))
    # stone base
    for y in range(20, C):
        for x in range(C):
            c = (122, 118, 124) if y == 20 else (96, 92, 100)
            if x % 12 == 0:
                c = (60, 56, 64)
            put(img, x, y, c if y != 23 else (54, 50, 58))
    return img


def wall_top(band, v):
    pal = BANDS[band]
    img = canvas(C, C)
    wall_top_fill(img, pal, band, v, C - 1)
    if band == "palace":
        for y in range(0, C, 4):  # roof tile rows
            for x in range(C):
                if (x + (y // 4) * 2) % 4 == 0:
                    put(img, x, y, shade(pal["top"], -0.3))
                else:
                    put(img, x, y, shade(pal["top"], 0.12))
    return img


# ---------------------------------------------------------------- features

def door(band):
    """Door in a wall that runs left-right, seen from the front."""
    pal = BANDS[band]
    img = wall_face(band, 0)
    wood = {"gate": (70, 70, 78), "palace": (168, 44, 40)}.get(band, (122, 80, 42))
    stud = {"gate": (150, 150, 160), "palace": pal["trim"]}.get(band, (60, 60, 66))
    for y in range(5, C):
        for x in range(5, 19):
            if x in (5, 18) or y == 5:
                c = shade(wood, -0.5)
            else:
                c = shade(wood, 0.12 if (x - 6) % 3 == 0 else (-0.12 if (x - 6) % 3 == 2 else 0.0))
            put(img, x, y, c)
    for x in range(6, 18):
        for y in (9, 18):
            put(img, x, y, shade(stud, -0.35))
    for x in (7, 11, 16):
        for y in (9, 18):
            put(img, x, y, stud)
    for x, y in ((14, 13), (15, 13), (14, 14), (15, 14)):
        put(img, x, y, (230, 190, 70))
    put(img, 14, 13, (255, 236, 150))
    return img


def door_side(band):
    """Door in a wall that runs up-down: seen edge-on from above."""
    pal = BANDS[band]
    img = floor_tile(band, 0)
    wood = {"gate": (70, 70, 78), "palace": (168, 44, 40)}.get(band, (122, 80, 42))
    for y in range(C):
        for x in range(9, 15):
            c = shade(wood, 0.2 if x == 9 else (-0.3 if x == 14 else 0.0))
            if y in (0, 1, 22, 23):
                c = shade(pal["wall"], -0.1)
            put(img, x, y, c)
    for y in (6, 17):
        for x in range(9, 15):
            put(img, x, y, shade(wood, -0.45))
    return img


def stairs(band):
    """Steps going down into a dark pit with a cold glow at the bottom."""
    pal = BANDS[band]
    img = floor_tile(band, 0)
    rim = shade(pal["trim"], 0.1)
    rect(img, 3, 3, 20, 21, shade(pal["mortar"], -0.2))
    for x in range(3, 21):
        put(img, x, 3, rim)
    for y in range(3, 22):
        put(img, 3, y, shade(rim, -0.2))
        put(img, 20, y, shade(rim, -0.45))
    for i in range(4):
        y0 = 5 + i * 4
        base = shade(pal["floor"], 0.15 - i * 0.22)
        for y in range(y0, y0 + 3):
            for x in range(4 + i, 20 - i):
                put(img, x, y, shade(base, 0.25) if y == y0 else base)
    for x in range(8, 16):
        put(img, x, 21, (70, 110, 170))
    for x in range(9, 15):
        put(img, x, 20, (46, 70, 120))
    return img


def well(band, frame):
    img = floor_tile(band, 1)
    cx, cy = 11.5, 12.0
    for y in range(C):
        for x in range(C):
            d = ((x - cx) / 9.5) ** 2 + ((y - cy) / 8.5) ** 2
            if d <= 1.0:
                if d > 0.62:
                    c = (150, 144, 160) if (x < cx and y < cy + 2) else (104, 98, 116)
                    if d > 0.9:
                        c = (70, 64, 80)
                    put(img, x, y, c)
                else:
                    deep = (36, 82, 160) if d > 0.25 else (52, 108, 196)
                    put(img, x, y, deep)
    for i, (x, y) in enumerate(((8, 10), (9, 10), (13, 13), (14, 13), (10, 15))):
        put(img, x + (frame if i % 2 == 0 else -frame), y, (150, 206, 250))
    return img


def altar(band, frame):
    img = floor_tile(band, 2)
    stone_c = (150, 142, 160) if band != "palace" else (120, 70, 50)
    rect(img, 3, 10, 20, 12, shade(stone_c, 0.25))
    rect(img, 4, 13, 19, 19, stone_c)
    rect(img, 4, 19, 19, 19, shade(stone_c, -0.35))
    rect(img, 5, 20, 7, 21, shade(stone_c, -0.2))
    rect(img, 16, 20, 18, 21, shade(stone_c, -0.2))
    for x in range(9, 15):  # offering bowl
        put(img, x, 9, (220, 176, 64))
    for x in range(10, 14):
        put(img, x, 8, (250, 210, 100))
    put(img, 11, 7, (255, 240, 170))
    for cx in (5, 18):
        candle(img, cx, 9, frame)
    return img


def candle(img, x, base_y, frame):
    rect(img, x, base_y - 4, x + 1, base_y, (238, 232, 218))
    put(img, x + 1, base_y - 4, (200, 192, 180))
    tip = base_y - 5
    if frame == 0:
        put(img, x, tip, FLAME[1])
        put(img, x, tip - 1, FLAME[0])
        put(img, x + 1, tip, FLAME[2])
    else:
        put(img, x + 1, tip, FLAME[1])
        put(img, x + 1, tip - 1, FLAME[0])
        put(img, x, tip - 1, FLAME[2])


def trap_spotted(band):
    pal = BANDS[band]
    img = floor_tile(band, 0)
    plate = shade(pal["floor"], 0.1)
    rect(img, 5, 5, 18, 18, plate)
    for i in range(5, 19):
        put(img, i, 5, shade(plate, 0.3))
        put(img, 5, i, shade(plate, 0.2))
        put(img, i, 18, shade(plate, -0.45))
        put(img, 18, i, shade(plate, -0.35))
    red = (200, 48, 48)
    for x, y in ((11, 8), (12, 8), (10, 9), (13, 9), (11, 10), (12, 10), (11, 11), (12, 11), (9, 12), (14, 12),
                 (11, 13), (12, 13), (10, 15), (11, 15), (12, 15), (13, 15)):
        put(img, x, y, red)
    return img


def trap_spent(band):
    pal = BANDS[band]
    img = trap_spotted(band)
    rect(img, 6, 6, 17, 17, shade(pal["floor"], -0.4))
    for sx in (8, 12, 16):
        for sy in (9, 13, 17):
            put(img, sx - 1, sy, (120, 120, 130))
            put(img, sx - 1, sy - 1, (190, 190, 200))
            put(img, sx - 1, sy - 2, (200, 70, 70))
    return img


# ---------------------------------------------------------------- decor

def decor(band, name, frame):
    """Transparent overlays laid on plain floor tiles."""
    pal = BANDS[band]
    img = canvas(C, C)
    rng = rng_for(band, name)
    if name == "bones":
        for i in range(6):
            put(img, 6 + i, 15 + i // 2, BONE)
            put(img, 6 + i, 16 + i // 2, shade(BONE, -0.3))
        for x, y in ((5, 14), (5, 16), (12, 17), (12, 19)):
            put(img, x, y, BONE)
        for i in range(4):
            put(img, 15 + i, 9 - i, BONE)
        put(img, 14, 10, BONE)
        put(img, 19, 5, BONE)
    elif name == "skull":
        rect(img, 12, 12, 17, 15, BONE)
        rect(img, 13, 11, 16, 11, BONE)
        rect(img, 13, 16, 16, 17, shade(BONE, -0.2))
        for x, y in ((13, 13), (16, 13)):
            put(img, x, y, (40, 30, 40))
            put(img, x, y + 1, (60, 50, 60))
        put(img, 14, 17, (70, 60, 70))
        put(img, 15, 17, (70, 60, 70))
        for x in range(12, 18):
            put(img, x, 18, (0, 0, 0), 70)
    elif name == "crack":
        dark = shade(pal["mortar"], -0.2)
        crack_line(img, rng, dark, (4, 3), 9)
        crack_line(img, rng, dark, (14, 12), 7)
    elif name == "pebbles":
        for (x, y) in ((6, 7), (15, 10), (10, 17), (18, 18)):
            c = shade(pal["floor"], rng.uniform(-0.1, 0.25))
            rect(img, x, y, x + 1, y, shade(c, 0.2))
            rect(img, x, y + 1, x + 1, y + 1, shade(c, -0.25))
    elif name == "grass":
        for bx in (5, 12, 17):
            for i in range(rng.randint(3, 5)):
                h = rng.randint(2, 4)
                for y in range(h):
                    put(img, bx + i - 1 + (y // 3), 19 - y, (132, 126, 84) if y else (98, 92, 64))
    elif name == "paper":
        paper = (222, 196, 112)
        rect(img, 8, 9, 13, 17, paper)
        for y in range(10, 17, 2):
            put(img, 10, y, (190, 50, 50))
            put(img, 11, y, (190, 50, 50))
        for x, y in ((13, 17), (12, 17), (13, 16)):
            put(img, x, y, (60, 44, 34))
    elif name == "puddle":
        for y in range(C):
            for x in range(C):
                d = ((x - 12) / 7.0) ** 2 + ((y - 14) / 3.5) ** 2
                if d <= 1.0:
                    put(img, x, y, (58, 104, 150) if d > 0.4 else (80, 132, 178))
        for x in (9, 10, 14):
            put(img, x, 13, (170, 214, 240))
    elif name == "reeds":
        for bx, h in ((7, 10), (9, 13), (11, 8), (15, 11), (17, 9)):
            for y in range(h):
                put(img, bx + (1 if y > h - 3 else 0), 20 - y, (82, 140, 78) if y < h - 2 else (120, 176, 96))
            put(img, bx, 20 - h, (140, 96, 60))
    elif name == "lotus":
        for y in range(C):
            for x in range(C):
                if ((x - 12) / 6.0) ** 2 + ((y - 15) / 3.0) ** 2 <= 1.0:
                    put(img, x, y, (60, 120, 70))
        pink, light = (226, 120, 160), (248, 186, 210)
        for x, y in ((10, 12), (11, 11), (12, 10), (13, 11), (14, 12), (11, 13), (13, 13), (12, 12)):
            put(img, x, y, light if y < 12 else pink)
        put(img, 12, 12, (250, 220, 90))
    elif name == "chain":
        for i in range(8):
            x, y = 5 + i * 2, 8 + i
            put(img, x, y, (140, 140, 150))
            put(img, x + 1, y, (90, 90, 100))
            put(img, x, y + 1, (70, 70, 80))
    elif name == "ember":
        glow = pal.get("glow", (255, 128, 44))
        pts = ((6, 8), (15, 6), (11, 15), (18, 17), (7, 19))
        for i, (x, y) in enumerate(pts):
            lit = (i + frame) % 2 == 0
            put(img, x, y, (255, 214, 120) if lit else glow)
            put(img, x + 1, y, shade(glow, -0.4))
    elif name == "lava":
        glow = pal.get("glow", (255, 128, 44))
        x, y = 5, 9
        path = rng_for("lava-path")
        for _ in range(16):
            core = (255, 224, 120) if (x + y + frame) % 3 == 0 else glow
            put(img, x, y, core)
            put(img, x, y + 1, shade(glow, -0.45))
            x += 1
            y += path.choice((-1, 0, 0, 1))
            y = max(4, min(19, y))
    elif name == "coins":
        for x, y in ((8, 12), (13, 15), (16, 10), (10, 18)):
            rect(img, x, y, x + 2, y + 1, (226, 186, 70))
            put(img, x + 1, y, (120, 90, 40))
            put(img, x, y, (255, 230, 140))
    elif name == "cushion":
        red, gold = (168, 40, 48), pal["trim"]
        rect(img, 5, 7, 18, 18, red)
        for i in range(5, 19):
            put(img, i, 7, gold)
            put(img, i, 18, shade(gold, -0.3))
            put(img, 5, i - 0 if i < 19 else 18, gold)
        for i in range(7, 19):
            put(img, 5, i, gold)
            put(img, 18, i, shade(gold, -0.3))
        rect(img, 10, 11, 13, 14, shade(red, 0.2))
        put(img, 11, 12, gold)
        put(img, 12, 13, gold)
    elif name == "scroll":
        rect(img, 6, 13, 17, 16, (232, 222, 196))
        rect(img, 5, 12, 5, 17, (120, 70, 40))
        rect(img, 18, 12, 18, 17, (120, 70, 40))
        for x in range(8, 16, 2):
            put(img, x, 14, (40, 36, 44))
    elif name == "incense":
        bronze = (150, 110, 60)
        rect(img, 8, 15, 15, 18, bronze)
        rect(img, 9, 19, 14, 19, shade(bronze, -0.4))
        for x in range(8, 16):
            put(img, x, 15, shade(bronze, 0.35))
        put(img, 11, 13, (90, 60, 40))
        put(img, 11, 14, (90, 60, 40))
        put(img, 11, 12, (255, 150, 60))
        smoke = (200, 196, 214)
        for i in range(6):
            sx = 11 + int(round(math.sin(i * 1.1 + frame * 1.6)))
            put(img, sx, 11 - i, smoke, 170 - i * 22)
    elif name == "candle":
        candle(img, 16, 18, frame)
        candle(img, 7, 12, 1 - frame)
    return img


# ---------------------------------------------------------------- atlas

def band_cells(band):
    """(name, image) pairs in atlas order. The order is the same for every
    band, so one index table serves them all."""
    cells = []
    for v in range(FLOOR_VARIANTS):
        cells.append(("floor_%d" % v, floor_tile(band, v)))
    for v in range(2):
        cells.append(("wall_face_%d" % v, wall_face(band, v)))
    cells.append(("wall_face_special", wall_face_special(band)))
    for v in range(2):
        cells.append(("wall_top_%d" % v, wall_top(band, v)))
    cells += [("door", door(band)), ("door_side", door_side(band)), ("stairs", stairs(band))]
    for f in range(2):
        cells.append(("well_%d" % f, well(band, f)))
    for f in range(2):
        cells.append(("altar_%d" % f, altar(band, f)))
    cells += [("trap_spotted", trap_spotted(band)), ("trap_spent", trap_spent(band))]
    return cells


def decor_cells(band):
    cells = []
    for name, frames in DECOR[band]:
        for f in range(frames):
            cells.append(("decor_%s_%d" % (name, f), decor(band, name, f)))
    return cells


def all_decor_names():
    names = []
    for band in BANDS:
        for name, frames in DECOR[band]:
            for f in range(frames):
                n = "decor_%s_%d" % (name, f)
                if n not in names:
                    names.append(n)
    return names


def build():
    base_names = [n for n, _ in band_cells("path")]
    names = base_names + all_decor_names()
    index = {n: i for i, n in enumerate(names)}
    rows = (len(names) + COLS - 1) // COLS
    os.makedirs(OUT, exist_ok=True)
    previews = []
    for band in BANDS:
        atlas = canvas(COLS * C, rows * C)
        for name, img in band_cells(band) + decor_cells(band):
            i = index[name]
            atlas.alpha_composite(img, ((i % COLS) * C, (i // COLS) * C))
        atlas.save(os.path.join(OUT, band + ".png"))
        previews.append(atlas)
    write_gd(index)
    if os.environ.get("SHEET_DIR"):
        sheet(previews, 2, 3).save(os.path.join(os.environ["SHEET_DIR"], "tile_atlases.png"))
    print("tile atlases: %d bands x %d cells" % (len(BANDS), len(names)))


def write_gd(index):
    decor = {band: [[n, f] for n, f in DECOR[band]] for band in BANDS}
    lines = [
        "class_name TileAtlas",
        "## Generated by tools/gen_tiles.py. Do not edit by hand: rerun the script.",
        "## Where each tile sits in the per-band atlases under res://assets/sprites/tiles/.",
        "",
        "const CELL: int = %d" % C,
        "const COLS: int = %d" % COLS,
        "const FLOOR_VARIANTS: int = %d" % FLOOR_VARIANTS,
        "## One atlas per FloorTheme band, in band order.",
        "const BANDS: Array[String] = [%s]" % ", ".join('"%s"' % b for b in BANDS),
        "## Floor decor each band may scatter: [name, frame count].",
        "const DECOR := {",
    ]
    for band, entries in decor.items():
        lines.append('\t"%s": [' % band)
        pairs = ['["%s", %d]' % (n, f) for n, f in entries]
        for i in range(0, len(pairs), 4):
            lines.append("\t\t%s," % ", ".join(pairs[i:i + 4]))
        lines.append("\t],")
    lines += [
        "}",
        "## Decor that casts a little warm light.",
        "const LIGHTS: Array[String] = [%s]" % ", ".join('"%s"' % n for n in LIGHTS),
        "const INDEX := {",
    ]
    for name, i in index.items():
        lines.append('\t"%s": %d,' % (name, i))
    lines += [
        "}",
        "",
        "## The atlas region of a tile, in atlas pixels.",
        "static func region(tile_name: String) -> Rect2:",
        "\tvar i: int = INDEX.get(tile_name, 0)",
        "\treturn Rect2((i % COLS) * CELL, (i / COLS) * CELL, CELL, CELL)",
        "",
    ]
    with open(GD_OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    build()
