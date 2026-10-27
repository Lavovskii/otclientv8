#!/usr/bin/env python3
"""Makes the plate of the Store button (data/images/ui/store_plate.png, 176x32) from its large picture.

data/images/ui/store_plate_src.png is the dragon-wing plate made with ChatGPT, cut out of its black background. It is
scaled down to the button's height keeping its shape and centred; the golden "Store" (store_neon.png, Palatino Bold)
is drawn on top of it by the button itself. Run from the client's root after changing the large picture:

    python tools/gen_store_plate.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SRC = os.path.join(ROOT, 'data', 'images', 'ui', 'store_plate_src.png')
OUT = os.path.join(ROOT, 'data', 'images', 'ui', 'store_plate.png')
SIZE = (176, 32)


def main():
    src = np.array(Image.open(SRC).convert('RGBA')).astype(float)
    # scaled with premultiplied alpha, so the transparent background does not darken the edges
    src[..., :3] *= src[..., 3:4] / 255
    width = min(SIZE[0], round(src.shape[1] * SIZE[1] / src.shape[0]))
    small = np.array(Image.fromarray(src.clip(0, 255).astype(np.uint8), 'RGBA').resize((width, SIZE[1]), Image.LANCZOS)).astype(float)
    alpha = small[..., 3:4]
    small[..., :3] = np.where(alpha > 0, small[..., :3] * 255 / np.maximum(alpha, 1), 0)
    plate = Image.new('RGBA', SIZE, (0, 0, 0, 0))
    plate.alpha_composite(Image.fromarray(small.clip(0, 255).astype(np.uint8), 'RGBA'), ((SIZE[0] - width) // 2, 0))
    plate.save(OUT, optimize=True)
    print('wrote', OUT, '(plate %dx%d)' % (width, SIZE[1]))


if __name__ == '__main__':
    main()
