-- Names above big outfits (the owner, 2026-11-09): the engine draws a creature's name and health bar at the same height
-- for every outfit (Creature::drawInformation at m_informationOffset), right for a Citizen-sized outfit and in the
-- middle of the body of a big one. heights.lua (tools/gen_name_offsets.py) has how tall each big looktype is drawn;
-- a creature taller than the Citizen gets its information raised by the difference, so its name sits on top of its
-- head as a Citizen's does. Outfits up to a few pixels taller are left as they are.
local TOLERANCE = 4

local function heightOf(outfit)
  if not outfit or not outfit.type or outfit.type == 0 then
    return 0 -- an item or invisible outfit: the engine's own place
  end
  local mount = tonumber(outfit.mount) or 0
  if mount > 0 then
    return math.max(NAME_OFFSET_MOUNTED[outfit.type] or NAME_OFFSET_REFERENCE, NAME_OFFSET_HEIGHTS[mount] or NAME_OFFSET_REFERENCE)
  end
  return NAME_OFFSET_HEIGHTS[outfit.type] or NAME_OFFSET_REFERENCE
end

local function place(creature)
  if not creature or not creature.setInformationOffset then return end
  local rise = heightOf(creature:getOutfit()) - NAME_OFFSET_REFERENCE
  if rise <= TOLERANCE then rise = 0 end
  creature:setInformationOffset(0, -rise)
end

local function onOutfitChange(creature)
  place(creature)
end

local function placeAll()
  local player = g_game.getLocalPlayer()
  local position = player and player:getPosition()
  if not position then return end
  for _, creature in ipairs(g_map.getSpectators(position, true)) do
    place(creature)
  end
end

function init()
  connect(Creature, { onAppear = place, onOutfitChange = onOutfitChange })
  connect(g_game, { onGameStart = placeAll })
  if g_game.isOnline() then placeAll() end
end

function terminate()
  disconnect(Creature, { onAppear = place, onOutfitChange = onOutfitChange })
  disconnect(g_game, { onGameStart = placeAll })
end
