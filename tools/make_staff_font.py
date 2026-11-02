"""Paints the staff letters into the name font (data/fonts/verdana-11px-rounded_cp1252.png).

The client draws a creature's name in one font tinted with one colour, so a two-colour name can only come from letters
already painted in the font: red inside, a thin gold edge. They take the unused cp1252 slots of 128-191, in the order
modules/game_staffnames reads (keep both lists the same). Their colours are divided by the tint of a staff name (TINT,
also the colour of their health bar) so the screen shows FILL and EDGE. The other glyphs stay as they are; running it
again gives the same file.
"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'data', 'fonts', 'verdana-11px-rounded_cp1252.png')
CELL = 16
FIRST = 32

TINT = (255, 208, 96)
FILL = (232, 26, 26)
EDGE = (214, 168, 60)
CORNER = (24, 12, 6)  # outline pixels that only touch a letter by a corner: dark, so the gold stays thin

LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\'-'
# left alone: euro, ordinal and degree signs, accent, inverted marks (players type them) and the blank ones
KEEP = (128, 129, 160, 161, 170, 173, 176, 180, 186, 191)
SLOTS = [c for c in range(128, 192) if c not in KEEP]
assert len(SLOTS) == len(LETTERS)


def baked(color):
    return tuple(min(255, round(c * 255 / t)) for c, t in zip(color, TINT)) + (255,)


def cell_box(code):
    x, y = (code - FIRST) % 16 * CELL, (code - FIRST) // 16 * CELL
    return x, y, x + CELL, y + CELL


def paint(font, fill=FILL, edge=EDGE, corner=CORNER):
    for letter, slot in zip(LETTERS, SLOTS):
        src = font.crop(cell_box(ord(letter)))
        s = src.load()
        out = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        o = out.load()
        is_fill = lambda x, y: 0 <= x < CELL and 0 <= y < CELL and s[x, y] == (255, 255, 255, 255)
        for y in range(CELL):
            for x in range(CELL):
                if s[x, y][3] == 0:
                    continue
                if is_fill(x, y):
                    o[x, y] = baked(fill)
                elif any(is_fill(x + a, y + b) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    o[x, y] = baked(edge)
                else:
                    o[x, y] = baked(corner)
        font.paste(out, cell_box(slot)[:2])


if __name__ == '__main__':
    font = Image.open(FONT).convert('RGBA')
    before = font.copy()
    paint(font)
    # only the staff slots may differ
    for code in range(FIRST, 256):
        if code not in SLOTS:
            assert before.crop(cell_box(code)).tobytes() == font.crop(cell_box(code)).tobytes(), code
    font.save(FONT)
    print('staff letters painted in', os.path.relpath(FONT, ROOT))
