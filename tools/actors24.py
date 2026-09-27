"""24x24 character art, built from simple shapes and lit from the top left.

Each shape fills pixels with a material and a light value; render() turns the
light into one of five tones of the material's colour ramp (pixel_kit.ramp),
then adds a dark outline. Every character gets two idle frames: 'breath'
(the upper body sinks a pixel) or 'float' (the whole figure rises a pixel).
Characters face right; the game flips them when they move left."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_kit import canvas, outline, ramp  # noqa: E402

S = 24
OUTLINE = (18, 14, 26)
LIGHT = (-0.5, -0.62, 0.6)
_ll = math.sqrt(sum(v * v for v in LIGHT))
LIGHT = tuple(v / _ll for v in LIGHT)
SKIN = (236, 200, 168)
PALE = (214, 222, 230)


def tone(v):
    if v > 0.78:
        return 4
    if v > 0.42:
        return 3
    if v > -0.02:
        return 2
    if v > -0.45:
        return 1
    return 0


class Fig:
    """A 24x24 drawing: (x, y) -> (material, light value or fixed tone)."""

    def __init__(self):
        self.px = {}

    def _set(self, x, y, mat, val):
        if 0 <= x < S and 0 <= y < S:
            self.px[(x, y)] = (mat, val)

    def ell(self, cx, cy, rx, ry, mat, bias=0.0, flat=None):
        """Filled ellipse, shaded as a sphere (or one tone with flat)."""
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    if flat is not None:
                        self._set(x, y, mat, ("t", flat))
                        continue
                    dz = math.sqrt(max(0.0, 1.0 - d))
                    v = dx * LIGHT[0] + dy * LIGHT[1] + dz * LIGHT[2]
                    self._set(x, y, mat, v + bias)

    def poly(self, pts, mat, bias=0.0, flat=None, fade=0.3):
        """Filled polygon, shaded like an upright cylinder, a little darker
        toward the bottom (fade)."""
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        for y in range(int(math.floor(y0)), int(math.ceil(y1)) + 1):
            for x in range(int(math.floor(x0)), int(math.ceil(x1)) + 1):
                if not _inside(pts, x + 0.5, y + 0.5):
                    continue
                if flat is not None:
                    self._set(x, y, mat, ("t", flat))
                    continue
                w = max(1.0, x1 - x0)
                dx = ((x + 0.5 - x0) / w) * 2.0 - 1.0
                dz = math.sqrt(max(0.0, 1.0 - dx * dx))
                v = dx * LIGHT[0] - 0.25 * LIGHT[1] + dz * LIGHT[2]
                v -= fade * ((y + 0.5 - y0) / max(1.0, y1 - y0))
                self._set(x, y, mat, v + bias)

    def box(self, x0, y0, x1, y1, mat, bias=0.0, flat=None, fade=0.3):
        self.poly([(x0, y0), (x1 + 1, y0), (x1 + 1, y1 + 1), (x0, y1 + 1)], mat, bias, flat, fade)

    def line(self, x0, y0, x1, y1, mat, t=2):
        """A one-pixel line in a fixed tone t."""
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self._set(x0, y0, mat, ("t", t))
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def dot(self, x, y, mat, t=2):
        self._set(x, y, mat, ("t", t))

    def erase(self, x, y):
        self.px.pop((x, y), None)

    def shifted(self, mode, waist):
        out = Fig()
        for (x, y), v in self.px.items():
            if mode == "float":
                out._set(x, y - 1, *v)
            elif y < waist:
                out._set(x, y + 1, *v)
        if mode != "float":
            for (x, y), v in self.px.items():
                if y >= waist and (x, y) not in out.px:
                    out._set(x, y, *v)
        return out

    def render(self, pal):
        img = canvas(S, S)
        ramps = {}
        for (x, y), (mat, val) in self.px.items():
            base = pal[mat]
            if isinstance(base, tuple) and len(base) == 2 and base[0] == "flat":
                img.putpixel((x, y), base[1] + (255,))
                continue
            r = ramps.setdefault(mat, ramp(base))
            t = val[1] if isinstance(val, tuple) else tone(val)
            img.putpixel((x, y), r[t] + (255,))
        return outline(img, OUTLINE)


def _inside(pts, x, y):
    inside = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def flat(rgb):
    return ("flat", rgb)


# ------------------------------------------------------------ shared parts

def human(f, robe="robe", sleeve=None, skin="skin", hem=20, wide=6, arms=True, legs=True):
    """Front-facing body in a long robe: shoulders at y 11, hem at `hem`."""
    sleeve = sleeve or robe
    f.poly([(8, 11), (16, 11), (12 + wide, hem + 1), (12 - wide, hem + 1)], robe)
    if arms:
        f.poly([(5, 12), (8, 11), (9, 17), (6, 18)], sleeve, bias=0.1)
        f.poly([(16, 11), (19, 12), (18, 18), (15, 17)], sleeve, bias=-0.15)
        f.ell(6.8, 18.2, 1.3, 1.1, skin)
        f.ell(17.2, 18.2, 1.3, 1.1, skin, bias=-0.2)
    if legs:
        f.box(9, hem + 1, 10, 22, "shoe", fade=0)
        f.box(13, hem + 1, 14, 22, "shoe", bias=-0.2, fade=0)


def head(f, cy=7.0, skin="skin", eyes="eye", eye_y=None, rx=3.7, ry=3.9):
    f.ell(12, cy, rx, ry, skin)
    ey = int(eye_y if eye_y is not None else cy + 0.5)
    if eyes:
        f.dot(10, ey, eyes)
        f.dot(13, ey, eyes)


def gat(f, y=3, brim="hat", color_bias=0.0, tassel=None):
    """Korean horsehair hat: crown and a wide brim."""
    f.box(9, y - 3, 14, y, brim, bias=color_bias)
    f.ell(12, y + 1.2, 7.5, 1.3, brim, bias=color_bias)
    if tassel:
        for yy in range(y + 2, y + 7):
            f.dot(17, yy, tassel, 3 if yy % 2 else 2)


def ghost_tail(f, mat, top=11, left=7, right=17, bottom=21):
    f.poly([(left, top), (right, top), (right - 1, bottom - 3), (15, bottom), (13, bottom - 2),
            (11, bottom), (9, bottom - 2), (left + 1, bottom - 4)], mat)


def quadruped(f, body="fur", head_mat=None, legs="fur", tail="fur", belly=None, big=False):
    head_mat = head_mat or body
    ry = 4.4 if big else 3.8
    f.ell(11, 14, 6.8 if big else 6.2, ry, body)
    for lx, far in ((7, True), (10, False), (14, True), (16, False)):
        f.box(lx, 16, lx + 1, 21, legs, bias=-0.45 if far else 0.0, fade=0.2)
        f.dot(lx, 21, "claw", 1)
        f.dot(lx + 1, 21, "claw", 1)
    if belly:
        f.ell(11, 16.6, 4.5, 1.2, belly)
    f.ell(18, 10.5, 3.4, 3.1, head_mat)
    f.box(20, 11, 22, 12, head_mat, bias=-0.1)
    f.dot(22, 11, "nose", 1)


# ------------------------------------------------------------ heroes

def mudang(f):
    """Shaman: white robe, red sash, a five-colour fan and a hairpin."""
    human(f, robe="robe", sleeve="robe")
    f.box(8, 15, 16, 15, "sash", fade=0)
    f.ell(14.5, 15.5, 1.3, 1.1, "sash")  # a knot on one side, ribbons hanging
    f.line(14, 16, 13, 19, "sash", 2)
    f.line(15, 16, 16, 19, "sash", 1)
    head(f)
    f.ell(12, 4.8, 4.2, 2.6, "hair")
    f.ell(12, 1.9, 2.2, 1.6, "hair")
    f.dot(15, 2, "gold", 3)
    f.dot(16, 2, "gold", 2)
    f.box(9, 3, 10, 6, "hair")
    f.box(14, 3, 15, 6, "hair")
    for i, c in enumerate(("fan_r", "fan_y", "fan_b")):  # fan in the right hand
        f.poly([(18, 18), (21 - i, 12 + i * 2), (23 - i, 13 + i * 2)], c, flat=3)
    f.dot(5, 19, "gold", 3)  # bells
    f.dot(6, 20, "gold", 2)
    f.dot(4, 20, "gold", 2)


def hwarang(f):
    """Young knight: blue robe, gold belt, headband, a raised sword."""
    human(f, robe="robe", sleeve="robe")
    f.box(8, 15, 16, 15, "gold", fade=0)
    head(f)
    f.ell(12, 4.7, 4.1, 2.4, "hair")
    f.ell(12, 1.8, 1.6, 1.4, "hair")
    f.box(8, 5, 16, 5, "band", fade=0)
    f.dot(7, 6, "band", 2)
    f.dot(7, 7, "band", 1)
    f.line(18, 17, 22, 5, "steel", 3)  # sword
    f.line(19, 17, 23, 6, "steel", 1)
    f.box(17, 17, 19, 17, "gold", flat=2)
    f.box(17, 18, 17, 19, "hilt", flat=2)


def dosa(f):
    """Taoist sage: green robe, black gat, white beard, a staff."""
    human(f, robe="robe", sleeve="robe")
    f.box(8, 15, 16, 15, "sash", fade=0)
    head(f, cy=7.2)
    f.poly([(9, 9), (15, 9), (14, 14), (12, 16), (10, 14)], "beard")
    gat(f, y=4, brim="hat")
    f.line(4, 22, 4, 4, "staff", 2)
    f.line(5, 22, 5, 5, "staff", 1)
    f.ell(4.5, 3.5, 1.6, 1.6, "gourd")


# ------------------------------------------------------------ monsters

def mongdal(f):
    """Bachelor ghost: pale, a topknot, tattered white clothes."""
    ghost_tail(f, "body")
    f.poly([(5, 12), (8, 11), (8, 16), (5, 17)], "body", bias=0.1)
    f.poly([(16, 11), (19, 12), (19, 17), (16, 16)], "body", bias=-0.2)
    head(f, skin="face", eyes="eye")
    f.ell(12, 4.3, 3.9, 1.8, "hair")
    f.ell(12, 1.6, 1.4, 1.5, "hair")
    f.dot(10, 10, "mouth", 1)
    f.dot(11, 10, "mouth", 1)


def cheonyeo(f):
    """Maiden ghost: white mourning dress, long black hair over the face."""
    ghost_tail(f, "body", top=10, left=6, right=18)
    head(f, skin="face", eyes=None)
    f.ell(12, 5.6, 4.6, 3.4, "hair")
    f.poly([(7, 6), (9, 6), (9, 16), (7, 18)], "hair")
    f.poly([(15, 6), (17, 6), (17, 18), (15, 16)], "hair", bias=-0.2)
    f.box(10, 7, 14, 9, "face")
    f.dot(10, 8, "eye", 2)
    f.dot(13, 8, "eye", 2)
    f.dot(12, 10, "mouth", 2)
    f.poly([(5, 11), (7, 11), (7, 16), (4, 17)], "body", bias=0.1)
    f.poly([(17, 11), (19, 11), (20, 17), (17, 16)], "body", bias=-0.2)


def dalgyal(f):
    """Egg ghost: a smooth featureless face on a pale robe."""
    ghost_tail(f, "body", top=12)
    f.ell(12, 7.5, 4.6, 5.4, "egg")
    f.poly([(5, 13), (8, 12), (8, 17), (5, 18)], "body", bias=0.1)
    f.poly([(16, 12), (19, 13), (19, 18), (16, 17)], "body", bias=-0.2)


def mulgwisin(f):
    """Water ghost: dripping, weed-tangled hair, rising from a puddle."""
    f.ell(12, 20.5, 8.5, 2.2, "water")
    f.poly([(7, 11), (17, 11), (16, 20), (8, 20)], "body")
    head(f, skin="face", eyes="eye")
    f.ell(12, 5.2, 4.4, 3.1, "hair")
    for x, h in ((8, 14), (9, 12), (15, 13), (16, 15)):
        f.box(x, 6, x, h, "hair", bias=-0.1 if x > 12 else 0.1)
    f.line(8, 9, 7, 15, "weed", 3)
    f.line(16, 8, 17, 14, "weed", 2)
    f.poly([(4, 13), (7, 11), (8, 14), (5, 16)], "body", bias=0.1)
    f.poly([(17, 11), (20, 13), (19, 16), (16, 14)], "body", bias=-0.2)
    f.ell(4.5, 15.5, 1.2, 1.2, "face")
    f.ell(19.5, 15.5, 1.2, 1.2, "face", bias=-0.2)
    for x, y in ((6, 19), (10, 21), (15, 21), (18, 19)):
        f.dot(x, y, "water", 4)


def dokkaebi(f):
    """Goblin: red skin, one horn, a studded club, a big grin."""
    f.poly([(7, 11), (17, 11), (18, 19), (6, 19)], "skin")
    f.box(7, 17, 17, 19, "cloth", fade=0.1)
    for x in range(7, 18, 3):
        f.dot(x, 18, "cloth", 4)
    f.box(8, 20, 10, 22, "skin", bias=0.05)
    f.box(14, 20, 16, 22, "skin", bias=-0.25)
    f.ell(12, 7, 5.0, 4.5, "skin")
    f.poly([(11, 3), (13, 3), (12, 0)], "horn")
    f.ell(8, 4, 1.8, 1.6, "hair")
    f.ell(16, 4, 1.8, 1.6, "hair", bias=-0.2)
    f.dot(10, 6, "eye", 2)
    f.dot(14, 6, "eye", 2)
    f.box(9, 9, 15, 9, "mouth", flat=2)
    f.dot(10, 9, "fang", 2)
    f.dot(14, 9, "fang", 2)
    f.poly([(4, 12), (7, 11), (7, 16), (4, 16)], "skin", bias=0.1)
    f.poly([(17, 11), (20, 12), (20, 16), (17, 15)], "skin", bias=-0.2)
    f.poly([(19, 16), (21, 16), (23, 4), (20, 4)], "club")  # club
    for x, y in ((20, 7), (22, 9), (21, 12), (20, 5)):
        f.dot(x, y, "stud", 3)


def duoksini(f):
    """Hulking night demon: dark red, two horns, tusks, long arms."""
    f.poly([(6, 10), (18, 10), (19, 20), (5, 20)], "skin")
    f.ell(12, 13, 5, 3, "skin", bias=0.15)
    f.box(6, 18, 18, 20, "cloth", fade=0.1)
    f.box(7, 21, 9, 22, "skin")
    f.box(15, 21, 17, 22, "skin", bias=-0.25)
    f.ell(12, 6.5, 5.2, 4.3, "skin")
    f.poly([(7, 4), (9, 3), (6, 0)], "horn")
    f.poly([(15, 3), (17, 4), (18, 0)], "horn", bias=-0.2)
    f.dot(10, 6, "eye", 2)
    f.dot(14, 6, "eye", 2)
    f.box(10, 9, 14, 9, "mouth", flat=1)
    f.dot(10, 10, "fang", 3)
    f.dot(14, 10, "fang", 3)
    f.poly([(3, 11), (6, 10), (6, 19), (3, 20)], "skin", bias=0.1)
    f.poly([(18, 10), (21, 11), (21, 20), (18, 19)], "skin", bias=-0.25)
    for x in (3, 5, 19, 21):
        f.dot(x, 21, "claw", 3)


def yacha(f):
    """Lean, fierce yaksha: green skin, wild hair, crouched with claws out."""
    f.poly([(8, 11), (16, 11), (17, 17), (7, 17)], "skin")
    f.box(8, 16, 16, 18, "cloth", fade=0.1)
    f.poly([(7, 18), (10, 18), (8, 22), (5, 22)], "skin", bias=0.1)
    f.poly([(14, 18), (17, 18), (19, 22), (16, 22)], "skin", bias=-0.25)
    f.ell(12, 7.2, 4.0, 3.9, "skin")
    for x, top in ((8, 1), (10, 0), (12, 1), (14, 0), (16, 2)):
        f.line(x, 5, x + (1 if x > 12 else -1), top, "hair", 2)
    f.ell(12, 4.4, 4.2, 1.8, "hair")
    f.dot(10, 7, "eye", 2)
    f.dot(13, 7, "eye", 2)
    f.box(10, 9, 14, 9, "mouth", flat=1)
    f.dot(11, 10, "fang", 3)
    f.dot(13, 10, "fang", 3)
    f.poly([(3, 10), (8, 11), (8, 14), (4, 13)], "skin", bias=0.1)
    f.poly([(16, 11), (21, 10), (20, 13), (16, 14)], "skin", bias=-0.25)
    for x, y in ((2, 9), (2, 11), (22, 9), (22, 11)):
        f.dot(x, y, "claw", 3)


def okjol(f):
    """Hell jailer: red skin, horned iron helmet, black armour, a trident."""
    human(f, robe="armor", sleeve="armor", skin="skin", hem=19, wide=6)
    f.box(8, 13, 16, 13, "trim", fade=0)
    f.box(8, 16, 16, 16, "trim", fade=0)
    head(f, cy=7.4)
    f.ell(12, 4.8, 4.4, 2.6, "helm")
    f.poly([(7, 4), (9, 4), (5, 0)], "horn")
    f.poly([(15, 4), (17, 4), (19, 0)], "horn", bias=-0.2)
    f.dot(10, 8, "eye", 2)
    f.dot(13, 8, "eye", 2)
    f.line(20, 22, 20, 3, "pole", 2)
    f.line(18, 5, 18, 2, "steel", 3)
    f.line(22, 5, 22, 2, "steel", 2)
    f.box(18, 5, 22, 5, "steel", flat=3)
    f.dot(20, 1, "steel", 4)


def saja(f):
    """Reaper: black gat and robe, deathly pale face, the ledger of names."""
    human(f, robe="robe", sleeve="robe", skin="face", hem=20, wide=6)
    head(f, cy=7.6, skin="face", eyes="eye")
    f.dot(11, 10, "mouth", 1)
    f.dot(12, 10, "mouth", 1)
    gat(f, y=4, brim="hat")
    f.box(3, 14, 6, 19, "ledger", fade=0.1)  # ledger of names
    f.box(4, 15, 5, 15, "ink", flat=2)
    f.box(4, 17, 5, 17, "ink", flat=2)


def gangnim(f):
    """Gangnim, captain of reapers (boss): dark blue robe with gold, red
    chin-strap tassels, a red rope of binding."""
    f.poly([(7, 10), (17, 10), (20, 21), (4, 21)], "robe")
    f.box(11, 10, 12, 21, "gold", fade=0.1)
    f.box(6, 15, 18, 15, "gold", fade=0)
    f.poly([(3, 11), (7, 10), (8, 17), (4, 18)], "robe", bias=0.1)
    f.poly([(17, 10), (21, 11), (20, 18), (16, 17)], "robe", bias=-0.2)
    f.ell(5.5, 18.6, 1.4, 1.2, "face")
    f.ell(18.5, 18.6, 1.4, 1.2, "face", bias=-0.2)
    f.box(8, 22, 10, 23, "shoe", fade=0)
    f.box(14, 22, 16, 23, "shoe", bias=-0.2, fade=0)
    head(f, cy=6.6, skin="face", eyes="eye")
    f.box(10, 9, 13, 9, "mouth", flat=1)
    gat(f, y=3, brim="hat", tassel="tassel")
    f.dot(6, 3, "tassel", 3)
    f.dot(6, 4, "tassel", 2)
    for i in range(7):  # red binding rope in the left hand
        f.dot(2 + (i % 2), 13 + i, "rope", 3 if i % 2 else 2)


def yeomra(f):
    """King Yama (boss): red royal robe with gold, a crown with bead strings,
    a black beard, holding the ivory tablet of judgement."""
    f.poly([(6, 10), (18, 10), (21, 22), (3, 22)], "robe")
    f.ell(12, 15.5, 2.6, 2.6, "gold")  # embroidered roundel
    f.ell(12, 15.5, 1.4, 1.4, "robe", bias=0.2)
    f.box(5, 19, 19, 19, "gold", fade=0)
    f.poly([(2, 11), (6, 10), (7, 18), (3, 19)], "robe", bias=0.1)
    f.poly([(18, 10), (22, 11), (21, 19), (17, 18)], "robe", bias=-0.2)
    f.box(11, 11, 13, 17, "tablet", fade=0.1)  # tablet held in both hands
    f.ell(9.5, 16.5, 1.3, 1.1, "skin")
    f.ell(14.5, 16.5, 1.3, 1.1, "skin", bias=-0.2)
    head(f, cy=6.8, eyes="eye")
    f.poly([(9, 9), (15, 9), (14, 12), (12, 13), (10, 12)], "beard")
    f.box(7, 1, 16, 2, "crown", fade=0)  # mian crown: flat board, bead strings
    f.box(9, 3, 14, 3, "crown", bias=-0.2, fade=0)
    for x in (7, 9, 14, 16):
        for y in (3, 4):
            f.dot(x, y, "bead", 3 if y == 3 else 2)


def dog(f):
    """Black dog of the underworld with red eyes."""
    quadruped(f, body="fur")
    f.poly([(16, 8), (18, 8), (16, 5)], "fur", bias=0.2)
    f.poly([(18, 8), (20, 8), (20, 5)], "fur", bias=-0.1)
    f.line(5, 13, 2, 8, "fur", 2)
    f.dot(19, 10, "eye", 2)
    f.dot(21, 13, "fang", 3)


def gumiho(f):
    """Nine-tailed fox: golden fur, white tail tips fanned behind."""
    for i in range(9):
        a = math.radians(110 + i * 14)
        x1 = int(round(6 + math.cos(a) * 6))
        y1 = int(round(12 - math.sin(a) * 7))
        f.line(6, 13, x1, y1, "fur", 3 if i % 2 else 2)
        f.dot(x1, y1, "tip", 3)
    quadruped(f, body="fur", belly="tip")
    f.poly([(16, 8), (18, 8), (16, 4)], "fur", bias=0.2)
    f.poly([(18, 8), (20, 8), (20, 4)], "fur", bias=-0.1)
    f.dot(19, 10, "eye", 2)


def jangsanbeom(f):
    """White beast of Jangsan: shaggy white fur, a long mane, gold eyes."""
    quadruped(f, body="fur", big=True)
    for x in range(6, 17, 2):
        f.dot(x, 9, "fur", 4)
        f.dot(x + 1, 10, "fur", 3)
    f.poly([(14, 7), (21, 7), (22, 14), (15, 15)], "mane")
    f.ell(18.5, 10.5, 3.0, 2.6, "fur")
    f.box(20, 11, 22, 12, "fur", bias=-0.1)
    f.dot(22, 11, "nose", 1)
    f.dot(19, 10, "eye", 2)
    f.line(4, 13, 1, 16, "fur", 3)


def bulgasari(f):
    """Iron-eater: a bull-bodied beast of grey metal, spines, glowing eyes."""
    quadruped(f, body="metal", big=True, legs="metal")
    for x in range(6, 17, 3):
        f.poly([(x, 10), (x + 2, 10), (x + 1, 7)], "spike")
    f.poly([(17, 7), (18, 7), (17, 4)], "spike")
    f.dot(19, 10, "eye", 2)
    f.dot(20, 10, "eye", 1)
    for x, y in ((9, 13), (13, 12), (11, 15)):
        f.dot(x, y, "rivet", 3)


def sangyeo(f):
    """Bier ghost: a hunched grey figure carrying a painted funeral bier."""
    f.poly([(7, 12), (17, 12), (18, 21), (6, 21)], "body")
    f.box(8, 22, 10, 22, "body", bias=-0.1)
    f.box(14, 22, 16, 22, "body", bias=-0.3)
    head(f, cy=10.5, skin="face", eyes="eye", rx=3.3, ry=3.2)
    f.box(2, 5, 21, 7, "bier_red", fade=0)  # the bier on its shoulders
    f.box(4, 2, 19, 4, "bier_blue", fade=0)
    f.poly([(6, 2), (18, 2), (12, 0)], "bier_gold", flat=3)
    for x in (3, 8, 15, 20):
        f.box(x, 7, x, 8, "wood", flat=1)
    for x in range(5, 19, 3):
        f.dot(x, 3, "bier_gold", 3)
    f.poly([(4, 13), (7, 12), (7, 17), (4, 17)], "body", bias=0.1)
    f.poly([(17, 12), (20, 13), (20, 17), (17, 17)], "body", bias=-0.2)


def imugi(f):
    """Imugi, the great serpent that never became a dragon: green coils."""
    f.ell(12, 19, 9.0, 3.4, "scale")
    f.ell(12, 18.4, 6.0, 1.4, "belly")
    f.ell(10.5, 15, 6.5, 2.8, "scale", bias=0.05)
    f.ell(10.5, 14.2, 4.2, 1.0, "belly")
    f.poly([(12, 13), (16, 13), (17, 7), (14, 6)], "scale")
    f.ell(16.5, 5.6, 3.8, 2.8, "scale", bias=0.1)
    f.box(18, 6, 21, 7, "scale", bias=-0.1)
    f.dot(17, 5, "eye", 3)
    f.dot(18, 5, "eye", 1)
    f.line(21, 8, 23, 9, "tongue", 3)
    f.dot(23, 10, "tongue", 2)
    for x, y in ((5, 18), (9, 20), (14, 20), (18, 18), (7, 15), (12, 14)):
        f.dot(x, y, "scale", 0)


# ------------------------------------------------------------ roster

COMMON = {"eye": flat((250, 250, 250)), "mouth": flat((60, 24, 30)), "fang": (240, 236, 220),
          "shoe": (52, 44, 60), "gold": (232, 186, 70), "claw": (220, 214, 200), "nose": (30, 24, 30)}

# id: (draw function, idle mode, waist row for breathing, palette)
ACTORS = {
    "mudang": (mudang, "breath", 13, dict(robe=(236, 236, 246), sash=(206, 44, 54), hair=(40, 34, 48), skin=SKIN,
                                         fan_r=(214, 50, 50), fan_y=(240, 200, 60), fan_b=(60, 100, 200),
                                         eye=flat((40, 30, 40)))),
    "hwarang": (hwarang, "breath", 13, dict(robe=(78, 128, 214), hair=(40, 34, 48), skin=SKIN, band=(210, 50, 60),
                                           steel=(214, 220, 236), hilt=(110, 70, 40), eye=flat((40, 30, 40)))),
    "dosa": (dosa, "breath", 13, dict(robe=(88, 168, 100), sash=(240, 240, 240), hat=(48, 44, 56), skin=SKIN,
                                     beard=(236, 236, 240), staff=(140, 96, 56), gourd=(214, 150, 60),
                                     eye=flat((40, 30, 40)))),
    "mongdal": (mongdal, "float", 0, dict(body=(206, 214, 236), face=PALE, hair=(40, 40, 60),
                                         eye=flat((30, 30, 60)))),
    "cheonyeo_gwisin": (cheonyeo, "float", 0, dict(body=(242, 242, 250), face=(226, 230, 236), hair=(22, 20, 30),
                                                   eye=flat((200, 30, 40)), mouth=flat((150, 20, 30)))),
    "dalgyal_gwisin": (dalgyal, "float", 0, dict(body=(222, 218, 196), egg=(240, 234, 214))),
    "mulgwisin": (mulgwisin, "breath", 14, dict(body=(64, 130, 170), face=(170, 206, 214), hair=(20, 36, 44),
                                               weed=(70, 140, 80), water=(70, 130, 190), eye=flat((240, 250, 255)))),
    "dokkaebi": (dokkaebi, "breath", 12, dict(skin=(214, 76, 70), horn=(240, 226, 170), hair=(60, 40, 40),
                                             cloth=(120, 180, 80), club=(150, 104, 60), stud=(200, 200, 210),
                                             eye=flat((255, 240, 120)))),
    "duoksini": (duoksini, "breath", 12, dict(skin=(128, 52, 52), horn=(220, 210, 180), cloth=(60, 50, 60),
                                             eye=flat((255, 200, 60)))),
    "yacha": (yacha, "breath", 12, dict(skin=(84, 150, 94), hair=(40, 30, 40), cloth=(150, 50, 60),
                                       eye=flat((255, 255, 120)))),
    "okjol": (okjol, "breath", 13, dict(armor=(58, 50, 62), skin=(190, 70, 60), trim=(150, 120, 70),
                                       helm=(90, 90, 100), horn=(232, 222, 190), pole=(110, 76, 48),
                                       steel=(200, 204, 214), eye=flat((255, 220, 60)))),
    "jeoseung_saja": (saja, "breath", 13, dict(robe=(38, 36, 46), face=(222, 226, 232), hat=(26, 24, 32),
                                              ledger=(224, 206, 150), ink=flat((40, 30, 30)),
                                              eye=flat((230, 40, 40)))),
    "gangnim": (gangnim, "breath", 12, dict(robe=(40, 52, 128), face=(226, 222, 214), hat=(28, 26, 36),
                                           tassel=(214, 40, 50), rope=(206, 40, 44), eye=flat((40, 60, 160)))),
    "yeomra": (yeomra, "breath", 12, dict(robe=(176, 34, 36), skin=SKIN, beard=(30, 26, 34), tablet=(240, 232, 206),
                                         crown=(40, 34, 44), bead=(240, 200, 70), eye=flat((255, 220, 90)))),
    "jeoseung_dog": (dog, "breath", 12, dict(fur=(56, 54, 66), eye=flat((255, 60, 60)))),
    "gumiho": (gumiho, "breath", 12, dict(fur=(236, 176, 82), tip=(250, 246, 236), eye=flat((50, 20, 20)))),
    "jangsanbeom": (jangsanbeom, "breath", 12, dict(fur=(226, 226, 230), mane=(246, 246, 250),
                                                    eye=flat((240, 190, 40)))),
    "bulgasari": (bulgasari, "breath", 12, dict(metal=(112, 116, 128), spike=(170, 176, 190), rivet=(200, 200, 210),
                                               eye=flat((255, 150, 50)))),
    "sangyeo_gwi": (sangyeo, "breath", 11, dict(body=(122, 110, 100), face=(200, 196, 184), bier_red=(190, 50, 50),
                                               bier_blue=(60, 90, 170), bier_gold=(236, 196, 80), wood=(90, 60, 40),
                                               eye=flat((255, 200, 80)))),
    "imugi": (imugi, "breath", 10, dict(scale=(56, 118, 76), belly=(200, 200, 140), eye=flat((255, 230, 80)),
                                       tongue=(220, 50, 60))),
}


def frames(actor_id):
    draw, mode, waist, pal = ACTORS[actor_id]
    f = Fig()
    draw(f)
    full = dict(COMMON)
    full.update(pal)
    return [f.render(full), f.shifted(mode, waist).render(full)]


def strip(actor_id):
    """Both idle frames side by side (48x24): what the game loads."""
    a, b = frames(actor_id)
    out = canvas(S * 2, S)
    out.alpha_composite(a, (0, 0))
    out.alpha_composite(b, (S, 0))
    return out
