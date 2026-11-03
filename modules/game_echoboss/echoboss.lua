-- An echo boss is a monster with a red skull (data/lib/112-echo.lua in the server). Its name has the red glow of Tibia's leader
-- monsters, and its outfit a red contour.
-- The client draws a name in one font, but a title in its own, right above the name: so the name and the level go there, in
-- letters with the glow (tools/make_echo_boss_font.py), and the real name is blank. Creature.getName keeps giving the whole name
-- to every module.
local SHADER = "outfit_echo_boss"
local FONT = "verdana-11px-rounded-glow"
local TITLE_COLOR = "#ffffff"
local BLANK_NAME = " "

local wholeNames = {} -- creature id -> its whole name
local baseGetName
local changingOutfit = false

local function getWholeName(creature)
  return wholeNames[creature:getId()] or baseGetName(creature)
end

local function markName(creature)
  local name = baseGetName(creature)
  if name == BLANK_NAME then return end
  wholeNames[creature:getId()] = name
  creature:setName(BLANK_NAME)
  creature:setTitle(name, FONT, TITLE_COLOR)
end

-- the server changes an outfit without knowing about shaders, so it goes back on after that
local function markOutfit(creature)
  if changingOutfit then return end
  local outfit = creature:getOutfit()
  -- invisible, or looking like an item: only an outfit has a shader
  if outfit.type == 0 or outfit.shader == SHADER then return end
  changingOutfit = true
  creature:setOutfitShader(SHADER)
  changingOutfit = false
end

local function isEchoBoss(creature)
  return creature:isMonster() and creature:getSkull() == SkullRed
end

local function onSkullChange(creature)
  if isEchoBoss(creature) then
    markName(creature)
    markOutfit(creature)
  end
end

local function onOutfitChange(creature)
  if isEchoBoss(creature) then
    markOutfit(creature)
  end
end

local function onGameEnd()
  wholeNames = {}
end

function init()
  g_shaders.createOutfitShader(SHADER, "/shaders/outfit_echo_boss_vertex", "/shaders/outfit_echo_boss_fragment")
  baseGetName = Creature.getName
  Creature.getName = getWholeName
  connect(Creature, {onSkullChange = onSkullChange, onOutfitChange = onOutfitChange})
  connect(g_game, {onGameEnd = onGameEnd})
end

function terminate()
  Creature.getName = baseGetName
  disconnect(Creature, {onSkullChange = onSkullChange, onOutfitChange = onOutfitChange})
  disconnect(g_game, {onGameEnd = onGameEnd})
end
