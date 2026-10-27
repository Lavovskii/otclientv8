-- Plays a spell demo (SpellDemos, written by tools/gen_spell_demos.py) on a small grid of floor tiles: the caster, the
-- target, the missiles, the magic effects of every wave and the field left behind, drawn with the client's own sprites
-- (data/images/game/spelldemo, made by tools/gen_spell_demo_sprites.py). The demo repeats until it is stopped.

SpellDemoPlayer = {}
SpellDemoPlayer.__index = SpellDemoPlayer

local EFFECT_TICKS = 75      -- ms per effect phase, as the client draws effects on the map
local HOLD = 1300            -- ms the result stays before the demo starts again
local TICK = 30
local MONSTER = {type = 15, head = 20, body = 30, legs = 40, feet = 50}   -- a troll
local FRIEND = {type = 128, head = 78, body = 69, legs = 58, feet = 76}   -- a citizen
-- missile sprite of each direction, in the order of the missiles sheet (the 3x3 patterns of the client)
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

local function effectClip(id, phase)
  local block = math.floor((id - 1) / SpellDemoEffectRows)
  local row = (id - 1) % SpellDemoEffectRows
  return {x = (block * SpellDemoEffectColumns + phase) * 64, y = row * 64, width = 64, height = 64}
end

-- the tiles of a flat {x1, y1, x2, y2, ...} list
local function eachTile(flat, fn)
  for i = 1, #flat - 1, 2 do
    fn(flat[i], flat[i + 1])
  end
end

function SpellDemoPlayer.create(panel)
  local player = setmetatable({}, SpellDemoPlayer)
  player.panel = panel
  player.layers = {}
  for _, name in ipairs({'floor', 'items', 'creatures', 'effects'}) do
    local layer = g_ui.createWidget('SpellDemoLayer', panel)
    player.layers[name] = layer
  end
  return player
end

function SpellDemoPlayer:clear(layerNames)
  for _, name in ipairs(layerNames) do
    self.layers[name]:destroyChildren()
  end
end

function SpellDemoPlayer:stop()
  removeEvent(self.event)
  self.event = nil
  self.demo = nil
  self:clear({'floor', 'items', 'creatures', 'effects'})
end

-- the size of a tile and the pixel position of tile 0, 0, so that everything the demo shows fits and is centred
function SpellDemoPlayer:layout(demo)
  local minX, maxX, minY, maxY = 0, 0, 0, 0
  local function add(x, y)
    minX, maxX = math.min(minX, x), math.max(maxX, x)
    minY, maxY = math.min(minY, y), math.max(maxY, y)
  end
  for _, c in ipairs(demo.creatures or {}) do add(c[1], c[2]) end
  for _, s in ipairs(demo.shots or {}) do add(s[1], s[2]) add(s[3], s[4]) end
  for _, w in ipairs(demo.waves or {}) do eachTile(w[3], add) end
  if demo.field then eachTile(demo.field[2], add) end

  local width, height = self.panel:getWidth(), self.panel:getHeight()
  local tiles = math.max(maxX - minX + 1, maxY - minY + 1) + 2
  self.tile = math.min(32, math.floor(math.min(width, height) / math.max(tiles, 7)))
  self.originX = math.floor(width / 2 - ((minX + maxX) / 2 + 0.5) * self.tile)
  self.originY = math.floor(height / 2 - ((minY + maxY) / 2 + 0.5) * self.tile)
end

function SpellDemoPlayer:place(widget, x, y, size)
  widget:setSize({width = size or self.tile, height = size or self.tile})
  widget:setMarginLeft(self.originX + x * self.tile - ((size or self.tile) - self.tile))
  widget:setMarginTop(self.originY + y * self.tile - ((size or self.tile) - self.tile))
end

function SpellDemoPlayer:drawScene(demo)
  self:clear({'floor', 'items', 'creatures', 'effects'})
  local t = self.tile
  local width, height = self.panel:getWidth(), self.panel:getHeight()
  local firstX = -math.ceil(self.originX / t)
  local firstY = -math.ceil(self.originY / t)
  local lastX = math.ceil((width - self.originX) / t)
  local lastY = math.ceil((height - self.originY) / t)
  for y = firstY, lastY do
    for x = firstX, lastX do
      self:place(g_ui.createWidget('SpellDemoFloor', self.layers.floor), x, y)
    end
  end

  -- the area: every tile some wave hits is tinted, so the shape stays visible between the effects
  local area = {}
  for _, w in ipairs(demo.waves or {}) do
    eachTile(w[3], function(x, y) area[x .. ',' .. y] = {x, y} end)
  end
  if demo.field then
    eachTile(demo.field[2], function(x, y) area[x .. ',' .. y] = {x, y} end)
  end
  for _, tile in pairs(area) do
    self:place(g_ui.createWidget('SpellDemoArea', self.layers.floor), tile[1], tile[2])
  end

  for _, c in ipairs(demo.creatures or {}) do
    local widget = g_ui.createWidget('SpellDemoCreature', self.layers.creatures)
    local outfit = c[3] == 'monster' and MONSTER or c[3] == 'friend' and FRIEND or nil
    if not outfit then
      local localPlayer = g_game.getLocalPlayer()
      outfit = localPlayer and localPlayer:getOutfit() or FRIEND
    end
    widget:setOutfit(outfit)
    if widget.setDirection then
      widget:setDirection(c[3] == 'caster' and Directions.North or Directions.South)
    end
    -- the outfit is drawn in the middle of the widget: a widget of two tiles centred on the creature's tile
    widget:setSize({width = t * 2, height = t * 2})
    widget:setMarginLeft(self.originX + c[1] * t - math.floor(t / 2))
    widget:setMarginTop(self.originY + c[2] * t - math.floor(t / 2))
  end
end

function SpellDemoPlayer:play(demo)
  self:stop()
  if not demo then return end
  self.demo = demo
  self:layout(demo)
  self:drawScene(demo)
  self:startLoop()
end

-- one round of the demo: the shots fly, then the waves go off and the field appears, then everything rests a moment
function SpellDemoPlayer:startLoop()
  local demo = self.demo
  self:clear({'items', 'effects'})
  local now = g_clock.millis()
  local land = 0
  self.shots = {}
  for _, s in ipairs(demo.shots or {}) do
    local dx, dy = s[3] - s[1], s[4] - s[2]
    local duration = math.floor(150 * math.sqrt(math.sqrt(dx * dx + dy * dy)))
    local widget = g_ui.createWidget('SpellDemoMissile', self.layers.effects)
    local d = missileDirection(dx, dy)
    widget:setImageClip({x = d * 32, y = (s[5] - 1) * 32, width = 32, height = 32})
    widget:hide()
    table.insert(self.shots, {widget = widget, from = {s[1], s[2]}, delta = {dx, dy}, start = now, duration = duration})
    land = math.max(land, duration)
  end

  self.pending = {}
  local finish = land
  for _, w in ipairs(demo.waves or {}) do
    local phases = SpellDemoEffectPhases[w[2]] or 1
    table.insert(self.pending, {at = now + land + w[1], effect = w[2], tiles = w[3], phases = phases})
    finish = math.max(finish, land + w[1] + phases * EFFECT_TICKS)
  end
  if demo.field then
    table.insert(self.pending, {at = now + land, field = demo.field[1], tiles = demo.field[2]})
  end
  self.effects = {}
  self.restartAt = now + finish + HOLD
  removeEvent(self.event)
  self.event = cycleEvent(function() self:update() end, TICK)
  self:update()
end

function SpellDemoPlayer:update()
  if not self.demo or self.panel:isDestroyed() then
    removeEvent(self.event)
    self.event = nil
    return
  end
  local now = g_clock.millis()
  local t = self.tile

  for _, shot in ipairs(self.shots) do
    if shot.widget and not shot.widget:isDestroyed() then
      local f = (now - shot.start) / math.max(shot.duration, 1)
      if f >= 1 then
        shot.widget:destroy()
        shot.widget = nil
      else
        shot.widget:show()
        shot.widget:setSize({width = t, height = t})
        shot.widget:setMarginLeft(math.floor(self.originX + (shot.from[1] + shot.delta[1] * f) * t))
        shot.widget:setMarginTop(math.floor(self.originY + (shot.from[2] + shot.delta[2] * f) * t))
      end
    end
  end

  for i = #self.pending, 1, -1 do
    local p = self.pending[i]
    if now >= p.at then
      table.remove(self.pending, i)
      eachTile(p.tiles, function(x, y)
        if p.field then
          local item = g_ui.createWidget('SpellDemoItem', self.layers.items)
          item:setItemId(p.field)
          self:place(item, x, y)
        else
          local widget = g_ui.createWidget('SpellDemoEffect', self.layers.effects)
          self:place(widget, x, y, t * 2)
          table.insert(self.effects, {widget = widget, id = p.effect, start = p.at, phases = p.phases, phase = -1})
        end
      end)
    end
  end

  for i = #self.effects, 1, -1 do
    local e = self.effects[i]
    local phase = math.floor((now - e.start) / EFFECT_TICKS)
    if phase >= e.phases then
      e.widget:destroy()
      table.remove(self.effects, i)
    elseif phase ~= e.phase then
      e.phase = phase
      e.widget:setImageClip(effectClip(e.id, phase))
    end
  end

  if now >= self.restartAt then
    self:startLoop()
  end
end
