-- The boss bar (the owner, 2026-11-08): while the player attacks a boss, a big bar at the top of the game with its picture, kind,
-- name, level and health. It fades in over 2 seconds when the attack starts and out over 2 seconds when it stops (or the boss dies).
-- The server (data/lib/125-boss_bar.lua) says which monster is a boss and its health, extended opcode 31, fields split by |:
--   S|creature id|name|kind|level|health|max health     H|creature id|health|max health     E|creature id
local OPCODE = 31
local FADE = 2000 -- milliseconds, in and out
local TRAIL_WAIT, TRAIL_TIME = 450, 700 -- the damage just taken stays a moment lighter, then shrinks
local KINDS = {world = true, event = true, quest = true, echo = true, task = true, hunt = true, raid = true, dungeon = true}

local panel, content
local boss -- {id, name, kind, level, health, max}
local trail = 0 -- the health the lighter part reaches
local trailEvent, fadeEvent
local opacity, target = 0, 0

local function comma(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
  return (out:gsub('^,', ''))
end

local function fadeTo(value)
  target = value
  if fadeEvent then return end
  local last = g_clock.millis()
  local function step()
    fadeEvent = nil
    if not content then return end
    local now = g_clock.millis()
    local delta = (now - last) / FADE
    last = now
    if opacity < target then
      opacity = math.min(target, opacity + delta)
    else
      opacity = math.max(target, opacity - delta)
    end
    content:setOpacity(opacity)
    if opacity ~= target then
      fadeEvent = scheduleEvent(step, 30)
    elseif opacity == 0 then
      boss = nil
    end
  end
  fadeEvent = scheduleEvent(step, 30)
end

local function widthOf(value)
  local track = content.track
  local inner = math.max(0, track:getWidth() - 4)
  if not boss or boss.max <= 0 then return 0 end
  return math.floor(inner * math.max(0, math.min(1, value / boss.max)))
end

local function drawBar()
  if not boss or not content then return end
  content.track.fill:setWidth(widthOf(boss.health))
  content.track.trail:setWidth(widthOf(math.max(trail, boss.health)))
  local percent = boss.max > 0 and math.floor(boss.health * 100 / boss.max + 0.5) or 0
  content.track.health:setText(comma(boss.health) .. ' / ' .. comma(boss.max) .. '  (' .. percent .. '%)')
end

-- the lighter part waits, then follows the health down
local function shrinkTrail()
  removeEvent(trailEvent)
  trailEvent = scheduleEvent(function()
    local from, started = trail, g_clock.millis()
    local function step()
      trailEvent = nil
      if not boss then return end
      local k = math.min(1, (g_clock.millis() - started) / TRAIL_TIME)
      trail = from + (boss.health - from) * k
      drawBar()
      if k < 1 then trailEvent = scheduleEvent(step, 30) end
    end
    step()
  end, TRAIL_WAIT)
end

local function drawBoss()
  if not boss or not content then return end
  local kind = KINDS[boss.kind] and boss.kind or 'world'
  content.tag:setImageSource('/images/game/bossbar/tag_' .. kind)
  content.name:setText(boss.name)
  if boss.level > 0 then
    content.level:setText('Lv. ' .. comma(boss.level))
    content.level:setWidth(content.level:getTextSize().width + 18)
    content.level:show()
  else
    content.level:hide()
  end
  local creature = g_map.getCreatureById(boss.id)
  if creature then
    content.portrait.creature:setOutfit(creature:getOutfit())
    content.portrait.creature:show()
  else
    content.portrait.creature:hide()
  end
  drawBar()
end

local function attacking(id)
  local creature = g_game.getAttackingCreature()
  return creature and creature:getId() == id
end

local function onMessage(protocol, opcode, buffer)
  local f = {}
  for part in (tostring(buffer or '') .. '|'):gmatch('([^|]*)|') do table.insert(f, part) end
  local id = tonumber(f[2])
  if not id or not content then return end
  if f[1] == 'S' then
    boss = {id = id, name = f[3] or '', kind = f[4] or 'world', level = tonumber(f[5]) or 0,
      health = tonumber(f[6]) or 0, max = math.max(1, tonumber(f[7]) or 1)}
    trail = boss.health
    removeEvent(trailEvent)
    trailEvent = nil
    drawBoss()
    fadeTo(1)
  elseif f[1] == 'H' and boss and boss.id == id then
    local health = tonumber(f[3]) or boss.health
    boss.max = math.max(1, tonumber(f[4]) or boss.max)
    if health < boss.health then
      trail = math.max(trail, boss.health)
      shrinkTrail()
    else
      trail = health
    end
    boss.health = health
    drawBar()
  elseif f[1] == 'E' and boss and boss.id == id then
    fadeTo(0)
  end
end

-- the attack stops or turns to another creature: the bar goes without waiting for the server
local function onAttackingCreatureChange(creature)
  if not boss then return end
  if creature and creature:getId() == boss.id then
    fadeTo(1)
  else
    fadeTo(0)
  end
end

local function place()
  local top = modules.game_interface.getTopBar()
  local bar = top and top:recursiveGetChildById('topbar')
  if not bar then return end
  if not panel or panel:isDestroyed() then
    panel = g_ui.createWidget('BossBarPanel', bar)
    content = panel.content
  end
  bar:moveChildToIndex(panel, 1)
  local stats = bar:getChildById('stats')
  if stats then stats:hide() end -- the health and mana bars: the boss bar takes their place
end

local function onGameStart()
  scheduleEvent(place, 100) -- after the topbar is built
end

local function onGameEnd()
  boss = nil
  opacity, target = 0, 0
  removeEvent(fadeEvent)
  removeEvent(trailEvent)
  fadeEvent, trailEvent = nil, nil
  if content then content:setOpacity(0) end
end

-- for the window preview: show a made-up boss at once
function preview(data, outfit)
  if not content then place() end
  onMessage(nil, OPCODE, data)
  if outfit and content then
    content.portrait.creature:setOutfit(outfit)
    content.portrait.creature:show()
  end
  opacity, target = 1, 1
  if content then content:setOpacity(1) end
end

function init()
  g_ui.importStyle('bossbar')
  ProtocolGame.registerExtendedOpcode(OPCODE, onMessage)
  connect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd, onAttackingCreatureChange = onAttackingCreatureChange})
  if g_game.isOnline() then place() end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd, onAttackingCreatureChange = onAttackingCreatureChange})
  removeEvent(fadeEvent)
  removeEvent(trailEvent)
  if panel then panel:destroy() end
  panel, content, boss = nil, nil, nil
end
