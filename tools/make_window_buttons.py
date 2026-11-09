#!/usr/bin/env python3
"""The corner buttons of the small windows (Reborn look): minus, plus, close, up, down, dot, locked, open; one row each
for normal, hover and pressed (14x14 each, layouts/reborn/images/ui/miniwindow_buttons.png, as 30-miniwindow.otui and
40-container.otui read it). The owner asked for better-worked symbols (2026-11-09): each one is drawn eight times larger,
as a bevelled bronze plate with a gold symbol (light at the top, darker below, a dark outline), and scaled down.

  python tools/make_window_buttons.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'layouts', 'reborn', 'images', 'ui', 'miniwindow_buttons.png')
S = 8          # drawn this many times larger
CELL = 14


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical(size, top, bottom):
    w, h = size
    img = Image.new('RGB', size)
    px = img.load()
    for y in range(h):
        c = lerp(top, bottom, y / max(1, h - 1))
        for x in range(w):
            px[x, y] = c
    return img


def plate(state):
    """the bevelled plate: dark rim, bronze (gold on hover) frame lit from the top left, a stone field"""
    n = CELL * S
    rim = {'normal': ((122, 96, 52), (52, 40, 22)), 'hover': ((236, 196, 104), (120, 88, 36)),
           'pressed': ((70, 54, 30), (40, 30, 16))}[state]
    field = {'normal': ((62, 58, 52), (30, 28, 25)), 'hover': ((76, 70, 60), (38, 35, 30)),
             'pressed': ((26, 24, 21), (44, 41, 36))}[state]
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=3 * S, fill=255)
    outer = Image.new('RGBA', (n, n), (14, 10, 6, 255))
    img.paste(outer, (0, 0), mask)
    frame = vertical((n - 2 * S, n - 2 * S), rim[0], rim[1]).convert('RGBA')
    m2 = Image.new('L', frame.size, 0)
    ImageDraw.Draw(m2).rounded_rectangle([0, 0, frame.size[0] - 1, frame.size[1] - 1], radius=2 * S, fill=255)
    img.paste(frame, (S, S), m2)
    inner = vertical((n - 4 * S, n - 4 * S), field[0], field[1]).convert('RGBA')
    m3 = Image.new('L', inner.size, 0)
    ImageDraw.Draw(m3).rounded_rectangle([0, 0, inner.size[0] - 1, inner.size[1] - 1], radius=S, fill=255)
    img.paste(inner, (2 * S, 2 * S), m3)
    return img


def shape(index):
    """the symbol's mask, drawn on the big grid (coordinates in 14-pixel units times S)"""
    n = CELL * S
    m = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(m)
    u = S

    def r(x0, y0, x1, y1, rad=0.6):
        d.rounded_rectangle([x0 * u, y0 * u, x1 * u - 1, y1 * u - 1], radius=rad * u, fill=255)

    if index == 0:      # minus
        r(3.5, 6, 10.5, 8.2)
    elif index == 1:    # plus
        r(3.5, 6, 10.5, 8.2)
        r(5.9, 3.5, 8.1, 10.5)
    elif index == 2:    # close: two bars crossed
        w = 1.25 * u
        for a, b in (((4, 4), (10, 10)), ((10, 4), (4, 10))):
            d.line([(a[0] * u, a[1] * u), (b[0] * u, b[1] * u)], fill=255, width=int(2 * w))
            for p in (a, b):
                d.ellipse([p[0] * u - w, p[1] * u - w, p[0] * u + w, p[1] * u + w], fill=255)
    elif index == 3:    # up: an arrow head on a stem
        d.polygon([(7 * u, 3 * u), (11 * u, 7.4 * u), (8.3 * u, 7.4 * u), (8.3 * u, 10.6 * u), (5.7 * u, 10.6 * u),
                   (5.7 * u, 7.4 * u), (3 * u, 7.4 * u)], fill=255)
    elif index == 4:    # down
        d.polygon([(7 * u, 11 * u), (11 * u, 6.6 * u), (8.3 * u, 6.6 * u), (8.3 * u, 3.4 * u), (5.7 * u, 3.4 * u),
                   (5.7 * u, 6.6 * u), (3 * u, 6.6 * u)], fill=255)
    elif index == 5:    # dot
        r(4.6, 4.6, 9.4, 9.4, 1.2)
    elif index in (6, 7):  # padlock, shut or open
        r(3.6, 6.6, 10.4, 11, 0.8)
        shackle = Image.new('L', (n, n), 0)
        ds = ImageDraw.Draw(shackle)
        ds.rounded_rectangle([4.9 * u, 2.6 * u, 9.1 * u, 8 * u], radius=2.2 * u, outline=255, width=int(1.2 * u))
        if index == 7:  # open: the right leg lifted away
            ds.rectangle([7.9 * u, 4.6 * u, 9.6 * u, 8 * u], fill=0)
        ds.rectangle([0, 6.8 * u, n, n], fill=0)
        m.paste(255, (0, 0), shackle)
        d.rectangle([6.6 * u, 8 * u, 7.4 * u, 9.6 * u], fill=0)   # the key hole
    return m


def symbol(index, state):
    n = CELL * S
    m = shape(index)
    top, bottom = {'normal': ((246, 222, 150), (176, 128, 44)), 'hover': ((255, 246, 196), (222, 170, 70)),
                   'pressed': ((170, 140, 80), (110, 80, 30))}[state]
    gold = vertical((n, n), top, bottom).convert('RGBA')
    outline = m.filter(ImageFilter.MaxFilter(2 * S - 1 if S % 2 else 2 * S + 1))
    layer = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    layer.paste(Image.new('RGBA', (n, n), (16, 10, 4, 235)), (0, 0), outline)
    layer.paste(gold, (0, 0), m)
    # a thin light edge along the top of the symbol
    edge = Image.eval(m.filter(ImageFilter.MinFilter(3)), lambda v: v)
    shine = Image.new('RGBA', (n, n), (255, 255, 230, 0))
    shifted = Image.new('L', (n, n), 0)
    shifted.paste(m, (0, S // 2))
    hi = Image.eval(Image.composite(m, Image.new('L', (n, n), 0), Image.eval(shifted, lambda v: 255 - v)), lambda v: v * 0.55)
    shine.putalpha(hi)
    layer = Image.alpha_composite(layer, shine)
    if state == 'pressed':
        moved = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        moved.paste(layer, (0, S))
        layer = moved
    return layer


def main():
    sheet = Image.new('RGBA', (CELL * 8, CELL * 3), (0, 0, 0, 0))
    for row, state in enumerate(('normal', 'hover', 'pressed')):
        for column in range(8):
            big = Image.alpha_composite(plate(state), symbol(column, state))
            if state == 'hover':
                glow = Image.new('RGBA', big.size, (255, 220, 120, 0))
                big = Image.alpha_composite(big, glow)
            small = big.resize((CELL, CELL), Image.LANCZOS)
            sheet.paste(small, (column * CELL, row * CELL))
    sheet.save(OUT)
    print('wrote', OUT, sheet.size)


if __name__ == '__main__':
    main()
