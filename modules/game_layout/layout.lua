-- Every character finds its windows and backpacks as it left them, also after restarting the client:
--   windows    the side panel and the place of every mini window (skills, battle, VIP...), its height, minimized or not
--              (open or closed is kept by the client itself, in its options)
--   backpacks  every backpack that was open is opened again, in the same order, and its window goes back to its place
-- Everything is written to the character's settings folder (layout.json) every few seconds and at logout, and put
-- back a moment after the login.
--
-- A backpack is remembered by its path: the inventory slot it comes from, then its place inside every backpack on the
-- way, with the item ids (a backpack that moved inside its parent is still found by its id). The path is learnt when
-- the player opens it: g_game.open and g_game.openParent are wrapped to know which item was opened.

local CAPTURE_INTERVAL = 2000 -- the layout is noted this often (the logout destroys the backpack windows first)
local SAVE_EVERY = 5 -- and written every 5 notes
local RESTORE_DELAY = 2000 -- after the login: the modules have set up their windows and the inventory has arrived
local OPEN_GAP = 250 -- between two backpacks (the server's action delay)
local OPEN_TIMEOUT = 1500
local OPEN_TRIES = 4 -- right after the login the server may not answer yet

local paths = {} -- container id -> {slots = {inventory slot, index, index...}, ids = {item id, item id...}}
local pending = nil -- the item the player is opening: {pos, id, time}
local pendingParent = nil -- the container whose parent the player is opening: {cid, time}
local restoring = false
local restoreQueue, restoreEntry, restoreOpened = nil, nil, nil
local restoreEvent, timeoutEvent, saveEvent, startEvent, soonEvent = nil, nil, nil, nil, nil
local lastLayout = nil -- the layout as last noted in game (at logout the backpack windows are already gone)
local captures = 0
local originalOpen, originalOpenParent

local function copy(list, count)
  local result = {}
  for i = 1, count or #list do
    result[i] = list[i]
  end
  return result
end

local function pathKey(slots, count)
  return table.concat(slots, '.', 1, count or #slots)
end

-- side panels ------------------------------------------------------------------------------------------------------

local function sidePanels()
  return {left = modules.game_interface.gameLeftPanels, right = modules.game_interface.gameRightPanels}
end

-- side and number of the side panel a window is in
local function panelOf(window)
  local parent = window:getParent()
  if not parent then
    return nil
  end

  for side, panels in pairs(sidePanels()) do
    if panels and parent:getParent() == panels then
      return side, panels:getChildIndex(parent)
    end
  end
end

local function getPanel(side, number)
  local panels = sidePanels()[side]
  if not panels or panels:getChildCount() == 0 then
    return nil
  end
  return panels:getChildByIndex(math.max(1, math.min(number, panels:getChildCount())))
end

local function windowState(window)
  local side, number = panelOf(window)
  if not side then
    return nil
  end

  local minimized = window:isOn()
  return {side = side, panel = number, index = window:getParent():getChildIndex(window),
    height = minimized and window.maximizedHeight or window:getHeight(), minimized = minimized}
end

-- puts a window in its panel (its order is fixed at the end, see orderPanels), with its height and minimized state
local function placeWindow(window, state)
  if not window or not state then
    return
  end

  local panel = getPanel(state.side, state.panel)
  if panel and window:getParent() ~= panel then
    local oldParent = window:getParent()
    if oldParent then
      oldParent:removeChild(window)
    end
    panel:addChild(window)
  end
  window.layoutIndex = state.index

  if state.minimized then
    if not window:isOn() then
      window:minimize(true)
    end
  else
    if window:isOn() then
      window:maximize(true)
    end
    if state.height and window:isResizeable() then
      window:setHeight(state.height)
    end
  end
end

-- the windows that have a saved place go back to it; the others keep their order after them
local function orderPanels()
  for _, panels in pairs(sidePanels()) do
    if panels then
      for _, panel in ipairs(panels:getChildren()) do
        local children = panel:getChildren()
        local current = {}
        for i, child in ipairs(children) do
          current[child] = i
        end
        table.sort(children, function(a, b)
          return (a.layoutIndex or 1000 + current[a]) < (b.layoutIndex or 1000 + current[b])
        end)
        panel:reorderChildren(children)
        if panel.fitAll then
          panel:fitAll()
        end
      end
    end
  end
end

-- backpack paths ---------------------------------------------------------------------------------------------------

local function noteOpen(item)
  if item and item.getPosition then
    pending = {pos = item:getPosition(), id = item:getId(), time = g_clock.millis()}
  end
end

local function wrappedOpen(item, previousContainer, ...)
  noteOpen(item)
  return originalOpen(item, previousContainer, ...)
end

local function wrappedOpenParent(container, ...)
  if container then
    pendingParent = {cid = container:getId(), time = g_clock.millis()}
  end
  return originalOpenParent(container, ...)
end

-- the first backpack with this id in a container (its own place first: it may have moved since)
local function findBackpack(container, index, id)
  local items = container:getItems()
  local item = items[index + 1]
  if item and item:isContainer() and item:getId() == id then
    return item, index
  end

  for i, other in ipairs(items) do
    if other:isContainer() and other:getId() == id then
      return other, i - 1
    end
  end
end

local function onContainerOpen(container, previousContainer)
  local now = g_clock.millis()
  local cid = container:getId()
  local path = nil

  if pendingParent and now - pendingParent.time < 3000 and previousContainer and paths[previousContainer:getId()] then
    -- "up": the parent of an open backpack
    local child = paths[previousContainer:getId()]
    if #child.slots > 1 then
      path = {slots = copy(child.slots, #child.slots - 1), ids = copy(child.ids, #child.ids - 1)}
    end
    pendingParent = nil
  elseif pending and now - pending.time < 3000 and pending.pos and pending.pos.x == 65535 then
    local pos = pending.pos
    if pos.y < 64 then
      path = {slots = {pos.y}, ids = {pending.id}}
    elseif paths[pos.y - 64] then
      local parent = paths[pos.y - 64]
      path = {slots = copy(parent.slots), ids = copy(parent.ids)}
      table.insert(path.slots, pos.z)
      table.insert(path.ids, pending.id)
    end
    pending = nil
  end

  if not path and restoreEntry then
    path = {slots = copy(restoreEntry.slots), ids = copy(restoreEntry.ids)}
  end
  paths[cid] = path -- nil for backpacks on the ground (depot, Browse Field...): those are not reopened

  if restoreEntry then
    if timeoutEvent then
      removeEvent(timeoutEvent)
      timeoutEvent = nil
    end
    restoreOpened[pathKey(restoreEntry.slots)] = container
    placeWindow(container.window, restoreEntry.window)
    restoreEntry = nil
    restoreEvent = scheduleEvent(restoreNext, OPEN_GAP)
  elseif path then
    saveSoon()
  end
end

local function onContainerClose(container)
  if g_game.isOnline() then
    paths[container:getId()] = nil
    saveSoon()
  end
end

-- before saving, a path whose backpack moved inside its (open) parent is corrected
local function refreshPaths()
  local byKey = {}
  for cid, container in pairs(g_game.getContainers()) do
    if paths[cid] then
      byKey[pathKey(paths[cid].slots)] = container
    end
  end

  for cid, path in pairs(paths) do
    if #path.slots > 1 then
      local parent = byKey[pathKey(path.slots, #path.slots - 1)]
      if parent then
        local _, index = findBackpack(parent, path.slots[#path.slots], path.ids[#path.ids])
        if index then
          path.slots[#path.slots] = index
        end
      end
    end
  end
end

-- save -------------------------------------------------------------------------------------------------------------

local function snapshot()
  local layout = {version = 1, windows = {}, backpacks = {}}

  for _, panels in pairs(sidePanels()) do
    if panels then
      for _, panel in ipairs(panels:getChildren()) do
        for _, window in ipairs(panel:getChildren()) do
          if not window.containerWindow and window:getId() ~= '' and window.getSettings then
            local state = windowState(window)
            if state then
              layout.windows[window:getId()] = state
            end
          end
        end
      end
    end
  end

  refreshPaths()
  local backpacks = {}
  for cid, container in pairs(g_game.getContainers()) do
    local path = paths[cid]
    if path and container.window then
      table.insert(backpacks, {cid = cid, slots = path.slots, ids = path.ids, window = windowState(container.window)})
    end
  end
  -- parents first, then in the order they were opened
  table.sort(backpacks, function(a, b)
    if #a.slots ~= #b.slots then
      return #a.slots < #b.slots
    end
    return a.cid < b.cid
  end)
  for _, backpack in ipairs(backpacks) do
    backpack.cid = nil
    table.insert(layout.backpacks, backpack)
  end

  return layout
end

local function load()
  local file = settingsFile()
  if not g_resources.fileExists(file) then
    return nil
  end

  local status, result = pcall(function() return json.decode(g_resources.readFileContents(file)) end)
  if not status or type(result) ~= 'table' then
    g_logger.error('Layout not loaded: ' .. tostring(result))
    return nil
  end
  return result
end

local function save(atLogout)
  -- a restore that did not finish would save only part of the backpacks
  if restoring or not (atLogout or g_game.isOnline()) then
    return
  end

  -- at logout the backpack windows are already gone: the layout as it was last noted in game
  local layout = atLogout and lastLayout or snapshot()
  lastLayout = layout

  local status, result = pcall(function() return json.encode(layout, 2) end)
  if status then
    g_resources.writeFileContents(settingsFile(), result)
  else
    g_logger.error('Layout not saved: ' .. tostring(result))
  end
  g_settings.save() -- the open or closed windows live in the client options
end

-- a backpack opened or closed is noted at once and written a moment later
function saveSoon()
  if not restoring and g_game.isOnline() then
    lastLayout = snapshot()
  end
  removeEvent(soonEvent)
  soonEvent = scheduleEvent(function()
    soonEvent = nil
    save()
  end, 1500)
end

-- notes the backpacks every CAPTURE_INTERVAL, writes the file every SAVE_EVERY notes
local function saveLoop()
  captures = captures + 1
  if captures >= SAVE_EVERY then
    captures = 0
    save()
  elseif not restoring and g_game.isOnline() then
    lastLayout = snapshot()
  end
  saveEvent = scheduleEvent(saveLoop, CAPTURE_INTERVAL)
end

-- restore ----------------------------------------------------------------------------------------------------------

local function finishRestore()
  restoring = false
  restoreQueue, restoreEntry, restoreOpened = nil, nil, nil
  if g_game.isOnline() then
    orderPanels()
  end
end

function restoreNext()
  restoreEvent = nil
  if not g_game.isOnline() then
    return finishRestore()
  end

  restoreEntry = table.remove(restoreQueue, 1)
  if not restoreEntry then
    return finishRestore()
  end

  local slots, ids = restoreEntry.slots or {}, restoreEntry.ids or {}
  local item = nil
  if #slots == 1 then
    local player = g_game.getLocalPlayer()
    item = player and player:getInventoryItem(slots[1])
    if item and (not item:isContainer() or item:getId() ~= ids[1]) then
      item = nil
    end
  elseif #slots > 1 then
    local parent = restoreOpened[pathKey(slots, #slots - 1)]
    item = parent and findBackpack(parent, slots[#slots], ids[#ids])
  end

  if not item then
    restoreEntry = nil
    restoreEvent = scheduleEvent(restoreNext, 10)
    return
  end

  -- no answer: asked again a few times, then a backpack that does not open does not stop the others
  timeoutEvent = scheduleEvent(function()
    timeoutEvent = nil
    local entry = restoreEntry
    restoreEntry = nil
    entry.tries = (entry.tries or 1) + 1
    if entry.tries <= OPEN_TRIES then
      table.insert(restoreQueue, 1, entry)
    end
    restoreNext()
  end, OPEN_TIMEOUT)
  g_game.open(item)
end

local function restore()
  startEvent = nil
  if not g_game.isOnline() then
    return
  end

  local layout = load()
  if layout then
    lastLayout = layout -- a logout before the first note keeps what was loaded
    local windows = layout.windows or {}
    for _, panels in pairs(sidePanels()) do
      for _, panel in ipairs(panels and panels:getChildren() or {}) do
        for _, window in ipairs(panel:getChildren()) do
          window.layoutIndex = nil -- left by another character
        end
      end
    end
    for _, panels in pairs(sidePanels()) do
      if panels then
        for _, panel in ipairs(panels:getChildren()) do
          for _, window in ipairs(panel:getChildren()) do
            local state = windows[window:getId()]
            if state and not window.containerWindow then
              placeWindow(window, state)
            end
          end
        end
      end
    end

    -- backpacks the player already opened himself since the login are left alone
    if next(g_game.getContainers()) == nil and layout.backpacks and #layout.backpacks > 0 then
      restoring = true
      restoreQueue = {}
      for i, backpack in ipairs(layout.backpacks) do
        restoreQueue[i] = {slots = backpack.slots, ids = backpack.ids, window = backpack.window}
      end
      restoreOpened = {}
      restoreNext()
    else
      orderPanels()
    end
  end

  saveEvent = scheduleEvent(saveLoop, CAPTURE_INTERVAL)
end

-- events -----------------------------------------------------------------------------------------------------------

local function onGameStart()
  paths = {}
  lastLayout = nil
  pending, pendingParent = nil, nil
  removeEvent(startEvent)
  startEvent = scheduleEvent(restore, RESTORE_DELAY)
end

local function onGameEnd()
  -- the character name and the open backpacks are still there
  save(true)
  for _, event in ipairs({startEvent, saveEvent, restoreEvent, timeoutEvent, soonEvent}) do
    removeEvent(event)
  end
  startEvent, saveEvent, restoreEvent, timeoutEvent, soonEvent = nil, nil, nil, nil, nil
  restoring = false
  restoreQueue, restoreEntry, restoreOpened = nil, nil, nil
end

function settingsFile()
  return modules.client_profiles.getSettingsFilePath('layout.json')
end

function init()
  originalOpen, originalOpenParent = g_game.open, g_game.openParent
  g_game.open = wrappedOpen
  g_game.openParent = wrappedOpenParent

  connect(Container, {onOpen = onContainerOpen, onClose = onContainerClose})
  connect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  if g_game.isOnline() then
    onGameEnd()
  end
  disconnect(Container, {onOpen = onContainerOpen, onClose = onContainerClose})
  disconnect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  g_game.open, g_game.openParent = originalOpen, originalOpenParent
end
