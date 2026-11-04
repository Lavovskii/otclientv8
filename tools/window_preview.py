#!/usr/bin/env python3
"""Every window of the client with made-up data and no login: a throw-away copy with its own name, so its own settings, no saved
login and no game connection. The module in tools/window_preview opens the windows and takes the screenshots.

  python tools/window_preview.py reborn                     every step, 1280 x 800
  python tools/window_preview.py reborn 1920x1080 store     only these steps at that size

The pictures land in %TEMP%\\forgl_preview\\shots\\<layout>. The engine can't draw the map without a real player, so a floor stands in
for it. Only ever stops its own process: the owner's client may be open.
"""
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SP = os.path.join(tempfile.gettempdir(), 'forgl_preview')
OUT = os.path.join(SP, 'client')
os.makedirs(SP, exist_ok=True)
layout = sys.argv[1]
names = sys.argv[2:]
size = None
if names and 'x' in names[0] and names[0].replace('x', '').isdigit():
    size = names.pop(0).replace('x', ' ')

os.makedirs(OUT, exist_ok=True)
for name in ('otclient_dx.exe', 'libEGL.dll', 'libGLESv2.dll', 'd3dcompiler_47.dll', 'forgottenl.ico'):
    if not os.path.exists(os.path.join(OUT, name)):
        shutil.copy2(os.path.join(REPO, name), os.path.join(OUT, name))
for name in ('data', 'layouts'):
    link = os.path.join(OUT, name)
    if not os.path.exists(link):
        subprocess.check_call(['cmd', '/c', 'mklink', '/J', link, os.path.join(REPO, name)], stdout=subprocess.DEVNULL)
os.makedirs(os.path.join(OUT, 'mods'), exist_ok=True)

modules = os.path.join(OUT, 'modules')
if os.path.exists(modules):
    shutil.rmtree(modules)
shutil.copytree(os.path.join(REPO, 'modules'), modules)
shutil.copytree(os.path.join(REPO, 'tools', 'window_preview'), os.path.join(modules, 'zz_preview'))
open(os.path.join(modules, 'zz_preview', 'only.txt'), 'w').write(' '.join(names))
open(os.path.join(modules, 'zz_preview', 'size.txt'), 'w').write(size or '1280 800')

text = open(os.path.join(REPO, 'init.lua'), encoding='latin1').read()
assert 'APP_NAME = "ForgottenL"' in text
text = text.replace('APP_NAME = "ForgottenL"', 'APP_NAME = "ForgottenLPreview"')
assert 'g_resources.setLayout(layout)' in text
text = text.replace('g_resources.setLayout(layout)', 'g_resources.setLayout("%s")' % layout)
open(os.path.join(OUT, 'init.lua'), 'w', encoding='latin1', newline='\n').write(text)

appdata = os.path.join(os.environ['APPDATA'], 'OTClientV8', 'ForgottenLPreview')
print('pasta', appdata, os.path.isdir(appdata))
if os.path.isdir(appdata):
    for f in os.listdir(appdata):
        if f.startswith('rb_') and f.endswith('.png'):
            os.remove(os.path.join(appdata, f))

run = os.path.join(SP, 'run_%s.txt' % layout)
with open(run, 'wb') as output:
    # only this copy: the owner's own client may be open with the same name
    process = subprocess.Popen([os.path.join(OUT, 'otclient_dx.exe')], cwd=OUT, stdout=output, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        code = 'timeout'
        process.kill()
print('saiu', code)

for name in ('data', 'layouts'):
    link = os.path.join(OUT, name)
    subprocess.call(['cmd', '/c', 'rmdir', link], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

lines = open(run, 'rb').read().decode('latin1').splitlines()
seen = {}
for line in lines:
    if 'preview]' in line or 'ERROR' in line or 'lua function' in line or 'FATAL' in line or 'Unable' in line or 'unable' in line or 'WARNING' in line:
        if 'for writing' in line:
            continue
        key = line[:170]
        seen[key] = seen.get(key, 0) + 1
for key, count in seen.items():
    print(count, key)

shots = os.path.join(SP, 'shots', layout)
os.makedirs(shots, exist_ok=True)
if os.path.isdir(appdata):
    for f in os.listdir(appdata):
        if f.startswith('rb_') and f.endswith('.png'):
            shutil.copy2(os.path.join(appdata, f), os.path.join(shots, f[3:]))
print('fotos', len(os.listdir(shots)), shots)
