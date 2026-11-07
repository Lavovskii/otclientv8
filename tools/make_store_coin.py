#!/usr/bin/env python3
"""The Store's currency icons: the red ForgottenL Coin the owner approved on 2026-11-06 (v4, white FL on red, gold rim), as Tibia's
Store shows its Tibia Coin beside every price and the balance (the owner, 2026-11-07).
  data/images/store/coin14.png   beside each price: drawn by hand at 14 px (a scaled 32 px coin loses its letters)
  data/images/store/coins36.png  beside the balance: the approved 32 px coin, centred
    python tools/make_store_coin.py [APPROVED_32PX_PNG]
"""
import math
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SRC = sys.argv[1] if len(sys.argv) > 1 else \
    r'C:\OTS\Tools\sprites\itens-pedidos-2026-11-06\moedas\forgottenl_coin_tibia\forgottenl_coin_v4_vermelho_fl_branco.png'
OUT = os.path.join(ROOT, 'data', 'images', 'store')

LINE = (34, 14, 12, 255)
RIM = [(255, 226, 120, 255), (236, 172, 52, 255), (176, 106, 22, 255)]  # light, mid, dark
FACE = [(222, 58, 62, 255), (186, 30, 42, 255), (128, 16, 28, 255)]
WHITE = [(255, 250, 255, 255), (226, 214, 232, 255)]
F = ['###', '#..', '##.', '#..', '#..']
L = ['#..', '#..', '#..', '#..', '###']


def coin14():
    im = Image.new('RGBA', (14, 14), (0, 0, 0, 0))
    px = im.load()
    c = 6.5
    for y in range(14):
        for x in range(14):
            r = math.hypot(x - c, y - c)
            light = ((c - x) + (c - y)) / 9.0  # from the upper left
            if r > 7.0:
                continue
            if r > 6.0:
                px[x, y] = LINE
            elif r > 4.75:
                px[x, y] = RIM[0] if light > .35 else RIM[1] if light > -.35 else RIM[2]
            else:
                px[x, y] = FACE[0] if light > .45 else FACE[1] if light > -.4 else FACE[2]
    for glyph, x0 in ((F, 3), (L, 8)):
        for j, row in enumerate(glyph):
            for i, ch in enumerate(row):
                if ch == '#':
                    px[x0 + i, 4 + j] = WHITE[0] if j < 3 else WHITE[1]
    return im


def coins36():
    src = Image.open(SRC).convert('RGBA')
    im = Image.new('RGBA', (36, 36), (0, 0, 0, 0))
    im.paste(src, ((36 - src.width) // 2, (36 - src.height) // 2), src)
    return im


if __name__ == '__main__':
    coin14().save(os.path.join(OUT, 'coin14.png'))
    coins36().save(os.path.join(OUT, 'coins36.png'))
    print('wrote', os.path.join(OUT, 'coin14.png'), os.path.join(OUT, 'coins36.png'))
