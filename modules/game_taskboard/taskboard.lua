-- The Task Board. The rules are all in the server (data/lib/113-task_board.lua): it sends what there is, in lines of fields
-- separated by | (extended opcode 11), and this window only draws them and asks for things with a word.
local OPCODE = 11
local SLOTS = 9
local REFRESH = 4000 -- how often the open board asks again, as the items a player carries change
local WEEKLY_TOTAL = 18
local WEEKLY_STEPS = {{0, 'x1', 1}, {4, 'x2', 2}, {8, 'x3', 3}, {12, 'x5', 5}, {16, 'x8', 8}}
local TRACKER_ROW, TRACKER_CAPTION = 36, 18
local GRADES = {
  Gold = {image = '/images/taskboard/ribbon_gold', color = '#3c2608'},
  Silver = {image = '/images/taskboard/ribbon_silver', color = '#202020'},
}
local PLAIN_GRADE = {image = '/images/taskboard/ribbon', color = '#ffffff'}
local GREEN, RED, GOLD = '#6ed06e', '#e05a4a', '#c8963c'
local EXPANSION_NAME = 'Weekly Tasks Expansion'

local window, tracker, boardButton, trackerButton, refreshEvent, box
local killCells, deliveryCells = {}, {}
local stepLabels = {}
local activeTab = 'bounty'
local trackerSized = false
local state

local function emptyState()
  return {points = 0, tokens = 0, tokenLimit = 10, canClaim = false, seconds = 0, expansion = false, xp = 0, done = 0,
    multiplier = 1, forecast = 0, kills = {}, deliveries = {}, offers = {}, damage = 20, expansionPrice = 900}
end

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

local function number(value)
  return tonumber(value) or 0
end

-- items are named in lower case on the server
local function titled(name)
  return (name:gsub('(%a)([%w\']*)', function(first, rest) return first:upper() .. rest end))
end

local function look(parts, at)
  return {type = number(parts[at]), auxType = number(parts[at + 1]), head = number(parts[at + 2]), body = number(parts[at + 3]),
    legs = number(parts[at + 4]), feet = number(parts[at + 5]), addons = number(parts[at + 6])}
end

local function closeBox()
  if box then
    box:destroy()
    box = nil
  end
end

local function confirm(title, text, action)
  closeBox()
  local function no() closeBox() end
  local function yes()
    closeBox()
    action()
  end
  box = displayGeneralBox(title, text, {{text = tr('Yes'), callback = yes}, {text = tr('No'), callback = no}}, yes, no)
end

local function setBar(track, part, whole, color)
  track.bar:setPercent(math.min(100, part * 100 / math.max(1, whole)))
  track.bar:setBackgroundColor(color or GOLD)
end

-- ---------------------------------------------------------------------------------------------- drawing
local function drawBounty()
  local panel = window.bountyPanel
  local bounty = state.bounty
  local card = panel.stage.card
  card:setVisible(bounty ~= nil)
  panel.stage.noTask:setVisible(bounty == nil)
  panel.rerollFrame.tokensBox.tokens:setText(state.tokens .. ' / ' .. state.tokenLimit)
  panel.rerollFrame.dailyButton:setEnabled(state.canClaim and state.tokens < state.tokenLimit)
  panel.rerollFrame.dailyButton:setTooltip(state.canClaim and tr('One free reroll token a day.') or tr("You already claimed today's reroll token."))
  local finished = bounty ~= nil and bounty.kills >= bounty.need
  panel.rerollFrame.rerollButton:setEnabled(bounty ~= nil and state.tokens > 0 and not finished)
  panel.rerollFrame.rerollButton:setTooltip(tr('Spend a reroll token to change this task for another.'))
  panel.stage.bonus.amount:setText(tr('+%d%% damage', state.damage))
  if not bounty then
    return
  end

  local grade = GRADES[bounty.grade] or PLAIN_GRADE
  card.ribbon:setImageSource(grade.image)
  card.ribbon.name:setText(bounty.name)
  card.ribbon.name:setColor(grade.color)
  card.ribbon:setTooltip(bounty.grade ~= '' and tr('%s task: greater rewards.', bounty.grade) or '')
  card.creature:setOutfit(bounty.look)
  setBar(card.kills, bounty.kills, bounty.need, finished and '#3f9a3f' or GOLD)
  card.kills.count:setText(comma_value(bounty.kills) .. ' / ' .. comma_value(bounty.need) .. ' ' .. tr('kills'))
  card.rewardXp:setText(comma_value(bounty.xp) .. ' XP')
  card.rewardPoints:setText(comma_value(bounty.points) .. ' ' .. tr('Task Points'))
  card.tokenLimit:setVisible(state.tokens >= state.tokenLimit)
  card.claimButton:setEnabled(finished)
  card.claimButton:setTooltip(finished and '' or tr('Finish the task to claim the reward.'))
end

local function showLocked(cell)
  cell.locked:setVisible(true)
  cell.locked.unlock.onClick = function()
    if modules.game_store then
      modules.game_store.show(EXPANSION_NAME)
    end
  end
  cell.locked.unlock:setTooltip(tr('Buy the %s in the Store for %d points: 3 more kill tasks and 3 more delivery tasks.', EXPANSION_NAME, state.expansionPrice))
end

local function drawCell(cell, name, finished, count, need)
  cell.name:setText(name)
  cell.name:setTooltip(name)
  cell.count:setText(comma_value(count))
  cell.count:setColor(finished and GREEN or RED)
  cell.need:setText(tr('of') .. ' ' .. comma_value(need))
  cell.seal:setVisible(finished)
  cell:setImageSource(finished and '/images/taskboard/cell_done' or '/images/taskboard/cell')
  cell.locked:setVisible(false)
end

local function drawKillCell(slot)
  local cell = killCells[slot]
  local task = state.kills[slot]
  cell:setVisible(task ~= nil)
  if not task then
    return
  end

  drawCell(cell, task.name, task.kills >= task.need, task.kills, task.need)
  cell.creature:setOutfit(task.look)
  if task.locked then
    showLocked(cell)
  end
end

local function drawDeliveryCell(slot)
  local cell = deliveryCells[slot]
  local task = state.deliveries[slot]
  cell:setVisible(task ~= nil)
  if not task then
    return
  end

  local count = task.done and task.need or task.have
  drawCell(cell, task.name, task.done, count, task.need)
  if not task.done and task.have >= task.need then
    cell.count:setColor(GREEN)
  end
  cell.item:setItemId(task.clientId)
  cell.deliver:setText(task.done and tr('Done') or tr('Deliver'))
  cell.deliver:setEnabled(not task.done and task.have >= task.need)
  cell.deliver.onClick = function()
    confirm(tr('Confirm'), tr('Do you really want to deliver %dx %s?', task.need, task.name), function()
      send('deliver,' .. slot)
    end)
  end
  if task.locked then
    showLocked(cell)
  end
end

local function drawWeekly()
  local panel = window.weeklyPanel
  for slot = 1, SLOTS do
    drawKillCell(slot)
    drawDeliveryCell(slot)
  end

  panel.rewardPlate.reward:setText(tr('Each task rewards you with %s XP.', comma_value(state.xp)))
  local frame = panel.progressFrame
  setBar(frame.track, state.done, WEEKLY_TOTAL)
  frame.track:setTooltip(tr('Completed tasks: %d. Reward multiplier: x%d.', state.done, state.multiplier))
  local width = frame.track:getWidth()
  for _, label in ipairs(stepLabels) do
    label:setMarginLeft(math.floor(label.step * width))
    if label.multiplier then
      label:setColor(label.multiplier == state.multiplier and '#f4d68c' or '#9a9a9a')
    end
  end

  local rewards = panel.rewardsFrame
  rewards.pointsBox.points:setText(comma_value(state.forecast))
  rewards.pointsBox:setTooltip(tr('Task Points when the week ends: (%d kill tasks x %d + %d delivery tasks x %d) x %d.',
    state.killsDone or 0, state.killPoints or 0, state.deliveriesDone or 0, state.deliveryPoints or 0, state.multiplier))
  local days = math.floor(state.seconds / 86400)
  rewards.remaining:setText(days >= 1 and tr('%d day(s) remaining', days) or tr('%d hour(s) remaining', math.ceil(state.seconds / 3600)))
end

local function drawShop()
  local panel = window.shopPanel.frame
  panel.offers:destroyChildren()
  local empty = #state.offers == 0
  panel.chest:setVisible(empty)
  panel.empty:setVisible(empty)
  for _, offer in ipairs(state.offers) do
    local cell = g_ui.createWidget('TaskOffer', panel.offers)
    cell.name:setText(offer.name)
    cell.name:setTooltip(offer.name)
    if offer.clientId > 0 then
      cell.item:setItemId(offer.clientId)
      cell.creature:hide()
    elseif offer.look > 0 then
      cell.creature:setOutfit({type = offer.look})
      cell.item:hide()
    end
    cell.buy:setText(offer.owned and tr('Bought') or comma_value(offer.price))
    cell.buy.coin:setVisible(not offer.owned)
    cell.buy:setEnabled(not offer.owned and state.points >= offer.price)
    cell.buy:setTooltip(not offer.owned and state.points < offer.price and tr("You don't have enough Task Points.") or '')
    cell.buy.onClick = function()
      confirm(tr('Confirm'), tr('Would you like to buy "%s" for %s Task Points?', offer.name, comma_value(offer.price)), function()
        send('buy,' .. offer.id)
      end)
    end
  end
end

local function drawBoard()
  if not window or not window:isVisible() then
    return
  end

  window.pointsBalance.value:setText(comma_value(state.points))
  if activeTab == 'bounty' then
    drawBounty()
  elseif activeTab == 'weekly' then
    drawWeekly()
  else
    drawShop()
  end
end

-- ---------------------------------------------------------------------------------------------- tracker
local function fillRow(row, task)
  setBar(row.back, task.kills, task.need)
  row.back.count:setText(comma_value(task.kills) .. ' / ' .. comma_value(task.need))
end

local function addRow(panel, task, tab)
  local row = g_ui.createWidget('TaskTrackerRow', panel)
  row.name:setText(task.name)
  row.creature:setOutfit(task.look)
  row:setTooltip(tr('Click to open the Task Board.'))
  row.onMouseRelease = function(widget, mousePos, button)
    if button == MouseLeftButton and widget:containsPoint(mousePos) then
      showTab(tab)
      return true
    end
  end
  fillRow(row, task)
  task.row = row
end

local function addCaption(panel, text)
  g_ui.createWidget('TaskTrackerCaption', panel):setText(text)
end

local function drawTracker()
  if not tracker then
    return
  end

  local panel = tracker.contentsPanel
  panel:destroyChildren()
  local height = 8
  if state.bounty then
    addCaption(panel, tr('Bounty Task'))
    addRow(panel, state.bounty, 'bounty')
    height = height + TRACKER_CAPTION + TRACKER_ROW
  end

  local first = true
  for slot = 1, SLOTS do
    local task = state.kills[slot]
    if task and not task.locked and task.kills < task.need then
      if first then
        addCaption(panel, tr('Weekly Tasks'))
        height = height + TRACKER_CAPTION
        first = false
      end
      addRow(panel, task, 'weekly')
      height = height + TRACKER_ROW
    end
  end

  tracker:setContentMaximumHeight(height)
  if not trackerSized and height > 8 then
    trackerSized = true
    tracker:setContentHeight(height)
    local parent = tracker:getParent()
    if parent and parent.fitAll then
      parent:fitAll(tracker)
    end
  end
end

-- ---------------------------------------------------------------------------------------------- the server
local function parseState(buffer)
  local new = emptyState()
  local results
  for line in buffer:gmatch('[^\n]+') do
    local f = split(line)
    if f[1] == 'P' then
      new.points, new.tokens, new.tokenLimit = number(f[2]), number(f[3]), number(f[4])
      new.canClaim, new.seconds, new.expansion = f[5] == '1', number(f[6]), f[7] == '1'
      new.xp, new.done, new.multiplier, new.forecast = f[8], number(f[9]), number(f[10]), number(f[11])
      new.killsDone, new.killPoints, new.deliveriesDone, new.deliveryPoints = number(f[12]), number(f[13]), number(f[14]), number(f[15])
      new.damage, new.expansionPrice = number(f[16]), number(f[17])
    elseif f[1] == 'B' then
      new.bounty = {name = f[2], kills = number(f[3]), need = number(f[4]), grade = f[5], xp = f[6], points = number(f[7]), look = look(f, 8)}
    elseif f[1] == 'K' then
      new.kills[number(f[2])] = {name = f[3], kills = number(f[4]), need = number(f[5]), locked = f[6] == '1', look = look(f, 7)}
    elseif f[1] == 'D' then
      new.deliveries[number(f[2])] = {name = titled(f[3]), clientId = number(f[4]), have = number(f[5]), need = number(f[6]), done = f[7] == '1', locked = f[8] == '1'}
    elseif f[1] == 'O' then
      table.insert(new.offers, {id = number(f[2]), kind = f[3], name = f[4], price = number(f[5]), clientId = number(f[6]), look = number(f[7]), owned = f[8] == '1'})
    elseif f[1] == 'R' then
      results = {kills = number(f[2]), killsTotal = number(f[3]), deliveries = number(f[4]), deliveriesTotal = number(f[5]), points = number(f[6])}
    end
  end
  return new, results
end

local function showResults(results)
  send('results')
  displayInfoBox(tr('Weekly Results'), tr('You have completed %d / %d kill tasks.', results.kills, results.killsTotal) .. '\n' ..
    tr('You have completed %d / %d delivery tasks.', results.deliveries, results.deliveriesTotal) .. '\n\n' ..
    tr('Total earned: %s Task Points.', comma_value(results.points)))
end

function onTaskMessage(protocol, opcode, buffer)
  local kind = buffer:sub(1, 1)
  if kind == 'S' then
    local results
    state, results = parseState(buffer)
    drawBoard()
    drawTracker()
    if results then
      if window:isVisible() then
        showResults(results)
      else
        state.results = results
      end
    end
  elseif kind == 'k' then
    local slot, kills = buffer:match('^k|(%d+)|(%d+)$')
    slot, kills = tonumber(slot), tonumber(kills)
    local task = slot == 0 and state.bounty or state.kills[slot or -1]
    if task and kills then
      task.kills = kills
      if task.row then
        fillRow(task.row, task)
      end
      drawBoard()
    end
  elseif kind == 'N' then
    if window:isVisible() then
      displayInfoBox(tr('Task Board'), buffer:sub(3))
    end
  end
end

-- ---------------------------------------------------------------------------------------------- the window
function showTab(tab)
  if not g_game.isOnline() then
    return
  end

  activeTab = tab
  for _, name in ipairs({'bounty', 'weekly', 'shop'}) do
    window[name .. 'Panel']:setVisible(name == tab)
    window[name .. 'Tab']:setOn(name == tab)
  end
  show()
end

local function refresh()
  refreshEvent = nil
  if window and window:isVisible() and g_game.isOnline() then
    send('open')
    refreshEvent = scheduleEvent(refresh, REFRESH)
  end
end

function show()
  if not g_game.isOnline() then
    return
  end

  window:show()
  window:raise()
  window:focus()
  drawBoard()
  removeEvent(refreshEvent)
  refresh()
  if state.results then
    local results = state.results
    state.results = nil
    showResults(results)
  end
end

function toggle()
  if window:isVisible() then
    window:hide()
  else
    showTab(activeTab)
  end
end

local function toggleTracker()
  if tracker:isVisible() then
    tracker:close()
  else
    tracker:open()
  end
end

local function onGameStart()
  state = emptyState()
  trackerSized = false
  send('open')
end

local function onGameEnd()
  closeBox()
  removeEvent(refreshEvent)
  refreshEvent = nil
  window:hide()
  state = emptyState()
  drawTracker()
end

local function makeCells()
  for slot = 1, SLOTS do
    killCells[slot] = g_ui.createWidget('TaskKillCell', window.weeklyPanel.killFrame.cells)
    deliveryCells[slot] = g_ui.createWidget('TaskDeliveryCell', window.weeklyPanel.deliveryFrame.cells)
    -- over what each kind of cell adds to the common ones
    killCells[slot].locked:raise()
    deliveryCells[slot].locked:raise()
  end

  -- the steps of the reward over the bar and the tasks they need under it
  local frame = window.weeklyPanel.progressFrame
  local function addStep(text, color, edge, hook, step, multiplier)
    local label = g_ui.createWidget('Label', frame)
    label:setText(text)
    label:setColor(color)
    label:setTextAutoResize(true)
    label:addAnchor(edge, 'track', hook)
    label:addAnchor(AnchorHorizontalCenter, 'track', AnchorLeft)
    label.step = step
    label.multiplier = multiplier
    table.insert(stepLabels, label)
  end
  for _, step in ipairs(WEEKLY_STEPS) do
    addStep(step[2], '#9a9a9a', AnchorBottom, AnchorTop, step[1] / WEEKLY_TOTAL, step[3])
    addStep(tostring(step[1]), '#c8c8c8', AnchorTop, AnchorBottom, step[1] / WEEKLY_TOTAL)
    if step[1] > 0 then
      local tick = g_ui.createWidget('TaskTick', frame.track)
      tick:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      tick.step = step[1] / WEEKLY_TOTAL
      table.insert(stepLabels, tick)
    end
  end
  addStep(tostring(WEEKLY_TOTAL), '#c8c8c8', AnchorTop, AnchorBottom, 1)

  window.bountyPanel.rerollFrame.caption:setText(tr('Reroll Task'))
  window.bountyPanel.stage.bonus.caption:setText(tr('Hunting Bonus'))
  window.bountyPanel.stage.grades.caption:setText(tr('Silver and Gold'))
  window.weeklyPanel.killFrame.caption:setText(tr('Kill Tasks'))
  window.weeklyPanel.deliveryFrame.caption:setText(tr('Delivery Tasks'))
  frame.caption:setText(tr('Weekly Progress'))
  window.weeklyPanel.rewardsFrame.caption:setText(tr('Weekly Rewards'))
  window.shopPanel.frame.caption:setText(tr('Task Shop'))
  window.bountyPanel.stage.card.caption:hide()
  window.bountyTab.picture:setImageSource('/images/taskboard/poster30')
  window.weeklyTab.picture:setImageSource('/images/taskboard/scroll30')
  window.shopTab.picture:setImageSource('/images/taskboard/pouch30')
end

function init()
  state = emptyState()
  window = g_ui.displayUI('taskboard')
  window:hide()
  makeCells()
  window.bountyTab.onClick = function() showTab('bounty') end
  window.weeklyTab.onClick = function() showTab('weekly') end
  window.shopTab.onClick = function() showTab('shop') end
  window.bountyPanel.rerollFrame.rerollButton.onClick = function()
    local bounty = state.bounty
    if bounty and bounty.kills > 0 then
      confirm(tr('Confirm'), tr('Change this task for another? You lose its %d kills.', bounty.kills), function() send('reroll') end)
    else
      send('reroll')
    end
  end
  window.bountyPanel.rerollFrame.dailyButton.onClick = function() send('daily') end
  window.bountyPanel.stage.card.claimButton.onClick = function() send('claim') end

  tracker = g_ui.createWidget('TaskTracker', modules.game_interface.getRightPanel())
  tracker:setup()
  boardButton = modules.client_topmenu.addLeftGameButton('taskBoardButton', tr('Task Board'), '/images/topbuttons/taskboard', toggle, false, 4)
  trackerButton = modules.client_topmenu.addRightGameToggleButton('taskTrackerButton', tr('Task Tracker'), '/images/topbuttons/tasktracker', toggleTracker, false, 5)
  trackerButton:setOn(tracker:isVisible())
  tracker.onOpen = function() trackerButton:setOn(true) end
  tracker.onClose = function() trackerButton:setOn(false) end

  ProtocolGame.registerExtendedOpcode(OPCODE, onTaskMessage)
  connect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  closeBox()
  removeEvent(refreshEvent)
  refreshEvent = nil
  killCells, deliveryCells, stepLabels = {}, {}, {}
  if window then
    window:destroy()
    window = nil
  end
  if tracker then
    tracker:destroy()
    tracker = nil
  end
  if boardButton then
    boardButton:destroy()
    boardButton = nil
  end
  if trackerButton then
    trackerButton:destroy()
    trackerButton = nil
  end
end
