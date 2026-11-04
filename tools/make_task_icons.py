#!/usr/bin/env python3
"""Paints the icons of the Task Board (modules/game_taskboard): the board and tracker of the top menu, Task Points, reroll
tokens and the lock of a closed task. Drawn here, not taken from Tibia's client.

  python tools/make_task_icons.py        running it again gives the same files
"""
import math
import os

from PIL import Image, ImageDraw

DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'images')
SCALE = 8


def canvas(size):
    return Image.new('RGBA', (size * SCALE, size * SCALE), (0, 0, 0, 0))


def save(image, size, path):
    image.resize((size, size), Image.LANCZOS).save(os.path.join(DATA, path))


def s(values):
    return [v * SCALE for v in values]


def board():
    image = canvas(16)
    d = ImageDraw.Draw(image)
    d.rounded_rectangle(s([2, 1, 14, 15]), radius=SCALE, fill=(112, 76, 42, 255), outline=(52, 33, 16, 255), width=SCALE)
    d.rectangle(s([4, 3.5, 12, 13]), fill=(226, 208, 164, 255))
    for y, color in ((5, (150, 40, 34, 255)), (8, (70, 60, 46, 255)), (11, (70, 60, 46, 255))):
        d.rectangle(s([5.5, y, 10.5, y + 1]), fill=color)
    d.rectangle(s([6, 0.5, 10, 2.5]), fill=(190, 150, 70, 255), outline=(90, 66, 24, 255))
    save(image, 16, 'topbuttons/taskboard.png')


def tracker():
    image = canvas(20)
    d = ImageDraw.Draw(image)
    d.ellipse(s([3, 3, 17, 17]), outline=(214, 60, 48, 255), width=2 * SCALE)
    d.ellipse(s([7, 7, 13, 13]), outline=(226, 208, 164, 255), width=SCALE + 4)
    d.ellipse(s([9, 9, 11, 11]), fill=(214, 60, 48, 255))
    for box in ([9.25, 0.5, 10.75, 5], [9.25, 15, 10.75, 19.5], [0.5, 9.25, 5, 10.75], [15, 9.25, 19.5, 10.75]):
        d.rectangle(s(box), fill=(226, 208, 164, 255))
    save(image, 20, 'topbuttons/tasktracker.png')


def points():
    image = canvas(12)
    d = ImageDraw.Draw(image)
    star = []
    for i in range(10):
        radius = 5.8 if i % 2 == 0 else 2.6
        angle = -math.pi / 2 + i * math.pi / 5
        star.append((6 * SCALE + radius * SCALE * math.cos(angle), 6.2 * SCALE + radius * SCALE * math.sin(angle)))
    d.polygon(star, fill=(236, 190, 70, 255), outline=(120, 76, 14, 255))
    save(image, 12, 'ui/task_points.png')


def reroll():
    image = canvas(12)
    d = ImageDraw.Draw(image)
    d.arc(s([1.5, 1.5, 10.5, 10.5]), start=320, end=250, fill=(110, 200, 90, 255), width=2 * SCALE)
    d.polygon(s([6.2, 0, 10, 2.6, 6.2, 5.2]), fill=(110, 200, 90, 255))
    save(image, 12, 'ui/task_reroll.png')


def lock():
    image = canvas(24)
    d = ImageDraw.Draw(image)
    d.arc(s([7, 2, 17, 15]), start=180, end=360, fill=(170, 170, 176, 255), width=2 * SCALE)
    d.rounded_rectangle(s([5, 10, 19, 22]), radius=2 * SCALE, fill=(196, 150, 60, 255), outline=(82, 56, 14, 255), width=SCALE)
    d.ellipse(s([10.5, 13.5, 13.5, 16.5]), fill=(60, 40, 12, 255))
    d.rectangle(s([11.25, 15, 12.75, 19]), fill=(60, 40, 12, 255))
    save(image, 24, 'ui/task_lock.png')


for paint in (board, tracker, points, reroll, lock):
    paint()
print('ok')
