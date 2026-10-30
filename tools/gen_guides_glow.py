#!/usr/bin/env python3
"""Draws the frame of the Guides button (data/images/ui/guides_glow.png): a thin golden border around the 20x20 button
with a shine running around it clockwise.

The image is a strip of FRAMES frames of SIZE x SIZE side by side; the Guides module (modules/game_guides) shows them one
after the other, and the Guides card about the button shows the first one. The border is one pixel wide, right outside
the button (the button is the middle 20x20 of a frame), shaded from pale to deep gold from top to bottom; the shine is a
small comet of warm white light with a soft halo on both sides of the border. Run from the client's root:

    python tools/gen_guides_glow.py
"""
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'data', 'images', 'ui', 'guides_glow.png')
SIZE = 24  # the frame: the 20x20 button and two pixels around it
FRAMES = 42  # the shine moves two pixels per frame around the 84 pixels of the border
RING = 1  # the border is the square one pixel in from the frame's edge, right outside the button

TOP, BOTTOM = (255, 236, 150), (214, 160, 24)  # the gold of the border at the top and at the bottom
SHINE = (255, 251, 232)  # the warm white of the shine
HEAD, TAIL = 1.6, 9.0  # how fast the shine fades ahead of its head and behind it (pixels)


def ring_pixels():
    """the border's pixels in clockwise order from the top left corner"""
    lo, hi = RING, SIZE - 1 - RING
    pixels = [(x, lo) for x in range(lo, hi)]
    pixels += [(hi, y) for y in range(lo, hi)]
    pixels += [(x, hi) for x in range(hi, lo, -1)]
    pixels += [(lo, y) for y in range(hi, lo, -1)]
    return pixels


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def outward(x, y):
    """the step from a border pixel to the pixel just outside it (corners go diagonally)"""
    lo, hi = RING, SIZE - 1 - RING
    return (-1 if x == lo else 1 if x == hi else 0), (-1 if y == lo else 1 if y == hi else 0)


def frame(head):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    pixels = ring_pixels()
    count = len(pixels)
    for i, (x, y) in enumerate(pixels):
        gold = mix(TOP, BOTTOM, y / (SIZE - 1))
        behind = (head - i) % count  # how far this pixel is behind the head of the shine
        ahead = count - behind
        light = math.exp(-(behind / TAIL) ** 2) if behind <= ahead else math.exp(-(ahead / HEAD) ** 2)
        px[x, y] = mix(gold, SHINE, light) + (255,)
        if light > 0.05:
            dx, dy = outward(x, y)
            for sx, sy, strength in ((x + dx, y + dy, 0.6), (x - dx, y - dy, 0.3)):
                if 0 <= sx < SIZE and 0 <= sy < SIZE:
                    r, g, b, a = px[sx, sy]
                    alpha = max(a, round(255 * light * strength))
                    px[sx, sy] = SHINE + (alpha,)
    return img


def main():
    count = len(ring_pixels())
    strip = Image.new('RGBA', (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
    for f in range(FRAMES):
        strip.alpha_composite(frame(round(f * count / FRAMES)), (f * SIZE, 0))
    strip.save(OUT, optimize=True)
    print('wrote', OUT, '(%d frames of %dx%d)' % (FRAMES, SIZE, SIZE))


if __name__ == '__main__':
    main()
