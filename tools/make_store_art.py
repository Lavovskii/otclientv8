#!/usr/bin/env python3
"""The artwork of the Store (modules/game_store), in data/images/store, and the plate of its wide button.

In the same family as the Task Board (tools/make_task_art.py, whose frames and helpers it uses): pictures cut from the sheets
tools/task_art/forgl_store_art_*.png, generated with ChatGPT in pixel art on a flat magenta background, and buttons and tabs
painted here on the stone of the retro layout.

  python tools/make_store_art.py        running it again gives the same files
"""
import os

from PIL import Image, ImageDraw

from make_task_art import ROOT, SHEETS, base_stone, bevel, brightness, cut, shrink, tiled

OUT = os.path.join(ROOT, 'data', 'images', 'store')


def save(image, name):
    image.save(os.path.join(OUT, name + '.png'))


def sheet(number):
    return Image.open(os.path.join(SHEETS, 'forgl_store_art_%d.png' % number)).convert('RGB')


def cell(source, column, row, columns=4, rows=2):
    w, h = source.width / columns, source.height / rows
    return cut(source, (int(column * w), int(row * h), int((column + 1) * w), int((row + 1) * h)))


def pictures():
    icons = sheet(1)
    for name, column, row, sizes in (
        ('coins', 0, 0, (36,)),
        ('potion', 1, 0, (26,)),
        ('tunic', 2, 0, (26,)),
        ('flask', 3, 0, (26,)),
        ('crate', 0, 1, (26,)),
        ('stall', 1, 1, (26,)),
        ('purse', 2, 1, (26,)),
        ('scroll', 3, 1, (26,)),
    ):
        picture = cell(icons, column, row)
        for size in sizes:
            save(shrink(picture, size), '%s%d' % (name, size))


COIN = (
    "    ######    ",
    "  ##oooooo##  ",
    " #oOOOOOOOOx# ",
    " #oOOooooOOx# ",
    "#oOOoOOOOxOOx#",
    "#oOOoOOOOxOOx#",
    "#oOOoOOOOxOOx#",
    "#oOOoOOOOxOOx#",
    "#oOOoOOOOxOOx#",
    "#oOOOxxxxOOOx#",
    " #oOOOOOOOOx# ",
    " #xxOOOOOOxx# ",
    "  ##xxxxxx##  ",
    "    ######    ",
)
COIN_COLOURS = {'#': (58, 34, 8, 255), 'o': (255, 232, 150, 255), 'O': (236, 186, 78, 255), 'x': (168, 112, 34, 255)}


def coin():
    # a single coin, drawn at its size: a picture brought down to 14 pixels stops reading as anything
    out = Image.new('RGBA', (14, 14), (0, 0, 0, 0))
    for y, row in enumerate(COIN):
        for x, mark in enumerate(row):
            if mark in COIN_COLOURS:
                out.putpixel((x, y), COIN_COLOURS[mark])
    save(out, 'coin14')


def plate():
    """The wide button: the first of the plaques of its sheet, sharp at the size of the button."""
    plaques = sheet(2)
    third = plaques.height / 3
    top = cut(plaques, (0, 0, plaques.width, int(third)))
    shrink(top, 176, 32, threshold=100).save(os.path.join(ROOT, 'data', 'images', 'ui', 'store_plate.png'))


def buttons():
    """Bronze with gold edges: what buys. Normal, hover and pressed, one under the other."""
    stone = base_stone()
    out = Image.new('RGB', (40, 90))
    for state, (factor, light, shade) in enumerate((
        ((0.95, (232, 190, 96), (58, 36, 10))),
        ((1.2, (255, 226, 140), (70, 44, 12))),
        ((0.7, (58, 36, 10), (214, 170, 84))),
    )):
        piece = brightness(tiled(stone, 40, 30), factor, (1.32, 1.02, 0.62))
        d = ImageDraw.Draw(piece)
        # a band of light above and of shade below, in steps, as an old game paints metal
        for y in range(3, 9):
            for x in range(40):
                if (x + y) % 2 == 0 or y < 6:
                    r, g, b = piece.getpixel((x, y))
                    piece.putpixel((x, y), (min(255, r + 16), min(255, g + 12), min(255, b + 6)))
        for y in range(22, 28):
            for x in range(40):
                if (x + y) % 2 == 0 or y > 24:
                    r, g, b = piece.getpixel((x, y))
                    piece.putpixel((x, y), (max(0, r - 18), max(0, g - 14), max(0, b - 8)))
        bevel(piece, light, shade)
        d.line([(1, 1), (38, 1)], fill=tuple(v // 2 + 40 for v in light))
        d.line([(1, 28), (38, 28)], fill=tuple(v // 2 for v in shade))
        out.paste(piece, (0, state * 30))
    save(out, 'gold_button')


def tabs():
    """A category: the look of the Task Board's tabs, standing, with the gold on its left when chosen."""
    stone = base_stone()
    out = Image.new('RGB', (48, 102))
    normal = bevel(brightness(tiled(stone, 48, 34), 0.62), (88, 88, 88), (20, 20, 20))
    hover = bevel(brightness(tiled(stone, 48, 34), 0.8), (112, 112, 112), (24, 24, 24))
    active = bevel(tiled(stone, 48, 34), (126, 126, 126), (28, 28, 28))
    d = ImageDraw.Draw(active)
    d.line([(0, 0), (0, 33)], fill=(226, 182, 92))
    d.line([(1, 0), (1, 33)], fill=(160, 122, 58))
    d.line([(2, 1), (2, 32)], fill=(96, 74, 38))
    for row, picture in enumerate((normal, hover, active)):
        out.paste(picture, (0, row * 34))
    save(out, 'tab')


def offers():
    """An offer: the Task Board's cell, lighter under the mouse, with gold around it when chosen."""
    stone = base_stone()
    save(bevel(brightness(tiled(stone, 32, 32), 0.92), (112, 112, 112), (24, 24, 24)), 'offer')
    save(bevel(brightness(tiled(stone, 32, 32), 1.06), (138, 138, 138), (28, 28, 28)), 'offer_hover')
    chosen = brightness(tiled(stone, 32, 32), 1.04, (1.05, 1.0, 0.9))
    bevel(chosen, (236, 194, 104), (156, 112, 44))
    d = ImageDraw.Draw(chosen)
    d.rectangle((1, 1, 30, 30), outline=(120, 90, 42))
    save(chosen, 'offer_focus')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    pictures()
    coin()
    plate()
    buttons()
    tabs()
    offers()
    print('ok')
