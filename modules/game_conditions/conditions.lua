-- The player's conditions (the owner, 2026-11-16): 8 control conditions, 7 debuffs and 5 buffs that spells put on a creature (the
-- server's data/lib/143-conditions.lua, the engine's CONDITION_CONTROL and CONDITION_STATUS). The server sends extended opcode 42 to
-- the player alone each time the list changes, and at login:
--   S|key:ms:value:max;key:ms:value:max;...      S| when there is none
-- ms is the time left (-1: no end), value the percent (the Barrier: the damage it still absorbs) and max the Barrier's starting
-- absorb (0 for the others). The whole list comes each time; between two messages the seconds are counted here.
--
-- What shows: a row of icons at the top of the map, centred on it (under the health and mana bars of the map's top when they show),
-- control first, then debuffs, then buffs. Under each icon the seconds left, and a dark part grows from its top as the time runs
-- out; the Barrier has a bar of what it still absorbs. The mouse over an icon gives its name (in the client's language, the other
-- language in brackets) and what it does with its value. While Blind is on, the map darkens from its edges, more with a higher
-- value (40 is strong but playable), fading in and out; the darkness lies under the other things drawn on the map (the circles,
-- the frame rate plate), only the world goes dark. Pictures: tools/make_condition_icons.py.
local OPCODE = 42
local MAX_MESSAGE = 4096
local MAX_ENTRIES = 40
local MAX_MS = 24 * 3600 * 1000
local MAX_VALUE = 2000000000
local TICK = 100 -- ms between two redraws of the seconds
local FADE = 450 -- ms of the blind darkness from nothing to full and back
local ICON_SIZE = 32
local CELL_W, CELL_H, GAP = 34, 55, 4
local TOP = 6 -- under the map's top edge
local SIDE_ROOM = 112 -- the frame rate plate in the map's corner: a long row breaks into lines before it gets there
local SOON = 3000 -- the last seconds are written in orange
local TIME_COLOR, SOON_COLOR = '#f0e6cc', '#ff9a5a'
local ICONS = '/modules/game_conditions/icons/'

-- the order of the spec: control, then debuffs, then buffs. pt and en: the name and what it does (%d the value)
local LIST = {
  {'stun', 'control', 'Atordoado', 'Stunned',
   'N\227o anda, n\227o ataca, n\227o lan\231a spells nem usa itens, n\227o recebe cura.',
   'Cannot walk, attack, cast spells or use items, and gets no healing.'},
  {'frozen', 'control', 'Congelado', 'Frozen',
   'N\227o anda nem recebe cura (nem lan\231a spells de cura). Pode atacar e lan\231ar spells de ataque. Dano de fogo parte o gelo.',
   'Cannot walk or be healed (nor cast healing spells). Can attack and cast attack spells. Fire damage breaks the ice.'},
  {'root', 'control', 'Enraizado', 'Rooted',
   'N\227o anda. Pode atacar, lan\231ar spells e curar.',
   'Cannot walk. Can attack, cast spells and heal.'},
  {'silence', 'control', 'Silenciado', 'Silenced',
   'N\227o lan\231a spells nem runas. Anda e ataca com a arma.',
   'Cannot cast spells or use runes. Can walk and attack with the weapon.'},
  {'disarm', 'control', 'Desarmado', 'Disarmed',
   'N\227o ataca com a arma. Pode lan\231ar spells.',
   'Cannot attack with the weapon. Can cast spells.'},
  {'sleep', 'control', 'Adormecido', 'Asleep',
   'N\227o anda, n\227o ataca, n\227o lan\231a spells nem usa itens. Acorda ao primeiro dano.',
   'Cannot walk, attack, cast spells or use items. Wakes up at the first damage.'},
  {'fear', 'control', 'Medo', 'Feared',
   'Foge de quem o assustou, sem controlar o movimento; n\227o ataca nem lan\231a spells.',
   'Runs away from whoever scared you, out of your control; cannot attack or cast spells.'},
  {'taunt', 'control', 'Provocado', 'Taunted',
   'S\243 pode atacar quem o provocou.',
   'Can only attack whoever taunted you.'},
  {'vulnerable', 'debuff', 'Exposto', 'Vulnerable',
   'Recebe +%d%% de dano de tudo.',
   'Takes +%d%% damage from everything.'},
  {'weakened', 'debuff', 'Enfraquecido', 'Weakened',
   'Causa -%d%% de dano.',
   'Deals -%d%% damage.'},
  {'mortalwound', 'debuff', 'Ferida grave', 'Mortal Wound',
   'Curas recebidas -%d%%.',
   'Healing received -%d%%.'},
  {'manaburn', 'debuff', 'Queima de mana', 'Mana Burn',
   'Perde %d%% da mana m\225xima a cada segundo.',
   'Loses %d%% of the maximum mana every second.'},
  {'armorbreak', 'debuff', 'Armadura partida', 'Armor Break',
   'Armor e defesa -%d%%.',
   'Armor and defence -%d%%.'},
  {'blind', 'debuff', 'Cego', 'Blind',
   'O ecr\227 escurece; os ataques da arma \224 dist\226ncia falham %d%% das vezes.',
   'The screen darkens; distance weapon attacks miss %d%% of the time.'},
  {'marked', 'debuff', 'Marcado', 'Marked',
   'O pr\243ximo golpe recebido tira +%d%%; n\227o pode ficar invis\237vel.',
   'The next hit taken deals +%d%%; cannot turn invisible.'},
  {'shield', 'buff', 'Barreira', 'Barrier',
   'Absorve dano antes da vida: faltam %s de %s.',
   'Absorbs damage before health: %s of %s left.'},
  {'reflect', 'buff', 'Espinhos', 'Thorns',
   'Devolve %d%% do dano corpo a corpo a quem bateu.',
   'Returns %d%% of the melee damage to the attacker.'},
  {'lifesteal', 'buff', 'Roubo de vida', 'Lifesteal',
   '%d%% do dano causado volta como vida.',
   '%d%% of the damage dealt comes back as health.'},
  {'fortified', 'buff', 'Fortalecido', 'Fortified',
   'Recebe -%d%% de dano.',
   'Takes -%d%% damage.'},
  {'unstoppable', 'buff', 'Impar\225vel', 'Unstoppable',
   'Imune a todo o controlo e a paralyze; tira os que tiver.',
   'Immune to every control and to paralyze; removes the ones it had.'},
}
local INFO = {}
for index, e in ipairs(LIST) do
  INFO[e[1]] = {index = index, group = e[2], pt = e[3], en = e[4], ptText = e[5], enText = e[6]}
end

-- the module's widgets (globals of the module: modules.game_conditions.row for a look from the terminal)
row = nil
vignette = nil

local state = {} -- key -> {value, max, endsAt (nil: no end), total}
local cells = {} -- key -> its ConditionCell
local order = {} -- the keys shown, in order
local tickEvent, fadeEvent
local opacity, target = 0, 0
local errorLogged = false

local function logError(err)
  if not errorLogged then
    errorLogged = true
    g_logger.error('[game_conditions] ' .. tostring(err))
  end
end

local function safe(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then logError(err) end
end

local function clamp(v, low, high)
  v = tonumber(v) or low
  if v ~= v then return low end -- NaN
  return math.max(low, math.min(high, v))
end

local function alive(widget)
  return widget and not widget:isDestroyed()
end

local function mapPanel()
  return modules.game_interface and modules.game_interface.getMapPanel()
end

-- the client's language: Portuguese when it is chosen, English otherwise
local function language()
  local ok, locale = pcall(function() return modules.client_locales.getCurrentLocale() end)
  return (ok and type(locale) == 'table' and locale.name == 'pt') and 'pt' or 'en'
end

-- the tooltip has no wrapping of its own
local function wrap(text, width)
  local lines, current = {}, ''
  for word in text:gmatch('%S+') do
    if current == '' then
      current = word
    elseif #current + 1 + #word <= width then
      current = current .. ' ' .. word
    else
      table.insert(lines, current)
      current = word
    end
  end
  if current ~= '' then table.insert(lines, current) end
  return table.concat(lines, '\n')
end

local function timeLeft(c, now)
  if not c.endsAt then return nil end
  return math.max(0, c.endsAt - now)
end

local function tooltipText(key, c, left)
  local info = INFO[key]
  local lang = language()
  local name = lang == 'pt' and (info.pt .. ' (' .. info.en .. ')') or (info.en .. ' (' .. info.pt .. ')')
  local text = lang == 'pt' and info.ptText or info.enText
  if key == 'shield' then
    local max = c.max > 0 and c.max or c.value
    local still, from = comma_value(math.floor(c.value)), comma_value(math.floor(max))
    if lang == 'pt' then
      still, from = still:gsub(',', '.'), from:gsub(',', '.')
    end
    text = string.format(text, still, from)
  elseif text:find('%%d') then
    text = string.format(text, math.floor(c.value))
  end
  local time
  if not left then
    time = lang == 'pt' and 'Sem fim' or 'No end'
  else
    local seconds = math.ceil(left / 1000)
    time = lang == 'pt' and ('Termina em ' .. seconds .. ' s') or (seconds .. ' s left')
  end
  return name .. '\n' .. wrap(text, 50) .. '\n' .. time
end

-- the seconds under an icon: 12s, past a minute 3m
local function shortTime(left)
  if not left then return '' end
  local seconds = math.ceil(left / 1000)
  if seconds >= 60 then return math.ceil(seconds / 60) .. 'm' end
  return seconds .. 's'
end

-- the tooltip on the screen follows the text while the mouse stays on the icon (g_tooltip.display would fade it in again)
local function refreshTooltip(text)
  local label = rootWidget and rootWidget:getChildById('toolTip')
  if not label or not label:isVisible() or label:getText() == text then return end
  label:setText(text)
  label:resizeToText()
  label:resize(label:getWidth() + 8, label:getHeight() + 6)
end

-- the message -------------------------------------------------------------------------------------------------------------

-- the list of the message, or nil when it is not one; unknown keys and bad numbers are left out
local function parse(buffer)
  buffer = tostring(buffer or '')
  if #buffer > MAX_MESSAGE then buffer = buffer:sub(1, MAX_MESSAGE) end
  local body = buffer:match('^S|(.*)$')
  if not body then return nil end
  local list, seen = {}, {}
  for part in body:gmatch('[^;]+') do
    if #list >= MAX_ENTRIES then break end
    local key, ms, value, max = part:match('^%s*(%w+):(%-?%d+):?(%-?%d*):?(%-?%d*)%s*$')
    key = key and key:lower()
    if key and INFO[key] and not seen[key] then
      seen[key] = true
      ms = tonumber(ms) or 0
      if ms < 0 then
        ms = -1
      else
        ms = clamp(ms, 0, MAX_MS)
      end
      if ms ~= 0 then
        table.insert(list, {key = key, ms = ms, value = clamp(value, 0, MAX_VALUE), max = clamp(max, 0, MAX_VALUE)})
      end
    end
  end
  return list
end

-- drawing -----------------------------------------------------------------------------------------------------------------

local function topOfRow(rect)
  local top = rect.y + TOP
  -- under the health and mana bars at the top of the map, when the options show them
  local info = modules.game_healthinfo
  local bar = info and info.topHealthBar
  if alive(bar) and alive(row) and bar:isVisible() and row:getParent() == mapPanel() then
    top = math.max(top, bar:getY() + bar:getHeight() + TOP)
  end
  return top
end

function place()
  if not alive(row) or not modules.game_interface then return end
  local rect = modules.game_interface.getMapRect()
  if alive(vignette) then vignette:setRect(rect) end
  local n = #order
  if n == 0 then
    row:hide()
    return
  end
  local perLine = math.max(1, math.floor((rect.width - 2 * SIDE_ROOM + GAP) / (CELL_W + GAP)))
  perLine = math.min(perLine, n)
  local lines = math.ceil(n / perLine)
  local width = perLine * CELL_W + (perLine - 1) * GAP
  for i, key in ipairs(order) do
    local cell = cells[key]
    if alive(cell) then
      local line = math.floor((i - 1) / perLine)
      local column = (i - 1) % perLine
      local inLine = math.min(perLine, n - line * perLine) -- the last line is centred too
      local lineWidth = inLine * CELL_W + (inLine - 1) * GAP
      cell:setMarginLeft(math.floor((width - lineWidth) / 2) + column * (CELL_W + GAP))
      cell:setMarginTop(line * (CELL_H + GAP))
    end
  end
  row:setRect({x = rect.x + math.floor((rect.width - width) / 2), y = topOfRow(rect), width = width, height = lines * (CELL_H + GAP) - GAP})
  row:show()
end

local function drawCell(key, now)
  local cell, c = cells[key], state[key]
  if not alive(cell) or not c then return end
  local left = timeLeft(c, now)
  local text = shortTime(left)
  if cell.shownText ~= text then
    cell.shownText = text
    cell.time:setText(text)
    cell.time:setVisible(text ~= '')
  end
  local color = (left and left <= SOON) and SOON_COLOR or TIME_COLOR
  if cell.shownColor ~= color then
    cell.shownColor = color
    cell.time:setColor(color)
  end
  local drain = 0
  if left and c.total and c.total > 0 then
    drain = math.floor(ICON_SIZE * (1 - left / c.total) + 0.5)
  end
  drain = clamp(drain, 0, ICON_SIZE)
  if cell.shownDrain ~= drain then
    cell.shownDrain = drain
    cell.frame.drain:setHeight(drain)
  end
  if key == 'shield' then
    local max = c.max > 0 and c.max or math.max(1, c.value)
    local width = math.floor((CELL_W - 4) * clamp(c.value / max, 0, 1) + 0.5)
    if cell.shownAbsorb ~= width then
      cell.shownAbsorb = width
      cell.absorb.fill:setWidth(width)
    end
    if not cell.absorb:isExplicitlyVisible() then cell.absorb:show() end
  end
  local tip = tooltipText(key, c, left)
  if cell.shownTip ~= tip then
    cell.shownTip = tip
    cell.frame:setTooltip(tip)
    if cell.frame:isHovered() then refreshTooltip(tip) end
  end
end

-- the blind darkness: from nothing to its strength over FADE ms, and back
local function strength(value)
  return clamp((tonumber(value) or 0) / 50, 0.15, 0.92)
end

local function fadeTo(value)
  target = value
  if fadeEvent or not alive(vignette) then return end
  if target > 0 then
    vignette:show()
    local panel = mapPanel()
    -- under everything else on the map: only the world goes dark
    if panel and vignette:getParent() == panel then panel:moveChildToIndex(vignette, 1) end
    place()
  end
  local last = g_clock.millis()
  local function step()
    fadeEvent = nil
    if not alive(vignette) then return end
    local now = g_clock.millis()
    local delta = (now - last) / FADE
    last = now
    if opacity < target then
      opacity = math.min(target, opacity + delta)
    else
      opacity = math.max(target, opacity - delta)
    end
    vignette:setOpacity(opacity)
    if opacity ~= target then
      fadeEvent = scheduleEvent(function() safe(step) end, 30)
    elseif opacity == 0 then
      vignette:hide()
    end
  end
  fadeEvent = scheduleEvent(function() safe(step) end, 30)
end

local function hasTimers()
  for _, c in pairs(state) do
    if c.endsAt then return true end
  end
  return false
end

local tick

-- the cells follow the list: the ended ones go, the new ones come, all in order
local function rebuild()
  if not alive(row) then return end
  for key, cell in pairs(cells) do
    if not state[key] then
      if alive(cell) then
        if cell.frame:isHovered() then g_tooltip.hide() end
        cell:destroy()
      end
      cells[key] = nil
    end
  end
  order = {}
  for key in pairs(state) do table.insert(order, key) end
  table.sort(order, function(a, b) return INFO[a].index < INFO[b].index end)
  for _, key in ipairs(order) do
    if not alive(cells[key]) then
      local cell = g_ui.createWidget('ConditionCell', row)
      cell:setId('condition_' .. key)
      cell.frame.icon:setImageSource(ICONS .. key)
      cells[key] = cell
    end
  end
  place()
  local now = g_clock.millis()
  for _, key in ipairs(order) do drawCell(key, now) end
  fadeTo(state.blind and strength(state.blind.value) or 0)
  if not tickEvent and hasTimers() then
    tickEvent = scheduleEvent(function() safe(tick) end, TICK)
  end
end

tick = function()
  tickEvent = nil
  local now = g_clock.millis()
  local ended = false
  for key, c in pairs(state) do
    if c.endsAt and c.endsAt <= now then
      state[key] = nil
      ended = true
    end
  end
  if ended then
    rebuild()
  else
    for _, key in ipairs(order) do drawCell(key, now) end
  end
  if not tickEvent and hasTimers() then
    tickEvent = scheduleEvent(function() safe(tick) end, TICK)
  end
end

local function onConditions(protocol, opcode, buffer)
  local list = parse(buffer)
  if not list then return end
  local now = g_clock.millis()
  local fresh = {}
  for _, e in ipairs(list) do
    local old = state[e.key]
    local c = {value = e.value, max = e.max}
    if e.ms > 0 then
      c.endsAt = now + e.ms
      -- the same condition going on: the dark part keeps its pace; a longer time than was left is a new one (refreshed)
      local oldLeft = old and old.endsAt and (old.endsAt - now)
      if old and old.total and oldLeft and e.ms <= oldLeft + 300 then
        c.total = math.max(old.total, e.ms)
      else
        c.total = e.ms
      end
    end
    fresh[e.key] = c
  end
  state = fresh
  rebuild()
end

-- everything off at once: logout, game end, a new login
local function clear()
  state, order = {}, {}
  removeEvent(tickEvent)
  removeEvent(fadeEvent)
  tickEvent, fadeEvent = nil, nil
  for key, cell in pairs(cells) do
    if alive(cell) then cell:destroy() end
  end
  cells = {}
  opacity, target = 0, 0
  if alive(vignette) then
    vignette:setOpacity(0)
    vignette:hide()
  end
  if alive(row) then row:hide() end
end

local function onPlace()
  safe(place)
end

-- for the window preview and tests (terminal): modules.game_conditions.preview('S|stun:2000:0:0;shield:10000:3200:5000')
function preview(data)
  safe(onConditions, nil, OPCODE, data)
end

-- the window preview has no map to draw on: it puts the row and the darkness on its stand-in
function previewParent(parent)
  if not alive(row) or not alive(vignette) or not parent then return end
  vignette:setParent(parent)
  row:setParent(parent)
  vignette:raise()
  row:raise()
  safe(place)
end

function init()
  g_ui.importStyle('conditions')
  local panel = mapPanel()
  vignette = g_ui.createWidget('ConditionVignette', panel)
  vignette:setId('conditionVignette')
  row = g_ui.createWidget('ConditionRow', panel)
  row:setId('conditionRow')
  ProtocolGame.registerExtendedOpcode(OPCODE, function(protocol, opcode, buffer) safe(onConditions, protocol, opcode, buffer) end)
  connect(g_game, {onGameStart = clear, onGameEnd = clear})
  connect(panel, {onGeometryChange = onPlace, onVisibleDimensionChange = onPlace})
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameStart = clear, onGameEnd = clear})
  local panel = mapPanel()
  if panel then disconnect(panel, {onGeometryChange = onPlace, onVisibleDimensionChange = onPlace}) end
  clear()
  if alive(row) then row:destroy() end
  if alive(vignette) then vignette:destroy() end
  row, vignette = nil, nil
end
