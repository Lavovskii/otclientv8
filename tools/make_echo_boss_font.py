"""Paints the font of an echo boss's name (data/fonts/verdana-11px-rounded-glow): the name font with a red glow.

Tibia's own client gives its leader monsters a Qt Glow around the name, with these values from its TibiaStyle: colour #FF2020,
radius 4, samples 9, spread 0.5 (fiendish monsters have the same in orange, #EE8413, radius 3, samples 7, spread 0.4). Our
client can't draw that, so each letter carries its glow, worked out as Qt does: a gaussian blur of the letter and its black edge,
with deviation (radius + 1) / 3.3333, then a smoothstep from 0 to 1 - spread * 0.97.

The client measures a glyph up to its last pixel that isn't fully transparent. A letter here is PAD wider on each side, so its
last column gets an almost invisible pixel and the font's spacing takes that width back: the letters keep the distances of the
name font. Running it again gives the same files.
"""
import os

import numpy
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'data', 'fonts')
SOURCE = os.path.join(FONTS, 'verdana-11px-rounded_cp1252.png')
NAME = 'verdana-11px-rounded-glow'
CELL = 16
FIRST = 32
TOP_ROW, LAST_ROW = 3, 14  # the rows of a cell of the name font that have letters
ROWS = LAST_ROW - TOP_ROW + 1
SPACING = -1  # the name font's
SPACE_WIDTH = 4  # the name font's

COLOR = (255, 32, 32)
RADIUS, SPREAD = 4, 0.5
PAD = RADIUS  # the glow reaches this far from a letter
BELOW = 1  # rows of glow kept under a letter's lowest row: a title's rect ends right above the name, so less glow, closer to it
WIDTH, HEIGHT = CELL + 2 * PAD, PAD + ROWS + BELOW
# the name font's staff letters (tools/make_staff_font.py) aren't in a monster's name
SLOTS = list(range(33, 127)) + list(range(192, 256))


def kernel():
    deviation = (RADIUS + 1) / 3.3333
    weights = numpy.exp(-numpy.arange(-RADIUS, RADIUS + 1) ** 2 / (2 * deviation ** 2))
    return weights / weights.sum()


def glow_of(alpha):
    blurred = alpha
    for axis in (0, 1):
        blurred = numpy.apply_along_axis(lambda line: numpy.convolve(line, kernel(), 'same'), axis, blurred)
    edge = 1 - SPREAD * 0.97
    t = numpy.clip(blurred / edge, 0, 1)
    return t * t * (3 - 2 * t)


def glyph(cell):
    """the cell of a letter with its glow, and its width in the name font (0 for a blank one)"""
    filled = numpy.nonzero(cell[:, :, 3].max(axis=0))[0]
    if len(filled) == 0:
        return None, 0
    width = filled[-1] + 1
    rgb = numpy.zeros((PAD + ROWS + PAD, WIDTH, 3))
    alpha = numpy.zeros((PAD + ROWS + PAD, WIDTH))
    rgb[PAD:PAD + ROWS, PAD:PAD + CELL] = cell[TOP_ROW:LAST_ROW + 1, :, :3] / 255
    alpha[PAD:PAD + ROWS, PAD:PAD + CELL] = cell[TOP_ROW:LAST_ROW + 1, :, 3] / 255
    glow = glow_of(alpha)
    # the glow goes behind the letter
    total = alpha + glow * (1 - alpha)
    color = numpy.array(COLOR) / 255
    mixed = rgb * alpha[:, :, None] + color * (glow * (1 - alpha))[:, :, None]
    mixed = numpy.divide(mixed, total[:, :, None], out=numpy.zeros_like(mixed), where=total[:, :, None] > 0)
    out = numpy.dstack((mixed, total))[:HEIGHT]
    out = numpy.round(out * 255).astype(numpy.uint8)
    # how far the next letter starts
    last = PAD + width + PAD - 1
    if out[:, last, 3].max() == 0:
        out[0, last] = (COLOR[0], COLOR[1], COLOR[2], 1)
    return out, width


def main():
    source = numpy.array(Image.open(SOURCE).convert('RGBA'))
    sheet = numpy.zeros((((256 - FIRST) // 16) * HEIGHT, 16 * WIDTH, 4), numpy.uint8)
    for code in SLOTS:
        column, row = (code - FIRST) % 16, (code - FIRST) // 16
        out, _ = glyph(source[row * CELL:(row + 1) * CELL, column * CELL:(column + 1) * CELL])
        if out is not None:
            sheet[row * HEIGHT:(row + 1) * HEIGHT, column * WIDTH:(column + 1) * WIDTH] = out
    Image.fromarray(sheet, 'RGBA').save(os.path.join(FONTS, NAME + '.png'), optimize=True)
    with open(os.path.join(FONTS, NAME + '.otfont'), 'w', newline='\n') as f:
        f.write('Font\n  name: %s\n  texture: %s\n  height: %d\n  glyph-size: %d %d\n  spacing: %d 0\n  space-width: %d\n'
                % (NAME, NAME, HEIGHT, WIDTH, HEIGHT, SPACING - 2 * PAD, SPACE_WIDTH + 2 * PAD))
    print('wrote', NAME, sheet.shape[1], 'x', sheet.shape[0])


if __name__ == '__main__':
    main()
