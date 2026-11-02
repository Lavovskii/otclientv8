-- The characters of the staff (Gamemaster and up, the website's list) have their name in red with a thin gold edge.
-- The client draws a name in one font tinted with one colour, so those two colours are letters painted in the name
-- font (tools/make_staff_font.py): the name of a staff creature is set to them and Creature.getName keeps giving its
-- real name to every module. The tint is the health bar's colour too, so a staff health bar is gold.
local STAFF_API = Services.website .. "/index.php/api/staff"
local TINT = "#ffd060"

-- the same lists as tools/make_staff_font.py
local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'-"
local KEEP = { [128] = true, [129] = true, [160] = true, [161] = true, [170] = true, [173] = true, [176] = true,
               [180] = true, [186] = true, [191] = true }

local staffGlyphs = {} -- letter -> its letter in the staff colours
local staffNames = {} -- real name -> the name in the staff colours, of the characters on the list
local realNames = {} -- the name in the staff colours -> real name, also of those no longer on the list
local cppGetName = Creature.getName

-- a text in the staff colours (Guides draws one too)
function staffLetters(text)
  return (text:gsub(".", staffGlyphs))
end

local function getRealName(creature)
  local shown = cppGetName(creature)
  return realNames[shown] or shown
end

local function refresh(creature)
  if not creature:isPlayer() then return end
  local shown = cppGetName(creature)
  local name = realNames[shown] or shown
  local staffName = staffNames[name]
  if staffName then
    if shown ~= staffName then creature:setName(staffName) end
    creature:setInformationColor(TINT)
  elseif shown ~= name then
    creature:setName(name)
    creature:resetInformationColor()
  end
end

local function onStaffList(data, err)
  if err or type(data) ~= "table" or type(data["names"]) ~= "table" then return end
  staffNames = {}
  for _, name in ipairs(data["names"]) do
    if type(name) == "string" then
      local staffName = staffLetters(name)
      staffNames[name] = staffName
      realNames[staffName] = name
    end
  end
  local player = g_game.getLocalPlayer()
  local position = player and player:getPosition()
  if position then
    for _, creature in ipairs(g_map.getSpectators(position, true)) do
      refresh(creature)
    end
  end
end

local function onGameStart()
  HTTP.getJSON(STAFF_API, onStaffList)
end

function init()
  local slot = 128
  for letter in LETTERS:gmatch(".") do
    while KEEP[slot] do slot = slot + 1 end
    staffGlyphs[letter] = string.char(slot)
    slot = slot + 1
  end
  Creature.getName = getRealName
  connect(Creature, {onAppear = refresh})
  connect(g_game, {onGameStart = onGameStart})
  if g_game.isOnline() then onGameStart() end
end

function terminate()
  Creature.getName = cppGetName
  disconnect(Creature, {onAppear = refresh})
  disconnect(g_game, {onGameStart = onGameStart})
end
