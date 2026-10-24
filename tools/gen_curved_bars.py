import os
from PIL import Image
import math

OUT = 'data/images/game/curved'
os.makedirs(OUT, exist_ok=True)
H, W = 380, 56
R, TH = 560.0, 17.0
SS = 4


def mask(inset):
    """ring segment bulging to the left, returned as an L mask (supersampled)"""
    w, h = W * SS, H * SS
    im = Image.new('L', (w, h), 0)
    px = im.load()
    cx = (3 + R) * SS
    cy = h / 2
    ro, ri = (R - inset) * SS, (R - TH + inset) * SS
    for y in range(h):
        dy = y - cy
        for x in range(w):
            if x > cx:
                continue
            d = math.hypot(x - cx, dy)
            if ri <= d <= ro:
                px[x, y] = 255
    return im.resize((W, H), Image.LANCZOS)


def colorize(m, top, bottom, alpha=255):
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    px = img.load()
    mp = m.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            a = mp[x, y]
            if a:
                # soft highlight on the outer edge of the arc
                px[x, y] = (c[0], c[1], c[2], int(a * alpha / 255))
    return img


outer = mask(0)
border = mask(1.5)
inner = mask(3.0)

# empty frame: dark gold edge + dark translucent body
frame = Image.new('RGBA', (W, H), (0, 0, 0, 0))
edge = colorize(outer, (214, 170, 80), (120, 84, 30))
body = colorize(inner, (18, 12, 10), (10, 6, 6), 205)
frame.alpha_composite(edge)
frame.alpha_composite(colorize(border, (24, 14, 10), (14, 8, 6)))
frame.alpha_composite(body)
frame.save(OUT + '/frame_left.png')
frame.transpose(Image.FLIP_LEFT_RIGHT).save(OUT + '/frame_right.png')

fills = {
    'hp': ((255, 96, 84), (150, 14, 20)),
    'mp': ((96, 150, 255), (22, 40, 170)),
}
for name, (top, bottom) in fills.items():
    f = colorize(inner, top, bottom)
    # glossy stripe on the outer side
    gl = colorize(mask(5.5), (255, 255, 255), (255, 255, 255), 55)
    f.alpha_composite(gl)
    f.save(OUT + '/%s_fill_left.png' % name)
    f.transpose(Image.FLIP_LEFT_RIGHT).save(OUT + '/%s_fill_right.png' % name)
print('ok', W, H)
