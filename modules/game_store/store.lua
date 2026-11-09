local STORE_API = Services.website .. "/index.php/api/store"
local win, topButton
local state = { admin = false, editor = nil, offers = {}, categories = {}, characters = {}, buyUrl = Services.website, selected = nil, category = nil, busy = false, sexes = {}, xpBoost = {} }

local function setStatus(text, color)
  win.bottomBar.statusLabel:setText(text or '')
  win.bottomBar.statusLabel:setColor(color or '#d8c9a0')
end

local function call(body, cb, attempt)
  attempt = attempt or 1
  body.account = G.account
  body.password = G.password
  state.busy = true
  HTTP.postJSON(STORE_API, body, function(data, err)
    state.busy = false
    if err or type(data) ~= 'table' then
      -- transient network failure: retry twice before giving up (buy requests carry a request id, so retries never double-charge)
      if attempt < 3 then
        setStatus(tr('Connection problem, retrying...'), '#e0b44c')
        scheduleEvent(function() if win then call(body, cb, attempt + 1) end end, 1500)
        return
      end
      setStatus(tr('Could not reach the store (%s). Try again later.', tostring(err or 'bad response'):sub(1, 60)), '#e05a4a')
      return
    end
    if not data.ok then
      setStatus(data.error or tr('Store error.'), '#e05a4a')
      return
    end
    cb(data)
  end)
end

local function formatPoints(n)
  return tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
end

-- the picture of a category, by what its name says; the staff name them, so any other gets the scroll
local CATEGORY_PICTURES = {
  {'equip', 'armor'}, {'armor', 'armor'}, {'weapon', 'weapons'}, {'consum', 'potion'}, {'potion', 'potion'}, {'rune', 'rune'},
  {'gem', 'gems'}, {'upgrade', 'gems'}, {'mount', 'saddle'}, {'boost', 'flask'}, {'exp', 'flask'}, {'premium', 'crown'},
  {'vip', 'crown'}, {'decor', 'table'}, {'furnitur', 'table'}, {'house', 'table'}, {'misc', 'sack'}, {'cosmet', 'tunic'},
  {'outfit', 'tunic'}, {'addon', 'tunic'}, {'extra', 'crate'}, {'task', 'stall'}, {'point', 'purse'},
}

local function categoryPicture(name)
  local lower = tostring(name):lower()
  for _, entry in ipairs(CATEGORY_PICTURES) do
    if lower:find(entry[1], 1, true) then
      return '/images/store/' .. entry[2] .. '26'
    end
  end
  return '/images/store/scroll26'
end

-- Offers that are not items (type 2 outfit, 3 mount, 4 XP Boost): the outfit is drawn for the chosen character's sex, in the
-- Citizen's default colours with both addons; the XP Boost's price is the chosen character's (it climbs with each one bought today).
local OFFER_ITEM, OFFER_OUTFIT, OFFER_MOUNT, OFFER_XPBOOST = 1, 2, 3, 4
local XP_BOOST_PICTURE = 7440 -- the experience potion

-- the outfit and mount offers the logged-in character already has (the server answers extended opcode 35 with their ids):
-- they are not offered to that character (the owner, 2026-11-09)
local OWNED_OPCODE = 35
local owned = {}

local function requestOwned()
  local protocol = g_game.getProtocolGame()
  if protocol and g_game.getFeature(GameExtendedOpcode) then
    protocol:sendExtendedOpcode(OWNED_OPCODE, 'owned')
  end
end

local function chosenCharacter()
  local opt = win and win.details.charBox:getCurrentOption()
  return opt and opt.text or nil
end

local function offerLook(offer)
  local kind = tonumber(offer.type) or OFFER_ITEM
  if type(offer.looks) ~= 'table' or not offer.looks[1] then return nil end
  if kind == OFFER_MOUNT then return { type = tonumber(offer.looks[1]) or 0 } end
  if kind ~= OFFER_OUTFIT then return nil end
  local sex = state.sexes[chosenCharacter() or ''] or 1
  local look = tonumber(offer.looks[sex == 0 and 1 or 2]) or tonumber(offer.looks[1]) or 0
  return { type = look, head = 78, body = 69, legs = 58, feet = 76, addons = math.max(0, math.min(3, tonumber(offer.count) or 0)) }
end

local function offerPrice(offer)
  if (tonumber(offer.type) or OFFER_ITEM) == OFFER_XPBOOST then
    local b = state.xpBoost[chosenCharacter() or '']
    if b then return tonumber(b.price) or 0, b end
  end
  return tonumber(offer.price) or 0
end

-- the picture of an offer in a 32 px item slot or a creature widget
local function paintOffer(itemWidget, creatureWidget, offer)
  local look = offer and offerLook(offer)
  creatureWidget:setVisible(look ~= nil)
  itemWidget:setVisible(look == nil)
  if look then
    creatureWidget:setOutfit(look)
    creatureWidget:setCenter(true)
    creatureWidget:setAnimate(true)
    itemWidget:setItemId(0)
    return
  end
  if not offer then itemWidget:setItemId(0) return end
  local id = (tonumber(offer.clientItem) ~= nil and tonumber(offer.clientItem) > 0 and tonumber(offer.clientItem)) or tonumber(offer.item) or 0
  local kind = tonumber(offer.type) or OFFER_ITEM
  if kind == OFFER_XPBOOST then id = XP_BOOST_PICTURE end
  if kind ~= OFFER_ITEM and kind ~= OFFER_XPBOOST and not (tonumber(offer.clientItem) and tonumber(offer.clientItem) > 0) then id = 0 end
  itemWidget:setItemId(id)
end

local function showOffer(offer)
  state.selected = offer
  win.details.priceBox:setVisible(offer ~= nil)
  win.details.line:setVisible(offer ~= nil)
  win.details.descBox:setVisible(offer ~= nil)
  if not offer then
    win.details.offerName:setText('')
    win.details.priceBox.offerPrice:setText('')
    win.details.descBox.offerDesc:setText('')
    paintOffer(win.details.bigBox.bigItem, win.details.bigBox.bigCreature, nil)
    win.details.buyButton:setEnabled(false)
    return
  end
  local kind = tonumber(offer.type) or OFFER_ITEM
  paintOffer(win.details.bigBox.bigItem, win.details.bigBox.bigCreature, offer)
  win.details.bigBox.bigItem:setItemCount(kind == OFFER_ITEM and math.max(1, tonumber(offer.count) or 1) or 1)
  win.details.bigBox.bigItem:setShowCount(false)
  local total = kind == OFFER_ITEM and math.max(1, tonumber(offer.count) or 1) * math.max(1, tonumber(offer.amount) or 1) or 1
  win.details.offerName:setText(total > 1 and (formatPoints(total) .. 'x ' .. offer.name) or offer.name)
  local price, boost = offerPrice(offer)
  local desc = offer.description or ''
  local canBuy = true
  if boost then
    if boost.active then
      desc = tr('%s still has an experience boost running.', chosenCharacter()) .. '\n\n' .. desc
      canBuy = false
    elseif price <= 0 then
      desc = tr('%s already bought 5 XP Boosts today. More from 10:00 server time.', chosenCharacter()) .. '\n\n' .. desc
      canBuy = false
    else
      desc = tr('XP Boosts bought today by %s: %d of 5.', chosenCharacter(), tonumber(boost.bought) or 0) .. '\n\n' .. desc
    end
  end
  win.details.priceBox.offerPrice:setText(price > 0 and formatPoints(price) or '-')
  win.details.descBox.offerDesc:setText(desc)
  win.details.buyButton:setEnabled(canBuy)
end

local function fillOffers()
  win.offersBox.offers:destroyChildren()
  for _, cat in ipairs(state.categories) do
    if tonumber(cat.id) == state.category then
      win.offersBox.caption:setText(cat.name)
    end
  end
  local first
  local forMe = chosenCharacter() == g_game.getCharacterName()
  for _, offer in ipairs(state.offers) do
    if tonumber(offer.category) == state.category and not (forMe and owned[tonumber(offer.id)]) then
      local row = g_ui.createWidget('StoreOffer', win.offersBox.offers)
      row.offer = offer
      paintOffer(row.itemBox.item, row.itemBox.creature, offer)
      row.itemBox.item:setItemCount((tonumber(offer.type) or OFFER_ITEM) == OFFER_ITEM and math.max(1, tonumber(offer.count) or 1) or 1)
      row.name:setText(offer.name)
      row.name:setTooltip(offer.name)
      local price = offerPrice(offer)
      row.priceBox.price:setText(price > 0 and formatPoints(price) or '-')
      first = first or row
    end
  end
  win.offersBox.noOffers:setVisible(first == nil)
  if first then first:focus() showOffer(first.offer) else showOffer(nil) end
end

local function fillCategories()
  local keep = state.category
  win.categoriesBox.categories:destroyChildren()
  local first, keepBtn
  for _, cat in ipairs(state.categories) do
    local btn = g_ui.createWidget('StoreCategory', win.categoriesBox.categories)
    btn:setText(cat.name)
    btn.picture:setImageSource(categoryPicture(cat.name))
    btn.catId = tonumber(cat.id)
    first = first or btn
    if btn.catId == keep then keepBtn = btn end
  end
  -- the column holds eleven; with more, the scrollbar takes its place beside them
  local crowded = #state.categories > 11
  win.categoriesBox.categoriesScroll:setVisible(crowded)
  win.categoriesBox.categories:setMarginRight(crowded and 18 or 6)
  local f = keepBtn or first
  if f then f:focus() state.category = f.catId fillOffers() end
end

local function applyInfo(data)
  state.offers = data.offers or {}
  state.categories = data.categories or {}
  state.characters = data.characters or {}
  state.sexes = type(data.sexes) == 'table' and data.sexes or {}
  state.xpBoost = type(data.xpBoost) == 'table' and data.xpBoost or {}
  if data.buyUrl and data.buyUrl:sub(1, 4):lower() == 'http' then state.buyUrl = data.buyUrl end
  state.admin = data.admin == true
  -- the staff's tools take room only from the staff's window
  win.bottomBar.staffFrame:setVisible(state.admin)
  win.bottomBar:setHeight(state.admin and 90 or 26)
  win:setHeight(state.admin and 579 or 515)
  win.pointsBox.pointsLabel:setText(formatPoints(data.points or 0))
  win.details.charBox:clearOptions()
  local current = g_game.getLocalPlayer() and g_game.getLocalPlayer():getName()
  for _, name in ipairs(state.characters) do win.details.charBox:addOption(name) end
  if current then win.details.charBox:setCurrentOption(current, true) end
end

-- opens straight on an offer, for who comes to buy that one (the Task Board's Unlock)
local function pickOffer(name)
  for _, offer in ipairs(state.offers) do
    if offer.name == name then
      state.category = tonumber(offer.category)
      fillCategories()
      for _, row in ipairs(win.offersBox.offers:getChildren()) do
        if row.offer == offer then
          row:focus()
          showOffer(offer)
        end
      end
      return
    end
  end
end

local function onOwned(protocol, opcode, buffer)
  owned = {}
  for id in tostring(buffer or ''):gsub('^owned|', ''):gmatch('%d+') do
    owned[tonumber(id)] = true
  end
  if win and win:isVisible() and state.offers then fillOffers() end
end

function refresh()
  requestOwned()
  setStatus(tr('Loading...'))
  call({ action = 'info' }, function(data)
    applyInfo(data)
    fillCategories()
    if state.pick then
      pickOffer(state.pick)
      state.pick = nil
    end
    setStatus('')
  end)
end

function buy()
  local offer = state.selected
  if not offer or state.busy then return end
  local character = win.details.charBox:getCurrentOption().text
  if not character or character == '' then return end
  local price = offerPrice(offer)
  if price <= 0 then return end
  local box
  local function yes()
    box:destroy()
    setStatus(tr('Processing...'))
    local rid = string.format('%08x%08x', math.random(0, 0x7fffffff), os.time())
    call({ action = 'buy', offer = tonumber(offer.id), character = character, requestId = rid, price = price }, function(data)
      win.pointsBox.pointsLabel:setText(formatPoints(data.points or 0))
      setStatus(data.message or tr('Purchase complete.'), '#7fd37a')
      -- the next XP Boost costs more, and outfits look different per character: the offers again
      if (tonumber(offer.type) or OFFER_ITEM) ~= OFFER_ITEM then refresh() end
    end)
  end
  local function no() box:destroy() end
  box = displayGeneralBox(tr('Confirm purchase'),
    tr('Buy %s for %s points?\nIt will be delivered to %s.', offer.name, formatPoints(price), character),
    { { text = tr('Yes'), callback = yes }, { text = tr('No'), callback = no }, anchor = AnchorHorizontalCenter },
    yes, no)
end

-- admin tools (server re-checks the admin right on every call)
local function adminCall(body, okMessage)
  call(body, function()
    setStatus(okMessage, '#7fd37a')
    refresh()
  end)
end

local function numberOf(widget)
  return math.max(0, tonumber(widget:getText()) or 0)
end

function adminEdit(editing)
  if not state.admin or state.editor then return end
  local offer = editing and state.selected or nil
  if editing and not offer then return end
  local w = g_ui.createWidget('StoreEditWindow', rootWidget)
  state.editor = w
  for _, cat in ipairs(state.categories) do w.category:addOption(cat.name, tonumber(cat.id)) end
  if offer then
    w.name:setText(offer.name or '')
    w.description:setText(offer.description or '')
    w.price:setText(tostring(offer.price or 0))
    w.item:setText(tostring(offer.item or 0))
    w.count:setText(tostring(offer.count or 1))
    w.amount:setText(tostring(offer.amount or 1))
    w.category:setCurrentOptionByData(tonumber(offer.category))
  else
    w.price:setText('100') w.item:setText('2160') w.count:setText('1') w.amount:setText('1')
    if state.category then w.category:setCurrentOptionByData(state.category) end
  end
  local function close() w:destroy() state.editor = nil end
  w.cancelButton.onClick = close
  w.okButton.onClick = function()
    local o = {
      id = offer and tonumber(offer.id) or 0,
      category = w.category:getCurrentOption().data,
      name = w.name:getText(),
      description = w.description:getText(),
      price = numberOf(w.price), item = numberOf(w.item),
      count = math.max(1, numberOf(w.count)), amount = math.max(1, numberOf(w.amount)),
      type = offer and tonumber(offer.type) or 0
    }
    if o.name == '' or not o.category or (o.item == 0 and o.type ~= OFFER_XPBOOST) then return end
    close()
    adminCall({ action = 'admin_save', offer = o }, tr('Offer saved.'))
  end
  w:raise() w:focus() w.name:focus()
end

function adminRemove()
  local offer = state.selected
  if not state.admin or not offer then return end
  local box
  local function yes()
    box:destroy()
    adminCall({ action = 'admin_delete', offer = tonumber(offer.id) }, tr('Offer removed.'))
  end
  local function no() box:destroy() end
  box = displayGeneralBox(tr('Remove offer'), tr('Remove "%s" from the store?', offer.name),
    { { text = tr('Yes'), callback = yes }, { text = tr('No'), callback = no }, anchor = AnchorHorizontalCenter }, yes, no)
end

function adminCategory(renaming)
  if not state.admin or state.editor then return end
  local current
  for _, cat in ipairs(state.categories) do if tonumber(cat.id) == state.category then current = cat end end
  if renaming and not current then return end
  local w = g_ui.createWidget('StoreNameWindow', rootWidget)
  state.editor = w
  if renaming then w.name:setText(current.name) end
  local function close() w:destroy() state.editor = nil end
  w.cancelButton.onClick = close
  w.okButton.onClick = function()
    local name = w.name:getText()
    if name == '' then return end
    close()
    adminCall({ action = 'admin_category_save', category = { id = renaming and tonumber(current.id) or 0, name = name } }, tr('Category saved.'))
  end
  w:raise() w:focus() w.name:focus()
end

function adminRemoveCategory()
  if not state.admin or not state.category then return end
  adminCall({ action = 'admin_category_delete', category = state.category }, tr('Category removed.'))
end

function adminPoints(mode)
  if not state.admin or state.editor then return end
  local w = g_ui.createWidget('StorePointsWindow', rootWidget)
  state.editor = w
  local titles = { add = tr('Add points'), remove = tr('Remove points'), set = tr('Edit points (set balance)') }
  w:setText(titles[mode])
  local current = g_game.getLocalPlayer()
  local function close() w:destroy() state.editor = nil end
  w.cancelButton.onClick = close
  w.okButton.onClick = function()
    local name = w.character:getText()
    local amount = tonumber(w.amount:getText())
    if name == '' or not amount or amount < 0 or (mode ~= 'set' and amount < 1) then
      setStatus(tr('Enter a character name and a valid amount.'), '#e05a4a')
      return
    end
    close()
    call({ action = 'admin_points', mode = mode, character = name, amount = math.floor(amount) }, function(data)
      setStatus(data.message or tr('Done.'), '#7fd37a')
      refresh()
    end)
  end
  w:raise() w:focus() w.character:focus()
end

local function applyAdmin(v)
  state.admin = v
  if modules.client_options then modules.client_options.setAdminTools(v) end
end

function isAdmin()
  return state.admin == true
end

function checkAdmin()
  if not g_game.isOnline() then return end
  call({ action = 'info' }, function(data) applyAdmin(data.admin == true) end)
end

function openBuyPoints()
  g_platform.openUrl(state.buyUrl)
end

function show(offerName)
  if not g_game.isOnline() then return end
  state.pick = offerName
  win:show()
  win:raise()
  win:focus()
  refresh()
end

function hide()
  win:hide()
  if state.editor then state.editor:destroy() state.editor = nil end
end

function toggle()
  if win:isVisible() then hide() else show() end
end

-- slow golden "neon" pulse on the wide Store button: the neon layer is looked up once (again only if it was
-- destroyed), and the pulse stops in layouts that have no Store button
local pulseEvent, neonWidget
local function pulse()
  if not neonWidget or neonWidget:isDestroyed() then
    local btn = g_ui.getRootWidget():recursiveGetChildById('storeWideButton')
    neonWidget = btn and btn:getChildById('neon')
  end
  if not neonWidget then
    pulseEvent = nil
    return
  end

  -- slow neon breathing: the glowing STORE layer fades between dim and full brightness
  local t = (math.sin(g_clock.millis() / 1000 * math.pi * 2 / 3.6) + 1) / 2
  neonWidget:setOpacity(0.55 + 0.45 * t)
  pulseEvent = scheduleEvent(pulse, 60)
end
local function startPulse() if not pulseEvent then pulse() end end
local function stopPulse() if pulseEvent then removeEvent(pulseEvent) pulseEvent = nil end end

local adminEvent
function onGameStart()
  applyAdmin(false)
  removeEvent(adminEvent)
  adminEvent = scheduleEvent(checkAdmin, 1500)
  startPulse()
end

function onGameEnd()
  removeEvent(adminEvent)
  adminEvent = nil
  stopPulse()
  applyAdmin(false)
  if win then
    hide()
  end
end

function init()
  win = g_ui.loadUI('store', g_ui.getRootWidget())
  win:hide()
  win.categoriesBox.caption:setText(tr('Categories'))
  win.details.caption:setText(tr('Offer'))
  connect(win.categoriesBox.categories, { onChildFocusChange = function(_, c) if c and c.catId and state.category ~= c.catId then state.category = c.catId fillOffers() end end })
  connect(win.offersBox.offers, { onChildFocusChange = function(_, c) if c and c.offer then showOffer(c.offer) end end })
  -- another character: outfits drawn for its sex, the XP Boost at its own price
  connect(win.details.charBox, { onOptionChange = function()
    for _, row in ipairs(win.offersBox.offers:getChildren()) do
      if row.offer and (tonumber(row.offer.type) or OFFER_ITEM) ~= OFFER_ITEM then
        paintOffer(row.itemBox.item, row.itemBox.creature, row.offer)
        local price = offerPrice(row.offer)
        row.priceBox.price:setText(price > 0 and formatPoints(price) or '-')
      end
    end
    if state.selected then showOffer(state.selected) end
    fillOffers() -- owned outfits and mounts are hidden only for the logged-in character
  end })
  ProtocolGame.registerExtendedOpcode(OWNED_OPCODE, onOwned)
  connect(g_game, { onGameEnd = onGameEnd, onGameStart = onGameStart })
  if g_game.isOnline() then
    adminEvent = scheduleEvent(checkAdmin, 500)
    startPulse()
  end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OWNED_OPCODE)
  disconnect(g_game, { onGameEnd = onGameEnd, onGameStart = onGameStart })
  removeEvent(adminEvent)
  adminEvent = nil
  stopPulse()
  if topButton then topButton:destroy() topButton = nil end
  if win then win:destroy() win = nil end
end
