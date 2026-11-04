#!/usr/bin/env python3
"""Real window messages for the circles, only to the window of the preview copy: no global mouse, no foreground, and never the owner's
client. Start it, then in another shell: python tools/window_preview.py reborn 1920x1080 online game_full circles_input

The press, the drag and the mouse position are real. The engine reads Alt and Ctrl from the real keyboard, which messages don't change, so
those go through files that the preview's step reads. The wheel takes the real cursor position, so it can't be tried this way.
"""
import ctypes
import ctypes.wintypes as w
import subprocess
import sys
import time

user32 = ctypes.windll.user32
WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_MOUSEWHEEL = 0x200, 0x201, 0x202, 0x20A
WM_SYSKEYDOWN, WM_SYSKEYUP, WM_KEYDOWN, WM_KEYUP, WM_ACTIVATE = 0x104, 0x105, 0x100, 0x101, 0x6
VK_MENU, VK_CONTROL = 0x12, 0x11


def preview_pid():
    out = subprocess.run(['powershell', '-NoProfile', '-Command',
                          "Get-Process otclient_dx -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*forgl_preview*' } | Select-Object -First 1 -ExpandProperty Id"],
                         capture_output=True, text=True).stdout.strip()
    return int(out) if out else None


def find_window(pid):
    found = []
    @ctypes.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
    def each(hwnd, _):
        owner = w.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(hwnd):
            found.append(hwnd)
        return True
    user32.EnumWindows(each, 0)
    return found[0] if found else None


pid = None
for _ in range(120):
    pid = preview_pid()
    if pid:
        break
    time.sleep(0.5)
if not pid:
    sys.exit('no preview process')
print('preview pid', pid)
hwnd = None
for _ in range(60):
    hwnd = find_window(pid)
    if hwnd:
        break
    time.sleep(0.5)
print('window', hwnd)

# coordinates come from the preview's log: the module writes them to a file when it is ready
import os
ready = os.path.join(os.environ['APPDATA'], 'OTClientV8', 'ForgottenLPreview', 'input_ready.txt')
if os.path.exists(ready):
    os.remove(ready)
for _ in range(240):
    if os.path.exists(ready) and os.path.getsize(ready) > 0:
        break
    time.sleep(0.5)
x, y, tx, ty, ox, oy = [int(v) for v in open(ready).read().split()]
print('circle point', x, y, 'drag to', tx, ty, 'outside', ox, oy)


def lparam(px, py):
    return (py << 16) | (px & 0xffff)


def post(msg, wparam, l):
    user32.PostMessageW(hwnd, msg, wparam, l)


def move(px, py, buttons=0):
    post(WM_MOUSEMOVE, buttons, lparam(px, py))


DIR = os.path.dirname(ready)
def flag(name, on):
    path = os.path.join(DIR, name)
    if on:
        open(path, 'w').write('1')
    elif os.path.exists(path):
        os.remove(path)
flag('alt_on.txt', False)
flag('ctrl_on.txt', False)
post(WM_ACTIVATE, 1, 0)
time.sleep(0.2)
move(ox, oy)
time.sleep(0.3)
print('alt down, mouse on the circle')
flag('alt_on.txt', True)
move(x, y)
time.sleep(1.0)
print('press and drag')
post(WM_LBUTTONDOWN, 1, lparam(x, y))
time.sleep(0.15)
for i in range(1, 11):
    move(x + (tx - x) * i // 10, y + (ty - y) * i // 10, 1)
    time.sleep(0.05)
time.sleep(0.2)
post(WM_LBUTTONUP, 0, lparam(tx, ty))
time.sleep(0.5)
print('wheel up twice')
post(WM_MOUSEWHEEL, 120 << 16, lparam(tx, ty))
time.sleep(0.1)
post(WM_MOUSEWHEEL, 120 << 16, lparam(tx, ty))
time.sleep(0.5)
print('ctrl and wheel down')
flag('ctrl_on.txt', True)
time.sleep(0.05)
post(WM_MOUSEWHEEL, (0x10000 - 120) << 16, lparam(tx, ty))
time.sleep(0.1)
flag('ctrl_on.txt', False)
time.sleep(0.5)
print('alt up, mouse leaves')
flag('alt_on.txt', False)
move(ox, oy)
time.sleep(1.5)
print('quick alt click must not open: alt down, click straight away')
flag('alt_on.txt', True)
move(x, y)
time.sleep(0.1)
post(WM_LBUTTONDOWN, 1, lparam(x, y))
time.sleep(0.05)
post(WM_LBUTTONUP, 0, lparam(x, y))
time.sleep(0.1)
flag('alt_on.txt', False)
move(ox, oy)
print('done')
