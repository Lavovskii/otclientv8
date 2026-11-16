-- The demos of the vocations' area spells (2026-11-16). Those spells are drawn by the client from a design
-- (modules/game_spellfx, SPELLFX_DESIGNS): layers of effects and missiles on tiles around the caster, each tile at its own
-- time. The demo plays the same design with the same timing (missile flight as Missile::setPath, each effect phase as long
-- as the dat says) from the sheets of tools/gen_spell_demo_sprites.py (SpellDemoFxEffects / SpellDemoFxMissiles, by DAT id
-- = the design's server id + 1). The tiles the spell hits are tinted and a few monsters stand on them.
-- Extends SpellDemoPlayer (spelldemo.lua).

local FX_EFFECTS = '/images/game/spelldemo/fx_effects'
local FX_MISSILES = '/images/game/spelldemo/fx_missiles'
local FX_MAX_EVENTS = 1500 -- things one round of a demo may draw
local FX_MAX_TIME = 6000 -- nothing of a round starts later than this (ms)
local HOLD = 1100 -- ms the result stays before the demo starts again
local TICK = 30
local MONSTER = {type = 15, head = 20, body = 30, legs = 40, feet = 50} -- a troll
local FRIEND = {type = 128, head = 78, body = 69, legs = 58, feet = 76}
local NW, N, NE, W, C, E, SW, S, SE = 0, 1, 2, 3, 4, 5, 6, 7, 8

local function missileDirection(dx, dy)
  if dx == 0 and dy == 0 then return C end
  local angle = math.atan2(-dy, dx) * 180 / math.pi
  if angle < 0 then angle = angle + 360 end
  if angle >= 360 - 22.5 or angle < 22.5 then return E
  elseif angle < 67.5 then return NE
  elseif angle < 112.5 then return N
  elseif angle < 157.5 then return NW
  elseif angle < 202.5 then return W
  elseif angle < 247.5 then return SW
  elseif angle < 292.5 then return S
  end
  return SE
end

-- the same generator as game_spellfx (Park-Miller), so a demo is the same every round
local function newRandom(seed)
  local s = math.floor(math.abs(tonumber(seed) or 0)) % 2147483646 + 1
  local rnd = {}
  function rnd.float()
    s = (s * 16807) % 2147483647
    return (s - 1) / 2147483646
  end
  function rnd.int(a, b)
    if b == nil then a, b = 1, a end
    if b <= a then return a end
    return a + math.floor(rnd.float() * (b - a + 1))
  end
  return rnd
end

local function flight(fx, fy, tx, ty)
  local dx, dy = tx - fx, ty - fy
  return math.floor(150 * math.sqrt(math.sqrt(dx * dx + dy * dy)))
end

-- the monsters of the demo: up to four tiles the spell hits, about two thirds of the way out, one in each quarter
local function monsterTiles(hit, radius)
  local reach = math.max(1, math.floor(radius * 0.66 + 0.5))
  local wanted = {{reach, -reach + 1}, {-reach, reach - 1}, {reach - 1, reach}, {-reach + 1, -reach}}
  local list, seen = {}, {}
  for i, w in ipairs(wanted) do
    if i > 2 and radius < 3 then break end
    local key = w[1] .. ',' .. w[2]
    if hit[key] and not seen[key] and not (w[1] == 0 and w[2] == 0) then
      seen[key] = true
      table.insert(list, w)
    end
  end
  return list
end

-- the design of a vocation spell, from game_spellfx (a sandboxed module: its globals live in modules.game_spellfx)
function SpellDemoPlayer.designOf(id)
  local fx = modules.game_spellfx
  local designs = fx and fx.SPELLFX_DESIGNS or SPELLFX_DESIGNS
  return type(designs) == 'table' and designs[id] or nil
end

-- the timeline of one round: every effect and missile with when it starts, as game_spellfx schedules them
function SpellDemoPlayer:designTimeline(design, seed)
  local rnd = newRandom(seed)
  local events = {}
  local finish = 0
  local function add(e)
    if #events < FX_MAX_EVENTS and e.at <= FX_MAX_TIME then
      table.insert(events, e)
      return true
    end
    return false
  end
  for _, layer in ipairs(design) do
    if type(layer) == 'table' and type(layer.tiles) == 'table' then
      local effect = (tonumber(layer.effect) or -1) >= 0 and tonumber(layer.effect) + 1 or nil
      local missile = (tonumber(layer.missile) or -1) >= 0 and tonumber(layer.missile) + 1 or nil
      if effect and not SpellDemoFxEffects[effect] then effect = nil end
      if missile and not SpellDemoFxMissiles[missile] then missile = nil end
      local step = tonumber(layer.step) or 0
      local chance = tonumber(layer.chance) or 100
      for rep = 0, math.max(1, math.min(50, tonumber(layer.repeats) or 1)) - 1 do
        local base = (tonumber(layer.delay) or 0) + rep * (tonumber(layer.interval) or 0)
        local order = {}
        for i, t in ipairs(layer.tiles) do order[i] = tonumber(t[3]) or 0 end
        if layer.random then
          for i = #order, 2, -1 do
            local j = rnd.int(i)
            order[i], order[j] = order[j], order[i]
          end
        end
        for i, t in ipairs(layer.tiles) do
          if chance >= 100 or rnd.int(100) <= chance then
            local x, y = tonumber(t[1]) or 0, tonumber(t[2]) or 0
            local at = base + order[i] * step
            local land = at
            if missile then
              local spread = math.max(0, math.min(10, tonumber(layer.spread) or 0))
              local fx, fy = 0, 0
              if layer.origin == 'sky' then
                fx = x + (tonumber(layer.skyX) or 0) + rnd.int(-spread, spread)
                fy = y + (tonumber(layer.skyY) or 0) + rnd.int(-spread, spread)
              elseif layer.origin == 'around' then
                local a = rnd.float() * 2 * math.pi
                local d = math.max(1, spread)
                fx, fy = x + math.floor(math.cos(a) * d + 0.5), y + math.floor(math.sin(a) * d + 0.5)
              end
              local tx, ty = x, y
              if layer.reverse then fx, fy, tx, ty = x, y, fx, fy end
              if fx ~= tx or fy ~= ty then
                local duration = flight(fx, fy, tx, ty)
                if add({at = at, missile = missile, from = {fx, fy}, to = {tx, ty}, duration = duration}) then
                  finish = math.max(finish, at + duration)
                end
                if layer.waitMissile and not layer.reverse then land = at + duration end
              end
            end
            if effect then
              local length = 0
              for _, ms in ipairs(SpellDemoFxEffects[effect][7]) do length = length + ms end
              if add({at = land, effect = effect, x = x, y = y}) then
                finish = math.max(finish, land + length)
              end
            end
          end
        end
      end
    end
  end
  table.sort(events, function(a, b) return a.at < b.at end)
  return events, finish
end

-- info: SpellWindowInfo of the spell (the tiles it hits, its radius); design: SPELLFX_DESIGNS[info.design]
function SpellDemoPlayer:playDesign(design, info)
  self:stop()
  if type(design) ~= 'table' or type(SpellDemoFxEffects) ~= 'table' then return false end
  self.design = design
  self.round = 0

  local hit, reach = {}, math.max(2, tonumber(info and info.radius) or 2)
  local flat = info and info.tiles or {}
  for i = 1, #flat - 1, 2 do
    hit[flat[i] .. ',' .. flat[i + 1]] = {flat[i], flat[i + 1]}
  end
  for _, layer in ipairs(design) do
    for _, t in ipairs(type(layer) == 'table' and type(layer.tiles) == 'table' and layer.tiles or {}) do
      reach = math.max(reach, math.abs(tonumber(t[1]) or 0), math.abs(tonumber(t[2]) or 0))
    end
  end
  reach = math.min(reach, 8)

  local width, height = self.panel:getWidth(), self.panel:getHeight()
  self.tile = math.max(8, math.min(32, math.floor(math.min(width, height) / (2 * reach + 2))))
  self.originX = math.floor(width / 2 - self.tile / 2)
  self.originY = math.floor(height / 2 - self.tile / 2)

  -- the scene: floor, the tinted tiles the spell hits, the caster and the monsters
  self:clear({'floor', 'items', 'creatures', 'effects'})
  local t = self.tile
  for y = -math.ceil(self.originY / t), math.ceil((height - self.originY) / t) do
    for x = -math.ceil(self.originX / t), math.ceil((width - self.originX) / t) do
      self:place(g_ui.createWidget('SpellDemoFloor', self.layers.floor), x, y)
    end
  end
  for _, tile in pairs(hit) do
    self:place(g_ui.createWidget('SpellDemoArea', self.layers.floor), tile[1], tile[2])
  end
  local creatures = {{0, 0, 'caster'}}
  for _, m in ipairs(monsterTiles(hit, tonumber(info and info.radius) or 2)) do
    table.insert(creatures, {m[1], m[2], 'monster'})
  end
  self:drawDesignCreatures(creatures)
  self:startDesignRound()
  return true
end

function SpellDemoPlayer:drawDesignCreatures(list)
  local t = self.tile
  for _, c in ipairs(list) do
    local widget = g_ui.createWidget('SpellDemoCreature', self.layers.creatures)
    local outfit = c[3] == 'monster' and MONSTER or nil
    if not outfit then
      local localPlayer = g_game.getLocalPlayer()
      local ok, own = pcall(function() return localPlayer and localPlayer:getOutfit() end)
      outfit = ok and type(own) == 'table' and own or FRIEND
    end
    widget:setOutfit(outfit)
    if widget.setDirection then
      widget:setDirection(Directions.South)
    end
    local size = math.floor(t * 1.5)
    local shift = math.floor(t / 4)
    widget:setSize({width = size, height = size})
    widget:setMarginLeft(self.originX + c[1] * t - shift)
    widget:setMarginTop(self.originY + c[2] * t - shift)
  end
end

function SpellDemoPlayer:startDesignRound()
  self:clear({'effects'})
  self.round = (self.round or 0) + 1
  local events, finish = self:designTimeline(self.design, 4242)
  self.events = events
  self.nextEvent = 1
  self.live = {}
  self.start = g_clock.millis()
  self.restartAt = self.start + finish + HOLD
  removeEvent(self.event)
  self.event = cycleEvent(function() self:update() end, TICK)
  self:updateDesign()
end

-- a thing of the sheets at its own size, scaled to the demo's tiles: its frame's bottom right on the tile's bottom right
function SpellDemoPlayer:placeFx(widget, x, y, fw, fh)
  local t = self.tile
  local w, h = math.floor(fw * t / 32 + 0.5), math.floor(fh * t / 32 + 0.5)
  widget:setSize({width = w, height = h})
  widget:setMarginLeft(math.floor(self.originX + (x + 1) * t - w))
  widget:setMarginTop(math.floor(self.originY + (y + 1) * t - h))
end

function SpellDemoPlayer:updateDesign()
  if not self.design or self.panel:isDestroyed() then
    removeEvent(self.event)
    self.event = nil
    return
  end
  local now = g_clock.millis()
  local elapsed = now - self.start

  while self.nextEvent <= #self.events and self.events[self.nextEvent].at <= elapsed do
    local e = self.events[self.nextEvent]
    self.nextEvent = self.nextEvent + 1
    local widget = g_ui.createWidget('SpellDemoEffect', self.layers.effects)
    if e.effect then
      widget:setImageSource(FX_EFFECTS)
      widget:hide()
      table.insert(self.live, {widget = widget, effect = SpellDemoFxEffects[e.effect], x = e.x, y = e.y, start = e.at,
                               phase = -1})
    else
      local m = SpellDemoFxMissiles[e.missile]
      local d = missileDirection(e.to[1] - e.from[1], e.to[2] - e.from[2])
      widget:setImageSource(FX_MISSILES)
      widget:setImageClip({x = m[1] + d * m[3], y = m[2], width = m[3], height = m[4]})
      table.insert(self.live, {widget = widget, missile = m, from = e.from, to = e.to, start = e.at,
                               duration = math.max(1, e.duration)})
    end
  end

  for i = #self.live, 1, -1 do
    local l = self.live[i]
    local done = false
    if l.effect then
      local fx = l.effect
      local at, phase = elapsed - l.start, nil
      for p, ms in ipairs(fx[7]) do
        if at < ms then phase = p - 1 break end
        at = at - ms
      end
      if not phase then
        done = true
      elseif phase ~= l.phase then
        l.phase = phase
        local perRow = math.max(1, fx[6])
        l.widget:setImageClip({x = fx[1] + (phase % perRow) * fx[3], y = fx[2] + math.floor(phase / perRow) * fx[4],
                               width = fx[3], height = fx[4]})
        self:placeFx(l.widget, l.x, l.y, fx[3], fx[4])
        l.widget:show()
      end
    else
      local f = (elapsed - l.start) / l.duration
      if f >= 1 then
        done = true
      else
        local x = l.from[1] + (l.to[1] - l.from[1]) * f
        local y = l.from[2] + (l.to[2] - l.from[2]) * f
        self:placeFx(l.widget, x, y, l.missile[3], l.missile[4])
      end
    end
    if done then
      l.widget:destroy()
      table.remove(self.live, i)
    end
  end

  if now >= self.restartAt then
    self:startDesignRound()
  end
end
