#!/usr/bin/env python3
"""The artwork of the Task Board (modules/game_taskboard), in data/images/taskboard and the two buttons of the top menu.

Pictures come from the sheets in tools/task_art, generated with ChatGPT in pixel art on a flat magenta background: each is cut
out and brought to its size in the game. Panels, tabs and bars are painted here on the stone of the retro layout, so they
sit with the rest of the interface. The buttons are drawn pixel by pixel in the family of layouts/retro/images/topbuttons.
No file comes from Tibia's client.

  python tools/make_task_art.py        running it again gives the same files
"""
import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SHEETS = os.path.join(ROOT, 'tools', 'task_art')
RETRO = os.path.join(ROOT, 'layouts', 'retro', 'images')
OUT = os.path.join(ROOT, 'data', 'images', 'taskboard')


def save(image, name):
    image.save(os.path.join(OUT, name + '.png'))


# ------------------------------------------------------------------------------------------- the generated sheets
def sheet(number):
    return Image.open(os.path.join(SHEETS, 'forgl_task_art_%d.png' % number)).convert('RGB')


def cut(source, box):
    """A piece of a sheet without its magenta background, trimmed to what it shows."""
    piece = source.crop(box)
    pixels = piece.load()
    out = Image.new('RGBA', piece.size, (0, 0, 0, 0))
    target = out.load()
    for y in range(piece.height):
        for x in range(piece.width):
            r, g, b = pixels[x, y]
            if not (r > 150 and b > 150 and g < 110 and abs(r - b) < 80):
                target[x, y] = (r, g, b, 255)
    return out.crop(out.getbbox())


def shrink(image, width, height=None, threshold=120):
    """To game size, hard edged: only the picture's own pixels count, so no magenta creeps in at the border."""
    height = height or width
    factor = min(width / image.width, height / image.height)
    size = (max(1, round(image.width * factor)), max(1, round(image.height * factor)))
    r, g, b, a = image.split()
    alpha = a.resize(size, Image.BOX)
    colour = Image.merge('RGB', (
        Image.composite(r, Image.new('L', image.size, 0), a).resize(size, Image.BOX),
        Image.composite(g, Image.new('L', image.size, 0), a).resize(size, Image.BOX),
        Image.composite(b, Image.new('L', image.size, 0), a).resize(size, Image.BOX),
    ))
    small = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    source_alpha, source_colour, target = alpha.load(), colour.load(), out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            weight = source_alpha[x, y]
            if weight >= threshold:
                red, green, blue = source_colour[x, y]
                target[x, y] = (min(255, red * 255 // weight), min(255, green * 255 // weight), min(255, blue * 255 // weight), 255)
    small.paste(out, ((width - size[0]) // 2, (height - size[1]) // 2))
    return small


def cell(number, column, row, columns=4, rows=2):
    source = sheet(number)
    w, h = source.width / columns, source.height / rows
    return cut(source, (int(column * w), int(row * h), int((column + 1) * w), int((row + 1) * h)))


def pictures():
    for name, number, column, row, sizes in (
        ('poster', 1, 0, 0, (30,)),
        ('scroll', 1, 1, 0, (30,)),
        ('pouch', 1, 2, 0, (30,)),
        ('points', 1, 3, 0, (14, 28)),
        ('reroll', 1, 0, 1, (14, 22)),
        ('lock', 1, 1, 1, (26,)),
        ('shield', 1, 2, 1, (28,)),
        ('chest', 3, 0, 0, (64,)),
        ('seal', 3, 1, 0, (18,)),
        ('hourglass', 3, 2, 0, (16,)),
        ('damage', 3, 0, 1, (36,)),
        ('star', 3, 1, 1, (16,)),
    ):
        picture = cell(number, column, row)
        for size in sizes:
            save(shrink(picture, size), '%s%d' % (name, size))

    divider = cell(3, 2, 1)
    save(shrink(divider, 150, 14), 'divider')
    corner = shrink(cell(3, 3, 1), 18)
    save(corner, 'corner_tl')
    save(corner.transpose(Image.FLIP_LEFT_RIGHT), 'corner_tr')
    save(corner.transpose(Image.FLIP_TOP_BOTTOM), 'corner_bl')
    save(corner.transpose(Image.ROTATE_180), 'corner_br')

    ribbons = sheet(2)
    for rows, name in (((16, 302), 'ribbon'), ((306, 584), 'ribbon_silver'), ((590, 852), 'ribbon_gold')):
        banner = cut(ribbons, (0, rows[0], ribbons.width, rows[1]))
        save(shrink(banner, 244, 38), name)


# ------------------------------------------------------------------------------------------- stone
def base_stone():
    window = Image.open(os.path.join(RETRO, 'ui', 'window.png')).convert('RGB')
    return window.crop((8, 24, 226, 198))


def dark_stone():
    return Image.open(os.path.join(RETRO, 'ui', 'dark_background.png')).convert('RGB')


def tiled(texture, width, height):
    # mirrored, so a texture that doesn't tile leaves no seams
    w, h = texture.size
    block = Image.new('RGB', (w * 2, h * 2))
    block.paste(texture, (0, 0))
    block.paste(texture.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    block.paste(texture.transpose(Image.FLIP_TOP_BOTTOM), (0, h))
    block.paste(texture.transpose(Image.ROTATE_180), (w, h))
    out = Image.new('RGB', (width, height))
    for y in range(0, height, h * 2):
        for x in range(0, width, w * 2):
            out.paste(block, (x, y))
    return out


def brightness(image, factor, tint=(1, 1, 1)):
    return image.point(lambda v: v).point([min(255, int(v * factor * t)) for t in tint for v in range(256)])


def bevel(image, light, shadow, width=1, top=True, left=True, bottom=True, right=True):
    d = ImageDraw.Draw(image)
    w, h = image.size
    for i in range(width):
        if top:
            d.line([(i, i), (w - 1 - i, i)], fill=light)
        if left:
            d.line([(i, i), (i, h - 1 - i)], fill=light)
        if bottom:
            d.line([(i, h - 1 - i), (w - 1 - i, h - 1 - i)], fill=shadow)
        if right:
            d.line([(w - 1 - i, i), (w - 1 - i, h - 1 - i)], fill=shadow)
    return image


def panels():
    stone, dark = base_stone(), dark_stone()

    # a raised frame, 2 pixels of light above and of shade below, like the retro window
    frame = bevel(tiled(stone, 64, 64), (126, 126, 126), (28, 28, 28), 2)
    save(frame, 'frame')

    # sunken
    inset = tiled(dark, 32, 32)
    inset = bevel(inset, (18, 18, 18), (110, 110, 110))
    save(inset, 'inset')

    # the bar with a frame's caption: dark, with a thin bronze line under it
    caption = tiled(dark, 40, 18)
    d = ImageDraw.Draw(caption)
    d.line([(0, 0), (39, 0)], fill=(20, 20, 20))
    d.line([(0, 16), (39, 16)], fill=(122, 92, 44))
    d.line([(0, 17), (39, 17)], fill=(30, 26, 18))
    save(caption, 'caption')

    # a cell of the weekly tasks, and the same when it's done
    weekly = bevel(brightness(tiled(stone, 32, 32), 0.92), (112, 112, 112), (24, 24, 24))
    save(weekly, 'cell')
    done = bevel(brightness(tiled(stone, 32, 32), 0.92, (0.86, 1.08, 0.86)), (92, 178, 92), (26, 70, 26))
    save(done, 'cell_done')

    # the three looks of a tab, one under the other
    tabs = Image.new('RGB', (48, 102))
    normal = bevel(brightness(tiled(stone, 48, 34), 0.62), (88, 88, 88), (20, 20, 20))
    hover = bevel(brightness(tiled(stone, 48, 34), 0.8), (112, 112, 112), (24, 24, 24))
    active = tiled(stone, 48, 34)
    d = ImageDraw.Draw(active)
    d.line([(0, 0), (47, 0)], fill=(214, 170, 84))
    d.line([(0, 1), (47, 1)], fill=(138, 104, 50))
    d.line([(0, 0), (0, 33)], fill=(126, 126, 126))
    d.line([(1, 2), (1, 33)], fill=(96, 96, 96))
    d.line([(47, 0), (47, 33)], fill=(28, 28, 28))
    d.line([(46, 2), (46, 33)], fill=(44, 44, 44))
    for y, picture in enumerate((normal, hover, active)):
        tabs.paste(picture, (0, y * 34))
    save(tabs, 'tab')

    # a bar: its groove, and the light over whatever colour fills it
    track = bevel(brightness(tiled(dark, 24, 14), 0.7), (10, 10, 10), (104, 104, 104))
    save(track, 'track')
    gloss = Image.new('RGBA', (8, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(gloss)
    for y, colour in enumerate(((255, 255, 255, 96), (255, 255, 255, 60), (255, 255, 255, 30), (255, 255, 255, 10), (0, 0, 0, 0), (0, 0, 0, 0),
                                (0, 0, 0, 0), (0, 0, 0, 16), (0, 0, 0, 30), (0, 0, 0, 44), (0, 0, 0, 58), (0, 0, 0, 72), (0, 0, 0, 86), (0, 0, 0, 100))):
        d.line([(0, y), (7, y)], fill=colour)
    save(gloss, 'gloss')

    # a plain plate for a line of text
    plate = bevel(brightness(tiled(dark, 32, 22), 1.1), (20, 20, 20), (92, 92, 92))
    save(plate, 'plate')


def stage():
    """The wall behind the bounty's card: dark blocks of stone, lit in the middle as if by a torch."""
    random.seed(12)
    width, height = 672, 306
    wall = brightness(tiled(dark_stone(), width, height), 0.85)
    d = ImageDraw.Draw(wall)
    block_w, block_h = 54, 26
    for row, y in enumerate(range(0, height, block_h)):
        shift = 0 if row % 2 == 0 else block_w // 2
        d.line([(0, y), (width, y)], fill=(16, 16, 16))
        d.line([(0, y + 1), (width, y + 1)], fill=(58, 58, 58))
        for x in range(-block_w + shift, width, block_w):
            d.line([(x, y), (x, y + block_h - 1)], fill=(16, 16, 16))
            d.line([(x + 1, y + 2), (x + 1, y + block_h - 1)], fill=(56, 56, 56))
    pixels = wall.load()
    cx, cy = width / 2, height * 0.45
    for y in range(height):
        for x in range(width):
            distance = math.hypot((x - cx) / (width * 0.5), (y - cy) / (height * 0.7))
            light = max(0.0, 1.0 - distance)
            shade = 0.55 + 0.95 * light
            r, g, b = pixels[x, y]
            # steps of light, as an old game would paint it, with a little dither between them
            level = shade * 8 + (0.5 if (x + y) % 2 else 0.0)
            shade = int(level) / 8
            pixels[x, y] = (min(255, int(r * shade * (1 + 0.28 * light))), min(255, int(g * shade * (1 + 0.1 * light))), min(255, int(b * shade * (1 - 0.1 * light))))
    bevel(wall, (14, 14, 14), (96, 96, 96))
    save(wall, 'stage')


# ------------------------------------------------------------------------------------------- the top menu's buttons
BOARD = (
    "     xxxxxx     ",
    "  ###xxxxxx###  ",
    "  ############  ",
    "  ####.#######  ",
    "  #.#.##.....#  ",
    "  ##.#########  ",
    "  ############  ",
    "  ####.#######  ",
    "  #.#.##.....#  ",
    "  ##.#########  ",
    "  ############  ",
    "  ####.#######  ",
    "  #.#.##.....#  ",
    "  ##.#########  ",
    "  ############  ",
)
TRACKER = (
    "       #       ",
    "       #       ",
    "     #####     ",
    "   ##  #  ##   ",
    "   #       #   ",
    "  #         #  ",
    "  #   ###   #  ",
    "####  ###  ####",
    "  #   ###   #  ",
    "  #         #  ",
    "   #       #   ",
    "   ##  #  ##   ",
    "     #####     ",
    "       #       ",
    "       #       ",
)
GLYPH = {'#': (180, 180, 180), 'x': (128, 128, 128), '.': (58, 58, 58)}


def button(rows, name):
    # the family: a stone square with light above, shade below; when pressed the light swaps and the sign moves a pixel
    family = Image.open(os.path.join(RETRO, 'topbuttons', 'particles.png')).convert('RGBA')
    inside = base_stone().crop((10, 10, 28, 28))
    out = Image.new('RGBA', (20, 40), (0, 0, 0, 0))
    for state in range(2):
        square = family.crop((0, state * 20, 20, state * 20 + 20))
        square.paste(inside.convert('RGBA').point(lambda v: int(v * 0.95)), (1, 1))
        x0 = (20 - len(rows[0])) // 2 + state
        y0 = (20 - len(rows)) // 2 + state
        for y, row in enumerate(rows):
            for x, mark in enumerate(row):
                if mark in GLYPH and 0 <= x0 + x < 20 and 0 <= y0 + y < 20:
                    square.putpixel((x0 + x, y0 + y), GLYPH[mark] + (255,))
        out.paste(square, (0, state * 20))
    out.save(os.path.join(RETRO, 'topbuttons', name + '.png'))
    out.crop((0, 0, 20, 20)).save(os.path.join(ROOT, 'data', 'images', 'topbuttons', name + '.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    pictures()
    panels()
    stage()
    button(BOARD, 'taskboard')
    button(TRACKER, 'tasktracker')
    print('ok')
