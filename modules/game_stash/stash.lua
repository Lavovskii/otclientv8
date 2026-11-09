-- The supply stash (the owner, 2026-11-09: as in Tibia). The server (data/lib/129-stash.lua, extended opcode 34) keeps the
-- counts; this window lists them with Tibia's search, filters, "sell to" trader and sorting, and takes items out. Items go
-- in from any item's right-click menu: Stow, Stow all items of this type, Stow container's content (gameinterface.lua).
--   server -> client: R|ok or error|text, O (a new list), I|itemid|clientId|name|count|category|store pays, E (show)
--   client -> server: open, take|itemid|amount, stow|x|y|z|stackpos|mode
local OPCODE = 34
local MAX_TAKE = 10000

local window, amountWindow
local items, pending = {}, nil
local selected = nil

-- Tibia's filters (without the Market's), each with the categories the server gives
local FILTERS = {
  {'Show All', nil},
  {'Show Amulets', {amulets = true}},
  {'Show Armors', {armors = true}},
  {'Show Boots', {boots = true}},
  {'Show Containers', {containers = true}},
  {'Show Helmets and Hats', {helmets = true}},
  {'Show Legs', {legs = true}},
  {'Show Others', {others = true}},
  {'Show Potions', {potions = true}},
  {'Show Rings', {rings = true}},
  {'Show Runes', {runes = true}},
  {'Show Shields', {shields = true}},
  {'Show Tools', {tools = true}},
  {'Show Valuables', {valuables = true}},
  {'Show Weapons: All', {ammo = true, axes = true, clubs = true, distance = true, swords = true, wands = true}},
  {'Show Weapons: Ammo', {ammo = true}},
  {'Show Weapons: Axes', {axes = true}},
  {'Show Weapons: Clubs', {clubs = true}},
  {'Show Weapons: Distance', {distance = true}},
  {'Show Weapons: Swords', {swords = true}},
  {'Show Weapons: Wands', {wands = true}},
}
local SORTS = {'Name (A-Z)', 'Name (Z-A)', 'Sell To Value (High to Low)', 'Sell To Value (Low to High)',
  'Total Sell To Value (High to Low)', 'Total Sell To Value (Low to High)', 'Quantity (High to Low)', 'Quantity (Low to High)'}
local TRADERS = {'No Trader Selected', 'Sell to ForgottenL General Store'}

local function send(text)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE, text)
  end
end

local function split(line)
  local parts = {}
  for part in (line .. '|'):gmatch('([^|]*)|') do
    parts[#parts + 1] = part
  end
  return parts
end

-- 1660, 11k, 2.5kk: as Tibia writes big counts
local function shortCount(n)
  if n >= 1000000 then
    return string.format('%gkk', math.floor(n / 100000) / 10)
  elseif n >= 10000 then
    return string.format('%dk', math.floor(n / 1000))
  end
  return tostring(n)
end

-- a frame in the colour of what one is worth to the store, like Tibia's loot value frames
local function frameColor(value)
  if value >= 1000000 then return '#e0b830'
  elseif value >= 100000 then return '#a050e0'
  elseif value >= 10000 then return '#3d7cff'
  elseif value >= 1000 then return '#3fae3f'
  end
  return '#3a3a3a'
end

local function amount()
  local n = math.floor(tonumber(amountWindow and amountWindow.amount:getText() or 1) or 1)
  local most = selected and math.min(selected.count, MAX_TAKE) or 1
  return math.max(1, math.min(most, n))
end

function closeAmount()
  if amountWindow then
    amountWindow:destroy()
    amountWindow = nil
  end
end

-- more than one: ask how many (stackable or not); just one: out it comes
local function askAmount(it)
  selected = it
  if it.count <= 1 then
    send('take|' .. it.id .. '|1')
    return
  end
  closeAmount()
  amountWindow = g_ui.createWidget('StashAmountWindow', rootWidget)
  amountWindow.item:setItemId(it.clientId)
  amountWindow.name:setText(it.name .. '\n' .. tr('In your stash:') .. ' ' .. comma_value(it.count))
  amountWindow.amount:setText(tostring(math.min(it.count, MAX_TAKE)))
  amountWindow.amount.onEnter = function() take() end
  amountWindow:raise()
  amountWindow:focus()
  amountWindow.amount:focus()
end

local function visible()
  local filter = window.filter:getCurrentOption()
  local cats = filter and filter.data or nil
  local trader = window.trader:getCurrentOption()
  local selling = trader and trader.text ~= TRADERS[1]
  local text = window.search:getText():lower()
  local list = {}
  for _, it in ipairs(items) do
    if (not cats or cats[it.category]) and (text == '' or it.name:lower():find(text, 1, true)) then
      table.insert(list, it)
    end
  end
  local sort = window.sort:getCurrentOption()
  sort = sort and sort.text or SORTS[1]
  local function value(it) return it.pays end
  local function total(it) return it.pays * it.count end
  table.sort(list, function(a, b)
    if sort == SORTS[2] then return a.name:lower() > b.name:lower()
    elseif sort == SORTS[3] then if value(a) ~= value(b) then return value(a) > value(b) end
    elseif sort == SORTS[4] then if value(a) ~= value(b) then return value(a) < value(b) end
    elseif sort == SORTS[5] then if total(a) ~= total(b) then return total(a) > total(b) end
    elseif sort == SORTS[6] then if total(a) ~= total(b) then return total(a) < total(b) end
    elseif sort == SORTS[7] then if a.count ~= b.count then return a.count > b.count end
    elseif sort == SORTS[8] then if a.count ~= b.count then return a.count < b.count end
    end
    return a.name:lower() < b.name:lower()
  end)
  return list, selling
end

-- The hover card (the owner, 2026-11-09: organised, with spacing and Look's green). The server's look text is cut in
-- parts: the first line's brackets hold the stats (or a rune's words), "It can only be..." the requirements, "Tier N."
-- the tier, "It weighs..." the weight; anything else is the item's own description.
local LOOK_GREEN = '#00eb00'
local REQUIREMENT = '#e8a33c'
local TIER_COLORS = {'#4ee34e', '#3d9cff', '#b65cff', '#ffd23b', '#ff7fd5', '#ff5a5a'}
local KINDS = {amulets = 'Amulet', armors = 'Armor', boots = 'Boots', containers = 'Container', helmets = 'Helmet',
  legs = 'Legs', others = 'Item', potions = 'Potion', rings = 'Ring', runes = 'Rune', shields = 'Shield', tools = 'Tool',
  valuables = 'Valuable', ammo = 'Ammunition', axes = 'Axe', clubs = 'Club', distance = 'Distance weapon',
  swords = 'Sword', wands = 'Wand or rod'}
local STAT_NAMES = {Atk = 'Attack', Def = 'Defense', Arm = 'Armor', Range = 'Range', Hit = 'Hit chance'}
local tip = nil

function hideTip()
  if tip then
    tip:destroy()
    tip = nil
  end
end

local function capitalise(text)
  return (text:gsub('^%l', string.upper))
end

local function line(text, color, font)
  local l = g_ui.createWidget('StashTipLine', tip)
  l:setText(text)
  if color then l:setColor(color) end
  if font then l:setFont(font) end
  return l
end

local function row(key, value, color)
  local r = g_ui.createWidget('StashTipRow', tip)
  r.key:setText(key)
  r.value:setText(value)
  if color then r.value:setColor(color) end
end

local function separator()
  g_ui.createWidget('StashTipSeparator', tip)
end

function showTip(it)
  hideTip()
  tip = g_ui.createWidget('StashTip', rootWidget)
  local header = g_ui.createWidget('StashTipHeader', tip)
  header.item:setItemId(it.clientId)
  header.name:setText(capitalise(it.name))
  header.kind:setText(tr(KINDS[it.category] or 'Item'))

  local lines = (it.look or ''):split('\n')
  local first = table.remove(lines, 1) or ''
  local inside = first:match('%((.*)%)%.?%s*$')
  local stats, words = {}, nil
  if inside then
    words = inside:match('^"(.*)"$')
    if not words then
      for part in (inside .. ','):gmatch('%s*([^,]+),') do
        local name, value = part:match('^(%a+)%%?:%s*(.+)$')
        if name then
          table.insert(stats, (STAT_NAMES[name] or name) .. ': ' .. value)
        else
          table.insert(stats, capitalise(part))
        end
      end
    end
  end

  local requirements, tier, weight, description = {}, nil, nil, {}
  for _, l in ipairs(lines) do
    l = l:gsub('^%s+', '')
    if l:find('^It can only be') then
      table.insert(requirements, l)
    elseif l:match('^Tier (%d+)%.?$') then
      tier = tonumber(l:match('^Tier (%d+)'))
    elseif l:find('^It weighs') then
      weight = l:match('^It weighs (.-)%.?$')
    elseif l ~= '' then
      table.insert(description, l)
    end
  end

  if words or #stats > 0 or tier then
    separator()
    if words then line(tr('Words') .. ': ' .. words, LOOK_GREEN) end
    for _, s in ipairs(stats) do line(s, LOOK_GREEN) end
    if tier then line(tr('Tier %d', tier), TIER_COLORS[math.min(tier, #TIER_COLORS)] or '#ffffff') end
  end
  if #requirements > 0 then
    separator()
    for _, r in ipairs(requirements) do line(r, REQUIREMENT) end
  end
  if #description > 0 then
    separator()
    for _, d in ipairs(description) do line(d, '#b8b0a0', 'verdana-9px-italic') end
  end

  separator()
  row(tr('Quantity'), comma_value(it.count))
  if weight then row(tr('Weight'), weight .. (it.count > 1 and ' ' .. tr('each') or '')) end
  if it.pays > 0 then
    row(tr('Store pays'), comma_value(it.pays) .. ' ' .. tr('gold each'), '#f4d68c')
    if it.count > 1 then row(tr('For all'), comma_value(it.pays * it.count) .. ' gold', '#f4d68c') end
  else
    row(tr('Store pays'), tr('not bought'), '#7a7468')
  end

  -- beside the mouse, kept inside the screen
  local pos = g_window.getMousePosition()
  tip:raise()
  scheduleEvent(function()
    if not tip then return end
    local root = rootWidget:getSize()
    local x, y = pos.x + 18, pos.y + 18
    if x + tip:getWidth() > root.width then x = pos.x - tip:getWidth() - 8 end
    if y + tip:getHeight() > root.height then y = math.max(0, root.height - tip:getHeight() - 4) end
    tip:setPosition({x = x, y = y})
  end, 1)
  tip:setPosition({x = pos.x + 18, y = pos.y + 18})
end

local function drawItems()
  hideTip()
  local panel = window.items
  panel:destroyChildren()
  local list, selling = visible()
  window.empty:setVisible(#items == 0)
  for _, it in ipairs(list) do
    local slot = g_ui.createWidget('StashSlot', panel)
    slot.item:setItemId(it.clientId)
    slot.item:setItemCount(1)
    slot.count:setText(it.count > 1 and shortCount(it.count) or '')
    slot:setBorderColor(frameColor(it.pays))
    if selling and it.pays <= 0 then
      slot:setOpacity(0.35)
    end
    slot.onHoverChange = function(widget, hovered)
      if hovered then showTip(it) else hideTip() end
    end
    slot.onClick = function() hideTip() askAmount(it) end
  end
end

function step(delta)
  if not selected or not amountWindow then return end
  amountWindow.amount:setText(tostring(math.max(1, math.min(math.min(selected.count, MAX_TAKE), amount() + delta))))
end

function maxAmount()
  if not selected or not amountWindow then return end
  amountWindow.amount:setText(tostring(math.min(selected.count, MAX_TAKE)))
end

function take()
  if not selected then return end
  send('take|' .. selected.id .. '|' .. amount())
  closeAmount()
end

-- from the right-click menu of an item the player carries
function stow(item, mode)
  if not item then return end
  local pos = item:getPosition()
  if not pos or pos.x ~= 0xffff then
    modules.game_textmessage.displayFailureMessage(tr('Only items you carry can be stowed.'))
    return
  end
  local stackpos = item:getStackPos()
  if not stackpos or stackpos < 0 then stackpos = 0 end
  send(string.format('stow|%d|%d|%d|%d|%s', pos.x, pos.y, pos.z, stackpos, mode or 'one'))
end

function hide()
  hideTip()
  closeAmount()
  if window then window:hide() end
end

local function show()
  window:show()
  window:raise()
  window:focus()
end

function onMessage(protocol, opcode, buffer)
  local shown = false
  for _, line in ipairs(buffer:split('\n')) do
    local f = split(line)
    if f[1] == 'R' then
      local ok = f[2] == 'ok'
      if window:isVisible() then
        window.status:setText(f[3] or '')
        window.status:setColor(ok and '#5fd35f' or '#ff6060')
      end
      if ok then
        modules.game_textmessage.displayStatusMessage(f[3] or '')
      else
        modules.game_textmessage.displayFailureMessage(f[3] or '')
      end
    elseif f[1] == 'O' then
      pending = {}
    elseif f[1] == 'I' and pending then
      table.insert(pending, {id = tonumber(f[2]) or 0, clientId = tonumber(f[3]) or 0, name = f[4] or '',
        count = tonumber(f[5]) or 0, category = f[6] or 'others', pays = tonumber(f[7]) or 0,
        look = (f[8] or ''):gsub('\t', '\n')})
    elseif f[1] == 'E' and pending then
      items = pending
      pending = nil
      shown = true
    end
  end
  if shown then
    if selected then
      local still = nil
      for _, it in ipairs(items) do
        if it.id == selected.id then still = it end
      end
      selected = still
    end
    drawItems()
    show()
  end
end

local function onGameEnd()
  closeAmount()
  if window then window:hide() end
  pending, items, selected = nil, {}, nil
end

function init()
  window = g_ui.displayUI('stash')
  window:hide()
  for _, f in ipairs(FILTERS) do window.filter:addOption(f[1], f[2]) end
  for _, t in ipairs(TRADERS) do window.trader:addOption(t) end
  for _, s in ipairs(SORTS) do window.sort:addOption(s) end
  window.filter.onOptionChange = function() drawItems() end
  window.trader.onOptionChange = function() drawItems() end
  window.sort.onOptionChange = function() drawItems() end
  window.search.onTextChange = function() drawItems() end
  ProtocolGame.registerExtendedOpcode(OPCODE, onMessage)
  connect(g_game, {onGameEnd = onGameEnd})
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd = onGameEnd})
  closeAmount()
  if window then window:destroy() end
end
