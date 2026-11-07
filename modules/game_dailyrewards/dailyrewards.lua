-- Daily Rewards. The rules are all in the server (data/lib/124-daily_rewards.lua): it sends the state in lines of fields split
-- by | (extended opcode 30) and this window draws them; it asks with "open" and "claim".
--   S|streak|claimed today|seconds to the server save|position of today's reward|week|regeneration|experience %|open now
--   R|day|kind|client item id|count|done, today or locked|bound|what it gives
--   B|from streak|client item id|on|what it gives
--   N|a notice
local OPCODE = 30

local window, button, clockEvent
local dayWidgets = {}
local state = {streak = 0, claimed = false, seconds = 0}

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

local function clock(seconds)
  seconds = math.max(0, seconds)
  return string.format('%d:%02d:%02d', math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

local function drawTime()
  if not window then return end
  if state.claimed then
    window.time:setText(tr('Your next reward comes with the server save, in %s.', clock(state.seconds)))
  elseif state.streak > 0 then
    window.time:setText(tr('Claim today\'s reward within %s to keep your streak of %d.', clock(state.seconds), state.streak))
  else
    window.time:setText(tr('Claim today\'s reward within %s to start a streak.', clock(state.seconds)))
  end
end

local function tick()
  clockEvent = nil
  state.seconds = state.seconds - 1
  if state.seconds <= 0 then
    -- a new day: the server says what it is now, while the window is open
    if window and window:isVisible() then
      send('open')
    end
    return
  end
  drawTime()
  if window and window:isVisible() then
    clockEvent = scheduleEvent(tick, 1000)
  end
end

local function startClock()
  removeEvent(clockEvent)
  clockEvent = nil
  if window and window:isVisible() then
    clockEvent = scheduleEvent(tick, 1000)
  end
end

local function drawDay(widget, parts)
  local day, kind, id, count, status = parts[2], parts[3], tonumber(parts[4]) or 0, tonumber(parts[5]) or 1, parts[6]
  local bound, text = parts[7] == '1', parts[8] or ''
  widget.day:setText(tr('Day %s', day))
  widget.item:setItemId(id)
  widget.item:setItemCount(kind == 'bonus' and 1 or count)
  widget.item:setVirtual(true)
  widget.kind:setText(kind == 'bonus' and tr('bonus') or (bound and tr('bound') or ''))
  widget.kind:setColor(kind == 'bonus' and '#f4d68c' or '#a8a8a8')
  widget:setTooltip(text)
  widget:setOn(status == 'done')
  widget.seal:setVisible(status == 'done')
  widget.done:setVisible(status == 'done')
  widget.claim:setVisible(status == 'today')
  widget.lock:setVisible(status == 'locked')
  widget.item:setOpacity(status == 'locked' and 0.55 or 1)
end

local function drawBonus(widget, parts)
  local from, id, on, text = tonumber(parts[2]) or 0, tonumber(parts[3]) or 0, parts[4] == '1', parts[5] or ''
  widget.item:setItemId(id)
  widget.item:setVirtual(true)
  widget.from:setText(tr('Streak %d or more', from))
  widget.text:setText((text:gsub(' while your streak is %d or more', ''):gsub(' every 2 seconds', ' every 2 s')))
  widget.seal:setVisible(on)
  widget.locked:setVisible(not on)
  widget:setTooltip(text)
end

function onDailyMessage(protocol, opcode, buffer)
  if not window then return end
  local bonus, day, open = 0, 0, false
  for line in buffer:gmatch('[^\n]+') do
    local parts = split(line)
    if parts[1] == 'S' then
      state.streak = tonumber(parts[2]) or 0
      state.claimed = parts[3] == '1'
      state.seconds = tonumber(parts[4]) or 0
      window.streakCount:setText(tostring(state.streak))
      window.daysFrame.caption:setText(tr('Daily Rewards - Week %s', parts[6] or '1'))
      open = parts[9] == '1'
    elseif parts[1] == 'R' then
      day = day + 1
      if dayWidgets[day] then drawDay(dayWidgets[day], parts) end
    elseif parts[1] == 'B' then
      bonus = bonus + 1
      local widget = window['bonus' .. bonus]
      if widget then drawBonus(widget, parts) end
    elseif parts[1] == 'N' then
      displayInfoBox(tr('Daily Rewards'), parts[2] or '')
    end
  end
  if open then
    show()
  end
  drawTime()
  startClock()
end

function show()
  if not window then return end
  window:show()
  window:raise()
  window:focus()
  startClock()
end

function hide()
  if window then window:hide() end
  removeEvent(clockEvent)
  clockEvent = nil
end

function toggle()
  if window:isVisible() then
    hide()
  else
    show()
    send('open')
  end
end

local function onGameEnd()
  hide()
end

function init()
  window = g_ui.displayUI('dailyrewards')
  window:hide()
  window.streakFrame.caption:setText(tr('Streak Bonuses'))
  window.daysFrame.caption:setText(tr('Daily Rewards'))
  for i = 1, 7 do
    local widget = g_ui.createWidget('DailyDay', window.days)
    widget.claim.onClick = function() send('claim') end
    dayWidgets[i] = widget
  end
  -- no button: the window opens only when the player uses a reward shrine in the game (the server sends open)
  ProtocolGame.registerExtendedOpcode(OPCODE, onDailyMessage)
  connect(g_game, {onGameEnd = onGameEnd})
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd = onGameEnd})
  removeEvent(clockEvent)
  clockEvent = nil
  if button then button:destroy() end
  if window then window:destroy() end
  window, button = nil, nil
  dayWidgets = {}
end
