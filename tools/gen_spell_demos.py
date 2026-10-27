#!/usr/bin/env python3
"""Writes the spell demos of the Spells window (modules/game_spelllist/spelldemos.lua) from the server's spells.

For every player spell of the server's data/spells/spells.xml it reads the spell's script and notes what a cast shows:
the missile, the magic effect, the area it covers (every wave of the custom spells, with its delay) and the field it
leaves behind. The Spells window plays that on a small grid when a spell is clicked. Run from the client's root after
changing the server's spells (the server repository is expected next to this one):

    python tools/gen_spell_demos.py [path to the server repository]

Demo format (offsets are in tiles from the caster, who stands at 0, 0 and faces north, so y < 0 is in front of him):
    creatures = {{x, y, kind}, ...}         kind: 'caster', 'monster' (target of an attack) or 'friend' (of a heal)
    shots = {{fromX, fromY, toX, toY, missile}, ...}   missiles that fly first, all at the same time
    waves = {{delay, effect, {x1, y1, x2, y2, ...}}, ...}   effects shown once the shots have landed (delay in ms)
    field = {itemId, {x1, y1, ...}}         item left on those tiles once the shots have landed
Effect and missile numbers are the client's (the server's constant + 1).
"""
import os
import re
import sys

CLIENT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SERVER = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(CLIENT, '..', 'ForgottenL'))
SPELLS = os.path.join(SERVER, 'data', 'spells')
OUT = os.path.join(CLIENT, 'modules', 'game_spelllist', 'spelldemos.lua')

# spells that are not meant for players (same list as the server's tools/gen_client_spells.py)
SKIP = re.compile(r'^(MW Tests|big_foot_spell|pinguin_\w+|sugar_cane|melee_spider)$')
TARGET = (3, -2)      # where the target of a rune or a targeted spell stands
STRIKE = (0, -2)      # strikes hit the creature in front of the caster, a little away
WEAPON_MISSILE = 24   # CONST_ANI_WEAPONTYPE (the thrown weapon) is shown as a whirlwind sword

# spells that are Lua functions of the server (no script to read) or whose script draws its own effects
SPECIAL = {
    'Magic Shield': dict(shots=[(1, 0, 0, 0, 37), (0, -1, 0, 0, 37), (0, 1, 0, 0, 37), (-1, 0, 0, 0, 37)],
                         waves=[(0, 'CONST_ME_LOSEENERGY', [(0, 0)]), (150, 49, [(0, 0)])]),
    'Magic Rope': dict(waves=[(0, 'CONST_ME_TELEPORT', [(0, 0)]), (400, 'CONST_ME_POFF', [(0, -1)])]),
    'Levitate': dict(waves=[(0, 'CONST_ME_TELEPORT', [(0, 0)]), (400, 'CONST_ME_TELEPORT', [(0, -1)])]),
    'Find Person': dict(waves=[(0, 'CONST_ME_MAGIC_BLUE', [(0, 0)])]),
    'Creature Illusion': dict(waves=[(0, 'CONST_ME_MAGIC_RED', [(0, 0)])]),
    'Chameleon': dict(waves=[(0, 'CONST_ME_MAGIC_RED', [(0, 0)])]),
    'Desintegrate': dict(target=True, waves=[(0, 'CONST_ME_POFF', [(0, 0)])]),
    'Destroy Field': dict(target=True, waves=[(0, 'CONST_ME_POFF', [(0, 0)])]),
    'Exevo Trap': dict(waves=[(0, 'CONST_ME_MAGIC_RED', [(0, 0)])]),
    'Poisoned Rune': dict(target=True, monster=True,
                          shots=[(-1, -1, 0, 0, 38), (1, -1, 0, 0, 38), (-1, 1, 0, 0, 38), (1, 1, 0, 0, 38)],
                          waves=[(0, 'CONST_ME_POISONAREA', [(0, 0)])]),
    'Freeze Shard': dict(extra=[(400, 'CONST_ME_ICEAREA', [(0, 0)])]),
    'Freeze Crystal': dict(extra=[(400, 'CONST_ME_ICEAREA', [(0, 0)])]),
}


def lua_tables(src):
    """every NAME = { {..}, .. } table of numbers in a Lua source"""
    tables = {}
    for m in re.finditer(r'(?:local\s+)?(\w+)\s*=\s*\{\s*(\{[\d,\s]*\}\s*,?\s*)+\}', src):
        rows = re.findall(r'\{([\d,\s]*)\}', m.group(0))
        tables[m.group(1)] = [[int(v) for v in r.split(',') if v.strip()] for r in rows]
    return tables


def strip_comments(src):
    src = re.sub(r'--\[\[.*?\]\]', '', src, flags=re.S)
    return re.sub(r'--[^\n]*', '', src)


def read(path):
    return strip_comments(open(path, encoding='latin1').read())


CONSTANTS = {m.group(1): int(m.group(2)) for m in re.finditer(r'^(CONST_(?:ME|ANI)_\w+)\s*=\s*(\d+)',
                                                                 read(os.path.join(SERVER, 'data', 'lib', '000-constant.lua')), re.M)}
LIB_AREAS = lua_tables(read(os.path.join(SPELLS, 'lib', 'spells.lua')))


def const(value):
    """a server effect or missile (constant name or number) as the client's number, None when there is none"""
    if value is None:
        return None
    number = int(value) if str(value).isdigit() else CONSTANTS.get(value)
    if number is None:
        raise ValueError('unknown constant %s' % value)
    if number == 254:
        number = WEAPON_MISSILE
    return None if number == 255 else number + 1


def tiles_of(array):
    """the tiles an area table hits, as offsets from its centre (the 2 or 3 cell; a 2 is not hit itself)"""
    cy = cx = None
    for y, row in enumerate(array):
        for x, v in enumerate(row):
            if v in (2, 3):
                cy, cx = y, x
    if cy is None:
        cy, cx = len(array) // 2, len(array[0]) // 2
    return [(x - cx, y - cy) for y, row in enumerate(array) for x, v in enumerate(row) if v in (1, 3)]


def combat_params(src, name):
    def param(key):
        m = re.search(r'setCombatParam\(%s,\s*COMBAT_PARAM_%s,\s*(\w+)\)' % (name, key), src)
        return m.group(1) if m else None
    area = None
    m = re.search(r'setCombatArea\(%s,\s*(?:createCombatArea\((\w+)|(\w+))' % name, src)
    if m:
        array_name = m.group(1)
        if not array_name:
            a = re.search(r'(?:local\s+)?%s\s*=\s*createCombatArea\(\s*(\w+|\{)' % m.group(2), src)
            array_name = a.group(1) if a else None
            if array_name == '{':
                inline = src[a.start(1):]
                inline = inline[:inline.index('\n}') + 2] if '\n}' in inline else inline
                area = tiles_of([[int(v) for v in r.split(',') if v.strip()] for r in re.findall(r'\{([\d,\s]*)\}', inline)])
        if area is None and array_name:
            table = lua_tables(src).get(array_name) or LIB_AREAS.get(array_name)
            if table is None:
                raise ValueError('unknown area %s' % array_name)
            area = tiles_of(table)
    item = param('CREATEITEM')
    return dict(effect=const(param('EFFECT')), missile=const(param('DISTANCEEFFECT')), area=area,
                item=int(item) if item and item.isdigit() else None)


def generated_waves(src):
    """the waves of a custom spell written by the server's tools/gen_spell_areas.py: {delay, {newCombat(...), ...}}"""
    areas = []
    block = re.search(r'local AREAS = \{(.*?)\n\}', src, re.S).group(1)
    for wave in re.split(r'\n\t\{\s*\n', '\n' + block)[1:]:
        areas.append(tiles_of([[int(v) for v in r.split(',') if v.strip()] for r in re.findall(r'\{([\d,\s]*)\}', wave)]))
    waves = []
    for m in re.finditer(r'^\t\{(\d+),\s*\{(.*)\}\},?\s*$', src, re.M):
        effect = None
        tiles = []
        for c in re.finditer(r'newCombat\(\w+,\s*(\w+),[^)]*?AREAS\[(\d+)\]\)', m.group(2)):
            if effect is None and c.group(1) != 'nil':
                effect = const(c.group(1))
            tiles = areas[int(c.group(2)) - 1]
        if effect:
            waves.append((int(m.group(1)), effect, tiles))
    return waves


def demo_of(name, kind, attrs, script):
    special = SPECIAL.get(name, {})
    aggressive = attrs.get('aggressive', '1') != '0'
    direction = attrs.get('direction') == '1'
    if attrs.get('selftarget') == '1' and kind == 'rune':
        cast = 'self'
    elif kind == 'rune':
        target = attrs.get('needtarget') == '1'
        cast = 'target' if target else 'position'
    elif attrs.get('casterTargetOrDirection') == '1':
        cast = 'strike'
    elif attrs.get('needtarget') == '1':
        cast = 'target'
    else:
        cast = 'self'

    src = read(os.path.join(SPELLS, 'scripts', script)) if script else ''
    shots, waves, field = [], [], None
    if 'local AREAS = {' in src:
        waves = generated_waves(src)
        cast = 'self'  # the custom figures are drawn around the caster whatever way he faces
    elif src:
        names = re.findall(r'(?:local\s+)?(\w+)\s*=\s*createCombatObject\(\)', src)
        if names:
            main = 'distanceCombat' if cast == 'strike' and 'distanceCombat' in names else names[0]
            p = combat_params(src, main)
            if p['missile'] and cast in ('self',) and not p['area']:
                cast = 'target'
            if p['missile'] and cast != 'self':
                shots.append(p['missile'])
            tiles = p['area'] or [(0, 0)]
            if p['effect']:
                waves.append((0, p['effect'], tiles))
            if p['item']:
                field = (p['item'], tiles)
            if not p['effect'] and not p['item'] and p['missile'] is None:
                waves.append((0, const('CONST_ME_MAGIC_BLUE'), tiles))

    if 'waves' in special:
        waves = [(d, const(e), t) for d, e, t in special['waves']]
    if 'extra' in special:
        waves += [(d, const(e), t) for d, e, t in special['extra']]
    if special.get('target'):
        cast = 'target' if special.get('monster') else 'position'
    if not waves and not field and not shots and 'shots' not in special:
        waves = [(0, const('CONST_ME_MAGIC_BLUE'), [(0, 0)])]

    # where things happen: around the caster, or around the target
    if cast == 'self':
        centre = (0, 0)
    elif cast == 'strike':
        centre = STRIKE
    else:
        centre = TARGET
    moved = lambda tiles: [(x + centre[0], y + centre[1]) for x, y in tiles]
    if direction and cast == 'self':
        moved = lambda tiles: [t for t in tiles if t != (0, 0)]  # waves and beams start in front of the caster
    creatures = [(0, 0, 'caster')]
    if cast in ('target', 'strike'):
        creatures.append((centre[0], centre[1], 'monster' if aggressive else 'friend'))
    elif cast == 'position' and aggressive and not field:
        creatures.append((centre[0], centre[1], 'monster'))
    elif cast == 'self' and aggressive:
        hit = set(t for _, _, tiles in waves for t in moved(tiles))
        for spot in ((2, -2), (-2, -1), (1, 2), (-1, -3), (0, -3), (3, 1)):
            if spot in hit and len(creatures) < 3:
                creatures.append((spot[0], spot[1], 'monster'))

    demo = dict(creatures=creatures, waves=[(d, e, moved(t)) for d, e, t in waves])
    if 'shots' in special:
        demo['shots'] = [(fx + centre[0], fy + centre[1], tx + centre[0], ty + centre[1], m) for fx, fy, tx, ty, m in special['shots']]
    elif shots:
        demo['shots'] = [(0, 0, centre[0], centre[1], shots[0])]
    if field:
        demo['field'] = (field[0], moved(field[1]))
    return demo


def title(name):
    return ' '.join(w if w.isupper() and len(w) > 1 else w[:1].upper() + w[1:] for w in name.split(' '))


def lua_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


def flat(tiles):
    return '{' + ', '.join('%d, %d' % t for t in tiles) + '}'


def main():
    xml = open(os.path.join(SPELLS, 'spells.xml'), encoding='latin1').read()
    xml = re.sub(r'<!--.*?-->', '', xml, flags=re.S)
    demos = {}
    for m in re.finditer(r'<(instant|rune)\b([^>]*?)(/>|>(.*?)</\1>)', xml, re.S):
        kind, attrs = m.group(1), dict(re.findall(r'(\w+)="([^"]*)"', m.group(2)))
        name = attrs.get('name', '')
        if not name or SKIP.match(name) or attrs.get('enabled') == '0' or title(name) in demos:
            continue
        script = attrs.get('script') or (attrs.get('value') if attrs.get('event') == 'script' else None)
        demos[title(name)] = demo_of(title(name), kind, attrs, script)

    lines = ['-- Generated by tools/gen_spell_demos.py from the server\'s data/spells: change that script, not this file.',
             '-- What every spell shows when it is cast, played by the Spells window (see the format in that script).',
             'SpellDemos = {']
    for name in sorted(demos, key=str.lower):
        d = demos[name]
        parts = ['creatures = {%s}' % ', '.join('{%d, %d, %s}' % (x, y, lua_str(k)) for x, y, k in d['creatures'])]
        if d.get('shots'):
            parts.append('shots = {%s}' % ', '.join('{%d, %d, %d, %d, %d}' % s for s in d['shots']))
        if d['waves']:
            parts.append('waves = {%s}' % ', '.join('{%d, %d, %s}' % (w[0], w[1], flat(w[2])) for w in d['waves']))
        if d.get('field'):
            parts.append('field = {%d, %s}' % (d['field'][0], flat(d['field'][1])))
        lines.append('  [%s] = {%s},' % (lua_str(name), ', '.join(parts)))
    lines.append('}')
    open(OUT, 'w', encoding='utf8', newline='\n').write('\n'.join(lines) + '\n')
    print('wrote', OUT, len(demos), 'spells')


if __name__ == '__main__':
    main()
