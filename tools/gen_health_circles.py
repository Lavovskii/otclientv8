#!/usr/bin/env python3
"""Draws the health and mana arcs around the character (data/images/game/circle/), retro style.

Each side has three layers, drawn in this order by layouts/*/styles/40-healthinfo.otui:
  *_back   the empty track: a dark, see-through groove
  *_fill   the liquid in the track, in grey: the client tints it (health: green to red with the health left, mana: blue)
           and cuts it from the bottom up (healthinfo.lua FILL_TOP / FILL_BOTTOM: the rows of the track, 6 to 206)
  *_frame  the bronze frame, the 10% notches and the medallion in the middle that holds the percentage
The right side is the mirror of the left one. Everything is drawn 4x larger and scaled down (smooth edges).

    python tools/gen_health_circles.py        (from the client repository root; needs Pillow and numpy)
"""
import math
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'images', 'game', 'circle')

W, H = 84, 212                 # image size (healthinfo.lua CIRCLE_W / CIRCLE_H)
CY = H / 2
R_OUT, R_IN = 150.0, 132.0     # the track: a ring 18 px thick, centred to the right of the image
CX = 20 + R_OUT                # leftmost point of the track at x = 20
R_MID = (R_OUT + R_IN) / 2
HALF = math.asin(94 / R_MID)   # the track spans 94 px up and down from the middle (at mid thickness)
RIM = 2.2                      # bronze border width
MED_R, MED_IN = 20.0, 15.5     # medallion: outer radius and the dark inside
MED_X, MED_Y = CX - R_MID, CY  # on the track, in the middle
S = 4                          # supersampling

BRONZE = np.array([156, 116, 54], float)
OUTLINE = np.array([28, 19, 8], float)


def grid():
    ys, xs = np.mgrid[0:H * S, 0:W * S]
    x = (xs + 0.5) / S
    y = (ys + 0.5) / S
    dx, dy = CX - x, CY - y
    return x, y, np.hypot(dx, dy), np.arctan2(dy, dx)


def layer():
    return np.zeros((H * S, W * S, 4), float)


def put(img, mask, rgb, alpha):
    """paints rgb (array or HxWx3) with alpha (scalar or HxW) where mask is set, over what is there"""
    a = np.where(mask, alpha, 0.0)
    rgb = np.broadcast_to(rgb, img[..., :3].shape)
    img[..., :3] = img[..., :3] * (1 - a[..., None]) + rgb * a[..., None]
    img[..., 3] = img[..., 3] * (1 - a) + a


def save(img, name):
    # average premultiplied colour over every S x S block, then back to straight alpha
    pre = img.copy()
    pre[..., :3] *= pre[..., 3:4]
    small = pre.reshape(H, S, W, S, 4).mean(axis=(1, 3))
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 0, small[..., :3] / np.maximum(alpha, 1e-6), 0)
    out = np.concatenate([rgb, alpha * 255], axis=2).clip(0, 255).astype(np.uint8)
    left = Image.fromarray(out, 'RGBA')
    left.save(os.path.join(OUT, 'left_' + name + '.png'))
    left.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(OUT, 'right_' + name + '.png'))


def main():
    x, y, r, th = grid()
    in_angle = np.abs(th) <= HALF
    track = in_angle & (r >= R_IN) & (r <= R_OUT)
    t = np.clip((r - R_IN) / (R_OUT - R_IN), 0, 1)  # 0 inner edge (next to the character), 1 outer edge
    med_d = np.hypot(x - MED_X, y - MED_Y)
    row = np.floor(y).astype(int)

    # back: a dark groove, darker at its edges
    back = layer()
    shade = 0.75 + 0.25 * np.sin(math.pi * t)
    put(back, track, np.stack([16 * shade, 13 * shade, 10 * shade], -1), 0.62)
    save(back, 'back')

    # fill: a lit glass tube in grey (tinted by the client), with a highlight and faint scanlines
    fill = layer()
    lum = 0.52 + 0.40 * np.sin(math.pi * t) ** 0.8 + 0.30 * np.exp(-((t - 0.30) / 0.09) ** 2)
    lum = np.where(row % 2 == 1, lum * 0.90, lum)
    lum = np.clip(lum, 0, 1) * 255
    put(fill, track, np.stack([lum, lum, lum], -1), 0.92)
    save(fill, 'fill')

    # frame: bronze border with a dark outline, lit from the top left
    frame = layer()
    cap = RIM / R_MID
    in_cap_angle = np.abs(th) <= HALF + cap
    ring = in_cap_angle & (r >= R_IN - RIM - 0.9) & (r <= R_OUT + RIM + 0.9)
    border = ring & ~track
    # normal of the border: outward on the outer rim, inward on the inner rim, along the arc on the caps
    nx, ny = -(CX - x) / np.maximum(r, 1e-6), -(CY - y) / np.maximum(r, 1e-6)
    inner = r < R_IN
    nx, ny = np.where(inner, -nx, nx), np.where(inner, -ny, ny)
    light = np.clip(0.80 + 0.45 * (-0.7071 * nx - 0.7071 * ny), 0.45, 1.25)
    edge = (r < R_IN - RIM) | (r > R_OUT + RIM) | (np.abs(th) > HALF + cap - 0.9 / R_MID)
    put(frame, border & ~edge, BRONZE * light[..., None], 1.0)
    put(frame, border & edge, OUTLINE, 1.0)

    # a notch every 10% of the track (dark line across it), the middle one is under the medallion
    span = 2 * HALF
    for k in range(1, 10):
        a = -HALF + span * k / 10
        dist = np.abs((th - a) * r)
        put(frame, track & (dist <= 0.55), np.array([12, 9, 6], float), 0.70)
        put(frame, track & (dist > 0.55) & (dist <= 1.1), np.array([214, 178, 104], float), 0.22)

    # the medallion: dark outline, bronze rim lit from the top left, dark glass inside
    mdx, mdy = (x - MED_X) / np.maximum(med_d, 1e-6), (y - MED_Y) / np.maximum(med_d, 1e-6)
    mlight = np.clip(0.80 + 0.45 * (-0.7071 * mdx - 0.7071 * mdy), 0.45, 1.25)
    put(frame, med_d <= MED_R, OUTLINE, 1.0)
    put(frame, med_d <= MED_R - 1.0, BRONZE * mlight[..., None], 1.0)
    put(frame, (med_d <= MED_IN + 0.8) & (med_d > MED_IN), OUTLINE, 1.0)
    glass = np.clip(1 - med_d / MED_IN, 0, 1)
    glass_rgb = np.stack([12 + 22 * glass, 10 + 18 * glass, 8 + 14 * glass], -1)
    put(frame, med_d <= MED_IN, glass_rgb, 0.93)
    # a soft glint on the top left of the glass
    glint = np.exp(-(((x - (MED_X - 5)) / 4.5) ** 2 + ((y - (MED_Y - 6)) / 2.5) ** 2))
    put(frame, med_d <= MED_IN - 1, np.array([255, 240, 200], float), 0.10 * glint)
    save(frame, 'frame')

    print('wrote', OUT)


if __name__ == '__main__':
    main()
