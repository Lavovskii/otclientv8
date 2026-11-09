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

local function addStat(name, value, color)
  local row = g_ui.createWidget('InspectStat', window.playerPanel.stats)
  row.name:setText(name)
  row.value:setText(value or '')
  if color then row.value:setColor(color) end
  if not value then row.name:setColor('#f4d68c') end
  return row
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
  addStat(tr('Character'))
  addStat(tr('Level'), money(head[4]))
  addStat(tr('Vocation'), head[5])
  addStat(tr('Health'), money(head[6]) .. ' / ' .. money(head[7]), '#ff7070')
  addStat(tr('Mana'), money(head[8]) .. ' / ' .. money(head[9]), '#7aa8ff')
  addStat(tr('Magic Level'), head[10])
  addStat(tr('Speed'), head[11])
  addStat(tr('Soul'), head[12])
  addStat(tr('Skills'))
  for i, name in ipairs(SKILLS) do
    addStat(tr(name), tostring(skills[i] or 0))
  end
  addStat(tr('Combat'))
  local first = function(key) return values[key] and values[key][1] end
  if first('attack') then addStat(tr('Attack'), first('attack')) end
  if first('defense') then addStat(tr('Defence'), first('defense')) end
  if first('armor') then addStat(tr('Armor'), first('armor')) end
  if first('increment') then
    local inc = {}
    for v in first('increment'):gmatch('[^,]+') do inc[#inc + 1] = tonumber(v) or 0 end
    if (inc[5] or 0) ~= 0 then addStat(tr('Damage'), (inc[5] > 0 and '+' or '') .. inc[5] .. '%', '#7fd36a') end
    if (inc[4] or 0) ~= 0 then addStat(tr('Magic Damage'), '+' .. inc[4] .. '%', '#7fd36a') end
    if (inc[2] or 0) ~= 0 then addStat(tr('Healing'), '+' .. inc[2] .. '%', '#7fd36a') end
  end
  if first('setname') then addStat(tr('Set bonus'), first('setname') .. ' +' .. (first('setprotection') or 0) .. '%', '#e8c66a') end
  if values['absorb'] then
    addStat(tr('Protection'))
    for _, v in ipairs(values['absorb']) do
      local t, p = v:match('^(%d+),(%-?%d+)$')
      if t then addStat(tr(ELEMENTS[tonumber(t)] or ('type ' .. t)), (tonumber(p) > 0 and '+' or '') .. p .. '%', tonumber(p) > 0 and '#7fd36a' or '#e05a4a') end
    end
  end
  if values['reflect'] then
    for _, v in ipairs(values['reflect']) do
      local t, p, c = v:match('^(%d+),(%-?%d+),(%d+)$')
      if t then addStat(tr('Reflect') .. ' ' .. tr(ELEMENTS[tonumber(t)] or t), p .. '% (' .. c .. '%)', '#e8c66a') end
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
      window.title:setText(f[3] .. (level > 0 and '' or ''))
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
    showPlayer(lines)
  elseif kind == 'M' then
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
