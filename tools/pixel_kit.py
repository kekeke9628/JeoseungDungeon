"""Helpers shared by the pixel-art generators: colour ramps that shift hue as
they darken or brighten (shadows go cool, light goes warm, the usual pixel-art
trick), tileable value noise, outlines and preview sheets."""
import colorsys
import random

from PIL import Image

COOL_HUE = 0.72  # shadows drift toward blue-violet
WARM_HUE = 0.12  # highlights drift toward yellow


def _toward(h, target, t):
    """Moves hue h (0-1, circular) toward target by fraction t."""
    d = ((target - h + 0.5) % 1.0) - 0.5
    return (h + d * t) % 1.0


def shade(rgb, amount):
    """amount < 0 darkens and cools, amount > 0 lightens and warms (-1..1)."""
    r, g, b = (c / 255.0 for c in rgb[:3])
    h, lum, s = colorsys.rgb_to_hls(r, g, b)
    if amount < 0:
        a = -amount
        lum *= 1.0 - a * 0.6
        h = _toward(h, COOL_HUE, a * 0.12)
        s = min(1.0, s * (1.0 + a * 0.15))
    else:
        lum += (1.0 - lum) * amount * 0.55
        h = _toward(h, WARM_HUE, amount * 0.1)
        s *= 1.0 - amount * 0.2
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, lum)), max(0.0, min(1.0, s)))
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))


def ramp(base):
    """Five tones: deep shadow, shadow, base, light, highlight."""
    return [shade(base, -0.55), shade(base, -0.28), tuple(base[:3]), shade(base, 0.25), shade(base, 0.5)]


def jitter(rgb, n):
    return tuple(max(0, min(255, c + n)) for c in rgb[:3])


class Noise:
    """Value noise on a lattice that wraps every `period` pixels, so a tile
    textured with it repeats without seams."""

    def __init__(self, seed, period=24, cell=6):
        rng = random.Random(str(seed))
        self.n = max(1, period // cell)
        self.cell = period / self.n
        self.v = [[rng.random() for _ in range(self.n)] for _ in range(self.n)]

    def at(self, x, y):
        fx, fy = x / self.cell, y / self.cell
        x0, y0 = int(fx) % self.n, int(fy) % self.n
        x1, y1 = (x0 + 1) % self.n, (y0 + 1) % self.n
        tx, ty = fx - int(fx), fy - int(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = self.v[y0][x0] + (self.v[y0][x1] - self.v[y0][x0]) * tx
        b = self.v[y1][x0] + (self.v[y1][x1] - self.v[y1][x0]) * tx
        return a + (b - a) * ty


def canvas(w, h, fill=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), fill)


def put(img, x, y, rgb, a=255):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), tuple(rgb[:3]) + (a,))


def rect(img, x0, y0, x1, y1, rgb):
    """Fills x0..x1, y0..y1 inclusive."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, rgb)


def outline(img, color=None, darken=0.75):
    """Adds a 1px outline around the opaque pixels. With color None each
    outline pixel takes a dark version of the pixel it borders (a 'selective'
    outline), which reads softer than flat black."""
    src = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    p = src.getpixel((nx, ny))
                    if p[3] != 0:
                        c = color if color is not None else shade(p, -darken)
                        img.putpixel((x, y), tuple(c[:3]) + (255,))
                        break
    return img


def sheet(images, cols, scale, bg=(40, 36, 48, 255), pad=2):
    """Lays images out on a grid, scaled up with nearest neighbour, for previews."""
    if not images:
        return canvas(1, 1)
    cw = max(i.width for i in images) + pad
    ch = max(i.height for i in images) + pad
    rows = (len(images) + cols - 1) // cols
    out = Image.new("RGBA", (cols * cw, rows * ch), bg)
    for i, im in enumerate(images):
        out.alpha_composite(im, ((i % cols) * cw, (i // cols) * ch))
    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)
