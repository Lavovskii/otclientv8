#!/usr/bin/env python3
"""The tier frames of items (the owner, 2026-11-09: "todos os items devem ter um contorno que representa o seu tier
(raridade) ... com brilhos suaves nos contornos em motion"). One sheet per tier, data/images/game/tiers/frame_tN.png:
16 frames of 34x34 side by side. Each frame: a thin line in the tier's colour, a soft glow around it, and two points of
light running round the frame (opposite each other, with a fading tail). modules/game_tiers draws it over the item and
steps through the frames.

  python tools/make_tier_frames.py
"""
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'data', 'images', 'game', 'tiers')
SIZE = 34
FRAMES = 16
# t1 white (common), t2 green, t3 blue, t4 purple, t5 gold, t6 red
COLORS = {1: (232, 232, 232), 2: (64, 220, 96), 3: (70, 140, 255), 4: (180, 92, 255), 5: (255, 204, 51), 6: (255, 64, 64)}
INSET = 1.5          # the line runs this far inside the edge
SIDE = SIZE - 2 * INSET
PERIMETER = 4 * SIDE


def outline(px, py):
    """distance from a pixel centre to the frame's line, and where along the line (0..PERIMETER) the nearest point is"""
    x, y = px + 0.5 - INSET, py + 0.5 - INSET
    cx, cy = min(max(x, 0), SIDE), min(max(y, 0), SIDE)
    if 0 < x < SIDE and 0 < y < SIDE:
        # inside: the nearest side
        d = min(x, y, SIDE - x, SIDE - y)
        if d == y:
            cx, cy = x, 0
        elif d == SIDE - x:
            cx, cy = SIDE, y
        elif d == SIDE - y:
            cx, cy = x, SIDE
        else:
            cx, cy = 0, y
    else:
        d = math.hypot(x - cx, y - cy)
    if cy == 0:
        s = cx
    elif cx == SIDE:
        s = SIDE + cy
    elif cy == SIDE:
        s = 2 * SIDE + (SIDE - cx)
    else:
        s = 3 * SIDE + (SIDE - cy)
    return d, s


def frame(color, phase):
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    heads = [phase * PERIMETER, (phase + 0.5) * PERIMETER]
    for y in range(SIZE):
        for x in range(SIZE):
            d, s = outline(x, y)
            line = math.exp(-(d / 0.75) ** 2)
            # the halo breathes: a little stronger and weaker twice a turn
            glow = math.exp(-(d / 2.6) ** 2) * (0.34 + 0.14 * math.sin(phase * 4 * math.pi))
            light = 0.0
            for h in heads:
                behind = (h - s) % PERIMETER          # how far behind the head this point is
                ahead = (s - h) % PERIMETER
                lit = math.exp(-(min(behind, ahead) / 3.2) ** 2) + (math.exp(-behind / 13.0) * 0.8 if behind < PERIMETER / 2 else 0)
                light = max(light, lit)
            near = math.exp(-(d / 2.2) ** 2)
            light *= near
            alpha = max(line * 0.86, glow, light)
            if alpha < 0.02:
                continue
            white = min(1.0, light * 0.6)
            r, g, b = (int(c + (255 - c) * white) for c in color)
            px[x, y] = (r, g, b, int(255 * min(1.0, alpha)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for tier, color in COLORS.items():
        sheet = Image.new('RGBA', (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
        for i in range(FRAMES):
            sheet.paste(frame(color, i / FRAMES), (i * SIZE, 0))
        path = os.path.join(OUT, 'frame_t%d.png' % tier)
        sheet.save(path)
        print('wrote', path)


if __name__ == '__main__':
    main()
