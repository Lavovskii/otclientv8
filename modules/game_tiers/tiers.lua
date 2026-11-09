-- Tier frames (the owner, 2026-11-09): t1 white, t2 green, t3 blue, t4 purple, t5 gold, t6 red. Every item widget whose
-- item has a tier (tiers_data.lua, from the server's items.xml) gets, over the item, a frame in the tier's colour with a
-- soft halo and two points of light running round it (16 frames, tools/make_tier_frames.py), and behind the item a faint
-- tint of the same colour. It works wherever an item is shown (backpacks, inventory, Inspect, stash, store, loot...):
-- gamelib's UIItem:onItemChange calls apply().
local SIZE, FRAMES, STEP_MS = 34, 16, 90
-- the tint behind the item: the slot picture coloured a little (image colour) and, for widgets without a picture, a
-- transparent background
local IMAGE_TINT = {'#f2f2f2', '#c8f0d0', '#c8d8ff', '#e2ccff', '#fff0c0', '#ffc8c8'}
local BACK_TINT = {'#ffffff18', '#40dc6028', '#468cff28', '#b45cff28', '#ffcc3328', '#ff404028'}

-- every widget showing a frame (it leaves the list when it is destroyed: a destroyed widget is never touched)
local tracked = {}
local frame = 0
local event = nil

local function clip()
  return {x = frame * SIZE, y = 0, width = SIZE, height = SIZE}
end

local function place(widget)
  local w, h = widget:getWidth(), widget:getHeight()
  if w <= 0 or h <= 0 then w, h = SIZE, SIZE end
  widget:setIconRect({x = 0, y = 0, width = w, height = h})
  widget.tierSize = w * 10000 + h
end

local function clear(widget)
  if not tracked[widget] then return end
  tracked[widget] = nil
  widget:setIcon('')
  widget:setImageColor('#ffffff')
  widget:setBackgroundColor(widget.tierBackground or '#00000000')
end

local function doApply(widget)
  if not widget or widget:isDestroyed() then return end
  local item = widget:getItem()
  local tier = item and ITEM_TIERS[item:getId()]
  if not tier then
    clear(widget)
    return
  end
  if not tracked[widget] then
    widget.tierBackground = widget:getBackgroundColor()
    if not widget.tierHooked then
      widget.tierHooked = true
      connect(widget, { onDestroy = function(w) tracked[w] = nil end })
    end
  end
  tracked[widget] = tier
  widget:setIcon('/images/game/tiers/frame_t' .. tier)
  widget:setIconClip(clip())
  place(widget)
  widget:setImageColor(IMAGE_TINT[tier])
  widget:setBackgroundColor(BACK_TINT[tier])
end

-- never let a frame break the window it is in
function apply(widget)
  local ok, err = pcall(doApply, widget)
  if not ok then g_logger.error('[tiers] apply: ' .. tostring(err)) end
end

-- the light runs round: every frame widget steps on together (hidden ones are skipped)
local function doStep()
  frame = (frame + 1) % FRAMES
  local c = clip()
  for widget in pairs(tracked) do
    if widget:isVisible() then
      local w, h = widget:getWidth(), widget:getHeight()
      if widget.tierSize ~= w * 10000 + h then place(widget) end
      widget:setIconClip(c)
    end
  end
end

local function step()
  local ok, err = pcall(doStep)
  if not ok then g_logger.error('[tiers] step: ' .. tostring(err)) end
end

function init()
  event = cycleEvent(step, STEP_MS)
end

function terminate()
  if event then removeEvent(event) event = nil end
  for widget in pairs(tracked) do
    if not widget:isDestroyed() then clear(widget) end
  end
end
