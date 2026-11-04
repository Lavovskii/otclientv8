# Reborn

The default look of the client since build 30. It grew out of the Task Board and the Store: stone, bevelled frames, a dark caption
with a thin bronze line, gold for what matters. Retro stays selectable under Options, Interface, Layout.

A layout overlays `/data`: a file here replaces the file of the same name there, and `styles/*.otui` replace the styles of the same
file name. Everything else falls back to `/data`, not to another layout.

## Where things come from

`tools/make_reborn_art.py` writes the images, cursors included, from the sheets in `tools/reborn_art`, generated with ChatGPT in pixel
art on a flat magenta background. Running it again gives the same files. Frames, buttons and glyphs below about 16 pixels are painted
by the tool, because a generated picture stops reading at that size. Change the tool, not the images.

## The rules that keep it together

| | |
|---|---|
| Stone | `M.stone`, average (70, 68, 65) |
| Wells: lists, fields, slots | `M.dark`, average (34, 33, 32), dark line above and left, thin bronze below and right |
| Bronze lines | light (182, 142, 74), middle (138, 104, 50), low (92, 68, 34), dark (46, 34, 18) |
| Titles and chosen things | `#e8cf94`, `#f4d68c`, font `verdana-11px-rounded` |
| Text | `#dfdfdf`, buttons `#f0e6cc`, dim `#a8a8a8` |
| Chosen row of a list | `#8a6a2e66` |

## Slices

A widget repeats the middle of its image, so:

- Anything that repeats has the textures' period (`PERIOD`, 160 pixels), or a seam shows in big windows.
- Shading only goes in the borders. A shadow inside the middle slice appears again in every repeat (a window's top slice is 28 pixels
  high for this reason, though its caption ends at 22).
- The sizes in the styles are part of the picture: `Window` has `image-border: 16` and `image-border-top: 28`, while its padding stays
  25 and 16 like Retro's, so module windows need no change between the two.

## Bars

`ProgressBar` here is an opaque groove with children: `fill` (the colour, with the shine `bar_gloss` stretched over it) and `caption`
(the text). `UIProgressBar` in corelib sends the width, the colour and the text to them. Bars without those children work as before.

## Checking

`python tools/window_preview.py reborn` shows every window with made-up data and no login, from a throw-away copy of the client with
its own settings, and leaves the screenshots in a temporary folder. The map itself can't be drawn without a real player.
