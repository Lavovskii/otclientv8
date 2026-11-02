"""Paints the staff letters into the name font (data/fonts/verdana-11px-rounded_cp1252.png).

The client draws a creature's name in one font tinted with one colour and has no way to change a name's font, so the
staff's gothic letters are drawn from tools/fonts/Almendra-Bold.ttf (SIL Open Font License) into the unused cp1252 slots
of 128-191, in the order modules/game_staffnames reads (keep both lists the same). Their colours are divided by the tint
of a staff name (TINT, also the colour of their health bar) so the screen shows FILL. The other glyphs stay as they are;
running it again gives the same file.

The client shows rows 2 to 15 of a cell (the font's y-offset cuts the first two) and measures a glyph up to its last pixel
that isn't fully transparent, then moves on one pixel less (spacing -1). So each letter gets one almost invisible pixel
that sets how far the next one starts.
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'data', 'fonts', 'verdana-11px-rounded_cp1252.png')
TTF = os.path.join(ROOT, 'tools', 'fonts', 'Almendra-Bold.ttf')
CELL = 16
FIRST = 32
TOP_ROW = 2

TINT = (255, 208, 96)
FILL = (255, 0, 3)

LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\'-'
# left alone: euro, ordinal and degree signs, accent, inverted marks (players type them) and the blank ones
KEEP = (128, 129, 160, 161, 170, 173, 176, 180, 186, 191)
SLOTS = [c for c in range(128, 192) if c not in KEEP]
assert len(SLOTS) == len(LETTERS)

BIG = 160  # the size the letters are drawn at before they are scaled down
ABOVE, BELOW = 11, 3  # rows of a letter above and below its baseline
SCALE_X, SCALE_Y = 0.086, 0.09
BOLD = 3  # extra stroke at the big size
LOW, HIGH = 0.3, 0.7  # coverage that becomes transparent and fully solid
GAP = 1  # free columns between two letters
MAX_WIDTH = 14  # the widest letter that still fits a cell with its outline and that pixel
OUTLINE = True  # a thin black edge, like every other name


def baked(color):
    return tuple(min(255, round(c * 255 / t)) for c, t in zip(color, TINT))


def cell_box(code):
    x, y = (code - FIRST) % 16 * CELL, (code - FIRST) // 16 * CELL
    return x, y, x + CELL, y + CELL


def letter_alpha(letter, scale_x=SCALE_X, scale_y=SCALE_Y, bold=BOLD, low=LOW, high=HIGH, above=ABOVE, below=BELOW):
    """the letter's coverage (mode L), above + below rows tall, as wide as its ink"""
    font = ImageFont.truetype(TTF, BIG)
    base = BIG * 2
    canvas = Image.new('L', (BIG * 3, BIG * 3), 0)
    ImageDraw.Draw(canvas).text((BIG // 2, base), letter, fill=255, font=font, anchor='ls', stroke_width=bold, stroke_fill=255)
    left, _, right, _ = canvas.getbbox()
    top, bottom = base - round(above / scale_y), base + round(below / scale_y)
    width = max(1, min(MAX_WIDTH, round((right - left) * scale_x)))
    small = canvas.crop((left, top, right, bottom)).resize((width, above + below), Image.BOX)
    return small.point(lambda v: 0 if v / 255 <= low else 255 if v / 255 >= high else round((v / 255 - low) / (high - low) * 255))


def glyph_cell(alpha, red, green, blue, outline):
    """one cell: the letter, its black outline if asked (the letter one column in) and the pixel for the next letter;
    two letters share the column between them, so their outlines touch like those of the font's own letters"""
    left = 1 if outline else 0
    a = alpha.load()
    near = lambda x, y: max((a[x + i, y + j] for i in (-1, 0, 1) for j in (-1, 0, 1)
                             if 0 <= x + i < alpha.width and 0 <= y + j < alpha.height), default=0)
    out = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    o = out.load()
    for y in range(CELL - TOP_ROW):
        for x in range(-left, alpha.width + left):
            cover = a[x, y] if 0 <= x < alpha.width and y < alpha.height else 0
            ring = 255 if outline and near(x, y) >= 128 else 0
            if cover or ring:
                t = cover / 255
                o[x + left, y + TOP_ROW] = (round(red * t), round(green * t), round(blue * t), max(cover, ring))
    out.putpixel((alpha.width + GAP, CELL - 1), (red, green, blue, 1))
    return out


def paint(font, fill=FILL, outline=OUTLINE, **kw):
    red, green, blue = baked(fill)
    for letter, slot in zip(LETTERS, SLOTS):
        alpha = letter_alpha(letter, **kw)
        assert alpha.width + max(GAP, 1 if outline else 0) <= CELL - 1, (letter, alpha.width)
        font.paste(glyph_cell(alpha, red, green, blue, outline), cell_box(slot)[:2])


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
