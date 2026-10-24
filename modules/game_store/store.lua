local STORE_API = Services.website .. "/index.php/api/store"
local win, topButton
local state = { offers = {}, categories = {}, characters = {}, buyUrl = Services.website, selected = nil, category = nil, busy = false }

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
    win.details.offerPrice:setText('')
    win.details.offerDesc:setText('')
    win.details.bigItem:setItemId(0)
    win.details.buyButton:setEnabled(false)
    return
  end
  win.details.bigItem:setItemId(tonumber(offer.item) or 0)
  win.details.bigItem:setItemCount(math.max(1, tonumber(offer.count) or 1))
  win.details.offerName:setText(offer.name)
  win.details.offerPrice:setText(formatPoints(offer.price) .. ' ' .. tr('points'))
  win.details.offerDesc:setText(offer.description or '')
  win.details.buyButton:setEnabled(true)
end

local function fillOffers()
  win.offers:destroyChildren()
  local first
  for _, offer in ipairs(state.offers) do
    if tonumber(offer.category) == state.category then
      local row = g_ui.createWidget('StoreOffer', win.offers)
      row.offer = offer
      row.item:setItemId(tonumber(offer.item) or 0)
      row.item:setItemCount(math.max(1, tonumber(offer.count) or 1))
      row.name:setText(offer.name)
      row.price:setText(formatPoints(offer.price) .. ' ' .. tr('points'))
      row.onFocusChange = function(w, focused) if focused then showOffer(w.offer) end end
      first = first or row
    end
  end
  if first then first:focus() else showOffer(nil) end
end

local function fillCategories()
  win.categories:destroyChildren()
  local first
  for _, cat in ipairs(state.categories) do
    local btn = g_ui.createWidget('StoreCategory', win.categories)
    btn:setText(cat.name)
    btn.catId = tonumber(cat.id)
    btn.onFocusChange = function(w, focused)
      if focused then state.category = w.catId fillOffers() end
    end
    first = first or btn
  end
  if first then first:focus() end
end

local function applyInfo(data)
  state.offers = data.offers or {}
  state.categories = data.categories or {}
  state.characters = data.characters or {}
  if data.buyUrl and data.buyUrl:sub(1, 4):lower() == 'http' then state.buyUrl = data.buyUrl end
  win.pointsLabel:setText(tr('Points: %s', formatPoints(data.points or 0)))
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
    call({ action = 'buy', offer = tonumber(offer.id), character = character }, function(data)
      win.pointsLabel:setText(tr('Points: %s', formatPoints(data.points or 0)))
      setStatus(data.message or tr('Purchase complete.'), '#7fd37a')
    end)
  end
  local function no() box:destroy() end
  box = displayGeneralBox(tr('Confirm purchase'),
    tr('Buy %s for %s points?\nIt will be delivered to %s.', offer.name, formatPoints(offer.price), character),
    { { text = tr('Yes'), callback = yes }, { text = tr('No'), callback = no }, anchor = AnchorHorizontalCenter },
    yes, no)
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
end

function toggle()
  if win:isVisible() then hide() else show() end
end

function init()
  g_ui.importStyle('/modules/client_entergame/forgottenl_style')
  win = g_ui.loadUI('store', g_ui.getRootWidget())
  win:hide()
  topButton = modules.client_topmenu.addRightGameToggleButton('storeButton', tr('Store'), '/images/topbuttons/shop', toggle, false, 8)
  connect(g_game, { onGameEnd = hide })
end

function terminate()
  disconnect(g_game, { onGameEnd = hide })
  if topButton then topButton:destroy() topButton = nil end
  if win then win:destroy() win = nil end
end
