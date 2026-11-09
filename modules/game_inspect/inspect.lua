-- Inspect (right click on a player or a monster > Inspect). The server (game.cpp inspectCreature) answers extended opcode 33:
--   P|id|name|level|vocation|health|max|mana|max|magic level|speed|soul     a player, then
--   K|skill|level      Q|slot|clientId|name|count      key=value lines of the Skills window (absorb=, increment=, attack=...)
--   M|id|name|level    a monster, then   L|clientId|name   one per item it may drop (no chances)
local OPCODE = 33
local SKILLS = {'Fist Fighting', 'Club Fighting', 'Sword Fighting', 'Axe Fighting', 'Distance Fighting', 'Shielding', 'Fishing'}
local SLOT_NAMES = {'Helmet', 'Necklace', 'Backpack', 'Armor', 'Right hand', 'Left hand', 'Legs', 'Boots', 'Ring', 'Ammo'}
local ELEMENTS = {[1] = 'Physical', [2] = 'Energy', [4] = 'Earth', [8] = 'Fire', [32] = 'Life Drain', [64] = 'Mana Drain',
  [256] = 'Drown', [512] = 'Ice', [1024] = 'Holy', [2048] = 'Death'}

local window

local function split(line)
  local parts = {}
  for part in (line .. '|'):gmatch('([^|]*)|') do
    parts[#parts + 1] = part
  end
  return parts
end

local function money(n)
  return comma_value(tonumber(n) or 0)
end

-- the tiles of the player page: an icon (an item sprite, or a picture), the value, a small name under it
local SKILL_ICONS = {nil, 3286, 3264, 3274, 3350, 3409, 3483}   -- fist has a picture of its own
local ELEMENT_ICONS = {[1] = 3264, [8] = 3191, [4] = 3175, [2] = 3198, [512] = 3161, [1024] = 3182, [2048] = 3155,
  [256] = 110, [32] = 3039, [64] = 3036}
local GOOD, BAD, GOLD = '#7fd36a', '#e05a4a', '#e8c66a'

local function section(text)
  local l = g_ui.createWidget('InspectSection', window.playerPanel.stats)
  l:setText(text)
end

local function grid(style)
  return g_ui.createWidget(style or 'InspectGrid', window.playerPanel.stats)
end

local function tile(parent, icon, value, name, color, tooltip)
  local t = g_ui.createWidget('InspectTile', parent)
  if type(icon) == 'number' then
    t.icon:setItemId(icon)
  elseif type(icon) == 'string' then
    t.icon:setVisible(false)
    t.image:setVisible(true)
    t.image:setImageSource(icon)
  end
  t.value:setText(value)
  if color then t.value:setColor(color) end
  t.name:setText(name)
  t:setTooltip(tooltip or (name .. ': ' .. value))
  return t
end

local function chip(parent, icon, value, color, tooltip)
  local c = g_ui.createWidget('InspectChip', parent)
  c.icon:setItemId(icon or 0)
  c.value:setText(value)
  c.value:setColor(color or '#ffffff')
  c:setTooltip(tooltip)
end

local function bar(widget, now, max, color, label)
  now, max = tonumber(now) or 0, math.max(1, tonumber(max) or 1)
  local width = math.floor((widget:getWidth() - 2) * math.min(1, now / max))
  widget.fill:setBackgroundColor(color)
  widget.fill:setWidth(math.max(0, width))
  widget.text:setText(money(now) .. ' / ' .. money(max))
  widget:setTooltip(label .. ': ' .. money(now) .. ' / ' .. money(max))
end

function hide()
  if window then window:hide() end
end

-- asks the server about a creature on the screen
function inspect(creature)
  if not creature then return end
  local protocol = g_game.getProtocolGame()
  if not protocol then return end
  protocol:sendExtendedOpcode(OPCODE, (creature:isPlayer() and 'p' or 'm') .. '|' .. creature:getId())
end

local function showPlayer(lines)
  local panel = window.playerPanel
  window.monsterPanel:hide()
  panel:show()
  panel.stats:destroyChildren()
  for i = 1, 10 do
    local slot = panel.equipment:getChildById('slot' .. i)
    slot.item:setItemId(0)
    slot:setTooltip(tr(SLOT_NAMES[i]) .. ': ' .. tr('nothing'))
  end

  local head, skills, values = nil, {}, {}
  for _, line in ipairs(lines) do
    local f = split(line)
    if f[1] == 'P' then
      head = f
    elseif f[1] == 'K' then
      skills[(tonumber(f[2]) or 0) + 1] = tonumber(f[3]) or 0
    elseif f[1] == 'Q' then
      local slot = panel.equipment:getChildById('slot' .. (tonumber(f[2]) or 0))
      if slot then
        slot.item:setItemId(tonumber(f[3]) or 0)
        local count = tonumber(f[5]) or 1
        if count > 1 then slot.item:setItemCount(count) end
        slot:setTooltip(tr(SLOT_NAMES[tonumber(f[2])] or '') .. ': ' .. f[4])
      end
    else
      local key, value = line:match('^(%w+)=(.*)$')
      if key and key ~= 'src' then
        values[key] = values[key] or {}
        table.insert(values[key], value)
      end
    end
  end
  if not head then return end

  window.title:setText(head[3])
  window.subtitle:setText(tr('Level %s', money(head[4])) .. '  -  ' .. head[5])
  local creature = g_map.getCreatureById(tonumber(head[2]) or 0)
  window.outfit:setOutfit(creature and creature:getOutfit() or {})
  window.outfit:setVisible(creature ~= nil)
  bar(panel.healthBar, head[6], head[7], '#a8322e', tr('Health'))
  bar(panel.manaBar, head[8], head[9], '#2e5ca8', tr('Mana'))

  section(tr('Character'))
  local g = grid()
  tile(g, 648, head[10], tr('Magic Level'))
  tile(g, 3079, money(head[11]), tr('Speed'))
  tile(g, 5944, head[12], tr('Soul'))
  tile(g, 266, money(head[7]), tr('Max health'), '#ff8a8a')

  section(tr('Skills'))
  g = grid()
  for i, name in ipairs(SKILLS) do
    local icon = SKILL_ICONS[i] or '/images/game/skills_fist'
    tile(g, icon, tostring(skills[i] or 0), tr(name))
  end

  local first = function(key) return values[key] and values[key][1] end
  section(tr('Combat'))
  g = grid()
  tile(g, 3264, first('attack') or '0', tr('Attack'))
  tile(g, 3409, first('defense') or '0', tr('Defence'))
  tile(g, 3366, first('armor') or '0', tr('Armor'))
  if first('increment') then
    local inc = {}
    for v in first('increment'):gmatch('[^,]+') do inc[#inc + 1] = tonumber(v) or 0 end
    if (inc[5] or 0) ~= 0 then tile(g, 3155, (inc[5] > 0 and '+' or '') .. inc[5] .. '%', tr('Damage'), inc[5] > 0 and GOOD or BAD) end
    if (inc[4] or 0) ~= 0 then tile(g, 648, '+' .. inc[4] .. '%', tr('Magic damage'), GOOD) end
    if (inc[2] or 0) ~= 0 then tile(g, 266, '+' .. inc[2] .. '%', tr('Healing'), GOOD) end
  end
  if first('setname') then
    tile(g, 3366, '+' .. (first('setprotection') or 0) .. '%', first('setname'), GOLD, tr('Set bonus') .. ': ' .. first('setname'))
  end

  local protections = {}
  for _, v in ipairs(values['absorb'] or {}) do
    local t, pct = v:match('^(%d+),(%-?%d+)$')
    if t and tonumber(pct) ~= 0 then table.insert(protections, {tonumber(t), tonumber(pct)}) end
  end
  local reflects = {}
  for _, v in ipairs(values['reflect'] or {}) do
    local t, pct, chance = v:match('^(%d+),(%-?%d+),(%d+)$')
    if t then table.insert(reflects, {tonumber(t), tonumber(pct), tonumber(chance)}) end
  end
  if #protections > 0 or #reflects > 0 then
    section(tr('Protection'))
    g = grid('InspectChips')
    for _, p in ipairs(protections) do
      local name = tr(ELEMENTS[p[1]] or ('type ' .. p[1]))
      chip(g, ELEMENT_ICONS[p[1]], (p[2] > 0 and '+' or '') .. p[2] .. '%', p[2] > 0 and GOOD or BAD, name .. ' ' .. tr('protection'))
    end
    for _, r in ipairs(reflects) do
      local name = tr(ELEMENTS[r[1]] or ('type ' .. r[1]))
      chip(g, ELEMENT_ICONS[r[1]], r[2] .. '% / ' .. r[3] .. '%', GOLD, tr('Reflect') .. ' ' .. name .. ': ' .. r[2] .. '% ' .. tr('with a chance of') .. ' ' .. r[3] .. '%')
    end
  end
end

local function showMonster(lines)
  local panel = window.monsterPanel
  window.playerPanel:hide()
  panel:show()
  panel.loot:destroyChildren()
  local count = 0
  for _, line in ipairs(lines) do
    local f = split(line)
    if f[1] == 'M' then
      local level = tonumber(f[4]) or 0
      window.title:setText(f[3])
      window.subtitle:setText(level > 0 and tr('Level %s', money(level)) or '')
      window.outfit:setVisible(false)
    elseif f[1] == 'L' then
      local cell = g_ui.createWidget('InspectLoot', panel.loot)
      cell.item:setItemId(tonumber(f[2]) or 0)
      cell:setTooltip(f[3])
      count = count + 1
    end
  end
  panel.lootCaption:setText(count > 0 and tr('It may drop (%d):', count) or tr('It drops nothing.'))
end

function onMessage(protocol, opcode, buffer)
  local lines = buffer:split('\n')
  if #lines == 0 then return end
  local kind = split(lines[1])[1]
  if kind == 'P' then
    window:setSize({width = 680, height = 430})
    showPlayer(lines)
  elseif kind == 'M' then
    window:setSize({width = 520, height = 400})
    showMonster(lines)
  else
    return
  end
  window:show()
  window:raise()
  window:focus()
end

local function onGameEnd()
  hide()
end

function init()
  window = g_ui.displayUI('inspect')
  window:hide()
  ProtocolGame.registerExtendedOpcode(OPCODE, onMessage)
  connect(g_game, {onGameEnd = onGameEnd})
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd = onGameEnd})
  if window then window:destroy() end
  window = nil
end
