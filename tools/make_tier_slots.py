#!/usr/bin/env python3
"""The tier slots (the owner, 2026-11-09: "é suposto notar-se a raridade mas muito suave", then "mais suave ainda e mais
trabalhado"). Like Awaken Legends' rarity slots the tier is in the slot picture, under the item, but as a light veil
over the game's own stone slot (layouts/reborn/images/ui/item.png), which keeps showing through:

- a faint veil of the tier's colour, with a soft glow rising from the bottom middle, where the item stands;
- a fine line in the colour along the edge, light at the top left and darker at the bottom right, strongest at the
  corners and fading towards the middle of each side;
- at each corner a second, inner line (a small double bracket) and a point of light, and a tiny dot one step inside;
- a hint of shadow just inside the line, so the veil sits within the frame.

Static, nothing drawn over the item. data/images/game/tiers/slot_t1.png .. slot_t6.png, 34x34; modules/game_tiers sets it
as the item widget's picture with an image border of 6, so larger slots keep their corners.

  python tools/make_tier_slots.py                      the slots of the game
  python tools/make_tier_slots.py <strength> <folder>  the same at another strength (STRENGTH is the game's), to compare
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
BASE = os.path.join(ROOT, 'layouts', 'reborn', 'images', 'ui', 'item.png')
OUT = os.path.join(ROOT, 'data', 'images', 'game', 'tiers')
SIZE = 34
LAST = SIZE - 1
# t1 white (common), t2 green, t3 blue, t4 purple, t5 gold, t6 red; and how much each one shows (white and gold read
# brighter on the dark stone, so a little less)
COLORS = {1: (210, 214, 220), 2: (84, 214, 108), 3: (84, 150, 255), 4: (180, 108, 255), 5: (244, 196, 70),
          6: (240, 76, 66)}
WEIGHT = {1: 0.80, 2: 1.0, 3: 1.0, 4: 1.0, 5: 0.90, 6: 1.0}
# how strongly each part covers the stone (0 = not at all, 1 = only the colour)
VEIL = 0.09          # the whole fill
GLOW = 0.13          # the glow from the bottom middle, on top of the veil
LINE_CORNER = 0.62   # the edge line next to a corner
LINE_MIDDLE = 0.20   # the edge line in the middle of a side
INNER_LINE = 0.52    # the second line of the corner bracket
GLINT = 0.80         # the point of light at each corner
DOT = 0.40           # the dot one step inside each corner
RIM = 0.30           # the outer rim, the colour darkened
# the game's strength: the owner picked D and then "um pouco mais transparente que o D" (D = 1.0)
STRENGTH = 0.87


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def scale(c, f):
    return tuple(max(0, min(255, int(round(v * f)))) for v in c)


def along(x, y):
    """for a pixel near the edge: how far it is, along its side, from the nearest corner"""
    ring = min(x, y, LAST - x, LAST - y)
    if ring in (y, LAST - y):
        return min(x, LAST - x)
    return min(y, LAST - y)


def slot(tier, strength=1.0):
    color = COLORS[tier]
    k = WEIGHT[tier] * strength
    light = mix(color, (255, 255, 255), 0.38)     # the line where the light falls (top, left)
    shade = scale(color, 0.78)                    # the line on the far side (bottom, right)
    stone = Image.open(BASE).convert('RGB').resize((SIZE, SIZE)).load()
    img = Image.new('RGBA', (SIZE, SIZE))
    px = img.load()
    cx, cy = LAST / 2.0, LAST - 5.0               # the glow's centre: low in the middle
    for y in range(SIZE):
        for x in range(SIZE):
            s = stone[x, y]
            ring = min(x, y, LAST - x, LAST - y)
            d = along(x, y)
            lit = y < LAST - x                    # above the diagonal from bottom left to top right: the lit half
            if ring == 0:
                v = mix(s, scale(color, 0.30), RIM * k)
            elif ring == 1:
                a = LINE_MIDDLE + (LINE_CORNER - LINE_MIDDLE) * math.exp(-(d - 1) / 5.0)
                v = mix(s, light if lit else shade, a * k)
            elif ring == 2:
                v = scale(s, 1 - 0.10 * min(1.0, k))   # the shadow inside the line
            else:
                g = math.exp(-((x - cx) ** 2 + (y - cy) ** 2 * 1.6) / (2 * 8.5 ** 2))
                v = mix(s, color, (VEIL + GLOW * g) * k)
                if ring == 3 and d <= 6:          # the inner line of the corner bracket
                    v = mix(v, light if lit else shade, INNER_LINE * math.exp(-(d - 3) / 2.2) * k)
            px[x, y] = v + (255,)
    glint = mix(color, (255, 255, 255), 0.72)
    for ox, oy, sx, sy in ((1, 1, 1, 1), (LAST - 1, 1, -1, 1), (1, LAST - 1, 1, -1), (LAST - 1, LAST - 1, -1, -1)):
        px[ox, oy] = mix(px[ox, oy][:3], glint, GLINT * k) + (255,)
        for dx, dy, a in ((1, 0, 0.45), (0, 1, 0.45)):   # the light spreads a little along both lines
            p = (ox + sx * dx, oy + sy * dy)
            px[p] = mix(px[p][:3], glint, GLINT * a * k) + (255,)
        p = (ox + sx * 3, oy + sy * 3)                    # the dot inside the bracket
        px[p] = mix(px[p][:3], light, DOT * k) + (255,)
    return img


def main():
    strength = float(sys.argv[1]) if len(sys.argv) > 2 else STRENGTH
    out = sys.argv[2] if len(sys.argv) > 2 else OUT
    os.makedirs(out, exist_ok=True)
    for tier in COLORS:
        path = os.path.join(out, 'slot_t%d.png' % tier)
        slot(tier, strength).save(path)
        print('wrote', path)


if __name__ == '__main__':
    main()
