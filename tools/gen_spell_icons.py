#!/usr/bin/env python3
"""The icons of the vocations' area spells and of Healing (exura) in the spell icon sheet (2026-11-16).

    python tools/gen_spell_icons.py
    python tools/gen_spell_icons.py --icons <folder of <id>.png> --spells <vocation_spells.json>
    python tools/gen_spell_icons.py --placeholders --sheet <out.png> --lua <out.lua>   (coloured squares for missing icons)

data/images/game/spells/defaultspells.png is a sheet of 32x32 cells, 12 per row, counted from 1 (Spells.getImageClip in
modules/gamelib/spells.lua). The first 144 cells (384x384) are the client's own icons and are kept as they are; the sheet
grows to 384x768 and the new icons go from cell 145 on: the spells of ForgottenL/tools/vocation_spells.json in their
order, then heal_exura. Writes modules/gamelib/spellicons_vocations.lua (loaded by gamelib after spells.lua) with the
SpellIcons entries 'vs_<spell id>' and 'heal_exura' = {cell, 0} that ForgottenL/tools/gen_client_spells.py puts on the
spells. Running it again rebuilds the new cells from the icons (the first 144 cells are read from the sheet itself).
Every window that shows a spell icon takes it by image-clip, so a taller sheet changes nothing for the old icons.
"""
import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = r'C:\OTS\Tools\sprites\spell-icons-2026-11-16\icons32'
SPELLS = os.environ.get('FORGL_SPELLS', r'C:\OTS\ForgottenL\tools\vocation_spells.json')
SHEET = os.path.join(ROOT, 'data', 'images', 'game', 'spells', 'defaultspells.png')
LUA = os.path.join(ROOT, 'modules', 'gamelib', 'spellicons_vocations.lua')

CELL, COLUMNS = 32, 12
OLD_CELLS = 144  # 12 x 12, the client's own icons
SHEET_SIZE = (COLUMNS * CELL, 2 * COLUMNS * CELL)  # 384 x 768: room for 144 more
FIRST = OLD_CELLS + 1
EXTRA = ['heal_exura']
ELEMENT_COLOURS = {'fire': (220, 90, 30), 'energy': (150, 80, 220), 'death': (110, 20, 30), 'ice': (120, 190, 240),
                   'earth': (80, 150, 60), 'wind': (210, 210, 220), 'holy': (240, 200, 80), 'physical': (150, 150, 160)}


def cell_box(cell):
    x = ((cell - 1) % COLUMNS) * CELL
    y = ((cell - 1) // COLUMNS) * CELL
    return x, y


def placeholder(rgb, n):
    img = Image.new('RGBA', (CELL, CELL), rgb + (255,))
    px = img.load()
    for i in range(CELL):  # a dark frame and a diagonal, so cells can be told apart
        for j in (0, CELL - 1):
            px[i, j] = px[j, i] = (20, 20, 20, 255)
    for i in range(2, 2 + min(n % 28 + 2, 28)):
        px[i, i] = (255, 255, 255, 255)
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--icons', default=ICONS, help='folder with <id>.png, 32x32')
    ap.add_argument('--spells', default=SPELLS, help='ForgottenL tools/vocation_spells.json')
    ap.add_argument('--sheet', default=SHEET, help='the sheet to grow (read and written)')
    ap.add_argument('--source', help='read the first 144 cells from this sheet instead of --sheet')
    ap.add_argument('--lua', default=LUA, help='where the SpellIcons entries go')
    ap.add_argument('--placeholders', action='store_true', help='a coloured square for every icon that is missing')
    args = ap.parse_args()

    spells = json.load(open(args.spells, encoding='utf-8'))['spells']
    ids = [s['id'] for s in spells] + EXTRA
    if len(set(ids)) != len(ids):
        sys.exit('repeated spell ids in %s' % args.spells)
    last = FIRST + len(ids) - 1
    if last > (SHEET_SIZE[0] // CELL) * (SHEET_SIZE[1] // CELL):
        sys.exit('%d icons do not fit in a %dx%d sheet' % (len(ids), *SHEET_SIZE))

    source = Image.open(args.source or args.sheet).convert('RGBA')
    if source.size[0] != COLUMNS * CELL or source.size[1] < COLUMNS * CELL:
        sys.exit('%s is %dx%d, expected 384 wide and at least 384 tall' % (args.source or args.sheet, *source.size))
    sheet = Image.new('RGBA', SHEET_SIZE, (0, 0, 0, 0))
    old = source.crop((0, 0, COLUMNS * CELL, COLUMNS * CELL))
    sheet.paste(old, (0, 0))

    element = {s['id']: s.get('element') for s in spells}
    missing, resized = [], []
    for n, sid in enumerate(ids):
        path = os.path.join(args.icons, sid + '.png')
        if os.path.exists(path):
            icon = Image.open(path).convert('RGBA')
            if icon.size != (CELL, CELL):
                resized.append('%s %dx%d' % (sid, *icon.size))
                icon = icon.resize((CELL, CELL), Image.LANCZOS)
        elif args.placeholders:
            icon = placeholder(ELEMENT_COLOURS.get(element.get(sid), (60, 160, 90)), n)
            missing.append(sid)
        else:
            sys.exit('no icon %s (use --placeholders for coloured squares)' % path)
        sheet.paste(icon, cell_box(FIRST + n))

    # the old cells must come out exactly as they were
    assert sheet.crop((0, 0, COLUMNS * CELL, COLUMNS * CELL)).tobytes() == old.tobytes()

    lines = ['-- The icons of the vocations\' area spells and of Healing in data/images/game/spells/defaultspells.png. Generated',
             '-- by tools/gen_spell_icons.py from ForgottenL/tools/vocation_spells.json: change that, not this file.',
             '-- {cell, server icon id}: cells from SPELLFX_ICON_FIRST on (12 per row, from 1); TFS 0.4 sends no icon id (0).',
             'SPELLFX_ICON_FIRST = %d' % FIRST,
             'SpellIcons = SpellIcons or {}']
    for n, sid in enumerate(ids):
        key = sid if sid in EXTRA else 'vs_' + sid
        lines.append("SpellIcons['%s'] = {%d, 0}" % (key, FIRST + n))
    text = '\n'.join(lines) + '\n'

    os.makedirs(os.path.dirname(os.path.abspath(args.sheet)), exist_ok=True)
    sheet.save(args.sheet, optimize=True)
    with open(args.lua, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print('%s: %dx%d, %d old cells kept, %d icons in cells %d-%d' % (args.sheet, *SHEET_SIZE, OLD_CELLS, len(ids), FIRST, last))
    print('%s: %d SpellIcons entries' % (args.lua, len(ids)))
    if missing:
        print('PLACEHOLDERS for %d missing icons: %s' % (len(missing), ', '.join(missing)))
    if resized:
        print('resized to 32x32: %s' % ', '.join(resized))
    return 0


if __name__ == '__main__':
    sys.exit(main())
