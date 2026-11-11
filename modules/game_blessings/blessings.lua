-- The blessings button of the inventory (the owner, 2026-11-11, like Tibia's): red with no blessing, yellow with some, green with
-- all five, and a window with each one. The server (data/lib/132-blessings-button.lua) sends them, extended opcode 37:
-- "B|" and one digit per blessing, 1 = held; the window asks with "get".
local OPCODE = 37
local NAMES = {'The Spiritual Shielding', 'The Embrace of Tibia', 'The Fire of the Suns', 'The Spark of the Phoenix',
  'The Wisdom of Solitude'}

local window, button
local held = {} -- blessing index -> true

local function count()
  local n = 0
  for i = 1, #NAMES do
    if held[i] then n = n + 1 end
  end
  return n
end

local function colour()
  local n = count()
  return n == 0 and 'red' or (n >= #NAMES and 'green' or 'yellow')
end

local function draw()
  local n = count()
  if button then
    button:setImageSource('/images/game/blessings/button_' .. colour())
    button:setTooltip(tr('Blessings: %d of %d', n, #NAMES))
  end
  if not window then return end
  window.summary:setText(n >= #NAMES and tr('You have all five blessings.') or tr('You have %d of the %d blessings.', n, #NAMES))
  for i, row in ipairs(window.rows:getChildren()) do
    row.icon:setImageSource('/images/game/blessings/' .. (held[i] and 'ankh_on' or 'ankh_off'))
    row.name:setColor(held[i] and '#e8e8e8' or '#8a8a8a')
    row.status:setText(held[i] and tr('Active') or tr('Missing'))
    row.status:setColor(held[i] and '#8fd48f' or '#d46a5a')
  end
end

local function onMessage(protocol, opcode, buffer)
  local digits = tostring(buffer or ''):match('^B|(%d*)$')
  if not digits then return end
  held = {}
  for i = 1, #NAMES do
    held[i] = digits:sub(i, i) == '1'
  end
  draw()
end

local function send(text)
  local protocol = g_game.getProtocolGame()
  if protocol then protocol:sendExtendedOpcode(OPCODE, text) end
end

function show()
  if not window then return end
  draw()
  window:show()
  window:raise()
  window:focus()
  send('get')
end

function hide()
  if window then window:hide() end
end

function toggle()
  if window and window:isVisible() then hide() else show() end
end

-- the button goes beside the inventory's minimize button, in any layout that has one
local function place()
  local inventory = modules.game_inventory and modules.game_inventory.inventoryWindow
  inventory = inventory or rootWidget:recursiveGetChildById('inventoryWindow')
  -- the minimize button inside the window's contents (the window has its own one, with the same id, at its top right)
  local contents = inventory and inventory:getChildById('contentsPanel')
  local minimize = contents and contents:getChildById('minimizeButton')
  if not minimize then return end
  local parent = minimize:getParent()
  if button and not button:isDestroyed() and button:getParent() == parent then return end
  if button and not button:isDestroyed() then button:destroy() end
  button = g_ui.createWidget('BlessingsButton', parent)
  button:addAnchor(AnchorTop, minimize:getId(), AnchorTop)
  button:addAnchor(AnchorLeft, minimize:getId(), AnchorRight)
  button:setMarginLeft(3)
  button.onClick = toggle
  draw()
end

local function onGameStart()
  scheduleEvent(place, 200)
end

local function onGameEnd()
  hide()
  held = {}
  draw()
end

-- for the window preview
function preview(digits)
  place()
  onMessage(nil, OPCODE, 'B|' .. digits)
end

function init()
  window = g_ui.displayUI('blessings') -- its styles too: BlessingsButton, BlessingRow
  window:hide()
  for i, name in ipairs(NAMES) do
    local row = g_ui.createWidget('BlessingRow', window.rows)
    row.name:setText(name)
  end
  ProtocolGame.registerExtendedOpcode(OPCODE, onMessage)
  connect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  if g_game.isOnline() then place() end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  if button and not button:isDestroyed() then button:destroy() end
  if window then window:destroy() end
  window, button, held = nil, nil, {}
end
