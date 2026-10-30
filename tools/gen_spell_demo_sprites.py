#!/usr/bin/env python3
"""Draws the client's magic effects and missiles into sprite sheets for the spell demos of the Spells window.

The spell demos (modules/game_spelllist) play effects and missiles on a small grid outside the game map, where the
client cannot draw things itself, so they use these sheets instead. Everything comes from the client's own
data/things/860/Tibia.dat and Tibia.spr (the the860 assets: the 8.60 dat layout with the OTClient extensions, extended
sprite ids, frame durations and frame groups), so the demos show exactly the sprites the game shows.

Writes:
  data/images/game/spelldemo/effects.png   one 64x64 cell per animation phase, one row per effect id in two blocks side
                                            by side (ids 1-35 on the left, 36-70 on the right) so the sheet stays small;
                                            only the first DEMO_EFFECTS effects, the ones the spells use
  data/images/game/spelldemo/missiles.png  one row per missile id (row = id - 1), one 32x32 cell per direction
                                            (NW, N, NE, W, centre, E, SW, S, SE)
  modules/game_spelllist/spelldemosprites.lua  the number of phases of every effect

The sheets are made of CipSoft's sprites, so like Tibia.spr they are not in the public repository (.gitignore): run
this before building the installer, which ships them. Effects bigger than one tile are drawn the way the client draws them: anchored at the bottom right tile, so a cell is
64x64 with the tile the effect belongs to in its bottom right quarter. Run from the client's root after changing the
things files:

    python tools/gen_spell_demo_sprites.py
"""
import os
import struct
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
THINGS = os.path.join(ROOT, 'data', 'things', '860')
DEMO_EFFECTS = 70  # the860 has 303 effects; the spells use the first 70 (those of the 8.70 client)
OUT_IMAGES = os.path.join(ROOT, 'data', 'images', 'game', 'spelldemo')
OUT_LUA = os.path.join(ROOT, 'modules', 'game_spelllist', 'spelldemosprites.lua')

# data size of every attribute of the 8.60-9.86 dat format (attributes not listed have no data; 0x21, market, is read
# apart: its name has a length)
ATTR_DATA = {0x00: 2, 0x08: 2, 0x09: 2, 0x15: 4, 0x18: 4, 0x19: 2, 0x1C: 2, 0x1D: 2, 0x20: 2}


def read_things(path):
    data = open(path, 'rb').read()
    _, items, outfits, effects, missiles = struct.unpack_from('<IHHHH', data, 0)
    pos = 12
    things = {'item': {}, 'outfit': {}, 'effect': {}, 'missile': {}}
    ranges = [('item', 100, items), ('outfit', 1, outfits), ('effect', 1, effects), ('missile', 1, missiles)]
    for category, first, last in ranges:
        for tid in range(first, last + 1):
            displacement = (0, 0)
            while True:
                attr = data[pos]
                pos += 1
                if attr == 0xFF:
                    break
                if attr == 0x21:  # market: category, trade as, show as, name, vocation, level
                    pos += 6
                    pos += 2 + struct.unpack_from('<H', data, pos)[0] + 4
                    continue
                if attr not in ATTR_DATA and attr > 0x20:
                    raise ValueError('unknown attribute 0x%02x in %s %d' % (attr, category, tid))
                if attr == 0x18:
                    displacement = struct.unpack_from('<HH', data, pos)
                pos += ATTR_DATA.get(attr, 0)
            groups = 1
            if category == 'outfit':  # frame groups: idle and walking; the demos only need effects and missiles
                groups = data[pos]
                pos += 1
            for group in range(groups):
                if category == 'outfit':
                    pos += 1  # group type
                width, height = data[pos], data[pos + 1]
                pos += 2
                if width > 1 or height > 1:
                    pos += 1  # exact size
                layers, px, py, pz, phases = data[pos:pos + 5]
                pos += 5
                if phases > 1:
                    pos += 1 + 4 + 1 + 8 * phases  # frame durations: async, loop count, start phase, min/max of each
                count = width * height * layers * px * py * pz * phases
                sprites = struct.unpack_from('<%dI' % count, data, pos)
                pos += 4 * count
            things[category][tid] = dict(width=width, height=height, layers=layers, px=px, py=py, pz=pz,
                                         phases=phases, sprites=sprites, displacement=displacement)
    return things


class Sprites:
    def __init__(self, path):
        self.data = open(path, 'rb').read()
        self.count = struct.unpack_from('<I', self.data, 4)[0]  # extended: u32 count, offsets from byte 8

    def image(self, sid):
        img = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        if sid == 0 or sid > self.count:
            return img
        offset = struct.unpack_from('<I', self.data, 8 + (sid - 1) * 4)[0]
        if offset == 0:
            return img
        size = struct.unpack_from('<H', self.data, offset + 3)[0]
        pos, end, pixel = offset + 5, offset + 5 + size, 0
        px = img.load()
        while pos < end:
            transparent, colored = struct.unpack_from('<HH', self.data, pos)
            pos += 4
            pixel += transparent
            for _ in range(colored):
                r, g, b = self.data[pos:pos + 3]
                pos += 3
                px[pixel % 32, pixel // 32] = (r, g, b, 255)
                pixel += 1
        return img


def draw_thing(thing, sprites, x_pattern, y_pattern, phase, cell):
    """the thing drawn like the client does: its bottom right tile is the bottom right 32x32 of the cell"""
    img = Image.new('RGBA', (cell, cell), (0, 0, 0, 0))
    w, h = thing['width'], thing['height']
    for layer in range(thing['layers']):
        for hy in range(h):
            for wx in range(w):
                index = (((((phase * thing['pz']) * thing['py'] + y_pattern) * thing['px'] + x_pattern)
                          * thing['layers'] + layer) * h + hy) * w + wx
                sprite = sprites.image(thing['sprites'][index])
                dx, dy = thing['displacement']
                img.alpha_composite(sprite, (cell - 32 - wx * 32 - dx, cell - 32 - hy * 32 - dy))
    return img


def main():
    things = read_things(os.path.join(THINGS, 'Tibia.dat'))
    sprites = Sprites(os.path.join(THINGS, 'Tibia.spr'))
    os.makedirs(OUT_IMAGES, exist_ok=True)

    effects = {eid: thing for eid, thing in things['effect'].items() if eid <= DEMO_EFFECTS}
    max_phases = max(t['phases'] for t in effects.values())
    rows = (len(effects) + 1) // 2
    sheet = Image.new('RGBA', (2 * 64 * max_phases, 64 * rows), (0, 0, 0, 0))
    for eid, thing in sorted(effects.items()):
        block, row = divmod(eid - 1, rows)
        for phase in range(thing['phases']):
            sheet.alpha_composite(draw_thing(thing, sprites, 0, 0, phase, 64),
                                  (block * 64 * max_phases + phase * 64, row * 64))
    sheet.save(os.path.join(OUT_IMAGES, 'effects.png'), optimize=True)

    missiles = things['missile']
    sheet = Image.new('RGBA', (32 * 9, 32 * len(missiles)), (0, 0, 0, 0))
    for mid, thing in sorted(missiles.items()):
        for d in range(9):
            x, y = d % 3, d // 3
            if thing['px'] < 3 or thing['py'] < 3:
                x, y = 0, 0
            sheet.alpha_composite(draw_thing(thing, sprites, x, y, 0, 32), (d * 32, (mid - 1) * 32))
    sheet.save(os.path.join(OUT_IMAGES, 'missiles.png'), optimize=True)

    lines = ['-- Generated by tools/gen_spell_demo_sprites.py from data/things/860: change that script, not this file.',
             '-- Layout of data/images/game/spelldemo/effects.png (rows per block, cells per row) and the animation phases of every',
             '-- magic effect (index = effect id)',
             'SpellDemoEffectRows = %d' % rows,
             'SpellDemoEffectColumns = %d' % max_phases,
             'SpellDemoEffectPhases = {']
    ids = sorted(effects)
    for i in range(0, len(ids), 20):
        lines.append('  ' + ' '.join('%d,' % effects[e]['phases'] for e in ids[i:i + 20]))
    lines.append('}')
    open(OUT_LUA, 'w', encoding='utf8', newline='\n').write('\n'.join(lines) + '\n')
    print('effects:', len(effects), 'max phases:', max_phases, '- missiles:', len(missiles))


if __name__ == '__main__':
    sys.exit(main())
