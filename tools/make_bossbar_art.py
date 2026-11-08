"""The artwork of the boss bar (modules/game_bossbar), version 9B of the owner's pick (2026-11-08): made of what the client already
shows, so it sits in the Reborn look.

  data/fonts/bossbar-name.otfont/.png      the boss's name: Almendra Bold (tools/fonts, SIL OFL) in the Store's gold, dark edge, shadow
  data/images/game/bossbar/tag_<kind>.png  the kind on a small plaque cut from the Store's red plaque (data/images/ui/store_plate)
  data/images/game/bossbar/portrait.png    an inventory item slot (Reborn ui/item) with the plaque's thin gold edge
  data/images/game/bossbar/dragon_*.png    the Store's gold dragons, holding the ends of the bar
  data/images/game/bossbar/level.png       the XP Boost plate (Reborn game/topbar/boost) without its words, for the level
  data/images/game/bossbar/track/fill/trail.png   the bar: the topbar's look, red, and the lighter part of the damage just taken (8 x 16, border 2)

  python tools/make_bossbar_art.py      running it again gives the same files
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TTF = os.path.join(ROOT, 'tools', 'fonts', 'Almendra-Bold.ttf')
FONTS = os.path.join(ROOT, 'data', 'fonts')
OUT = os.path.join(ROOT, 'data', 'images', 'game', 'bossbar')
RB = os.path.join(ROOT, 'layouts', 'reborn', 'images')
PLATE = Image.open(os.path.join(ROOT, 'data', 'images', 'ui', 'store_plate.png')).convert('RGBA')

INK = (12, 10, 9)
GOLD = [(255, 236, 170), (240, 200, 110), (206, 150, 60), (150, 100, 36)]
# the kinds of 120-boss-types.lua and the echo bosses: plaque colour, letters
KINDS = {
    'world': ('WORLD BOSS', (150, 18, 16), (255, 226, 140)),
    'event': ('EVENT BOSS', (98, 30, 140), (240, 210, 255)),
    'quest': ('QUEST BOSS', (22, 84, 120), (200, 236, 255)),
    'echo': ('ECHO BOSS', (176, 70, 10), (255, 230, 170)),
    'task': ('TASK BOSS', (34, 104, 40), (210, 255, 200)),
    'hunt': ('HUNT BOSS', (110, 74, 30), (255, 230, 180)),
    'raid': ('RAID BOSS', (120, 20, 60), (255, 200, 220)),
    'dungeon': ('DUNGEON BOSS', (60, 64, 76), (220, 226, 240)),
}


def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


def gradient(stops, k):
    k = max(0.0, min(1.0, k))
    seg = min(len(stops) - 2, int(k * (len(stops) - 1)))
    return lerp(stops[seg], stops[seg + 1], k * (len(stops) - 1) - seg)


def rect(img, box, color):
    ImageDraw.Draw(img).rectangle((box[0], box[1], box[2] - 1, box[3] - 1), outline=color)


def bevel(img, box, light, shade):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    d.line((x0, y0, x1 - 1, y0), fill=light)
    d.line((x0, y0, x0, y1 - 1), fill=light)
    d.line((x0, y1 - 1, x1 - 1, y1 - 1), fill=shade)
    d.line((x1 - 1, y0, x1 - 1, y1 - 1), fill=shade)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + '.png'))


# ------------------------------------------------------------------------------ the name font
CELL, FIRST, SIZE = 24, 32, 17
TOP = 3  # rows above the tallest letter in a cell


def name_font():
    font = ImageFont.truetype(TTF, SIZE)
    ascent, descent = font.getmetrics()
    sheet = Image.new('RGBA', (16 * CELL, 14 * CELL))
    for code in range(FIRST, 256):
        try:
            ch = bytes([code]).decode('cp1252')
        except UnicodeDecodeError:
            continue
        if not ch.strip():
            continue
        mask = Image.new('L', (CELL, CELL))
        ImageDraw.Draw(mask).text((1, TOP), ch, font=font, fill=255)
        if not mask.getbbox():
            continue
        edge = mask.filter(ImageFilter.MaxFilter(3))
        cell = Image.new('RGBA', (CELL, CELL))
        shadow = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        shadow.putalpha(edge.point(lambda v: int(v * 0.8)))
        cell.alpha_composite(shadow, (1, 1))
        dark = Image.new('RGBA', (CELL, CELL), INK + (0,))
        dark.putalpha(edge)
        cell.alpha_composite(dark)
        gold = Image.new('RGBA', (CELL, CELL))
        gd = ImageDraw.Draw(gold)
        for y in range(CELL):
            gd.line((0, y, CELL, y), fill=gradient(GOLD, (y - TOP - 3) / (ascent - 3)) + (255,))
        gold.putalpha(mask)
        cell.alpha_composite(gold)
        i = code - FIRST
        sheet.alpha_composite(cell, ((i % 16) * CELL, (i // 16) * CELL))
    sheet.save(os.path.join(FONTS, 'bossbar-name.png'))
    with open(os.path.join(FONTS, 'bossbar-name.otfont'), 'w', newline='\n') as out:
        out.write('Font\n  name: bossbar-name\n  texture: bossbar-name\n  height: %d\n  glyph-size: %d %d\n'
                  '  spacing: -3 0\n  space-width: 5\n' % (CELL, CELL, CELL))


# ------------------------------------------------------------------------------ the small letters of the tags
class Bitmap:
    """an OTClient font texture: a grid of 16x16 glyphs from char 32, each as wide as its last pixel that is not transparent"""

    def __init__(self, texture, spacing=0, space=3):
        self.img = Image.open(os.path.join(FONTS, texture)).convert('RGBA')
        self.spacing, self.space = spacing, space

    def glyph(self, ch):
        i = ord(ch) - 32
        g = self.img.crop(((i % 16) * 16, (i // 16) * 16, (i % 16) * 16 + 16, (i // 16) * 16 + 16))
        box = g.getchannel('A').getbbox()
        return g, box[2] if box else 0

    def width(self, text):
        return sum(self.space if c == ' ' else self.glyph(c)[1] + self.spacing for c in text) - self.spacing

    def draw(self, img, text, x, y, color):
        for c in text:
            if c == ' ':
                x += self.space
                continue
            g, w = self.glyph(c)
            px = g.load()
            for yy in range(16):
                for xx in range(16):
                    p = px[xx, yy]
                    if p[3]:
                        k = p[0] / 255.0
                        px[xx, yy] = (int(color[0] * k), int(color[1] * k), int(color[2] * k), p[3])
            img.alpha_composite(g, (x, y))
            x += w + self.spacing


SMALL = Bitmap('verdana-11px-monochrome_cp1252.png')


def tags():
    body_src = PLATE.crop((36, 9, 58, 23))
    for kind, (text, color, ink) in KINDS.items():
        w, h = SMALL.width(text) + 14, 16
        img = Image.new('RGBA', (w, h))
        body = body_src.resize((w - 4, h - 4), Image.NEAREST)
        if kind != 'world':
            r, g, b, a = body.split()
            grey = Image.merge('RGBA', (r, r, r, a))
            body = Image.blend(grey, Image.new('RGBA', body.size, color + (255,)), 0.65)
            body.putalpha(a)
        rect(img, (0, 0, w, h), INK + (255,))
        bevel(img, (1, 1, w - 1, h - 1), (250, 214, 120, 255), (120, 80, 26, 255))
        img.alpha_composite(body, (2, 2))
        d = ImageDraw.Draw(img)
        for sx in (3, w - 5):
            d.rectangle((sx, h // 2 - 1, sx + 1, h // 2), fill=(40, 34, 30, 255))
        SMALL.draw(img, text, 7, 0, ink)
        save(img, 'tag_' + kind)


# ------------------------------------------------------------------------------ the rest
def nine(src, w, h, b):
    out = Image.new('RGBA', (w, h))
    sw, sh = src.size
    for sx0, sx1, dx0, dx1 in ((0, b, 0, b), (b, sw - b, b, w - b), (sw - b, sw, w - b, w)):
        for sy0, sy1, dy0, dy1 in ((0, b, 0, b), (b, sh - b, b, h - b), (sh - b, sh, h - b, h)):
            out.alpha_composite(src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def vgrad(img, box, top, bottom, mid=None, alpha=255):
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    n = max(1, y1 - y0 - 1)
    for i, y in enumerate(range(y0, y1)):
        k = i / n
        c = (lerp(top, mid, k * 2) if k < 0.5 else lerp(mid, bottom, (k - 0.5) * 2)) if mid else lerp(top, bottom, k)
        d.line((x0, y, x1 - 1, y), fill=c + (alpha,))


def portrait():
    """44 x 44: the gold edge, the slot (40 x 40 inside the edge), a dark red glow behind the boss"""
    s = 44
    img = Image.new('RGBA', (s, s))
    rect(img, (0, 0, s, s), INK + (255,))
    bevel(img, (1, 1, s - 1, s - 1), (226, 180, 88, 255), (110, 74, 28, 255))
    slot = nine(Image.open(os.path.join(RB, 'ui', 'item.png')).convert('RGBA'), s - 4, s - 4, 3)
    img.alpha_composite(slot, (2, 2))
    vgrad(img, (5, 5, s - 5, s - 5), (70, 22, 18), (22, 10, 10))
    save(img, 'portrait')


def dragons():
    save(PLATE.crop((0, 0, 31, 32)), 'dragon_left')
    save(PLATE.crop((145, 0, 176, 32)), 'dragon_right')


def level_plate():
    """the XP Boost plate with its words wiped: the middle columns repeat a clean column of it"""
    boost = Image.open(os.path.join(RB, 'game', 'topbar', 'boost.png')).convert('RGBA').crop((0, 0, 76, 14))
    clean = boost.crop((3, 0, 4, 14))
    out = Image.new('RGBA', (16, 16))
    plate = Image.new('RGBA', (16, 14))
    plate.alpha_composite(boost.crop((0, 0, 4, 14)), (0, 0))
    for x in range(4, 12):
        plate.alpha_composite(clean, (x, 0))
    plate.alpha_composite(boost.crop((72, 0, 76, 14)), (12, 0))
    out.alpha_composite(plate.resize((16, 16), Image.NEAREST))
    save(out, 'level')


def bar():
    """track 8 x 20 (border 3: the frame of the topbar's bars), fill and trail 4 x 16 stretched across"""
    t = Image.new('RGBA', (8, 20))
    bevel(t, (0, 0, 8, 20), (40, 36, 32, 255), (86, 80, 72, 255))
    rect(t, (1, 1, 7, 19), (8, 7, 6, 255))
    vgrad(t, (2, 2, 6, 18), (16, 12, 11), (26, 20, 18))
    ImageDraw.Draw(t).line((2, 2, 5, 2), fill=(0, 0, 0, 255))
    save(t, 'track')
    # 8 identical columns, stretched with a border of 2: the engine's smoothing then never fades the ends
    f = Image.new('RGBA', (8, 16))
    vgrad(f, (0, 0, 8, 16), (246, 92, 78), (112, 10, 10), mid=(196, 30, 26))
    gl = Image.new('RGBA', (8, 16))
    gd = ImageDraw.Draw(gl)
    for i in range(7):
        gd.line((0, 1 + i, 7, 1 + i), fill=(255, 255, 255, int(70 * (1 - i / 8))))
    f.alpha_composite(gl)
    save(f, 'fill')
    tr = Image.new('RGBA', (8, 16))
    vgrad(tr, (0, 0, 8, 16), (246, 170, 140), (150, 56, 40))
    save(tr, 'trail')


def main():
    name_font()
    tags()
    portrait()
    dragons()
    level_plate()
    bar()
    print('ok', sorted(os.listdir(OUT)))


if __name__ == '__main__':
    main()
