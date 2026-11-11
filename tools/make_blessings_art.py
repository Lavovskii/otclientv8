"""The blessings button of the inventory and its window (modules/game_blessings), 2026-11-11.

  data/images/game/blessings/button_red|yellow|green.png   14 x 42: normal, hover, pressed, cut from the Reborn small buttons
                                                           (layouts/reborn/images/ui/miniwindow_buttons) with an ankh instead of
                                                           their sign: red no blessing, yellow some, green all
  data/images/game/blessings/ankh_on.png, ankh_off.png     16 x 16, a row of the window: the blessing held, or not

  python tools/make_blessings_art.py      running it again gives the same files
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'data', 'images', 'game', 'blessings')
BUTTONS = Image.open(os.path.join(ROOT, 'layouts', 'reborn', 'images', 'ui', 'miniwindow_buttons.png')).convert('RGBA')

ANKH = [
    '..xxx..',
    '.x...x.',
    '.x...x.',
    '..x.x..',
    'xxxxxxx',
    '...x...',
    '...x...',
    '...x...',
    '...x...',
]
COLOURS = {'red': ((255, 120, 100), (190, 30, 24)), 'yellow': ((255, 236, 140), (200, 150, 30)),
           'green': ((170, 255, 140), (40, 150, 40))}
INK = (14, 11, 9, 255)


def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


def ankh(img, x0, y0, light, dark, scale=1):
    px = img.load()
    h = len(ANKH)
    cells = [(x, y) for y, row in enumerate(ANKH) for x, c in enumerate(row) if c == 'x']
    # a dark edge around the glyph, then the glyph from light to dark
    for x, y in cells:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for sx in range(scale):
                    for sy in range(scale):
                        X, Y = x0 + (x * scale + sx) + dx, y0 + (y * scale + sy) + dy
                        if 0 <= X < img.width and 0 <= Y < img.height and px[X, Y][3] and (X, Y) not in ():
                            px[X, Y] = INK
    for x, y in cells:
        colour = lerp(light, dark, y / (h - 1))
        for sx in range(scale):
            for sy in range(scale):
                px[x0 + x * scale + sx, y0 + y * scale + sy] = colour + (255,)


def button(name, light, dark):
    out = Image.new('RGBA', (14, 42))
    for row in range(3):
        cell = BUTTONS.crop((0, row * 14, 14, row * 14 + 14))  # the "-" button
        px = cell.load()
        back = px[3, 3]
        for y in range(3, 11):
            for x in range(3, 11):
                px[x, y] = back
        k = 0.75 if row == 2 else 1.0  # pressed: a little darker
        ankh(cell, 3, 2 if row != 2 else 3, lerp((0, 0, 0), light, k), lerp((0, 0, 0), dark, k))
        out.alpha_composite(cell, (0, row * 14))
    out.save(os.path.join(OUT, 'button_%s.png' % name))


def row_icon(name, light, dark):
    img = Image.new('RGBA', (16, 16))
    # a 2x ankh does not fit 16 rows; one pixel per cell, centred, with its edge
    ankh(img, 4, 3, light, dark)
    img.save(os.path.join(OUT, name + '.png'))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (light, dark) in COLOURS.items():
        button(name, light, dark)
    row_icon('ankh_on', *COLOURS['green'])
    row_icon('ankh_off', (120, 112, 100), (60, 56, 50))
    print('ok', sorted(os.listdir(OUT)))


if __name__ == '__main__':
    main()
