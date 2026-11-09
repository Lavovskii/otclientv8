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

local function drawItems()
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
    -- what Look says (stats, tier, vocations and level), then how many and what the store pays
    local tip = (it.look ~= '' and it.look or it.name) .. '\n' .. tr('Quantity') .. ': ' .. comma_value(it.count)
    if it.pays > 0 then
      tip = tip .. '\n' .. tr('The General Store pays %s gold each (%s for all)', comma_value(it.pays), comma_value(it.pays * it.count))
    end
    slot:setTooltip(tip)
    slot.onClick = function() askAmount(it) end
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
