-- Boss icons (the owner, 2026-11-08, chose the fifth design of each kind): an icon beside the name of a boss, one per kind. Echo
-- bosses are monsters with a red skull (the server's 112-echo.lua); the other kinds come from the server at login (extended opcode
-- 23, "kind:name|name;kind:name", data/lib/120-boss-types.lua). Pictures in data/images/game/bosses/<kind>.png, 16x16.
local OPCODE = 23
local ICONS = "/images/game/bosses/"
local KINDS = { echo = true, world = true, quest = true, task = true, hunt = true, event = true, raid = true, dungeon = true }

local kindOf = {} -- monster name, lower case and without its level -> kind

-- "Dragon Lord [L. 120]" -> "dragon lord"
local function plainName(creature)
  local name = creature:getName() or ""
  return (name:gsub("%s*%[L%.%s*%d+%]%s*$", "")):lower()
end

local function mark(creature)
  if not creature or not creature:isMonster() then return end
  local kind
  if creature:getSkull() == SkullRed then
    kind = "echo"
  else
    kind = kindOf[plainName(creature)]
  end
  if kind and KINDS[kind] then
    creature:setIconTexture(ICONS .. kind)
  end
end

local function markAll()
  local player = g_game.getLocalPlayer()
  local position = player and player:getPosition()
  if not position then return end
  for _, creature in ipairs(g_map.getSpectators(position, true)) do
    mark(creature)
  end
end

local function onBossTypes(protocol, opcode, buffer)
  kindOf = {}
  for part in tostring(buffer or ""):gmatch("[^;]+") do
    local kind, names = part:match("^(%w+):(.*)$")
    if kind and KINDS[kind] then
      for name in names:gmatch("[^|]+") do
        kindOf[name:lower()] = kind
      end
    end
  end
  markAll()
end

local function onGameEnd()
  kindOf = {}
end

function init()
  ProtocolGame.registerExtendedOpcode(OPCODE, onBossTypes)
  connect(Creature, { onAppear = mark, onSkullChange = mark })
  connect(g_game, { onGameEnd = onGameEnd })
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(Creature, { onAppear = mark, onSkullChange = mark })
  disconnect(g_game, { onGameEnd = onGameEnd })
end
