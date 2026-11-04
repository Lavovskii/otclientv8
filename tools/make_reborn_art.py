#!/usr/bin/env python3
"""The artwork of the Reborn layout (layouts/reborn/images), the client's default look since build 30.

The Task Board and the Store set the look: stone, bevelled frames, a dark caption with a thin bronze line, gold for what matters.
Textures, pictures and ornaments come from the sheets in tools/reborn_art, generated with ChatGPT in pixel art on a flat
magenta background. Frames, buttons and small glyphs are painted here on those textures, because below about 16 pixels a
generated picture stops reading. No file comes from Tibia's client.

The sizes of the slices matter: a widget repeats the middle of its image, so anything that repeats has the period of the
textures (PERIOD), and shading only goes in the borders. See layouts/reborn/README.md.

  python tools/make_reborn_art.py        running it again gives the same files
"""
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from make_task_art import cut, shrink

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ART = os.path.join(ROOT, 'tools', 'reborn_art')
OUT = os.path.join(ROOT, 'layouts', 'reborn', 'images')
PERIOD = 160

INK = (10, 8, 6)
EDGE = (20, 16, 10)
GOLD = (244, 214, 140)
B_HI = (226, 186, 104)
B_LIGHT = (182, 142, 74)
B_MID = (138, 104, 50)
B_LOW = (92, 68, 34)
B_DARK = (46, 34, 18)
S_HI = (128, 124, 116)
S_LOW = (26, 24, 22)


def save(image, name):
    path = os.path.join(OUT, name + '.png')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)


# ------------------------------------------------------------------------------------------- materials
def seamless(texture):
    """The sheet's swatches don't quite tile: cross-fade each with itself moved by half."""
    a = np.array(texture).astype(float)
    h, w = a.shape[:2]
    b = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx) / (w / 4), np.minimum(yy, h - 1 - yy) / (h / 4))
    m = np.clip(edge, 0, 1)[..., None]
    return Image.fromarray(np.uint8(a * m + b * (1 - m)))


def tone(texture, mean, contrast):
    a = np.array(texture.convert('RGB')).astype(float)
    a = (a - a.mean((0, 1))) * contrast + np.array(mean, dtype=float)
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


def swatch(sheet, column, row):
    half = sheet.width // 2
    box = (column * half + 12, row * half + 12, (column + 1) * half - 12, (row + 1) * half - 12)
    return seamless(sheet.crop(box).resize((PERIOD, PERIOD), Image.BOX))


def tile(texture, width, height, offset=(0, 0)):
    w, h = texture.size
    out = Image.new('RGB', (width, height))
    for y in range(-offset[1], height, h):
        for x in range(-offset[0], width, w):
            out.paste(texture, (x, y))
    return out


def scale(image, factor, tint=(1, 1, 1)):
    a = np.array(image.convert('RGB')).astype(float) * factor * np.array(tint)
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


class M:
    """The materials, loaded once."""
    stone = dark = bronze = grain = None


def load_materials():
    sheet = Image.open(os.path.join(ART, 'reborn_textures.png')).convert('RGB')
    raw_stone, raw_dark, raw_bronze = swatch(sheet, 0, 0), swatch(sheet, 1, 0), swatch(sheet, 1, 1)
    M.stone = tone(raw_stone, (70, 68, 65), 0.5)
    M.dark = tone(raw_dark, (34, 33, 32), 0.85)
    M.bronze = tone(raw_bronze, (96, 70, 36), 0.7)
    M.grain = raw_stone


def bricks(width, height, mean=(46, 44, 42), mortar=(16, 15, 14), seed=7):
    """A wall of cut stone with the sheet's grain: the width and height must hold whole bricks, so that it tiles."""
    random.seed(seed)
    wall = tone(M.grain, mean, 0.4)
    out = tile(wall, width, height)
    bh, bw = 16, 40
    assert height % (bh * 2) == 0 and width % bw == 0
    a = np.array(out).astype(float)
    for row in range(height // bh):
        y0 = row * bh
        shift = (bw // 2) if row % 2 else 0
        for col in range(width // bw):
            x0 = col * bw + shift
            light = random.uniform(0.86, 1.14)
            for y in range(y0, y0 + bh):
                for x in range(x0, x0 + bw):
                    a[y % height, x % width] *= light
            for x in range(x0, x0 + bw):
                a[y0 % height, x % width] = np.array(a[y0 % height, x % width]) * 0.5 + np.array((92, 88, 84)) * 0.28
                a[(y0 + 1) % height, x % width] *= 1.12
                a[(y0 + bh - 2) % height, x % width] *= 0.82
                a[(y0 + bh - 1) % height, x % width] = mortar
            for y in range(y0, y0 + bh):
                a[y % height, (x0 + bw - 1) % width] = mortar
                a[y % height, (x0 + bw - 2) % width] *= 0.82
                a[y % height, (x0 + 1) % width] *= 1.08
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


# ------------------------------------------------------------------------------------------- drawing
def ring(image, inset, light, shade=None, box=None):
    """One line around the picture, one colour above and left, another below and right."""
    shade = shade or light
    d = ImageDraw.Draw(image)
    x0, y0, x1, y1 = box or (0, 0, image.width, image.height)
    x0, y0, x1, y1 = x0 + inset, y0 + inset, x1 - 1 - inset, y1 - 1 - inset
    d.line([(x0, y1), (x1, y1)], fill=shade)
    d.line([(x1, y0), (x1, y1)], fill=shade)
    d.line([(x0, y0), (x1, y0)], fill=light)
    d.line([(x0, y0), (x0, y1)], fill=light)


def rings(image, colours, box=None):
    for inset, colour in enumerate(colours):
        if isinstance(colour[0], tuple):
            ring(image, inset, colour[0], colour[1], box)
        else:
            ring(image, inset, colour, colour, box)


def metal_noise(image, box, amount=0.16, seed=3):
    """Worn metal: the lines of a frame vary a little, as if hammered."""
    rnd = random.Random(seed)
    px = image.load()
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            k = 1 + rnd.uniform(-amount, amount)
            p = px[x, y]
            px[x, y] = tuple(min(255, int(v * k)) for v in p[:3]) + tuple(p[3:])


def shade_inside(image, box, depth=6, strength=0.42):
    """The stone darkens where it meets its frame. Only ever inside the slices that don't repeat."""
    a = np.array(image.convert('RGB')).astype(float)
    x0, y0, x1, y1 = box
    for i in range(depth):
        k = 1 - strength * (depth - i) / depth
        a[y0 + i:y1 - i, x0 + i] *= k
        a[y0 + i:y1 - i, x1 - 1 - i] *= k
        a[y0 + i, x0 + i + 1:x1 - i - 1] *= k
        a[y1 - 1 - i, x0 + i + 1:x1 - i - 1] *= k
    return Image.fromarray(np.uint8(np.clip(a, 0, 255)))


def clear_corners(image, size=1):
    rgba = image.convert('RGBA')
    px = rgba.load()
    w, h = rgba.size
    for i in range(size):
        for j in range(size - i):
            for x, y in ((i, j), (w - 1 - i, j), (i, h - 1 - j), (w - 1 - i, h - 1 - j)):
                px[x, y] = (0, 0, 0, 0)
    return rgba


def glyph(image, rows, x, y, colours):
    """A small picture written by hand: every letter of the rows is a colour of the dictionary, spaces are clear."""
    px = image.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ' ':
                c = colours[ch]
                px[x + i, y + j] = c if len(px[0, 0]) == 3 else tuple(c) + (255,) if len(c) == 3 else c


# ------------------------------------------------------------------------------------------- sheets
def sheet(name):
    return Image.open(os.path.join(ART, name + '.png')).convert('RGB')


def cell(source, column, row, columns=4, rows=4):
    w, h = source.width / columns, source.height / rows
    return cut(source, (int(column * w), int(row * h), int((column + 1) * w), int((row + 1) * h)))


# ------------------------------------------------------------------------------------------- windows
def ornaments():
    """The pieces of metal that go in the corners of a frame."""
    source = sheet('reborn_ornaments')
    k = source.width / 800
    piece = lambda x0, y0, x1, y1: cut(source, (int(x0 * k), int(y0 * k), int(x1 * k), int(y1 * k)))
    return {
        'corner': piece(20, 25, 220, 210),
        'rivet': piece(255, 75, 355, 170),
        'fleur': piece(425, 30, 595, 220),
        'gem': piece(650, 70, 760, 185),
        'divider': piece(20, 245, 780, 325),
        'wing_left': piece(25, 355, 320, 510),
        'wing_right': piece(485, 355, 775, 510),
        'crest_blue': piece(20, 550, 190, 750),
        'crest_red': piece(215, 550, 385, 750),
        'lion': piece(415, 555, 590, 750),
        'keystone': piece(610, 565, 780, 730),
    }


def window(pieces):
    L, T, B = 16, 28, 16
    W, H = L + PERIOD + L, T + PERIOD + B
    im = tile(M.stone, W, H)
    im = shade_inside(im, (3, 22, W - 3, H - 3), 6, 0.34)
    # the caption
    d = ImageDraw.Draw(im)
    dark = tile(M.dark, W, 22)
    for y in range(4, 19):
        k = 1.22 - 0.5 * (y - 4) / 14
        row = scale(dark.crop((4, y, W - 4, y + 1)), k, (1.02, 1, 0.96))
        im.paste(row, (4, y))
    d.line([(4, 19), (W - 5, 19)], fill=B_MID)
    d.line([(4, 20), (W - 5, 20)], fill=B_DARK)
    d.line([(4, 21), (W - 5, 21)], fill=(24, 22, 20))
    # the frame: dark, bronze, dark, and the stone sunk into it
    rings(im, [INK, (B_LIGHT, B_LOW), (B_MID, B_DARK), EDGE])
    metal_noise(im, (1, 1, W - 1, 3), 0.14)
    metal_noise(im, (1, H - 3, W - 1, H - 1), 0.14, 4)
    metal_noise(im, (1, 3, 3, H - 3), 0.14, 5)
    metal_noise(im, (W - 3, 3, W - 1, H - 3), 0.14, 6)
    d = ImageDraw.Draw(im)
    d.line([(4, 22), (4, H - 5)], fill=(40, 38, 34))
    d.line([(W - 5, 22), (W - 5, H - 5)], fill=(102, 98, 90))
    d.line([(4, H - 5), (W - 5, H - 5)], fill=(102, 98, 90))
    im = clear_corners(im, 2)
    # the corners, in metal
    corner = shrink(pieces['corner'], 14, 14, threshold=110)
    im.alpha_composite(corner.transpose(Image.FLIP_TOP_BOTTOM), (1, H - 15))
    im.alpha_composite(corner.transpose(Image.ROTATE_180), (W - 15, H - 15))
    # the ends of the caption
    fleur = shrink(pieces['fleur'], 11, 13, threshold=110)
    for x in (3, W - 14):
        im.alpha_composite(fleur, (x, 5))
    save(im, 'ui/window')

    # the same without a caption
    W, H = 5 + PERIOD + 5, 5 + PERIOD + 5
    im = shade_inside(tile(M.stone, W, H), (3, 3, W - 3, H - 3), 2, 0.3)
    rings(im, [INK, (B_LIGHT, B_LOW), (B_MID, B_DARK), EDGE])
    save(clear_corners(im, 1), 'ui/window_headless')


def miniwindow(name, top=20, factor=0.94):
    W, H = 4 + PERIOD + 4, top + PERIOD + 4
    im = scale(tile(M.stone, W, H), factor)
    d = ImageDraw.Draw(im)
    dark = tile(M.dark, W, top)
    for y in range(3, top - 3):
        k = 1.28 - 0.5 * (y - 3) / (top - 6)
        im.paste(scale(dark.crop((3, y, W - 3, y + 1)), k, (1.02, 1, 0.96)), (3, y))
    d.line([(3, top - 3), (W - 4, top - 3)], fill=B_MID)
    d.line([(3, top - 2), (W - 4, top - 2)], fill=B_DARK)
    d.line([(3, top - 1), (W - 4, top - 1)], fill=(30, 28, 26))
    rings(im, [INK, (B_MID, B_DARK), EDGE])
    metal_noise(im, (1, 1, W - 1, 2), 0.16)
    d = ImageDraw.Draw(im)
    d.line([(1, 1), (W - 2, 1)], fill=B_LIGHT)
    d.line([(3, top), (3, H - 4)], fill=(38, 36, 32))
    d.line([(W - 4, top), (W - 4, H - 4)], fill=(96, 92, 86))
    d.line([(3, H - 4), (W - 4, H - 4)], fill=(96, 92, 86))
    for x, y in ((2, 2), (W - 3, 2)):
        d.point((x, y), fill=GOLD)
    save(clear_corners(im, 1), 'ui/' + name)


def panels():
    # sunk into the stone: lists, text, wells
    W = 1 + PERIOD + 1
    flat = tile(M.dark, W, W)
    ring(flat, 0, (12, 11, 10), (96, 90, 78))
    save(flat, 'ui/panel_flat')
    light = scale(tile(M.stone, W, W), 0.86)
    ring(light, 0, (22, 20, 18), (112, 106, 96))
    save(light, 'ui/panel_lightflat')
    # a text field, and the same with the keyboard in it
    field = scale(tile(M.dark, 32, 32), 0.85)
    ring(field, 0, (10, 9, 8), B_LOW)
    save(field, 'ui/textedit')
    focused = scale(tile(M.dark, 32, 32), 0.95)
    ring(focused, 0, B_HI, B_HI)
    save(focused, 'ui/textedit_focus')
    save(tile(M.dark, 51, 25), 'ui/dark_background')

    # the right click menus
    W = 3 + PERIOD + 3
    menu = scale(tile(M.dark, W, W), 1.25)
    rings(menu, [INK, (B_MID, B_LOW), EDGE])
    save(menu, 'ui/menubox')

    # the columns of panels around the map: a wall
    W, H = PERIOD, 160
    wall = bricks(W, H)
    side = Image.new('RGB', (4 + W + 4, 4 + H + 4))
    side.paste(tile(wall, 4 + W + 4, 4 + H + 4, (W - 4, H - 4)), (0, 0))
    a = ImageDraw.Draw(side)
    a.line([(0, 0), (0, H + 7)], fill=(12, 10, 8))
    a.line([(1, 0), (1, H + 7)], fill=B_DARK)
    a.line([(W + 7, 0), (W + 7, H + 7)], fill=(12, 10, 8))
    a.line([(W + 6, 0), (W + 6, H + 7)], fill=B_DARK)
    save(side, 'ui/panel_side')
    # the frame around the map
    W = 4 + PERIOD + 4
    around = Image.new('RGBA', (W, W), (0, 0, 0, 255))
    rings(around, [INK, (B_LIGHT, B_LOW), (B_MID, B_DARK), EDGE])
    metal_noise(around, (1, 1, W - 1, 3), 0.14)
    save(around, 'ui/panel_map')
    # the bar over the map
    strip = tile(M.stone, 942, 60)
    strip = scale(strip, 0.86)
    save(strip, 'ui/panel_bottom2')
    # the top menu of the login
    top = scale(tile(M.stone, 256, 36), 0.8)
    b = ImageDraw.Draw(top)
    b.line([(0, 33), (255, 33)], fill=B_MID)
    b.line([(0, 34), (255, 34)], fill=B_DARK)
    b.line([(0, 35), (255, 35)], fill=INK)
    b.line([(0, 0), (255, 0)], fill=(96, 92, 86))
    save(top, 'ui/panel_top')
    # the console: 29 pixels of tabs on top
    W, T, B = 7 + PERIOD + 7, 29, 7
    console = scale(tile(M.stone, W, T + PERIOD + B), 0.82)
    c = ImageDraw.Draw(console)
    c.line([(0, 0), (W - 1, 0)], fill=B_LOW)
    c.line([(0, 17), (W - 1, 17)], fill=B_MID)
    c.line([(0, 18), (W - 1, 18)], fill=B_DARK)
    rings(console, [INK], (0, 0, W, T + PERIOD + B))
    save(console, 'ui/panel_bottom')
    # an action bar
    bar = scale(tile(M.stone, 37, 19), 0.72)
    save(bar, 'ui/actionbar_background')

    # small lines
    line = Image.new('RGBA', (32, 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(line)
    d.line([(0, 0), (31, 0)], fill=B_LOW)
    d.line([(0, 1), (31, 1)], fill=(24, 22, 20))
    save(line, 'ui/separator_horizontal')
    line = Image.new('RGBA', (2, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(line)
    d.line([(0, 0), (0, 31)], fill=B_LOW)
    d.line([(1, 0), (1, 31)], fill=(24, 22, 20))
    save(line, 'ui/separator_vertical')


def plate(width, height, base, factor, light, inner, low, shade, tint=(1, 1, 1), noise=0.0):
    """A raised plate: dark line, a line of light, the inside, a line of shade, dark line."""
    im = scale(tile(base, width, height, (17, 9)), factor, tint)
    rings(im, [INK, (light, shade), (inner, low)])
    if noise:
        metal_noise(im, (1, 1, width - 1, 2), noise)
    return im


def buttons():
    def strip(width=22, height=23):
        out = Image.new('RGBA', (width, height * 3))
        normal = plate(width, height, M.stone, 0.92, B_LIGHT, (96, 88, 72), (58, 54, 48), B_DARK, (1.02, 1, 0.96))
        hover = plate(width, height, M.stone, 1.12, B_HI, (132, 118, 90), (70, 64, 54), B_LOW, (1.04, 1, 0.94))
        pressed = plate(width, height, M.stone, 0.7, B_DARK, (34, 32, 28), (84, 78, 66), B_MID, (1.02, 1, 0.96))
        for i, part in enumerate((normal, hover, pressed)):
            out.paste(clear_corners(part, 1), (0, i * height))
        return out
    for name in ('button', 'button_rounded', 'button_square', 'button_popupmenu', 'tabbutton_rounded'):
        save(strip(), 'ui/' + name)

    # tabs: the third is chosen, with the gold line on top like the Task Board's
    W, H = 48, 21
    tabs = Image.new('RGBA', (W, H * 3), (0, 0, 0, 0))
    normal = scale(tile(M.stone, W, H), 0.56)
    hover = scale(tile(M.stone, W, H), 0.76)
    active = scale(tile(M.stone, W, H), 1.0, (1.02, 1, 0.96))
    for row, part in enumerate((normal, hover, active)):
        d = ImageDraw.Draw(part)
        d.line([(0, 0), (W - 1, 0)], fill=(84, 80, 72) if row < 2 else B_HI)
        d.line([(0, 1), (W - 1, 1)], fill=(38, 36, 32) if row < 2 else B_MID)
        d.line([(0, 0), (0, H - 1)], fill=(84, 80, 72) if row < 2 else (126, 122, 114))
        d.line([(W - 1, 0), (W - 1, H - 1)], fill=(20, 18, 16))
        tabs.paste(part, (0, row * H))
    save(tabs, 'ui/tabbutton_square')

    # the frame of the buttons with an icon over the map's top
    top = Image.new('RGBA', (78, 26))
    blink = Image.new('RGBA', (78, 26))
    for i, (factor, light, shade) in enumerate(((0.9, B_MID, B_DARK), (1.15, B_HI, B_LOW), (0.65, B_DARK, B_MID))):
        top.paste(clear_corners(plate(26, 26, M.stone, factor, light, (70, 66, 58), (44, 42, 38), shade), 1), (i * 26, 0))
        blink.paste(clear_corners(plate(26, 26, M.stone, factor * 0.9, (236, 90, 60), (130, 44, 26), (70, 26, 16), (90, 20, 10), (1.5, 0.6, 0.5)), 1), (i * 26, 0))
    save(top, 'ui/button_top')
    save(top, 'ui/button_topgame')
    save(blink, 'ui/button_top_blink')


CHEVRON_UP = ['   #   ', '  #o#  ', ' #ooo# ', '#ooooo#', '#######']
CHEVRON_DOWN = ['#######', '#ooooo#', ' #ooo# ', '  #o#  ', '   #   ']
CHEVRON_LEFT = ['   ##', '  #o#', ' #oo#', '#ooo#', ' #oo#', '  #o#', '   ##']
CHEVRON_RIGHT = ['##   ', '#o#  ', '#oo# ', '#ooo#', '#oo# ', '#o#  ', '##   ']


def key(size, factor, light, shade):
    im = plate(size, size, M.stone, factor, light, (70, 66, 58), (44, 42, 38), shade)
    return im


def scrollbars():
    out = Image.new('RGBA', (52, 78), (0, 0, 0, 0))
    states = ((0.82, B_MID, B_DARK, B_HI), (1.05, B_HI, B_LOW, GOLD), (0.6, B_DARK, B_MID, B_MID))
    for column, (factor, light, shade, arrow) in enumerate(states):
        colours = {'#': (16, 12, 8), 'o': arrow}
        for row, (rows, width, height) in enumerate(((CHEVRON_UP, 7, 5), (CHEVRON_DOWN, 7, 5))):
            part = key(13, factor, light, shade)
            glyph(part, rows, 3, 4, colours)
            out.paste(part, (column * 13, row * 13))
        # the slider: a stone with a grip of three lines
        slider = key(13, factor + 0.1, light, shade)
        d = ImageDraw.Draw(slider)
        for y in (4, 6, 8):
            d.line([(4, y), (8, y)], fill=(20, 16, 10))
            d.line([(4, y + 1), (8, y + 1)], fill=light)
        out.paste(slider, (column * 13, 26))
        for row, rows in ((3, CHEVRON_LEFT), (4, CHEVRON_RIGHT)):
            part = key(13, factor, light, shade)
            glyph(part, rows, 4, 3, colours)
            out.paste(part, (column * 13, row * 13))
    track = scale(tile(M.dark, 13, 65), 0.75)
    d = ImageDraw.Draw(track)
    d.line([(0, 0), (0, 64)], fill=(8, 7, 6))
    d.line([(12, 0), (12, 64)], fill=(62, 54, 40))
    out.paste(track, (39, 0))
    track = scale(tile(M.dark, 52, 13), 0.75)
    d = ImageDraw.Draw(track)
    d.line([(0, 0), (51, 0)], fill=(8, 7, 6))
    d.line([(0, 12), (51, 12)], fill=(62, 54, 40))
    out.paste(track, (0, 65))
    save(out, 'ui/scrollbar')


def fields():
    # check boxes, 12 pixels: empty, then with the gold mark
    box = Image.new('RGBA', (12, 24), (0, 0, 0, 0))
    for row in range(2):
        part = scale(tile(M.dark, 12, 12), 0.8)
        ring(part, 0, (8, 7, 6), B_LOW)
        box.paste(part, (0, row * 12))
    mark = ['        #', '       #o', '      #oo', '#    #oo#', 'o#  #oo# ', 'oo##oo#  ', '#oooo#   ', ' #oo#    ', '  ##     ']
    glyph(box, mark, 2, 13, {'#': (22, 14, 6), 'o': GOLD})
    save(box, 'ui/checkbox')
    # round
    radio = Image.new('RGBA', (12, 24), (0, 0, 0, 0))
    disc = ['   ####   ', '  #oooo#  ', ' #oooooo# ', '#oooooooo#', '#oooooooo#', '#oooooooo#', '#oooooooo#', ' #oooooo# ', '  #oooo#  ', '   ####   ']
    for row in range(2):
        glyph(radio, disc, 1, 1 + row * 12, {'#': B_LOW, 'o': (20, 19, 18)})
    glyph(radio, [' ## ', '#oo#', '#oo#', ' ## '], 4, 16, {'#': (120, 92, 44), 'o': GOLD})
    save(radio, 'ui/checkbox_round')

    # combo boxes: normal, hover, open, and the back of its list
    W, H = 91, 23
    combo = Image.new('RGBA', (W, H * 4), (0, 0, 0, 0))
    for row, (factor, line, arrow) in enumerate(((0.95, B_LOW, B_LIGHT), (1.2, B_MID, GOLD), (1.2, B_HI, GOLD))):
        part = scale(tile(M.dark, W, H), factor)
        ring(part, 0, (10, 9, 8), line)
        d = ImageDraw.Draw(part)
        d.line([(W - 20, 2), (W - 20, H - 3)], fill=(12, 11, 10))
        d.line([(W - 19, 2), (W - 19, H - 3)], fill=(62, 54, 40))
        glyph(part, CHEVRON_DOWN, W - 14, 9, {'#': (16, 12, 8), 'o': arrow})
        combo.paste(part, (0, row * H))
    back = scale(tile(M.dark, W, H), 1.3)
    ring(back, 0, B_LOW, B_LOW)
    combo.paste(back, (0, 3 * H))
    for name in ('combobox', 'combobox_rounded', 'combobox_square'):
        save(combo, 'ui/' + name)

    # spin boxes: three looks one under the other, 10 pixels each
    for name, rows in (('spinbox_up', ['  #  ', ' #o# ', '#ooo#']), ('spinbox_down', ['#ooo#', ' #o# ', '  #  '])):
        out = Image.new('RGBA', (10, 30), (0, 0, 0, 0))
        for row, (factor, light, shade, arrow) in enumerate(((0.8, B_MID, B_DARK, B_HI), (1.0, B_HI, B_LOW, GOLD), (0.6, B_DARK, B_MID, B_MID))):
            part = key(10, factor, light, shade)
            glyph(part, rows, 2, 3, {'#': (16, 12, 8), 'o': arrow})
            out.paste(part, (0, row * 10))
        save(out, 'ui/' + name)

    # the bars: a groove, and the shine over whatever colour fills it (see 10-progressbars.otui)
    groove = scale(tile(M.dark, 90, 18), 0.55)
    ring(groove, 0, (6, 5, 4), B_LOW)
    save(groove, 'ui/progressbar')
    gloss = Image.new('RGBA', (1, 16), (0, 0, 0, 0))
    px = gloss.load()
    for y, value in enumerate(((255, 120), (255, 90), (255, 66), (255, 46), (255, 30), (255, 16), (255, 6), (0, 0), (0, 0), (0, 10), (0, 22), (0, 36), (0, 50), (0, 66), (0, 84), (0, 104))):
        px[0, y] = (value[0], value[0], value[0], value[1])
    save(gloss, 'ui/bar_gloss')

    # an item's slot, and the blessed one
    slot = scale(tile(M.dark, 34, 34), 0.9)
    rings(slot, [(EDGE, (72, 64, 48)), ((10, 9, 8), (40, 36, 30))])
    save(slot, 'ui/item')
    blessed = scale(tile(M.dark, 34, 34), 1.0)
    rings(blessed, [(B_HI, B_HI), (B_LOW, B_LOW)])
    save(blessed, 'ui/item-blessed')


def small_buttons():
    # the corner buttons of a small window: minus, plus, close, up, down, dot, locked, open; normal, hover, pressed
    glyphs = {
        0: ['       ', '       ', '       ', '#######', '#ooooo#', '#######', '       '],
        1: ['  ###  ', '  #o#  ', '###o###', '#ooooo#', '###o###', '  #o#  ', '  ###  '],
        2: ['##   ##', '#o# #o#', ' #o#o# ', '  #o#  ', ' #o#o# ', '#o# #o#', '##   ##'],
        3: ['   #   ', '  #o#  ', ' #ooo# ', '#ooooo#', '###o###', '  #o#  ', '  ###  '],
        4: ['  ###  ', '  #o#  ', '###o###', '#ooooo#', ' #ooo# ', '  #o#  ', '   #   '],
        5: ['       ', '  ###  ', ' #ooo# ', ' #ooo# ', ' #ooo# ', '  ###  ', '       '],
        6: ['  ###  ', ' #   # ', ' #   # ', '#######', '#ooooo#', '#ooooo#', '#######'],
        7: ['  ###  ', ' #   # ', '     # ', '#######', '#ooooo#', '#ooooo#', '#######'],
    }
    out = Image.new('RGBA', (112, 42), (0, 0, 0, 0))
    for row, (factor, light, shade, ink) in enumerate(((0.72, B_LOW, B_DARK, B_HI), (0.98, B_HI, B_LOW, GOLD), (0.5, B_DARK, B_LOW, B_MID))):
        for column, rows in glyphs.items():
            part = plate(14, 14, M.stone, factor, light, (62, 58, 50), (40, 38, 34), shade)
            glyph(part, rows, 4 - 1 + (0 if column else 0), 4 - 1, {'#': (14, 10, 6), 'o': ink})
            out.paste(clear_corners(part, 1), (column * 14, row * 14))
    save(out, 'ui/miniwindow_buttons')

    # the arrows beside the action bars
    for name, picture, colour in (('arrow', ['#    ', '##   ', '#o#  ', '#oo# ', '#ooo#', '#oo# ', '#o#  ', '##   ', '#    '], B_HI),
                                  ('arrow-disabled', ['#    ', '##   ', '#o#  ', '#oo# ', '#ooo#', '#oo# ', '#o#  ', '##   ', '#    '], (84, 78, 66))):
        im = Image.new('RGBA', (6, 9), (0, 0, 0, 0))
        glyph(im, picture, 0, 0, {'#': (14, 10, 6), 'o': colour})
        save(im, 'game/actionbar/' + name)
    for name, colour in (('arrow-skip', B_HI), ('arrow-skip-disabled', (84, 78, 66))):
        im = Image.new('RGBA', (13, 9), (0, 0, 0, 0))
        rows = ['#     #    ', '##    ##   ', '#o#   #o#  ', '#oo#  #oo# ', '#ooo# #ooo#', '#oo#  #oo# ', '#o#   #o#  ', '##    ##   ', '#     #    ']
        glyph(im, rows, 1, 0, {'#': (14, 10, 6), 'o': colour})
        save(im, 'game/actionbar/' + name)
    # an empty slot of an action bar
    slot = scale(tile(M.dark, 34, 34), 0.82)
    rings(slot, [(EDGE, (70, 62, 46)), ((10, 9, 8), (34, 30, 26))])
    d = ImageDraw.Draw(slot)
    for x, y in ((3, 3), (30, 3), (3, 30), (30, 30)):
        d.point((x, y), fill=B_LOW)
    save(slot, 'game/actionbar/actionbarslot')


# ------------------------------------------------------------------------------------------- pictures
def round_key(picture, size, inner):
    """A picture on its stone key: the normal look above, the pressed one below (the family of the top buttons)."""
    out = Image.new('RGBA', (size, size * 2 + 14), (0, 0, 0, 0))
    small = shrink(picture, inner, inner, threshold=100)
    # below them, for the caption of a small window
    out.alpha_composite(shrink(picture, 14, 14, threshold=100), (0, size * 2))
    margin = (size - inner) // 2
    up = clear_corners(plate(size, size, M.stone, 0.8, B_LOW, (60, 56, 50), (36, 34, 30), B_DARK), 1)
    up.alpha_composite(small, (margin, margin))
    down = clear_corners(plate(size, size, M.stone, 0.56, B_DARK, (28, 26, 24), (70, 62, 50), B_MID), 1)
    down.alpha_composite(small, (margin + 1, margin + 1))
    out.paste(up, (0, 0))
    out.paste(down, (0, size))
    return out


TOP_ICONS = {
    # sheet 1
    'options': (1, 0, 0), 'audio': (1, 1, 0), 'audio_mute': (1, 2, 0), 'debug': (1, 3, 0),
    'terminal': (1, 0, 1), 'exit': (1, 1, 1), 'logout': (1, 1, 1), 'guides': (1, 2, 1), 'battle': (1, 3, 1),
    'healthinfo': (1, 0, 2), 'inventory': (1, 1, 2), 'minimap': (1, 2, 2), 'questlog': (1, 3, 2),
    'quest_tracker': (1, 0, 3), 'skills': (1, 1, 3), 'taskboard': (1, 2, 3), 'tasktracker': (1, 3, 3),
    # sheet 2
    'unjustifiedpoints': (2, 0, 0), 'viplist': (2, 1, 0), 'spelllist': (2, 2, 0), 'prey': (2, 3, 0),
    'prey_window': (2, 0, 1), 'shop': (2, 1, 1), 'login': (2, 2, 1), 'hotkeys': (2, 3, 1),
    'cooldowns': (2, 0, 2), 'dailyreward': (2, 1, 2), 'motd': (2, 2, 2), 'compedium': (2, 2, 2), 'analyzers': (2, 3, 2),
    'bot': (2, 0, 3), 'modulemanager': (2, 1, 3), 'ciclopedia': (2, 2, 3), 'particles': (2, 3, 3),
}

OPTION_ICONS = {'game': (2, 0, 3), 'interface': (2, 1, 3), 'extras': (2, 1, 2), 'console': (2, 2, 3), 'graphics': (2, 3, 3), 'audio': (1, 1, 0), 'features': (2, 1, 2)}


def pictures():
    sheets = {1: sheet('reborn_icons_1'), 2: sheet('reborn_icons_2')}
    for name, (number, column, row) in TOP_ICONS.items():
        save(round_key(cell(sheets[number], column, row), 20, 18), 'topbuttons/' + name)
    for name, (number, column, row) in OPTION_ICONS.items():
        small = shrink(cell(sheets[number], column, row), 30, 30, threshold=100)
        canvas = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        canvas.alpha_composite(small, (1, 1))
        save(canvas, 'optionstab/' + name)


SLOTS = {
    'head': (0, 0), 'neck': (1, 0), 'back': (2, 0), 'body': (3, 0),
    'right-hand': (0, 1), 'left-hand': (1, 1), 'legs': (2, 1), 'feet': (3, 1),
    'finger': (0, 2), 'ammo': (1, 2),
}


def engraved(mask, size, colour, shadow, light):
    """A silhouette cut into the slot's stone: dark, with a line of light at its lower right."""
    small = shrink(mask, size, size, threshold=128)
    out = Image.new('RGBA', small.size, (0, 0, 0, 0))
    source = small.load()
    target = out.load()
    w, h = small.size
    for y in range(h):
        for x in range(w):
            if source[x, y][3]:
                target[x, y] = colour
    for y in range(h):
        for x in range(w):
            if source[x, y][3]:
                if y + 1 < h and x + 1 < w and not source[x + 1, y + 1][3]:
                    target[x, y] = light
                elif (y == 0 or x == 0 or not source[x - 1, y - 1][3]):
                    target[x, y] = shadow
    return out


def slots():
    source = sheet('reborn_silhouettes')
    for name, (column, row) in SLOTS.items():
        mask = cell(source, column, row, 4, 3)
        for suffix, frame, ink, dim, hi in (
            ('', 'ui/item', (62, 58, 52, 255), (26, 24, 22, 255), (108, 100, 86, 255)),
            ('-blessed', 'ui/item-blessed', (120, 92, 44, 255), (60, 44, 20, 255), (214, 170, 84, 255)),
        ):
            base = Image.open(os.path.join(OUT, frame + '.png')).convert('RGBA')
            cutout = engraved(mask, 24, ink, dim, hi)
            base.alpha_composite(cutout, (5, 5))
            save(base, 'game/slots/' + name + suffix)


def combat():
    source = sheet('reborn_icons_3')
    for name, column, row in (('fightoffensive', 0, 0), ('fightbalanced', 1, 0), ('fightdefensive', 2, 0), ('chasemode', 3, 0), ('safefight', 0, 1),
                              ('whitedovemode', 0, 1), ('whitehandmode', 1, 1), ('yellowhandmode', 2, 1), ('redfistmode', 3, 1), ('mount', 0, 2)):
        picture = shrink(cell(source, column, row), 16, 16, threshold=100)
        out = Image.new('RGBA', (20, 40), (0, 0, 0, 0))
        off = clear_corners(plate(20, 20, M.stone, 0.72, B_LOW, (58, 54, 48), (36, 34, 30), B_DARK), 1)
        off.alpha_composite(scale_alpha(picture, 0.62), (2, 2))
        on = clear_corners(plate(20, 20, M.stone, 0.95, B_HI, (150, 118, 62), (112, 86, 44), B_MID), 1)
        on.alpha_composite(picture, (2, 2))
        out.paste(off, (0, 0))
        out.paste(on, (0, 20))
        save(out, 'game/combatmodes/' + name)

    # the PvP switch: the word and a hand
    hand = shrink(cell(source, 1, 1), 14, 14, threshold=100)
    out = Image.new('RGBA', (42, 40), (0, 0, 0, 0))
    font = ImageFont.truetype('C:/Windows/Fonts/verdanab.ttf', 10)
    for row, (factor, light, shade, ink) in enumerate(((0.72, B_LOW, B_DARK, (190, 186, 176)), (0.95, B_HI, B_MID, (255, 244, 214)))):
        part = clear_corners(plate(42, 20, M.stone, factor, light, (58, 54, 48), (36, 34, 30), shade), 1)
        d = ImageDraw.Draw(part)
        d.fontmode = '1'
        d.text((4, 4), 'PvP', fill=(14, 10, 6), font=font)
        d.text((3, 3), 'PvP', fill=ink, font=font)
        part.alpha_composite(hand if row else scale_alpha(hand, 0.7), (26, 3))
        out.paste(part, (0, row * 20))
    save(out, 'game/combatmodes/pvp')

    # the filters of the battle window. Not checked: that kind is shown, in full colour. Checked: it's hidden, dim.
    # Rows: shown, hidden, shown under the mouse, hidden under the mouse.
    for name, column, row in (('battle_players', 1, 2), ('battle_monsters', 2, 2), ('battle_npcs', 3, 2), ('battle_party', 0, 3), ('battle_skulls', 1, 3)):
        picture = shrink(cell(source, column, row), 16, 16, threshold=100)
        out = Image.new('RGBA', (20, 80), (0, 0, 0, 0))
        for index, (factor, light, shade, inner, low, dim) in enumerate((
            (0.86, B_MID, B_DARK, (70, 66, 58), (44, 42, 38), 1),
            (0.55, B_DARK, INK, (40, 38, 34), (28, 26, 24), 0.34),
            (1.05, B_HI, B_LOW, (120, 104, 72), (70, 62, 48), 1),
            (0.7, B_LOW, B_DARK, (52, 48, 42), (36, 34, 30), 0.5),
        )):
            part = clear_corners(plate(20, 20, M.stone, factor, light, inner, low, shade), 1)
            part.alpha_composite(picture if dim == 1 else scale_alpha(picture, dim), (2, 2))
            out.paste(part, (0, index * 20))
        save(out, 'game/battle/' + name)


def scale_alpha(image, factor):
    """Dimmer: for a picture that is off."""
    a = np.array(image).astype(float)
    a[..., :3] = a[..., :3] * factor + 24 * (1 - factor)
    return Image.fromarray(np.uint8(a))


def console_icons():
    source = sheet('reborn_icons_3')
    ink = {'#': (14, 10, 6), 'o': B_HI}
    # arrows, 16 pixels
    for name, rows, x, y in (('leftarrow', CHEVRON_LEFT, 5, 4), ('rightarrow', CHEVRON_RIGHT, 6, 4), ('uparrow', CHEVRON_UP, 4, 5), ('downarrow', CHEVRON_DOWN, 4, 5)):
        im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
        glyph(im, rows, x, y, ink)
        save(im, 'game/console/' + name)
    close = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    glyph(close, ['##     ##', '#o#   #o#', ' #o# #o# ', '  #o#o#  ', '   #o#   ', '  #o#o#  ', ' #o# #o# ', '#o#   #o#', '##     ##'], 3, 3, ink)
    save(close, 'game/console/closechannel')
    for name, column, row in (('say', 2, 3), ('yell', 3, 3)):
        save(shrink(cell(source, column, row), 16, 16, threshold=100), 'game/console/' + name)
    whisper = shrink(cell(source, 2, 3), 12, 12, threshold=100)
    canvas = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    canvas.alpha_composite(whisper, (2, 2))
    save(canvas, 'game/console/whisper')
    # the list of channels, cleaning a channel, ignoring
    lines = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(lines)
    for y in (3, 7, 11):
        d.rectangle((2, y, 13, y + 1), fill=B_HI, outline=None)
        d.line([(2, y + 2), (13, y + 2)], fill=(14, 10, 6))
    save(lines, 'game/console/channels')
    broom = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    glyph(broom, ['         ##', '        #o#', '       #o# ', '      #o#  ', '     #o#   ', '  ####o#   ', ' #bbbb#    ', '#bbbbb#    ', '#bbbb#     ', '#b#b#      ', '##b#       '], 2, 2, {'#': (14, 10, 6), 'o': (150, 104, 56), 'b': B_HI})
    save(broom, 'game/console/clearchannel')
    ignore = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    glyph(ignore, ['    ####    ', '  ##oooo##  ', ' #oo####oo# ', ' #o#   ##o# ', '#o#   #o##o#', '#o#  #o# #o#', '#o# #o#  #o#', '#o##o#   #o#', ' #o##   #o# ', ' #oo####oo# ', '  ##oooo##  ', '    ####    '], 2, 2, {'#': (14, 10, 6), 'o': (216, 72, 56)})
    save(ignore, 'game/console/ignore')
    # the arrows of the floors on the minimap: pressed, under the mouse, normal
    for name, rows in (('floor_up', ['     ##     ', '    #oo#    ', '   #oooo#   ', '  #oooooo#  ', ' #oooooooo# ', '#oooooooooo#', ' ###oooo### ', '   #oooo#   ', '   #oooo#   ', '   ######   ']),
                       ('floor_down', ['   ######   ', '   #oooo#   ', '   #oooo#   ', ' ###oooo### ', '#oooooooooo#', ' #oooooooo# ', '  #oooooo#  ', '   #oooo#   ', '    #oo#    ', '     ##     '])):
        out = Image.new('RGBA', (16, 48), (0, 0, 0, 0))
        for row, colour in enumerate((B_MID, GOLD, B_HI)):
            glyph(out, rows, 2, 3 + row * 16, {'#': (14, 10, 6), 'o': colour})
        save(out, 'game/minimap/' + name)
    # the cross in the middle of the map
    cross = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    glyph(cross, ['   #   ', '   #   ', '   #   ', '### ###', '   #   ', '   #   ', '   #   '], 4, 4, {'#': (255, 240, 200)})
    save(cross, 'game/minimap/cross')


def small_panels():
    # soul and capacity: a dark plate with a thin bronze line
    plate_small = scale(tile(M.dark, 34, 20), 1.0)
    rings(plate_small, [(EDGE, (88, 70, 40))])
    save(plate_small, 'game/slots/soulcap')
    # the purse's button: normal and pressed, one under the other
    coin = shrink(cell(sheet('reborn_icons_2'), 1, 1), 11, 11, threshold=100)
    out = Image.new('RGBA', (34, 24), (0, 0, 0, 0))
    for row, (factor, light, shade) in enumerate(((0.8, B_LOW, B_DARK), (0.56, B_DARK, B_LOW))):
        part = clear_corners(plate(34, 12, M.stone, factor, light, (58, 54, 48), (36, 34, 30), shade), 1)
        part.alpha_composite(coin, (11 + row, 0 + row // 1))
        out.paste(part, (0, row * 12))
    save(out, 'game/slots/purse')
    # XP Boost in the top bar: a plaque, normal and pressed
    font = ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf', 11)
    out = Image.new('RGBA', (76, 28), (0, 0, 0, 0))
    for row, (factor, light, shade, ink) in enumerate(((0.9, B_HI, B_DARK, GOLD), (0.65, B_DARK, B_MID, B_LIGHT))):
        part = plate(76, 14, M.bronze, factor, light, (150, 112, 56), (70, 50, 24), shade)
        d = ImageDraw.Draw(part)
        d.fontmode = '1'
        d.text((12, 0), 'XP Boost', fill=(20, 12, 4), font=font)
        d.text((11, -1), 'XP Boost', fill=ink, font=font)
        out.paste(clear_corners(part, 1), (0, row * 14))
    save(out, 'game/topbar/boost')
    # the buttons that turn an outfit
    arrows = {'#': (14, 10, 6), 'o': B_HI}
    out = Image.new('RGBA', (40, 40), (0, 0, 0, 0))
    for index, (x, y) in enumerate(((0, 0), (20, 0), (0, 20), (20, 20))):
        part = clear_corners(plate(20, 20, M.stone, 0.85 if y == 0 else 0.6, B_LOW if y == 0 else B_DARK, (70, 66, 58), (44, 42, 38), B_DARK if y == 0 else B_LOW), 1)
        glyph(part, CHEVRON_LEFT if x == 0 else CHEVRON_RIGHT, 7 if x == 0 else 8, 6, arrows)
        out.paste(part, (x, y))
    save(out, 'ui/rotate_button')
    # small arrows of the old lists
    h = Image.new('RGBA', (24, 63), (0, 0, 0, 0))
    for row, colour in enumerate((B_LIGHT, B_HI, GOLD)):
        glyph(h, CHEVRON_LEFT, 3, 7 + row * 21, {'#': (14, 10, 6), 'o': colour})
        glyph(h, CHEVRON_RIGHT, 16, 7 + row * 21, {'#': (14, 10, 6), 'o': colour})
    save(h, 'ui/arrow_horizontal')
    v = Image.new('RGBA', (42, 36), (0, 0, 0, 0))
    for row, colour in enumerate((B_LIGHT, B_HI, GOLD)):
        glyph(v, CHEVRON_DOWN, 7, 3 + row * 12, {'#': (14, 10, 6), 'o': colour})
        glyph(v, CHEVRON_UP, 28, 3 + row * 12, {'#': (14, 10, 6), 'o': colour})
    save(v, 'ui/arrow_vertical')
    # an item's rarity stays in its colour, on the new slot
    for name, colour in (('blue', (64, 132, 228)), ('gold', (236, 194, 92)), ('green', (82, 196, 96)), ('purple', (176, 100, 226)), ('white', (224, 224, 224))):
        rare = scale(tile(M.dark, 32, 32), 0.9)
        rings(rare, [colour, tuple(v // 2 for v in colour)])
        save(rare, 'ui/rarity_' + name)
    # a graph's back
    graph = tile(M.dark, 96, 96)
    d = ImageDraw.Draw(graph)
    for i in range(0, 96, 24):
        d.line([(i, 0), (i, 95)], fill=(52, 48, 42))
        d.line([(0, i), (95, i)], fill=(52, 48, 42))
    save(graph, 'ui/graph_background')


def store_and_tasks():
    """The panels of the Task Board and the Store, on this stone. Their pictures stay as they are."""
    W = 64
    frame = tile(M.stone, W, W)
    rings(frame, [(S_HI, S_LOW), ((104, 100, 94), (36, 34, 30))])
    save(frame, 'taskboard/frame')
    inset = tile(M.dark, 32, 32)
    ring(inset, 0, (16, 15, 14), (108, 102, 92))
    save(inset, 'taskboard/inset')
    caption = tile(M.dark, 40, 18)
    d = ImageDraw.Draw(caption)
    d.line([(0, 0), (39, 0)], fill=(18, 17, 16))
    d.line([(0, 16), (39, 16)], fill=(122, 92, 44))
    d.line([(0, 17), (39, 17)], fill=(30, 26, 18))
    save(caption, 'taskboard/caption')
    cell_ = scale(tile(M.stone, 32, 32), 0.92)
    rings(cell_, [((112, 108, 100), (24, 22, 20))])
    save(cell_, 'taskboard/cell')
    done = scale(tile(M.stone, 32, 32), 0.92, (0.86, 1.08, 0.86))
    rings(done, [((92, 178, 92), (26, 70, 26))])
    save(done, 'taskboard/cell_done')
    plate_ = scale(tile(M.dark, 32, 22), 1.15)
    ring(plate_, 0, (20, 19, 18), (92, 88, 80))
    save(plate_, 'taskboard/plate')
    track = scale(tile(M.dark, 24, 14), 0.7)
    ring(track, 0, (10, 9, 8), (104, 98, 88))
    save(track, 'taskboard/track')

    tabs = Image.new('RGB', (48, 102))
    for row, part in enumerate((scale(tile(M.stone, 48, 34), 0.6), scale(tile(M.stone, 48, 34), 0.8), tile(M.stone, 48, 34))):
        d = ImageDraw.Draw(part)
        if row == 2:
            d.line([(0, 0), (47, 0)], fill=(214, 170, 84))
            d.line([(0, 1), (47, 1)], fill=(138, 104, 50))
            d.line([(0, 0), (0, 33)], fill=(126, 122, 114))
            d.line([(47, 0), (47, 33)], fill=(28, 26, 24))
        else:
            ring(part, 0, (88, 84, 78) if row == 0 else (112, 108, 100), (20, 18, 16))
        tabs.paste(part, (0, row * 34))
    save(tabs, 'taskboard/tab')

    tabs = Image.new('RGB', (48, 102))
    for row, part in enumerate((scale(tile(M.stone, 48, 34), 0.6), scale(tile(M.stone, 48, 34), 0.8), tile(M.stone, 48, 34))):
        ring(part, 0, (88, 84, 78) if row == 0 else (112, 108, 100) if row == 1 else (126, 122, 114), (20, 18, 16))
        if row == 2:
            d = ImageDraw.Draw(part)
            d.line([(0, 0), (0, 33)], fill=(226, 182, 92))
            d.line([(1, 0), (1, 33)], fill=(160, 122, 58))
            d.line([(2, 1), (2, 32)], fill=(96, 74, 38))
        tabs.paste(part, (0, row * 34))
    save(tabs, 'store/tab')

    offer = scale(tile(M.stone, 32, 32), 0.92)
    ring(offer, 0, (112, 108, 100), (24, 22, 20))
    save(offer, 'store/offer')
    hover = scale(tile(M.stone, 32, 32), 1.06)
    ring(hover, 0, (138, 134, 126), (28, 26, 24))
    save(hover, 'store/offer_hover')
    chosen = scale(tile(M.stone, 32, 32), 1.04, (1.05, 1.0, 0.9))
    rings(chosen, [((236, 194, 104), (156, 112, 44)), (B_MID, B_MID)])
    save(chosen, 'store/offer_focus')

    gold = Image.new('RGB', (40, 90))
    for state, (factor, light, shade) in enumerate(((0.95, (232, 190, 96), (58, 36, 10)), (1.2, (255, 226, 140), (70, 44, 12)), (0.7, (58, 36, 10), (214, 170, 84)))):
        piece = scale(tile(M.bronze, 40, 30), factor * 1.25)
        px = piece.load()
        for y in range(3, 9):
            for x in range(40):
                if (x + y) % 2 == 0 or y < 6:
                    r, g, b = px[x, y]
                    px[x, y] = (min(255, r + 16), min(255, g + 12), min(255, b + 6))
        for y in range(22, 28):
            for x in range(40):
                if (x + y) % 2 == 0 or y > 24:
                    r, g, b = px[x, y]
                    px[x, y] = (max(0, r - 18), max(0, g - 14), max(0, b - 8))
        ring(piece, 0, light, shade)
        ring(piece, 1, tuple(v // 2 + 40 for v in light), tuple(v // 2 for v in shade))
        gold.paste(piece, (0, state * 30))
    save(gold, 'store/gold_button')


def extras():
    source = sheet('reborn_extras')
    w, h = source.width / 4, source.height / 2
    piece = lambda column, row: cut(source, (int(column * w), int(row * h), int((column + 1) * w), int((row + 1) * h)))
    # the mouse: a 32 pixel image as the system wants it, with the tip of the sword on the hot spot of cursors.otml
    os.makedirs(os.path.join(ROOT, 'layouts', 'reborn', 'cursors'), exist_ok=True)
    pointer = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    sword = shrink(piece(0, 0), 24, 24, threshold=110)
    pointer.alpha_composite(sword.crop(sword.getbbox()), (0, 0))
    pointer.save(os.path.join(ROOT, 'layouts', 'reborn', 'cursors', 'pointer.png'))
    target = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    target.alpha_composite(shrink(piece(1, 0), 19, 19, threshold=110), (0, 0))
    target.save(os.path.join(ROOT, 'layouts', 'reborn', 'cursors', 'targetcursor.png'))
    for name in ('textcursor', 'horizontalcursor', 'verticalcursor'):
        Image.open(os.path.join(ROOT, 'data', 'cursors', name + '.png')).save(os.path.join(ROOT, 'layouts', 'reborn', 'cursors', name + '.png'))
    # on the minimap
    save(shrink(piece(2, 0), 30, 30, threshold=110), 'game/minimap/compass')
    # beside the health and mana bars
    save(shrink(piece(3, 1), 14, 14, threshold=100), 'ui/flask_health')
    save(shrink(piece(2, 1), 14, 14, threshold=100), 'ui/flask_mana')


def main():
    load_materials()
    pieces = ornaments()
    window(pieces)
    miniwindow('miniwindow')
    miniwindow('minipanel')
    miniwindow('special_miniwindow')
    panels()
    buttons()
    scrollbars()
    fields()
    small_buttons()
    pictures()
    slots()
    combat()
    console_icons()
    small_panels()
    store_and_tasks()
    extras()
    print('ok')


if __name__ == '__main__':
    main()
