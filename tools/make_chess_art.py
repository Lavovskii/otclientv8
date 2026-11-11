"""The artwork of the chess minigame (modules/game_chess), 2026-11-11.

  data/images/game/chess/pieces/<w|b><K|Q|R|B|N|P>.png   the pieces of the chosen set, 48 x 48, from the ChatGPT sheets cut by
                                                          C:/OTS/Tools/propostas/chess/cut_pieces.py (pecas/<set>)
  data/images/game/chess/light.png, dark.png              the squares, 52 x 52: stone of the Reborn colours with a soft grain
  data/images/game/chess/selected.png, last.png, check.png, move.png, capture.png, hover.png   what lies on a square

  python tools/make_chess_art.py [set]      set = A, B, C or D (default B, until the owner picks); the same files every time
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


def pieces(chosen):
    out = os.path.join(OUT, 'pieces')
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


def square(name, base, seed):
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
    img.save(os.path.join(OUT, name + '.png'))


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
    chosen = sys.argv[1] if len(sys.argv) > 1 else 'B'
    os.makedirs(OUT, exist_ok=True)
    pieces(chosen)
    square('light', (206, 190, 156), 1)
    square('dark', (124, 96, 70), 2)
    overlays()
    with open(os.path.join(OUT, 'pieces', 'SET.txt'), 'w') as f:
        f.write(chosen + '\n')
    print('ok', chosen, sorted(os.listdir(OUT)))


if __name__ == '__main__':
    main()
