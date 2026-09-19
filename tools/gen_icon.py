"""Builds the app icon set from the mudang sprite. Run: python tools/gen_icon.py"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SPRITE = os.path.join(ROOT, "assets", "sprites", "actors", "mudang.png")
OUT = os.path.join(ROOT, "assets", "icon")


def background(size):
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / (size - 1)
        color = (int(34 + 22 * t), int(22 + 10 * t), int(52 + 30 * t), 255)
        for x in range(size):
            img.putpixel((x, y), color)
    return img


def sprite_scaled(px):
    s = Image.open(SPRITE).convert("RGBA")
    return s.resize((px, px), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    bg512 = background(512)
    bg512.alpha_composite(sprite_scaled(384), (64, 64))
    bg512.save(os.path.join(ROOT, "assets", "icon.png"))
    bg512.resize((192, 192), Image.NEAREST).save(os.path.join(OUT, "main_192.png"))
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(sprite_scaled(256), (88, 88))
    fg.save(os.path.join(OUT, "adaptive_foreground_432.png"))
    background(432).save(os.path.join(OUT, "adaptive_background_432.png"))
    print("icons written")


if __name__ == "__main__":
    main()
