-- The plate with the frame rate and the ping in the corner of the map.
-- Protocol 8.70 has no ping the client can start, so the engine's g_game.getPing() stays at -1 (and its other way, extended opcode 2,
-- is the loot ignore list on this server). It is measured here instead: PING_OPCODE goes to the server, which answers at once
-- (data/creaturescripts/scripts/player/client_ping.lua), one question at a time.
ui = nil
updateEvent = nil

local PING_OPCODE = 12
local PING_EVERY = 2000   -- ms between an answer and the next question
local PING_RETRY = 10000  -- ms without an answer before asking again
local SHOW_WAIT_AFTER = 1000 -- ms without an answer before the plate shows the wait itself

local GOOD, FAIR, BAD, UNKNOWN = '#57d36e', '#e8c547', '#ef5350', '#9a927e'
local BAR_OFF = '#2c2820'

local pingSentAt, pingWaitingSince, pingNextAt, lastPing = nil, nil, 0, nil
local shown = false

-- how many of the 4 bars light and in what colour: the colour never says it alone
local function fpsQuality(fps)
  if fps >= 50 then return 4, GOOD end
  if fps >= 30 then return 3, GOOD end
  if fps >= 15 then return 2, FAIR end
  return 1, BAD
end

local function pingQuality(ping)
  if ping < 100 then return 4, GOOD end
  if ping < 250 then return 3, GOOD end
  if ping < 500 then return 2, FAIR end
  return 1, BAD
end

local function drawRow(row, text, bars, color)
  -- only what changed: this runs twice a second for as long as the game is open
  if row.drawnText ~= text then
    row.drawnText = text
    row:getChildById('value'):setText(text)
  end
  if row.drawnBars ~= bars or row.drawnColor ~= color then
    row.drawnBars, row.drawnColor = bars, color
    row:getChildById('value'):setColor(color)
    local meter = row:getChildById('meter')
    for i = 1, 4 do
      meter:getChildById('bar' .. i):setBackgroundColor(i <= bars and color or BAR_OFF)
    end
  end
end

-- also draws the plates of the Guides. No ping yet: nil
function drawPlate(plate, fps, ping)
  local bars, color = fpsQuality(fps)
  drawRow(plate:getChildById('fps'), tostring(fps), bars, color)
  if ping then
    bars, color = pingQuality(ping)
    drawRow(plate:getChildById('ping'), ping .. ' ms', bars, color)
  else
    drawRow(plate:getChildById('ping'), '--', 0, UNKNOWN)
  end
end

local function currentPing()
  -- a late answer shows as it grows: a frozen connection must not keep showing its last good number
  if lastPing and pingWaitingSince then
    local waited = g_clock.millis() - pingWaitingSince
    if waited > SHOW_WAIT_AFTER and waited > lastPing then
      return waited
    end
  end
  return lastPing
end

local function askPing()
  if not g_game.isOnline() or not modules.client_options.getOption('showPing') then return end
  local now = g_clock.millis()
  if pingSentAt then
    if now - pingSentAt < PING_RETRY then return end
  elseif now < pingNextAt then
    return
  end
  local protocol = g_game.getProtocolGame()
  if protocol then
    pingSentAt = now
    pingWaitingSince = pingWaitingSince or now
    protocol:sendExtendedOpcode(PING_OPCODE, '')
  end
end

local function onPingAnswer()
  if not pingSentAt then return end
  local now = g_clock.millis()
  lastPing = now - pingSentAt
  pingSentAt, pingWaitingSince = nil, nil
  pingNextAt = now + PING_EVERY
end

local function resetPing()
  pingSentAt, pingWaitingSince, pingNextAt, lastPing = nil, nil, 0, nil
end

local function showPlate()
  ui:setVisible(shown and (ui:getChildById('fps'):isExplicitlyVisible() or ui:getChildById('ping'):isExplicitlyVisible()))
end

function init()
  ui = g_ui.loadUI('stats', modules.game_interface.getMapPanel())
  ui:getChildById('fps'):setVisible(modules.client_options.getOption('showFps'))
  ui:getChildById('ping'):setVisible(modules.client_options.getOption('showPing'))

  ProtocolGame.registerExtendedOpcode(PING_OPCODE, onPingAnswer)
  connect(g_game, { onGameStart = resetPing, onGameEnd = resetPing })

  updateEvent = scheduleEvent(update, 200)
end

function terminate()
  removeEvent(updateEvent)
  disconnect(g_game, { onGameStart = resetPing, onGameEnd = resetPing })
  ProtocolGame.unregisterExtendedOpcode(PING_OPCODE)
  ui:destroy()
end

function update()
  updateEvent = scheduleEvent(update, 500)
  askPing()
  if ui:isHidden() then return end
  drawPlate(ui, g_app.getFps(), currentPing())
end

-- row: 'fps' or 'ping', from the options
function setRowVisible(row, visible)
  ui:getChildById(row):setVisible(visible)
  showPlate()
end

function show()
  shown = true
  showPlate()
end

function hide()
  shown = false
  showPlate()
end
