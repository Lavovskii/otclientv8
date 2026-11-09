-- The ForgottenL General Store. The rules are all in the server (data/lib/127-general-store.lua): the NPC sends "T" when the
-- player says trade, this window asks for the store ("open") and the server answers in lines of fields split by | on
-- extended opcode 32 (the store may come in parts: it starts at O and is shown at E):
--   O|vip|gold coin clientId|buffary coin clientId|npc name
--   C|key|name|icon clientId
--   I|category|itemid|clientId|name|price|currency|npc sells|npc buys|price the npc pays now
--   F|gold (carried + bank)|buffary coins
--   H|itemid|count in the backpack        H|end closes a reply's list
--   R|ok or error|text
-- The window asks with: open | buy|itemid|amount | sell|itemid|amount | close
local OPCODE = 32
local MAX_AMOUNT = 10000 -- the server's GENERAL_STORE_MAX_AMOUNT: as many as gold and capacity allow
local GREEN, RED, GREY, GOLD = '#7fd36a', '#e05a4a', '#a8a8a8', '#f4d68c'

local window
local store = {vip = false, goldIcon = 0, buffaryIcon = 0, categories = {}, items = {}}
local pending -- the store while its parts arrive
local funds = {gold = 0, buffary = 0}
local holding = {}
local tab, category, selected = 'buy', nil, nil

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

local function money(n)
  return comma_value(tonumber(n) or 0)
end

local function priceText(n, currency)
  if currency == 'buffary' then
    return money(n) .. (n == 1 and ' Buffary Coin' or ' Buffary Coins')
  end
  return money(n) .. ' gold'
end

-- the currency's word on the price of an item: a coin there looked like a price in crystal coins (the owner, 2026-11-09)
local function currencyWord(currency)
  return currency == 'buffary' and 'buffary' or 'gold'
end

local GOLD_COIN_CLIENT = 3031 -- the gold coin (server id 2148): the balance shows a heap of gold coins, not crystal coins
local HEAP = 100 -- the coins of the balance are drawn as a heap

-- the price shown in this tab: what the store asks (BUY) or pays (SELL)
local function priceOf(item)
  return tab == 'buy' and item.price or item.pays
end

local function visibleItems()
  local list = {}
  for _, item in ipairs(store.items) do
    if item.category == category and ((tab == 'buy' and item.sells) or (tab == 'sell' and item.buys and item.pays > 0)) then
      list[#list + 1] = item
    end
  end
  return list
end

local function amount()
  local n = math.floor(tonumber(window.details.amount:getText()) or 1)
  return math.max(1, math.min(MAX_AMOUNT, n))
end

local function canAfford(item, n)
  local have = item.currency == 'buffary' and funds.buffary or funds.gold
  return have >= item.price * n
end

local function drawFunds()
  local f = window.header.funds
  for _, icon in ipairs({{f.goldIcon, GOLD_COIN_CLIENT}, {f.buffaryIcon, store.buffaryIcon}}) do
    icon[1]:setItemId(icon[2])
    icon[1]:setItemCount(HEAP)
    icon[1]:setShowCount(false)
  end
  f.gold:setText(money(funds.gold) .. ' gold')
  f.buffary:setText(money(funds.buffary) .. ' buffary')
  local goldTip = tr('Gold: what you carry and your bank account (the store takes from both).')
  local buffaryTip = tr('Buffary Coin: what you carry.')
  f.goldIcon:setTooltip(goldTip)
  f.gold:setTooltip(goldTip)
  f.buffaryIcon:setTooltip(buffaryTip)
  f.buffary:setTooltip(buffaryTip)
  f:setTooltip(goldTip .. '\n' .. buffaryTip)
  if store.vip then
    window.header.vipNote:setText(tr('VIP: the store buys from you at the full price!'))
    window.header.vipNote:setColor(GOLD)
  else
    window.header.vipNote:setText(tr('The store buys at half the price. VIP players sell at the full price.'))
    window.header.vipNote:setColor(GREY)
  end
end

local function drawDetails()
  local d = window.details
  if not selected then
    d.bigBox.bigItem:setItemId(0)
    d.itemName:setText(tr('Choose an item'))
    d.eachLabel:setText('')
    d.haveLabel:setText('')
    d.totalLabel:setText('')
    d.actionButton:setEnabled(false)
    return
  end
  local n = amount()
  d.bigBox.bigItem:setItemId(selected.clientId)
  d.itemName:setText(selected.name)
  local have = holding[selected.id] or 0
  if tab == 'buy' then
    d.eachLabel:setText(tr('Price: %s each', priceText(selected.price, selected.currency)))
    d.haveLabel:setText(have > 0 and tr('You have %d in your backpack', have) or '')
    local total = selected.price * n
    d.totalLabel:setText(tr('Total: %s', priceText(total, selected.currency)))
    d.totalLabel:setColor(canAfford(selected, n) and GREEN or RED)
    d.actionButton:setText(tr('Buy'))
    d.actionButton:setEnabled(canAfford(selected, n))
  else
    local note = store.vip and tr(' (VIP: full price)') or tr(' (half the price)')
    d.eachLabel:setText(tr('The store pays %s each', priceText(selected.pays, selected.currency)) .. note)
    d.haveLabel:setText(tr('You have %d in your backpack', have))
    d.totalLabel:setText(tr('You get: %s', priceText(selected.pays * n, selected.currency)) ..
      (selected.currency == 'gold' and tr(' (to your bank account)') or ''))
    d.totalLabel:setColor(have >= n and GREEN or RED)
    d.actionButton:setText(tr('Sell'))
    d.actionButton:setEnabled(have >= n)
  end
end

local function select(item)
  selected = item
  drawDetails()
end

local function drawItems()
  local panel = window.itemsBox.items
  panel:destroyChildren()
  local list = visibleItems()
  window.itemsBox.empty:setVisible(#list == 0)
  window.itemsBox.empty:setText(tab == 'buy' and tr('Nothing for sale here.') or tr('The store buys nothing here.'))
  local stillThere = false
  for _, item in ipairs(list) do
    local cell = g_ui.createWidget('GsOffer', panel)
    cell.name:setText(item.name)
    cell.itemBox.item:setItemId(item.clientId)
    cell.priceBox.price:setText(money(priceOf(item)) .. ' ' .. currencyWord(item.currency))
    cell.priceBox.price:setColor(item.currency == 'buffary' and '#f0a050' or '#f4d68c')
    local have = holding[item.id] or 0
    if tab == 'sell' then
      cell.note:setText(have > 0 and tr('You have %d', have) or tr('You have none'))
      cell.note:setColor(have > 0 and GREEN or GREY)
    else
      cell.note:setText('')
    end
    cell:setTooltip(item.name .. '\n' .. (tab == 'buy' and tr('Price: %s', priceText(item.price, item.currency))
      or tr('The store pays %s', priceText(item.pays, item.currency))))
    cell.onClick = function() select(item) end
    cell.onFocusChange = function(widget, focused) if focused then select(item) end end
    if selected and selected.id == item.id then
      stillThere = true
      cell:focus()
    end
  end
  if not stillThere then
    selected = nil
  end
  drawDetails()
end

local function drawCategories()
  local panel = window.categoriesBox.categories
  panel:destroyChildren()
  for _, c in ipairs(store.categories) do
    local button = g_ui.createWidget('GsCategory', panel)
    button:setText(c.name)
    button.picture:setItemId(c.icon)
    button.onClick = function()
      category = c.key
      selected = nil
      drawItems()
    end
    if c.key == category then
      button:focus()
    end
  end
end

function setTab(name)
  tab = name
  window.header.buyTab:setOn(tab == 'buy')
  window.header.sellTab:setOn(tab == 'sell')
  window.itemsBox.caption:setText(tab == 'buy' and tr('The store sells') or tr('The store buys'))
  selected = nil
  drawItems()
end

function showCategory(key)
  category = key
  selected = nil
  drawCategories()
  drawItems()
end

function selectItem(id)
  for _, item in ipairs(visibleItems()) do
    if item.id == id then
      selected = item
      drawItems()
      return
    end
  end
end

function changeAmount(step)
  window.details.amount:setText(tostring(math.max(1, math.min(MAX_AMOUNT, amount() + step))))
  drawDetails()
end

function maxAmount()
  if not selected then return end
  local n
  if tab == 'buy' then
    local have = selected.currency == 'buffary' and funds.buffary or funds.gold
    n = selected.price > 0 and math.floor(have / selected.price) or MAX_AMOUNT
    -- and no more than the free capacity carries (weights in hundredths of an oz)
    local player = g_game.getLocalPlayer()
    local cap = player and tonumber(player:getFreeCapacity())
    if cap and (selected.weight or 0) > 0 then
      n = math.min(n, math.floor(cap * 100 / selected.weight))
    end
    -- and no more than the free slots of the backpack hold: one item a slot, or 100 a slot when it stacks
    if funds.slots then
      local thing = g_things.getThingType(selected.clientId, ThingCategoryItem)
      local stacks = thing and thing:isStackable()
      n = math.min(n, funds.slots * (stacks and 100 or 1))
    end
  else
    n = holding[selected.id] or 0
  end
  window.details.amount:setText(tostring(math.max(1, math.min(MAX_AMOUNT, n))))
  drawDetails()
end

function doAction()
  if not selected then return end
  send(tab .. '|' .. selected.id .. '|' .. amount())
  window.details.actionButton:setEnabled(false)
end

function hide()
  if window and window:isVisible() then
    window:hide()
    send('close')
  end
end

local function show()
  window.categoriesBox.caption:setText(tr('Categories'))
  if not category or not (function() for _, c in ipairs(store.categories) do if c.key == category then return true end end end)() then
    category = store.categories[1] and store.categories[1].key or nil
  end
  drawFunds()
  drawCategories()
  setTab(tab)
  window:show()
  window:raise()
  window:focus()
end

function onMessage(protocol, opcode, buffer)
  for _, line in ipairs(buffer:split('\n')) do
    local f = split(line)
    local kind = f[1]
    if kind == 'T' then
      send('open')
    elseif kind == 'O' then
      pending = {vip = f[2] == '1', goldIcon = tonumber(f[3]) or 0, buffaryIcon = tonumber(f[4]) or 0, categories = {}, items = {}}
      holding = {}
      if window then window:setText(f[5] ~= '' and f[5] or tr('ForgottenL General Store')) end
    elseif kind == 'C' and pending then
      table.insert(pending.categories, {key = f[2], name = f[3], icon = tonumber(f[4]) or 0})
    elseif kind == 'I' and pending then
      table.insert(pending.items, {category = f[2], id = tonumber(f[3]), clientId = tonumber(f[4]) or 0, name = f[5],
        price = tonumber(f[6]) or 0, currency = f[7], sells = f[8] == '1', buys = f[9] == '1', pays = tonumber(f[10]) or 0,
        weight = tonumber(f[11]) or 0})
    elseif kind == 'F' then
      funds.gold, funds.buffary, funds.slots = tonumber(f[2]) or 0, tonumber(f[3]) or 0, tonumber(f[4])
    elseif kind == 'R' then
      holding = {}
      window.statusLabel:setText(f[3] or '')
      window.statusLabel:setColor(f[2] == 'ok' and GREEN or RED)
    elseif kind == 'H' and f[2] ~= 'end' then
      holding[tonumber(f[2])] = tonumber(f[3]) or 0
    elseif kind == 'E' and pending then
      store = pending
      pending = nil
      window.statusLabel:setText('')
      show()
    end
  end
  -- after a buy or a sell: the funds, what the player carries, the button
  if window and window:isVisible() and not pending then
    drawFunds()
    drawItems()
  end
end

local function onGameEnd()
  if window then window:hide() end
  pending = nil
end

function init()
  window = g_ui.displayUI('generalstore')
  window:hide()
  window.header.funds.goldIcon:setItemId(0)
  window.details.amount.onTextChange = function() drawDetails() end
  ProtocolGame.registerExtendedOpcode(OPCODE, onMessage)
  connect(g_game, {onGameEnd = onGameEnd})
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd = onGameEnd})
  if window then window:destroy() end
  window = nil
end
