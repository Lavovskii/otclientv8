#!/usr/bin/env python3
"""The artwork of the Store (modules/game_store), in data/images/store, and the plate of its wide button.

In the same family as the Task Board (tools/make_task_art.py, whose frames and helpers it uses): pictures cut from the sheets
tools/task_art/forgl_store_art_*.png, generated with ChatGPT in pixel art on a flat magenta background, and buttons and tabs
painted here on the stone of the retro layout.

  python tools/make_store_art.py        running it again gives the same files
"""
import os

from PIL import Image, ImageDraw, ImageFont

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

    # this sheet came with a transparent background instead of the magenta
    more = Image.open(os.path.join(SHEETS, 'forgl_store_art_3.png')).convert('RGBA')
    w, h = more.width / 4, more.height / 2
    for index, name in enumerate(('armor', 'weapons', 'rune', 'gems', 'saddle', 'crown', 'table', 'sack')):
        piece = more.crop((int((index % 4) * w), int((index // 4) * h), int((index % 4 + 1) * w), int((index // 4 + 1) * h)))
        solid = piece.point(lambda v: v) if False else piece
        alpha = solid.getchannel('A').point(lambda v: 255 if v >= 128 else 0)
        solid.putalpha(alpha)
        save(shrink(solid.crop(alpha.getbbox()), 26), name + '26')


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


GOLD = [(255, 246, 204), (255, 234, 164), (252, 216, 120), (242, 196, 90), (228, 174, 68), (210, 150, 50), (188, 126, 38), (162, 104, 30)]
DIM = [tuple(v * 3 // 5 for v in colour) for colour in GOLD]
FONT = r'C:\Windows\Fonts\georgiab.ttf'


def lettering(text, size, ramp, edge=(30, 14, 4, 255), engraved=None):
    """Hard pixels, no blur: a colour from above to below and a dark edge, or letters cut into the metal."""
    font = ImageFont.truetype(FONT, size)
    probe = Image.new('L', (400, 80), 0)
    d = ImageDraw.Draw(probe)
    d.fontmode = '1'
    d.text((10, 10), text, fill=255, font=font)
    mask = probe.crop(probe.getbbox())
    w, h = mask.size
    out = Image.new('RGBA', (w + 2, h + 3), (0, 0, 0, 0))
    source, target = mask.load(), out.load()
    for y in range(h):
        for x in range(w):
            if source[x, y]:
                if engraved:
                    target[x + 1, y + 2] = engraved
                else:
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1), (0, 2), (1, 2), (-1, 2)):
                        target[x + 1 + dx, y + 1 + dy] = edge
    for y in range(h):
        colour = ramp[min(len(ramp) - 1, y * len(ramp) // h)]
        for x in range(w):
            if source[x, y]:
                target[x + 1, y + 1] = colour + (255,)
    return out


def plate():
    """The wide button: the first plaque of its sheet with the word in it, dim, so it always reads; the bright word that
    pulses over it goes in its own layer."""
    plaques = sheet(2)
    third = plaques.height / 3
    top = shrink(cut(plaques, (0, 0, plaques.width, int(third))), 176, 32, threshold=100)
    place = lambda letters: ((176 - letters.width) // 2, (32 - letters.height) // 2)
    dim = lettering('Store', 17, DIM)
    top.alpha_composite(dim, place(dim))
    top.save(os.path.join(ROOT, 'data', 'images', 'ui', 'store_plate.png'))
    bright = lettering('Store', 17, GOLD)
    neon = Image.new('RGBA', (176, 32), (0, 0, 0, 0))
    neon.alpha_composite(bright, place(bright))
    neon.save(os.path.join(ROOT, 'data', 'images', 'ui', 'store_neon.png'))


def title():
    # cut into the gold ribbon: dark letters with a line of light under them
    save(lettering('ForgottenL Store', 13, [(60, 34, 8)] * 8, engraved=(255, 232, 150, 255)), 'title')


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
    title()
    buttons()
    tabs()
    offers()
    print('ok')
