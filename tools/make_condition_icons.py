"""The icons of the 20 conditions (2026-11-16) and the blind vignette of modules/game_conditions.

The icons in use (v2, owner 2026-11-16: "têm que se adaptar melhor ao estilo do nosso client") are ChatGPT pixel-art icons in
the spell icons' style, cut by C:\\OTS\\Tools\\sprites\\condition-icons-v2-2026-11-16\\tools\\cut_conditions.py: frame by group
(steel + violet = control, blackened iron + blood red = debuff, bronze + gold = buff). This script installs them:

  python tools/make_condition_icons.py           the v2 icons into the module and the map editor, and the blind vignette
  python tools/make_condition_icons.py --drawn   the first, drawn pictograms below instead (flat rounded squares, replaced)

The first version, kept for --drawn:

Each icon is a pictogram on a rounded square whose colour says the group: violet = control (stun, frozen, root, silence, disarm,
sleep, fear, taunt), red = debuff (vulnerable, weakened, mortalwound, manaburn, armorbreak, blind, marked), green = buff (shield,
reflect, lifesteal, fortified, unstoppable). Every glyph has its own colour and a dark edge so it reads at 16 px.

Drawn at 256 x 256 in a 32-unit grid (1 unit = one pixel of the 32 px icon) and scaled down:

  C:\\OTS\\Tools\\sprites\\condition-icons-2026-11-16\\<key>.png     32 x 32
  C:\\OTS\\Tools\\sprites\\condition-icons-2026-11-16\\<key>_16.png  16 x 16 (glyph a little bigger, thinner frame)
  C:\\OTS\\Tools\\sprites\\condition-icons-2026-11-16\\preview.png   contact sheet
  C:\\OTS\\Tools\\RME-ZONES\\data\\condition_icons\\<key>.png        32 x 32, the map editor's Spell Creator
  modules/game_conditions/icons/<key>.png, <key>_16.png              the client (the 16 px ones for the Guides)
  modules/game_conditions/images/blind_vignette.png                  the dark edges of the map while blind

  python tools/make_condition_icons.py      running it again gives the same files
"""
import math
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = r'C:\OTS\Tools\sprites\condition-icons-2026-11-16'
EDITOR = r'C:\OTS\Tools\RME-ZONES\data\condition_icons'
MODULE = os.path.join(ROOT, 'modules', 'game_conditions')
V2 = r'C:\OTS\Tools\sprites\condition-icons-v2-2026-11-16'

S = 256
U = S / 32.0
INK = (16, 10, 8, 255)

# key, group, pt, en (the spec: side-session-notes conditions-spec.md)
CONDITIONS = [
    ('stun', 'control', 'Atordoado', 'Stunned'),
    ('frozen', 'control', 'Congelado', 'Frozen'),
    ('root', 'control', 'Enraizado', 'Rooted'),
    ('silence', 'control', 'Silenciado', 'Silenced'),
    ('disarm', 'control', 'Desarmado', 'Disarmed'),
    ('sleep', 'control', 'Adormecido', 'Asleep'),
    ('fear', 'control', 'Medo', 'Feared'),
    ('taunt', 'control', 'Provocado', 'Taunted'),
    ('vulnerable', 'debuff', 'Exposto', 'Vulnerable'),
    ('weakened', 'debuff', 'Enfraquecido', 'Weakened'),
    ('mortalwound', 'debuff', 'Ferida grave', 'Mortal Wound'),
    ('manaburn', 'debuff', 'Queima de mana', 'Mana Burn'),
    ('armorbreak', 'debuff', 'Armadura partida', 'Armor Break'),
    ('blind', 'debuff', 'Cego', 'Blind'),
    ('marked', 'debuff', 'Marcado', 'Marked'),
    ('shield', 'buff', 'Barreira', 'Barrier'),
    ('reflect', 'buff', 'Espinhos', 'Thorns'),
    ('lifesteal', 'buff', 'Roubo de vida', 'Lifesteal'),
    ('fortified', 'buff', 'Fortalecido', 'Fortified'),
    ('unstoppable', 'buff', 'Impar\u00e1vel', 'Unstoppable'),
]

# the rounded square: gradient top, bottom and the light rim of each group
GROUPS = {
    'control': ((112, 76, 178), (40, 24, 84), (190, 156, 246)),
    'debuff': ((158, 46, 40), (62, 14, 12), (244, 128, 104)),
    'buff': ((42, 134, 78), (12, 54, 30), (134, 230, 154)),
}


# --- drawing in units --------------------------------------------------------------------------------------------------

def P(x, y):
    return (x * U, y * U)


def pts(seq):
    return [P(x, y) for x, y in seq]


def box(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    return [(cx - rx) * U, (cy - ry) * U, (cx + rx) * U, (cy + ry) * U]


def line(d, points, w, fill):
    p = pts(points)
    d.line(p, fill=fill, width=max(1, int(round(w * U))), joint='curve')
    r = w * U / 2
    for x, y in (p[0], p[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def bezier(p0, p1, p2, p3=None, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        else:
            x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0]
            y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1]
        out.append((x, y))
    return out


def star(cx, cy, ro, ri, n=5, rot=-90):
    out = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = ro if i % 2 == 0 else ri
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def mask():
    return Image.new('L', (S, S), 0)


def gradient(top, bottom, y0, y1):
    g = Image.new('RGBA', (S, S))
    px = g.load()
    for y in range(S):
        k = min(1, max(0, (y / U - y0) / max(0.01, y1 - y0)))
        c = tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)) + (255,)
        for x in range(S):
            px[x, y] = c
    return g


def paint(layer, m, top, bottom=None, y0=0, y1=32):
    """fills the white of mask m on layer, flat or with a vertical gradient between y0 and y1 (units)"""
    if bottom is None:
        fill = Image.new('RGBA', (S, S), tuple(top[:3]) + (255,))
    else:
        fill = gradient(top, bottom, y0, y1)
    fill.putalpha(Image.composite(m, Image.new('L', (S, S), 0), m))
    layer.alpha_composite(fill)


def shape(draw_fn):
    m = mask()
    draw_fn(ImageDraw.Draw(m))
    return m


def heater(x0, y0, x1, y1, bend=0.55):
    """a heater shield: straight top, sides down to `bend` of the height, then curves to the point"""
    mid = (x0 + x1) / 2
    yb = y0 + (y1 - y0) * bend
    right = bezier((x1, yb), (x1, yb + (y1 - yb) * 0.55), (mid + (x1 - mid) * 0.35, y1 - (y1 - yb) * 0.1), (mid, y1), 24)
    left = bezier((mid, y1), (mid - (mid - x0) * 0.35, y1 - (y1 - yb) * 0.1), (x0, yb + (y1 - yb) * 0.55), (x0, yb), 24)
    return [(x0, y0), (x1, y0)] + right + left


def heart(cx, cy, r):
    """a heart whose top lobes have radius r; returns a mask"""
    def draw(d):
        d.ellipse(box(cx - r * 0.72, cy, r), fill=255)
        d.ellipse(box(cx + r * 0.72, cy, r), fill=255)
        d.polygon(pts([(cx - r * 1.62, cy + r * 0.35), (cx + r * 1.62, cy + r * 0.35), (cx, cy + r * 2.45)]), fill=255)
        d.rectangle([P(cx - r * 0.72, cy)[0], P(0, cy)[1], P(cx + r * 0.72, 0)[0], P(0, cy + r * 0.6)[1]], fill=255)
    return shape(draw)


def arrow_down(d, x, y0, y1, w, head, fill):
    line(d, [(x, y0), (x, y1 - head * 0.6)], w, fill)
    d.polygon(pts([(x - head, y1 - head), (x + head, y1 - head), (x, y1)]), fill=fill)


# --- the 20 glyphs --------------------------------------------------------------------------------------------------------

def g_stun(L, d):
    # a dizzy swirl and stars around it
    gold, light = (255, 210, 60), (255, 246, 190)
    turns, r_max, cx, cy = 1.8, 9.8, 14.6, 17.4
    spiral = []
    for i in range(160):
        t = i / 159
        a = math.radians(-90 + 360 * turns * t)
        r = 1.0 + (r_max - 1.0) * t
        spiral.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    sm = mask()
    line(ImageDraw.Draw(sm), spiral, 2.9, 255)
    paint(L, sm, light, gold, 8, 28)
    for sx, sy, r in ((25.4, 7.4, 4.6), (7.2, 6.2, 3.0), (27.0, 20.4, 2.6)):
        st = shape(lambda m, sx=sx, sy=sy, r=r: m.polygon(pts(star(sx, sy, r, r * 0.45)), fill=255))
        paint(L, st, light, gold, sy - r, sy + r)


def g_frozen(L, d):
    ice, deep = (232, 248, 255, 255), (130, 210, 255, 255)
    for k in range(6):
        a = math.radians(90 + k * 60)
        ex, ey = 16 + 12.6 * math.cos(a), 16 + 12.6 * math.sin(a)
        line(d, [(16, 16), (ex, ey)], 2.5, ice)
        bx, by = 16 + 7.4 * math.cos(a), 16 + 7.4 * math.sin(a)
        for side in (-1, 1):
            b = a + side * math.radians(48)
            line(d, [(bx, by), (bx + 4.2 * math.cos(b), by + 4.2 * math.sin(b))], 1.9, ice)
    hexagon = [(16 + 3.6 * math.cos(math.radians(30 + 60 * k)), 16 + 3.6 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
    d.polygon(pts(hexagon), fill=deep)


def g_root(L, d):
    bark, light = (122, 76, 36), (198, 140, 78)
    m = shape(lambda m: (
        m.polygon(pts([(13, 6.5), (19, 6.5), (20, 17), (12, 17)]), fill=255),
    ))
    # roots fanning out from the stump
    roots = [
        bezier((14, 15), (10, 18), (5, 19), (3.8, 26.5)),
        bezier((15, 16), (12.5, 21), (9.5, 24), (9.5, 29)),
        bezier((16, 16), (16, 21), (15.5, 25), (16.5, 29.5)),
        bezier((17, 16), (19.5, 21), (22.5, 24), (22.5, 29)),
        bezier((18, 15), (22, 18), (27, 19), (28.2, 26.5)),
    ]
    rm = mask()
    rd = ImageDraw.Draw(rm)
    for i, r in enumerate(roots):
        w = 2.6 if i in (0, 4) else 2.9
        line(rd, r, w, 255)
    rm = Image.composite(Image.new('L', (S, S), 255), rm, m)
    paint(L, rm, light, bark, 6, 29)
    # rings of the stump and its leaves
    line(d, [(13.6, 9.5), (18.4, 9.5)], 0.8, (92, 56, 26, 255))
    line(d, [(13.2, 12.5), (18.8, 12.5)], 0.8, (92, 56, 26, 255))
    green, dark = (120, 230, 80), (40, 140, 40)
    for cx, cy, a in ((11, 4.6, -35), (21, 4.6, 35)):
        leaf = Image.new('L', (S, S), 0)
        ImageDraw.Draw(leaf).ellipse(box(16, 16, 4.2, 2.1), fill=255)
        leaf = leaf.rotate(-a, resample=Image.BICUBIC, center=(16 * U, 16 * U))
        leaf = leaf.transform((S, S), Image.AFFINE, (1, 0, (16 - cx) * U, 0, 1, (16 - cy) * U), resample=Image.BICUBIC)
        paint(L, leaf, green, dark, cy - 2, cy + 2)
    line(d, [(16, 6.5), (16, 3.5)], 1.2, (70, 160, 50, 255))


def g_silence(L, d):
    m = shape(lambda m: (
        m.ellipse(box(16, 13.5, 11.6, 8.6), fill=255),
        m.polygon(pts([(8.5, 18.5), (14, 20.8), (5.5, 27.5)]), fill=255),
    ))
    paint(L, m, (255, 255, 252), (206, 206, 214), 5, 27)
    for x in (10.5, 16, 21.5):
        d.ellipse(box(x, 13.5, 1.7), fill=(86, 86, 100, 255))
    line(d, [(4.8, 27.6), (27.2, 4.8)], 3.6, INK)
    line(d, [(4.8, 27.6), (27.2, 4.8)], 2.6, (255, 58, 58, 255))


def g_disarm(L, d):
    # a sword broken in two: the hilt with half a blade, and the point flying off, turned, with a gap between
    steel, shade = (236, 242, 248), (150, 164, 180)

    def blade(x0, y0, angle, length, tip):
        a = math.radians(angle)
        ux, uy = math.cos(a), math.sin(a)
        nx, ny = -uy * 2.0, ux * 2.0
        x1, y1 = x0 + ux * length, y0 + uy * length
        if tip:
            end = [(x1 + nx * 0.9, y1 + ny * 0.9), (x1 + ux * 3.0, y1 + uy * 3.0), (x1 - nx * 0.9, y1 - ny * 0.9)]
            start = [(x0 - nx, y0 - ny), (x0 + ux * 0.9 + nx * 0.1, y0 + uy * 0.9 + ny * 0.1), (x0 + nx, y0 + ny)]
            return start + end
        return [(x0 - nx, y0 - ny), (x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 + ux * 0.6 - nx * 0.2, y1 + uy * 0.6 - ny * 0.2),
                (x1 - ux * 0.4 - nx * 0.6, y1 - uy * 0.4 - ny * 0.6), (x1 - nx, y1 - ny)]

    lower = shape(lambda m: m.polygon(pts(blade(9.4, 22.6, -45, 6.4, False)), fill=255))
    paint(L, lower, steel, shade, 15, 23)
    upper = shape(lambda m: m.polygon(pts(blade(19.6, 12.6, -24, 7.4, True)), fill=255))
    paint(L, upper, steel, shade, 5, 14)
    line(d, [(5.6, 26.4), (8.6, 23.4)], 2.8, (126, 80, 40, 255))
    line(d, [(6.2, 19.8), (12.2, 25.8)], 2.4, (236, 190, 76, 255))
    d.ellipse(box(4.8, 27.2, 1.8), fill=(236, 190, 76, 255))
    # the break: a hot spark and two chips
    d.polygon(pts(star(17.0, 15.4, 3.8, 1.2, n=4, rot=-20)), fill=(255, 150, 40, 255))
    d.polygon(pts(star(17.0, 15.4, 2.0, 0.7, n=4, rot=-20)), fill=(255, 244, 180, 255))
    d.polygon(pts([(20.6, 18.0), (22.4, 17.4), (21.6, 19.4)]), fill=steel + (255,))
    d.polygon(pts([(13.0, 11.6), (14.6, 10.8), (14.4, 12.6)]), fill=steel + (255,))


def g_sleep(L, d):
    moon = mask()
    md = ImageDraw.Draw(moon)
    md.ellipse(box(12.6, 18.8, 9.4), fill=255)
    md.ellipse(box(17.4, 14.0, 8.2), fill=0)
    paint(L, moon, (255, 244, 186), (226, 196, 96), 10, 28)
    blue = (172, 218, 255, 255)
    line(d, [(17.8, 9.4), (25.4, 9.4), (17.8, 16.6), (25.4, 16.6)], 2.3, blue)
    line(d, [(23.0, 3.4), (27.6, 3.4), (23.0, 7.6), (27.6, 7.6)], 1.7, blue)


def g_fear(L, d):
    m = shape(lambda m: (
        m.ellipse(box(16, 12.6, 9.6), fill=255),
        m.rectangle([P(6.4, 12.6)[0], P(0, 12.6)[1], P(25.6, 0)[0], P(0, 25)[1]], fill=255),
        [m.ellipse(box(x, 25, 3.2), fill=255) for x in (9.6, 16, 22.4)],
    ))
    paint(L, m, (246, 242, 255), (184, 170, 236), 4, 28)
    for x in (12.2, 19.8):
        d.ellipse(box(x, 11.6, 2.2, 3.2), fill=(20, 14, 30, 255))
        d.ellipse(box(x - 0.6, 10.4, 0.7), fill=(255, 255, 255, 255))
    d.ellipse(box(16, 19.4, 2.4, 3.1), fill=(20, 14, 30, 255))


def g_taunt(L, d):
    m = shape(lambda m: m.polygon(pts(star(16, 16, 14, 9.4, n=10, rot=-90)), fill=255))
    paint(L, m, (255, 168, 60), (214, 36, 24), 3, 29)
    d.polygon(pts([(14.1, 7.2), (17.9, 7.2), (17.0, 18.8), (15.0, 18.8)]), fill=INK)
    d.polygon(pts([(14.6, 7.8), (17.4, 7.8), (16.6, 18.2), (15.4, 18.2)]), fill=(255, 246, 200, 255))
    d.ellipse(box(16, 22.8, 2.6), fill=INK)
    d.ellipse(box(16, 22.8, 2.0), fill=(255, 246, 200, 255))


def g_vulnerable(L, d):
    m = shape(lambda m: m.polygon(pts(heater(4.5, 5.0, 21.5, 28.0)), fill=255))
    paint(L, m, (214, 224, 236), (112, 126, 146), 5, 28)
    line(d, [(13, 5.2), (11.4, 9.8), (14.6, 13.2), (11.6, 17.6), (14.2, 21.4), (12.8, 24.6)], 1.5, (34, 26, 28, 255))
    red = (255, 72, 72, 255)
    arrow_down(d, 25.8, 11.5, 28.8, 1.6 * 2, 4.2, INK)
    arrow_down(d, 25.8, 12.0, 28.0, 1.1 * 2, 3.4, red)


def g_weakened(L, d):
    skin, shade, edge = (246, 198, 150), (206, 140, 92), (110, 64, 34, 255)
    m = shape(lambda m: (
        m.rounded_rectangle(box(12.5, 18.5, 8.4, 6.8), radius=3 * U, fill=255),
        m.rounded_rectangle([P(8.4, 23)[0], P(0, 23)[1], P(17.2, 0)[0], P(0, 29)[1]], radius=1.5 * U, fill=255),
    ))
    paint(L, m, skin, shade, 10, 28)
    for i, x in enumerate((4.4, 8.4, 12.4, 16.4)):
        top = 7.4 if i in (1, 2) else 8.4
        finger = shape(lambda m, x=x, top=top: m.rounded_rectangle([P(x, top)[0], P(0, top)[1], P(x + 4.2, 0)[0], P(0, 16.4)[1]],
                                                                     radius=2 * U, fill=255))
        e = finger.filter(ImageFilter.MaxFilter(9))
        paint(L, e, edge)
        paint(L, finger, (255, 214, 172), skin, top, 16)
    thumb = shape(lambda m: m.rounded_rectangle([P(5.4, 15.4)[0], P(0, 15.4)[1], P(15.6, 0)[0], P(0, 19.6)[1]], radius=2 * U, fill=255))
    paint(L, thumb.filter(ImageFilter.MaxFilter(9)), edge)
    paint(L, thumb, (255, 214, 172), skin, 15, 20)
    violet = (206, 128, 255, 255)
    arrow_down(d, 26.0, 9.0, 27.6, 1.6 * 2, 4.2, INK)
    arrow_down(d, 26.0, 9.5, 26.8, 1.1 * 2, 3.4, violet)


def g_mortalwound(L, d):
    m = heart(16, 12.0, 6.6)
    paint(L, m, (255, 92, 104), (168, 10, 32), 5, 28)
    d.ellipse(box(11.0, 10.6, 2.0, 1.4), fill=(255, 190, 196, 255))
    line(d, [(7.6, 24.6), (24.8, 6.4)], 3.4, INK)
    line(d, [(8.2, 24.0), (24.2, 7.0)], 1.2, (90, 0, 12, 255))


def flame(cx, base_y, r, tip_y, lick=0.0):
    """a teardrop flame: a circle at the bottom and a curved tip"""
    def draw(m):
        m.ellipse(box(cx, base_y, r), fill=255)
        right = bezier((cx + r, base_y), (cx + r, base_y - r * 1.4), (cx + r * 0.35 + lick, tip_y + (base_y - tip_y) * 0.35), (cx + lick, tip_y))
        left = bezier((cx + lick, tip_y), (cx - r * 0.6 + lick, tip_y + (base_y - tip_y) * 0.45), (cx - r, base_y - r * 1.2), (cx - r, base_y))
        m.polygon(pts([(cx, base_y)] + right + left), fill=255)
    return shape(draw)


def g_manaburn(L, d):
    outer = flame(16, 20.6, 8.0, 2.6, lick=1.2)
    for cx, base, r, tip, lk in ((9.4, 17.4, 3.0, 8.0, -1.4), (22.8, 17.0, 3.0, 7.6, 1.6)):
        side = flame(cx, base, r, tip, lick=lk)
        outer = Image.composite(Image.new('L', (S, S), 255), outer, side)
    paint(L, outer, (90, 160, 255), (24, 60, 210), 3, 28)
    inner = flame(16, 22.2, 4.8, 9.6, lick=0.6)
    paint(L, inner, (200, 240, 255), (110, 196, 255), 9, 27)
    d.ellipse(box(16, 23.6, 2.3), fill=(255, 255, 255, 255))


def g_armorbreak(L, d):
    plate = [(5.6, 6.2), (12.2, 6.2), (16, 9.4), (19.8, 6.2), (26.4, 6.2), (27.2, 12.4), (24.0, 15.0), (23.6, 25.6), (16, 28.4),
             (8.4, 25.6), (8.0, 15.0), (4.8, 12.4)]
    crack = [(16, 9.4), (14.4, 13.2), (17.6, 16.6), (15.0, 20.2), (17.2, 24.0), (16, 28.4)]
    whole = shape(lambda m: m.polygon(pts(plate), fill=255))
    left_side = shape(lambda m: m.polygon(pts([(0, 0), (16, 0)] + crack + [(16, 32), (0, 32)]), fill=255))
    from PIL import ImageChops
    left = ImageChops.multiply(whole, left_side)
    right = ImageChops.subtract(whole, left_side)
    left = left.transform((S, S), Image.AFFINE, (1, 0, 0.7 * U, 0, 1, 0), resample=Image.BICUBIC)
    right = right.transform((S, S), Image.AFFINE, (1, 0, -1.0 * U, 0, 1, -0.8 * U), resample=Image.BICUBIC)
    right = right.rotate(-6, resample=Image.BICUBIC, center=(18 * U, 18 * U))
    for part in (left, right):
        paint(L, part.filter(ImageFilter.MaxFilter(9)), (60, 66, 76))
        paint(L, part, (228, 234, 242), (112, 122, 138), 6, 28)
    # the ridges of the breastplate
    line(d, [(10.2, 15.6), (10.6, 23.6)], 0.8, (150, 160, 176, 255))
    line(d, [(23.6, 16.6), (23.4, 24.0)], 0.8, (150, 160, 176, 255))
    d.polygon(pts([(14.0, 27.8), (15.0, 30.0), (13.0, 29.4)]), fill=(200, 208, 220, 255))
    d.polygon(pts([(19.4, 9.6), (20.8, 8.0), (21.2, 10.4)]), fill=(200, 208, 220, 255))


def g_blind(L, d):
    upper = bezier((3.6, 16), (10, 5.0), (22, 5.0), (28.4, 16))
    lower = bezier((28.4, 16), (22, 27.0), (10, 27.0), (3.6, 16))
    m = shape(lambda m: m.polygon(pts(upper + lower), fill=255))
    paint(L, m, (250, 250, 246), (204, 206, 214), 6, 26)
    d.ellipse(box(16, 16, 5.6), fill=(46, 140, 186, 255))
    d.ellipse(box(16, 16, 2.6), fill=(10, 10, 14, 255))
    d.ellipse(box(14.4, 14.2, 1.1), fill=(255, 255, 255, 255))
    line(d, [(4.8, 27.6), (27.2, 4.8)], 3.6, INK)
    line(d, [(4.8, 27.6), (27.2, 4.8)], 2.6, (255, 58, 58, 255))


def g_marked(L, d):
    red = (255, 76, 60, 255)
    d.ellipse(box(16, 16, 10.0), outline=red, width=int(2.6 * U))
    for a, b in (((16, 2.6), (16, 10.4)), ((16, 21.6), (16, 29.4)), ((2.6, 16), (10.4, 16)), ((21.6, 16), (29.4, 16))):
        line(d, [a, b], 2.4, red)
    d.ellipse(box(16, 16, 2.0), fill=(255, 220, 200, 255))


def g_shield(L, d):
    glow = Image.new('RGBA', (S, S))
    gd = ImageDraw.Draw(glow)
    for i in range(12, 0, -1):
        r = 12.4 * i / 12
        a = int(20 + 120 * (i / 12) ** 3)
        gd.ellipse(box(16, 16, r), fill=(120, 226, 255, a))
    L.alpha_composite(glow)
    d.ellipse(box(16, 16, 12.4), outline=(186, 244, 255, 255), width=int(1.6 * U))
    small = shape(lambda m: m.polygon(pts(heater(11.6, 10.4, 20.4, 22.6)), fill=255))
    paint(L, small.filter(ImageFilter.MaxFilter(9)), (40, 70, 90))
    paint(L, small, (255, 232, 140), (214, 150, 40), 10, 23)
    d.arc(box(16, 16, 9.4), 200, 255, fill=(255, 255, 255, 235), width=int(1.7 * U))
    d.ellipse(box(9.4, 10.6, 1.2), fill=(255, 255, 255, 255))


def g_reflect(L, d):
    # a spiked shield, and an arrow that comes from the right, turns on the shield and goes back
    gold = shape(lambda m: (
        m.polygon(pts(heater(3.6, 5.0, 15.6, 27.4)), fill=255),
        [m.polygon(pts([(15.0, y - 1.6), (18.4, y), (15.0, y + 1.6)]), fill=255) for y in (8.6, 14.0)],
    ))
    paint(L, gold, (255, 232, 140), (190, 128, 30), 5, 27)
    line(d, [(9.6, 7.6), (9.6, 23.6)], 1.0, (160, 104, 24, 255))
    white, orange = (240, 240, 244, 255), (255, 176, 56, 255)
    d.arc(box(22.4, 16.8, 5.4, 5.4), 90, 270, fill=white, width=int(2.2 * U))
    line(d, [(22.4, 11.4), (28.6, 11.4)], 2.2, white)
    line(d, [(22.4, 22.2), (25.4, 22.2)], 2.2, white)
    d.polygon(pts([(24.2, 18.6), (29.8, 22.2), (24.2, 25.8)]), fill=orange)
    d.polygon(pts(star(17.4, 16.8, 2.8, 0.9, n=4, rot=0)), fill=(255, 250, 210, 255))


def g_lifesteal(L, d):
    m = heart(16, 18.6, 5.0)
    paint(L, m, (255, 120, 140), (186, 18, 52), 14, 30)
    d.ellipse(box(12.2, 17.6, 1.6, 1.1), fill=(255, 200, 210, 255))
    drop = shape(lambda m: (
        m.ellipse(box(16, 9.4, 3.7), fill=255),
        m.polygon(pts([(12.6, 8.2), (19.4, 8.2), (16, 2.0)]), fill=255),
    ))
    paint(L, drop.filter(ImageFilter.MaxFilter(9)), (20, 4, 6))
    paint(L, drop, (255, 70, 70), (196, 0, 24), 2, 13)
    d.ellipse(box(14.8, 9.0, 0.9, 1.3), fill=(255, 190, 190, 255))


def g_fortified(L, d):
    outer = shape(lambda m: m.polygon(pts(heater(5.4, 4.0, 26.6, 29.0)), fill=255))
    paint(L, outer, (255, 226, 130), (186, 130, 36), 4, 29)
    inner = shape(lambda m: m.polygon(pts(heater(7.4, 6.0, 24.6, 26.0)), fill=255))
    paint(L, inner, (128, 150, 186), (52, 66, 96), 6, 26)
    line(d, [(16, 9.6), (16, 21.6)], 4.8, INK)
    line(d, [(10.0, 15.6), (22.0, 15.6)], 4.8, INK)
    line(d, [(16, 10.4), (16, 20.8)], 3.2, (120, 255, 132, 255))
    line(d, [(10.8, 15.6), (21.2, 15.6)], 3.2, (120, 255, 132, 255))


def g_unstoppable(L, d):
    for y, x0, x1 in ((20.6, 2.8, 8.6), (24.6, 4.4, 9.4), (16.6, 3.6, 8.0)):
        line(d, [(x0, y), (x1, y)], 1.5, (255, 220, 150, 255))
    bolt = [(19.8, 2.4), (8.8, 17.4), (15.2, 17.4), (11.8, 29.6), (25.2, 12.6), (18.2, 12.6), (22.6, 2.4)]
    m = shape(lambda m: m.polygon(pts(bolt), fill=255))
    paint(L, m, (255, 248, 170), (255, 132, 20), 3, 29)
    line(d, [(19.6, 4.6), (12.4, 15.6)], 0.9, (255, 255, 236, 255))


GLYPHS = {k: globals()['g_' + k] for k, *_ in CONDITIONS}


# --- the icon ------------------------------------------------------------------------------------------------------------

def background(group, small):
    top, bottom, rim = GROUPS[group]
    img = Image.new('RGBA', (S, S))
    edge = 0.3 if small else 0.5
    m = shape(lambda m: m.rounded_rectangle(box(16, 16, 16 - edge), radius=6 * U, fill=255))
    paint(img, m, (14, 10, 8))
    inset = edge + (1.6 if small else 1.3)
    m = shape(lambda m: m.rounded_rectangle(box(16, 16, 16 - inset), radius=5.2 * U, fill=255))
    paint(img, m, rim, tuple(int(c * 0.62) for c in rim), 0, 32)
    inset += 1.4 if small else 1.3
    m = shape(lambda m: m.rounded_rectangle(box(16, 16, 16 - inset), radius=4.4 * U, fill=255))
    paint(img, m, top, bottom, 2, 30)
    # a soft light at the top and darker corners: the glyph stands out in the middle
    shine = Image.new('RGBA', (S, S))
    ImageDraw.Draw(shine).ellipse(box(16, 5, 13, 7), fill=(255, 255, 255, 34))
    shine.putalpha(Image.composite(shine.getchannel('A'), Image.new('L', (S, S), 0), m))
    img.alpha_composite(shine)
    return img


def glyph(key):
    layer = Image.new('RGBA', (S, S))
    GLYPHS[key](layer, ImageDraw.Draw(layer))
    return layer


def icon(key, group, size):
    small = size <= 16
    img = background(group, small)
    g = glyph(key)
    if small:
        # the glyph fills a little more of a 16 px icon
        k = 1.12
        big = g.resize((int(S * k), int(S * k)), Image.LANCZOS)
        off = (big.width - S) // 2
        g = big.crop((off, off, off + S, off + S))
    alpha = g.getchannel('A').point(lambda a: 255 if a > 24 else 0)
    radius = 13 if small else 7
    edge = alpha.filter(ImageFilter.MaxFilter(radius * 2 + 1))
    shadow = edge.filter(ImageFilter.GaussianBlur(5)).transform((S, S), Image.AFFINE, (1, 0, -0.6 * U, 0, 1, -0.9 * U))
    shade = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    shade.putalpha(shadow.point(lambda a: int(a * 0.55)))
    img.alpha_composite(shade)
    ink = Image.new('RGBA', (S, S), INK)
    ink.putalpha(edge)
    img.alpha_composite(ink)
    img.alpha_composite(g)
    out = img.resize((size, size), Image.LANCZOS)
    if small:
        out = out.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=1))
    return out


# --- the blind vignette ------------------------------------------------------------------------------------------------

def vignette():
    """black, clear around the middle of the map and dark at its edges; stretched over the map (15 x 11), the module sets its
    opacity from the blind's value"""
    w, h = 300, 220
    img = Image.new('RGBA', (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            dy = (y + 0.5 - h / 2) / (h / 2)
            dist = math.sqrt(dx * dx * 0.82 + dy * dy)  # a little wider than high, like the map
            k = min(1.0, max(0.0, (dist - 0.16) / 0.86))
            k = k * k * (3 - 2 * k)
            a = 0.30 + 0.70 * k
            px[x, y] = (6, 4, 10, int(a * 255))
    return img


def sheet(icons):
    font = ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf', 12)
    bold = ImageFont.truetype(r'C:\Windows\Fonts\arialbd.ttf', 13)
    cols, cw, ch = 5, 220, 112
    rows = (len(CONDITIONS) + cols - 1) // cols
    out = Image.new('RGBA', (cols * cw + 20, rows * ch + 56), (46, 44, 42, 255))
    d = ImageDraw.Draw(out)
    d.text((14, 12), 'ForgottenL conditions 2026-11-16: 64 px (32 x2), 32 px, 16 px x2, 16 px   violet control, red debuff, green buff',
           fill=(232, 207, 148), font=bold)
    for i, (key, group, pt, en) in enumerate(CONDITIONS):
        x, y = 10 + (i % cols) * cw, 40 + (i // cols) * ch
        d.rectangle([x, y, x + cw - 10, y + ch - 10], fill=(34, 33, 32, 255), outline=(92, 68, 34, 255))
        i32, i16 = icons[key]
        out.alpha_composite(i32.resize((64, 64), Image.NEAREST), (x + 8, y + 8))
        out.alpha_composite(i32, (x + 80, y + 8))
        out.alpha_composite(i16.resize((32, 32), Image.NEAREST), (x + 120, y + 8))
        out.alpha_composite(i16, (x + 160, y + 8))
        d.text((x + 8, y + 76), key, fill=(244, 214, 140), font=bold)
        d.text((x + 80, y + 46), pt, fill=(223, 223, 223), font=font)
        d.text((x + 80, y + 62), en, fill=(168, 168, 168), font=font)
    return out


def install_v2():
    """the ChatGPT icons: icons32 -> <key>.png, icons16 -> <key>_16.png"""
    keys = [c[0] for c in CONDITIONS]
    for key in keys:
        for size, suffix in ((32, ''), (16, '_16')):
            src = os.path.join(V2, 'icons%d' % size, key + '.png')
            if not os.path.exists(src):
                raise SystemExit('missing ' + src + ' (run cut_conditions.py there first)')
            shutil.copy2(src, os.path.join(MODULE, 'icons', key + suffix + '.png'))
        shutil.copy2(os.path.join(V2, 'icons32', key + '.png'), os.path.join(EDITOR, key + '.png'))
    return len(keys)


def main():
    import sys
    for folder in (SPRITES, EDITOR, os.path.join(MODULE, 'icons'), os.path.join(MODULE, 'images')):
        os.makedirs(folder, exist_ok=True)
    vignette().save(os.path.join(MODULE, 'images', 'blind_vignette.png'))
    if '--drawn' not in sys.argv:
        print('icons (v2)', install_v2(), V2)
        return
    icons = {}
    for key, group, _, _ in CONDITIONS:
        i32 = icon(key, group, 32)
        i16 = icon(key, group, 16)
        icons[key] = (i32, i16)
        i32.save(os.path.join(SPRITES, key + '.png'))
        i16.save(os.path.join(SPRITES, key + '_16.png'))
        shutil.copy2(os.path.join(SPRITES, key + '.png'), os.path.join(EDITOR, key + '.png'))
        shutil.copy2(os.path.join(SPRITES, key + '.png'), os.path.join(MODULE, 'icons', key + '.png'))
        shutil.copy2(os.path.join(SPRITES, key + '_16.png'), os.path.join(MODULE, 'icons', key + '_16.png'))
    sheet(icons).save(os.path.join(SPRITES, 'preview.png'))
    print('icons (drawn)', len(icons), SPRITES)


if __name__ == '__main__':
    main()
