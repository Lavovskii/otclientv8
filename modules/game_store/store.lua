local STORE_API = Services.website .. "/index.php/api/store"
local win, topButton
local state = { admin = false, editor = nil, offers = {}, categories = {}, characters = {}, buyUrl = Services.website, selected = nil, category = nil, busy = false }

local function setStatus(text, color)
  win.bottomBar.statusLabel:setText(text or '')
  win.bottomBar.statusLabel:setColor(color or '#d8c9a0')
end

local function call(body, cb)
  body.account = G.account
  body.password = G.password
  state.busy = true
  HTTP.postJSON(STORE_API, body, function(data, err)
    state.busy = false
    if err or type(data) ~= 'table' then
      setStatus(tr('Could not reach the store. Try again later.'), '#e05a4a')
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

local function showOffer(offer)
  state.selected = offer
  if not offer then
    win.details.offerName:setText('')
    win.details.priceBox.offerPrice:setText('')
    win.details.descBox.offerDesc:setText('')
    win.details.bigBox.bigItem:setItemId(0)
    win.details.buyButton:setEnabled(false)
    return
  end
  win.details.bigBox.bigItem:setItemId(tonumber(offer.item) or 0)
  win.details.bigBox.bigItem:setItemCount(math.max(1, tonumber(offer.count) or 1))
  win.details.offerName:setText(offer.name)
  win.details.priceBox.offerPrice:setText(formatPoints(offer.price) .. ' ' .. tr('points'))
  win.details.descBox.offerDesc:setText(offer.description or '')
  win.details.buyButton:setEnabled(true)
end

local function fillOffers()
  win.offersBox.offers:destroyChildren()
  local first
  for _, offer in ipairs(state.offers) do
    if tonumber(offer.category) == state.category then
      local row = g_ui.createWidget('StoreOffer', win.offersBox.offers)
      row.offer = offer
      row.item:setItemId(tonumber(offer.item) or 0)
      row.item:setItemCount(math.max(1, tonumber(offer.count) or 1))
      row.name:setText(offer.name)
      row.priceBox.price:setText(formatPoints(offer.price) .. ' pts')
      first = first or row
    end
  end
  if first then first:focus() showOffer(first.offer) else showOffer(nil) end
end

local function fillCategories()
  local keep = state.category
  win.categoriesBox.categories:destroyChildren()
  local first, keepBtn
  for _, cat in ipairs(state.categories) do
    local btn = g_ui.createWidget('StoreCategory', win.categoriesBox.categories)
    btn:setText(cat.name)
    btn.catId = tonumber(cat.id)
    first = first or btn
    if btn.catId == keep then keepBtn = btn end
  end
  local f = keepBtn or first
  if f then f:focus() state.category = f.catId fillOffers() end
end

local function applyInfo(data)
  state.offers = data.offers or {}
  state.categories = data.categories or {}
  state.characters = data.characters or {}
  if data.buyUrl and data.buyUrl:sub(1, 4):lower() == 'http' then state.buyUrl = data.buyUrl end
  state.admin = data.admin == true
  win.bottomBar.adminBar:setVisible(state.admin)
  win.pointsBox.pointsLabel:setText(tr('Points: %s', formatPoints(data.points or 0)))
  win.details.charBox:clearOptions()
  local current = g_game.getLocalPlayer() and g_game.getLocalPlayer():getName()
  for _, name in ipairs(state.characters) do win.details.charBox:addOption(name) end
  if current then win.details.charBox:setCurrentOption(current, true) end
end

function refresh()
  setStatus(tr('Loading...'))
  call({ action = 'info' }, function(data)
    applyInfo(data)
    fillCategories()
    setStatus('')
  end)
end

function buy()
  local offer = state.selected
  if not offer or state.busy then return end
  local character = win.details.charBox:getCurrentOption().text
  if not character or character == '' then return end
  local box
  local function yes()
    box:destroy()
    setStatus(tr('Processing...'))
    local rid = string.format('%08x%08x', math.random(0, 0x7fffffff), os.time())
    call({ action = 'buy', offer = tonumber(offer.id), character = character, requestId = rid }, function(data)
      win.pointsBox.pointsLabel:setText(tr('Points: %s', formatPoints(data.points or 0)))
      setStatus(data.message or tr('Purchase complete.'), '#7fd37a')
    end)
  end
  local function no() box:destroy() end
  box = displayGeneralBox(tr('Confirm purchase'),
    tr('Buy %s for %s points?\nIt will be delivered to %s.', offer.name, formatPoints(offer.price), character),
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
    if o.name == '' or not o.category or o.item == 0 then return end
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

function openBuyPoints()
  g_platform.openUrl(state.buyUrl)
end

function show()
  if not g_game.isOnline() then return end
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

function init()
  win = g_ui.loadUI('store', g_ui.getRootWidget())
  win:hide()
  connect(win.categoriesBox.categories, { onChildFocusChange = function(_, c) if c and c.catId and state.category ~= c.catId then state.category = c.catId fillOffers() end end })
  connect(win.offersBox.offers, { onChildFocusChange = function(_, c) if c and c.offer then showOffer(c.offer) end end })
  topButton = modules.client_topmenu.addRightGameToggleButton('storeButton', tr('Store'), '/images/topbuttons/shop', toggle, false, 8)
  connect(g_game, { onGameEnd = hide })
end

function terminate()
  disconnect(g_game, { onGameEnd = hide })
  if topButton then topButton:destroy() topButton = nil end
  if win then win:destroy() win = nil end
end
