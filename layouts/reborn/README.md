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

## Beside the map

The map keeps its 15 x 11 proportions, so its panel has room left on two sides. `ui/panel_map` is only an edge with an empty middle, and
`GameMapBackdrop` (`styles/40-mapbackdrop.otui`) lies under the panel: the wall, the pillars, the banners, the torches and the map's frame.
The engine draws the map over all of it, so what reaches too far is simply covered. `updateMapBackdrop` in `gameinterface.lua` works out
where the map is (`getMapRect`, the same sums as the engine's) and shows the pieces that fit; `data/styles` has an empty backdrop, which
is why Retro doesn't change.

## The health and mana circles

`modules/game_healthinfo/circles.lua`. One ChatGPT picture has its channel in pure cyan and the medallion's glass in pure yellow, so both
can be cut exactly. `tools/make_reborn_art.py` writes three layers per side at seven sizes and prints the numbers in `PICTURES`; change the
picture and those numbers change with it. The next bigger picture is shown, so they stay sharp between sizes.

Alt with the mouse over a circle opens the controls after 300 ms (Alt with a quick click still attacks what stands behind it). Only the
circle itself reacts to the mouse, not its whole square (`band`). Retro uses the same code with its old pictures.

## Checking

`python tools/window_preview.py reborn` shows every window with made-up data and no login, from a throw-away copy of the client with
its own settings, and leaves the screenshots in a temporary folder. The map itself can't be drawn without a real player.

`python tools/window_preview_input.py` with `python tools/window_preview.py reborn 1920x1080 online game_full circles_input` sends real mouse
messages to that copy's window alone, to try a real press and drag on the circles.
