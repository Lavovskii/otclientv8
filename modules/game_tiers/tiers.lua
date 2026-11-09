-- Tier slots (the owner, 2026-11-09): t1 white, t2 green, t3 blue, t4 purple, t5 gold, t6 red. Every item widget whose
-- item has a tier (tiers_data.lua, from the server's items.xml) shows, under the item, the slot picture of its tier: the
-- stone slot washed with the tier's colour, a bevelled line and corner pieces (tools/make_tier_slots.py). Static, like
-- Awaken Legends' rarity slots: nothing is drawn over the item (the running-light frames of build 54 were too much).
-- It works wherever an item is shown (backpacks, inventory, Inspect, stash, store, loot...): gamelib's
-- UIItem:onItemChange calls apply().
local SLOT_BORDER = 6

-- every widget showing a tier slot, and the picture it had before (it leaves the list when it is destroyed)
local tracked = {}

-- the picture the widget's style gives it (the slot it goes back to when the item has no tier)
local function styleImage(widget)
  local ok, style = pcall(function() return widget:getStyle() end)
  if ok and type(style) == 'table' then
    -- an inventory slot that is "on" (blessed) has its own picture
    local on = style['$on']
    if widget:isOn() and type(on) == 'table' and type(on['image-source']) == 'string' then return on['image-source'] end
    local source = style['image-source']
    if type(source) == 'string' then return source end
  end
  return ''
end

local function clear(widget)
  local before = tracked[widget]
  if not before then return end
  tracked[widget] = nil
  widget:setImageSource(styleImage(widget))
  widget:setImageBorder(before.border or 0)
  widget:setImageColor('#ffffff')
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
    tracked[widget] = {border = 0}
    if not widget.tierHooked then
      widget.tierHooked = true
      connect(widget, { onDestroy = function(w) tracked[w] = nil end })
    end
  end
  tracked[widget].tier = tier
  widget:setImageSource('/images/game/tiers/slot_t' .. tier)
  widget:setImageBorder(SLOT_BORDER)
  widget:setImageColor('#ffffff')
end

-- never let a slot break the window it is in
function apply(widget)
  local ok, err = pcall(doApply, widget)
  if not ok then g_logger.error('[tiers] apply: ' .. tostring(err)) end
end

function init()
end

function terminate()
  for widget in pairs(tracked) do
    if not widget:isDestroyed() then pcall(clear, widget) end
  end
  tracked = {}
end
