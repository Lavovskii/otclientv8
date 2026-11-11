"""The artwork of the chess minigame (modules/game_chess), 2026-11-11.

  data/images/game/chess/pieces/<set>/<w|b><K|Q|R|B|N|P>.png   the four sets the players choose from (A, the default, the
                                                          owner's pick of 2026-11-11; B, C, D), 48 x 48, from the ChatGPT sheets cut by
                                                          C:/OTS/Tools/propostas/chess/cut_pieces.py (pecas/<set>)
  data/images/game/chess/themes/<theme>/light.png, dark.png   the squares of each board theme, 52 x 52, with a soft grain
  data/images/game/chess/selected.png, last.png, check.png, move.png, capture.png, hover.png   what lies on a square

  python tools/make_chess_art.py      the same files every time
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'data', 'images', 'game', 'chess')
PIECES = 'C:/OTS/Tools/propostas/chess/pecas'
SQUARE, PIECE = 52, 46


def fit(piece, size):
    k = size / max(piece.size)
    return piece.resize((max(1, round(piece.width * k)), max(1, round(piece.height * k))), Image.LANCZOS)


THEMES = {  # light square, dark square (the settings of modules/game_chess list them in this order)
    'classic': ((206, 190, 156), (124, 96, 70)),
    'stone': ((172, 168, 160), (92, 88, 82)),
    'emerald': ((222, 226, 194), (98, 130, 86)),
    'ocean': ((212, 224, 234), (86, 114, 148)),
    'royal': ((228, 212, 182), (112, 74, 112)),
    'night': ((112, 112, 122), (50, 50, 60)),
}


def pieces(chosen):
    out = os.path.join(OUT, 'pieces', chosen)
    os.makedirs(out, exist_ok=True)
    for color in 'wb':
        for kind in 'KQRBNP':
            src = Image.open(os.path.join(PIECES, chosen, color + kind + '.png')).convert('RGBA')
            p = fit(src, PIECE)
            img = Image.new('RGBA', (48, 48))
            # standing on the bottom of the square, a soft shadow under it
            shadow = Image.new('RGBA', (48, 48))
            ImageDraw.Draw(shadow).ellipse((10, 39, 38, 46), fill=(0, 0, 0, 90))
            img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(2)))
            img.alpha_composite(p, ((48 - p.width) // 2, 46 - p.height))
            img.save(os.path.join(out, color + kind + '.png'))


def square(path, base, seed):
    rnd = random.Random(seed)
    img = Image.new('RGBA', (SQUARE, SQUARE), base + (255,))
    px = img.load()
    for y in range(SQUARE):
        for x in range(SQUARE):
            n = rnd.randint(-7, 7)
            r, g, b, a = px[x, y]
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), 255)
    img = img.filter(ImageFilter.SMOOTH)
    d = ImageDraw.Draw(img)
    d.line((0, 0, SQUARE - 1, 0), fill=tuple(min(255, c + 14) for c in base) + (255,))
    d.line((0, SQUARE - 1, SQUARE - 1, SQUARE - 1), fill=tuple(max(0, c - 14) for c in base) + (255,))
    img.save(path)


def overlays():
    s = SQUARE
    sel = Image.new('RGBA', (s, s), (255, 214, 90, 90))
    ImageDraw.Draw(sel).rectangle((0, 0, s - 1, s - 1), outline=(255, 220, 120, 230), width=2)
    sel.save(os.path.join(OUT, 'selected.png'))
    Image.new('RGBA', (s, s), (240, 200, 80, 70)).save(os.path.join(OUT, 'last.png'))
    hover = Image.new('RGBA', (s, s))
    ImageDraw.Draw(hover).rectangle((0, 0, s - 1, s - 1), outline=(255, 255, 255, 140), width=2)
    hover.save(os.path.join(OUT, 'hover.png'))
    # a legal move: a dot; a capture: a ring in the corners
    big = s * 4
    dot = Image.new('RGBA', (big, big))
    ImageDraw.Draw(dot).ellipse((big * 0.36, big * 0.36, big * 0.64, big * 0.64), fill=(20, 16, 10, 120))
    dot.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, 'move.png'))
    ring = Image.new('RGBA', (big, big))
    ImageDraw.Draw(ring).ellipse((big * 0.04, big * 0.04, big * 0.96, big * 0.96), outline=(20, 16, 10, 120), width=int(big * 0.08))
    ring.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, 'capture.png'))
    check = Image.new('RGBA', (big, big))
    for i in range(40, 0, -1):
        a = int(180 * (1 - i / 40))
        r = big * 0.5 * i / 40
        ImageDraw.Draw(check).ellipse((big / 2 - r, big / 2 - r, big / 2 + r, big / 2 + r), fill=(230, 30, 20, a))
    check.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, 'check.png'))


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in ('light.png', 'dark.png'):
        if os.path.exists(os.path.join(OUT, old)):
            os.remove(os.path.join(OUT, old))
    for old in os.listdir(os.path.join(OUT, 'pieces')) if os.path.isdir(os.path.join(OUT, 'pieces')) else []:
        if os.path.isfile(os.path.join(OUT, 'pieces', old)):
            os.remove(os.path.join(OUT, 'pieces', old))
    for chosen in 'ABCD':
        pieces(chosen)
    for i, (theme, (light, dark)) in enumerate(THEMES.items()):
        folder = os.path.join(OUT, 'themes', theme)
        os.makedirs(folder, exist_ok=True)
        square(os.path.join(folder, 'light.png'), light, 1 + i * 2)
        square(os.path.join(folder, 'dark.png'), dark, 2 + i * 2)
    overlays()
    print('ok', sorted(os.listdir(OUT)))


if __name__ == '__main__':
    main()
