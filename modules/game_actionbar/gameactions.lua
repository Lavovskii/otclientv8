-- Game actions that can be assigned to an action button ("Assign Action"):
--   attackNext  attack the next creature of the battle list (so its filters and sorting apply), optionally players only
--               or monsters only
--   loot        instantly move everything from the corpses around the player (and the containers inside them, never the
--               containers) to the loot bag (right click a backpack -> "Set as loot bag") or the main backpack, except
--               the items on the ignore loot list (right click an item -> "Add to ignore loot list")
--   stopAttack  stop attacking (and following)
--   useUnder    use the item under the player (climb a ladder, use stairs, a lever, a hole...)

GAME_ACTION = {
  ATTACK_NEXT = 'attackNext',
  LOOT = 'loot',
  STOP_ATTACK = 'stopAttack',
  USE_UNDER = 'useUnder'
}

TARGET_FILTER = {
  ALL = 'all',
  PLAYERS = 'players',
  MONSTERS = 'monsters'
}

function gameActionLabel(action, filter)
  if action == GAME_ACTION.ATTACK_NEXT then
    if filter == TARGET_FILTER.PLAYERS then return 'Next\nPlayer' end
    if filter == TARGET_FILTER.MONSTERS then return 'Next\nMonster' end
    return 'Next\nTarget'
  elseif action == GAME_ACTION.LOOT then
    return 'Loot'
  elseif action == GAME_ACTION.STOP_ATTACK then
    return 'Stop\nAttack'
  elseif action == GAME_ACTION.USE_UNDER then
    return 'Use\nUnder'
  end
  return ''
end

function gameActionDescription(action, filter)
  if action == GAME_ACTION.ATTACK_NEXT then
    local what = 'creature'
    if filter == TARGET_FILTER.PLAYERS then what = 'player' elseif filter == TARGET_FILTER.MONSTERS then what = 'monster' end
    return 'Attack the next ' .. what .. ' of the battle list'
  elseif action == GAME_ACTION.LOOT then
    return 'Loot the creatures around you into your loot bag (items on the ignore loot list are left behind)'
  elseif action == GAME_ACTION.STOP_ATTACK then
    return 'Stop attacking'
  elseif action == GAME_ACTION.USE_UNDER then
    return 'Use the item under you (ladders, stairs, levers...)'
  end
  return 'None'
end

function runGameAction(action, filter)
  if not g_game.isOnline() then
    return
  end

  if action == GAME_ACTION.ATTACK_NEXT then
    attackNextTarget(filter)
  elseif action == GAME_ACTION.LOOT then
    lootAround()
  elseif action == GAME_ACTION.STOP_ATTACK then
    g_game.cancelAttackAndFollow()
  elseif action == GAME_ACTION.USE_UNDER then
    useItemUnderPlayer()
  end
end

-- use item under the player ---------------------------------------------------------------------------------------

function useItemUnderPlayer()
  local player = g_game.getLocalPlayer()
  local tile = player and player:getTile()
  if not tile then
    return
  end

  -- the top usable item of the tile first, then the ground (some stairs and holes are ground items)
  local thing = tile:getTopUseThing()
  if not thing or thing:isCreature() then
    thing = tile:getGround()
  end

  if thing then
    g_game.use(thing)
  end
end

-- attack -------------------------------------------------------------------------------------------------------

function attackNextTarget(filter)
  local battle = modules.game_battle
  if not battle or not battle.getDisplayedCreatures then
    return
  end

  local candidates = {}
  for _, creature in ipairs(battle.getDisplayedCreatures()) do
    if creature:isPlayer() and filter ~= TARGET_FILTER.MONSTERS
        or creature:isMonster() and filter ~= TARGET_FILTER.PLAYERS then
      table.insert(candidates, creature)
    end
  end

  if #candidates == 0 then
    return
  end

  local current = g_game.getAttackingCreature()
  local index = 0
  if current then
    for i, creature in ipairs(candidates) do
      if creature == current then
        index = i
        break
      end
    end
  end

  g_game.attack(candidates[(index % #candidates) + 1])
end

-- ignore loot list ---------------------------------------------------------------------------------------------

function isIgnoredLoot(itemId)
  local list = getSettings().ignoreLoot
  return list ~= nil and list[tostring(itemId)] == true
end

function setIgnoredLoot(itemId, ignored)
  local settings = getSettings()
  settings.ignoreLoot = settings.ignoreLoot or {}
  settings.ignoreLoot[tostring(itemId)] = ignored and true or nil
  if next(settings.ignoreLoot) == nil then
    settings.ignoreLoot = nil
  end
  save()
end

-- loot ---------------------------------------------------------------------------------------------------------
--
-- The loot hotkey takes everything out of the corpses around the player (and out of the containers inside them, never
-- the containers themselves) and puts it into the loot bag, or into the main backpack when there is no loot bag. It is
-- a "press to loot" auto loot: all the moves are sent at once, the server does not delay moves out of an open container.
--
-- How the server answers a move (kept in sync with the server, see player.cpp sendCancelMessage):
--   * dropping on a container that is full  -> "You cannot put more objects in this container."
--   * not enough capacity                   -> "This object is too heavy for you to carry."
--   * dropping on the inventory "capacity" position (x = 65535, y = 0) lets the server pick the first backpack, or
--     bag inside a backpack, that has room; dropping on a container stacks what can be stacked.
-- Items go to the loot bag first (right click a backpack -> "Set as loot bag"). When it is full they go to the next
-- backpack inside it, then to the main backpack (server routing) with a warning, until nothing has slots left.
-- No backpack has to be open: the containers that are needed are opened without a window and closed at the end.

local OPEN_TIMEOUT = 1500    -- ms to wait for a container to open before giving up on it
local SETTLE_DELAY = 250     -- ms to let the server answer the moves before checking what is left
local MAX_DEPTH = 3          -- containers inside containers inside corpses
local FAIL_FULL = 'You cannot put more objects in this container.'
local FAIL_HEAVY = 'This object is too heavy for you to carry.'
local FAIL_ROOM = 'There is not enough room.'
local AUTO_POSITION = {x = 65535, y = 0, z = 0}

local loot = nil        -- running loot job
local pendingOpen = nil -- container we asked the server to open: {containerId, callback, event}
local ownOpened = {}    -- containers opened by the loot hotkey, closed when it ends
local lastOpenRequest = nil
local originalOpen = nil

local function findEmptyContainerId()
  local open = g_game.getContainers()
  local id = 0
  while open[id] do
    id = id + 1
  end
  return id
end

local function cancelSilentOpen(containerId)
  if modules.game_containers then
    modules.game_containers.cancelSilent(containerId)
  end
end

function initGameActions()
  connect(Container, { onOpen = onLootContainerOpen })
  registerMessageMode(MessageModes.Failure, onLootFailureMessage)

  -- the item held by an open container has no position in the client, so every open request is remembered to know
  -- which item each open container belongs to (opening a container that is already open would close it)
  originalOpen = g_game.open
  g_game.open = function(item, previousContainer)
    lastOpenRequest = {
      containerId = previousContainer and previousContainer:getId() or findEmptyContainerId(),
      itemId = item:getId(),
      position = item:getPosition()
    }
    return originalOpen(item, previousContainer)
  end
end

function terminateGameActions()
  disconnect(Container, { onOpen = onLootContainerOpen })
  unregisterMessageMode(MessageModes.Failure, onLootFailureMessage)
  if originalOpen then
    g_game.open = originalOpen
    originalOpen = nil
  end
  stopLooting()
end

local function showFailure(text)
  if modules.game_textmessage then
    modules.game_textmessage.displayFailureMessage(text)
  end
end

local function showInfo(text)
  if modules.game_textmessage then
    modules.game_textmessage.displayGameMessage(text)
  end
end

local function logLoot(text)
  if modules.game_console and modules.game_console.addLootMessage then
    modules.game_console.addLootMessage(text)
  end
end

local function nothingToLoot()
  local text = "There's nothing interesting to loot."
  showInfo(text)
  logLoot(text)
end

local function samePosition(a, b)
  return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function isLootableCorpse(thing)
  return thing:isItem() and thing:isContainer() and not thing:isPickupable() and not thing:isNotMoveable()
end

function onLootFailureMessage(mode, text)
  if not loot then
    return
  end

  if text == FAIL_FULL or text == FAIL_ROOM then
    loot.fullFails = loot.fullFails + 1
  elseif text == FAIL_HEAVY then
    loot.heavyFails = loot.heavyFails + 1
  elseif pendingOpen then
    -- a container that cannot be opened ("You are not the owner.", "Too far away."...): skip it right away
    local callback = pendingOpen.callback
    removeEvent(pendingOpen.event)
    cancelSilentOpen(pendingOpen.containerId)
    pendingOpen = nil
    callback(nil)
  end
end

function stopLooting()
  if loot then
    removeEvent(loot.event)
  end

  if pendingOpen then
    removeEvent(pendingOpen.event)
    cancelSilentOpen(pendingOpen.containerId)
    pendingOpen = nil
  end

  for _, container in ipairs(ownOpened) do
    if container.lootOpened then
      container.lootOpened = nil
      g_game.close(container)
    end
  end
  ownOpened = {}

  loot = nil
end

-- opening containers ---------------------------------------------------------------------------------------------

-- the open container that was opened from this item, if the client knows it
local function findOpenContainer(item)
  local position = item:getPosition()
  for _, container in pairs(g_game.getContainers()) do
    if container.sourceItemId == item:getId() and samePosition(container.sourcePosition, position) then
      return container
    end
  end
end

-- opens the container held by an item without a window (or reuses it when it is already open, opening it again would
-- close it) and calls callback(container), or callback(nil) when the server did not open it in time
local function openContainerItem(item, callback)
  local open = findOpenContainer(item)
  if open then
    return callback(open)
  end

  if pendingOpen then
    removeEvent(pendingOpen.event)
    cancelSilentOpen(pendingOpen.containerId)
  end

  local containerId = findEmptyContainerId()
  pendingOpen = {containerId = containerId, callback = callback}
  pendingOpen.event = scheduleEvent(function()
    local cb = pendingOpen and pendingOpen.callback
    pendingOpen = nil
    cancelSilentOpen(containerId)
    if cb then
      cb(nil)
    end
  end, OPEN_TIMEOUT)
  if modules.game_containers then
    modules.game_containers.openSilently(containerId)
  end
  g_game.open(item)
end

function onLootContainerOpen(container, previousContainer)
  -- remember which item this container belongs to
  if lastOpenRequest and lastOpenRequest.containerId == container:getId() then
    container.sourceItemId = lastOpenRequest.itemId
    container.sourcePosition = lastOpenRequest.position
    lastOpenRequest = nil
  end

  if not pendingOpen or container:getId() ~= pendingOpen.containerId then
    return
  end

  local callback = pendingOpen.callback
  removeEvent(pendingOpen.event)
  pendingOpen = nil
  container.lootOpened = true
  table.insert(ownOpened, container)
  callback(container)
end

-- loot bag -----------------------------------------------------------------------------------------------------

-- the loot bag is remembered as where it is: an inventory slot, or the slot of a container (usually the main backpack)
local function describeItem(item)
  local position = item:getPosition()
  if not position or position.x ~= 65535 then
    return nil
  end

  if position.y < 64 then
    return {id = item:getId(), slot = position.y}
  end

  return {id = item:getId(), index = position.z}
end

function isLootBag(item)
  local ref = getSettings().lootBag
  local now = ref and describeItem(item)
  return now ~= nil and now.id == ref.id and now.slot == ref.slot and now.index == ref.index
end

function canBeLootBag(item)
  local position = item:getPosition()
  return item:isContainer() and item:isPickupable() and position and position.x == 65535
end

function setLootBag(item)
  local ref = describeItem(item)
  if not ref then
    return
  end

  getSettings().lootBag = ref
  save()
  showInfo('This backpack is now your loot bag.')
end

function clearLootBag()
  getSettings().lootBag = nil
  save()
  showInfo('You no longer have a loot bag.')
end

-- calls callback(bagItem, bagContainer), or callback(nil) when the saved loot bag cannot be found
local function findLootBag(ref, callback)
  local player = g_game.getLocalPlayer()
  if not player then
    return callback(nil)
  end

  if ref.slot then
    local item = player:getInventoryItem(ref.slot)
    if not item or item:getId() ~= ref.id then
      return callback(nil)
    end

    return openContainerItem(item, function(container) callback(container and item, container) end)
  end

  local main = player:getInventoryItem(InventorySlotBack)
  if not main then
    return callback(nil)
  end

  openContainerItem(main, function(mainContainer)
    if not mainContainer then
      return callback(nil)
    end

    local found
    for _, item in ipairs(mainContainer:getItems()) do
      if item:isContainer() and item:getId() == ref.id then
        if item:getPosition().z == ref.index then
          found = item
          break
        end
        found = found or item
      end
    end

    if not found then
      return callback(nil)
    end

    openContainerItem(found, function(container) callback(container and found, container) end)
  end)
end

-- destinations, in the order they are tried: {position, bag = true/false, free = free slots (bags only)}
local function buildDestinations(callback)
  local ref = getSettings().lootBag
  if not ref then
    return callback({{position = AUTO_POSITION}})
  end

  findLootBag(ref, function(bagItem, bagContainer)
    if not bagItem then
      showFailure('Your loot bag was not found, the loot goes to your main backpack.')
      return callback({{position = AUTO_POSITION}})
    end

    local destinations = {{position = bagItem:getPosition(), bag = true,
      free = bagContainer:getCapacity() - #bagContainer:getItems()}}

    -- the backpacks inside the loot bag are opened (without a window) to know how many slots they have left
    local children = {}
    for _, item in ipairs(bagContainer:getItems()) do
      if item:isContainer() then
        table.insert(children, item)
      end
    end

    local function nextChild(i)
      local child = children[i]
      if not child then
        table.insert(destinations, {position = AUTO_POSITION})
        return callback(destinations)
      end

      openContainerItem(child, function(container)
        table.insert(destinations, {position = child:getPosition(), bag = true,
          free = container and (container:getCapacity() - #container:getItems()) or 0})
        nextChild(i + 1)
      end)
    end

    nextChild(1)
  end)
end

-- messages -----------------------------------------------------------------------------------------------------

-- "a sword", "3 gold coins"
local function lootItemText(id, count)
  local info = ITEM_NAMES and ITEM_NAMES[id]
  local name = info and info[1] or ('item ' .. id)
  if count > 1 then
    return count .. ' ' .. ((info and info[2]) or name)
  end

  return (name:match('^[aeiouAEIOU]') and 'an ' or 'a ') .. name
end

-- running a loot job -------------------------------------------------------------------------------------------

local function showLootResult(job)

  -- what is still in the corpses was not taken
  local taken, left = 0, 0
  for _, corpse in ipairs(job.corpses) do
    local still = {}
    for _, item in ipairs(corpse.container:getItems()) do
      still[item] = true
    end

    local order, totals = {}, {}
    for _, entry in ipairs(corpse.moves) do
      if still[entry.item] then
        left = left + 1
      else
        taken = taken + 1
        if not totals[entry.id] then
          totals[entry.id] = 0
          table.insert(order, entry.id)
        end
        totals[entry.id] = totals[entry.id] + entry.count
      end
    end

    if #order > 0 then
      local parts = {}
      for _, id in ipairs(order) do
        table.insert(parts, lootItemText(id, totals[id]))
      end
      logLoot('Loot of ' .. lootItemText(corpse.id, 1) .. ': ' .. table.concat(parts, ', '))
    end
  end

  if taken > 0 then
    local text = 'Looted ' .. taken .. (taken == 1 and ' item.' or ' items.')
    showInfo(text)
    logLoot(text)
  elseif left == 0 then
    return nothingToLoot()
  end

  if job.heavyFails > 0 then
    showFailure('You have no capacity left to loot everything.')
  elseif left > 0 then
    showFailure('You have no slots left.')
  end
end

local function finishLoot()
  local job = loot
  if not job then
    return
  end

  showLootResult(job)
  stopLooting()
end

-- picks where an item goes: the first bag with room, then the main backpack
local function pickDestination(job)
  for _, destination in ipairs(job.destinations) do
    if destination.bag then
      if destination.free > 0 then
        destination.free = destination.free - 1
        return destination
      end
    else
      if job.hasBag and not job.warned then
        job.warned = true
        showFailure('Your loot bag has no slots left.')
      end
      return destination
    end
  end

  return job.destinations[#job.destinations]
end

local lootContainer

-- sends every item of an open container to its destination at once, then goes through the containers inside it
lootContainer = function(container, corpse, depth, done)
  local children = {}
  for _, item in ipairs(container:getItems()) do
    if item:isContainer() then
      table.insert(children, item) -- the container itself is never taken, only what is inside it
    elseif not isIgnoredLoot(item:getId()) then
      local destination = pickDestination(loot)
      table.insert(corpse.moves, {item = item, id = item:getId(), count = item:getCount()})
      g_game.move(item, destination.position, item:getCount())
    end
  end

  local function nextChild(i)
    if not loot then
      return
    end

    local child = children[i]
    if not child or depth >= MAX_DEPTH then
      return done()
    end

    openContainerItem(child, function(opened)
      if not loot then
        return
      end

      if not opened then
        return nextChild(i + 1)
      end

      table.insert(corpse.containers, opened)
      lootContainer(opened, corpse, depth + 1, function() nextChild(i + 1) end)
    end)
  end

  nextChild(1)
end

local function lootNextCorpse()
  if not loot then
    return
  end

  local corpseItem = table.remove(loot.queue, 1)
  if not corpseItem then
    -- every move was sent: let the server answer, then see what is left
    loot.event = scheduleEvent(finishLoot, SETTLE_DELAY)
    return
  end

  openContainerItem(corpseItem, function(container)
    if not loot then
      return
    end

    if not container then
      return lootNextCorpse()
    end

    local corpse = {id = corpseItem:getId(), container = container, containers = {container}, moves = {}}
    table.insert(loot.corpses, corpse)
    lootContainer(container, corpse, 1, lootNextCorpse)
  end)
end

function lootAround()
  if loot then
    return
  end

  local player = g_game.getLocalPlayer()
  local position = player and player:getPosition()
  if not position then
    return
  end

  local corpses = {}
  for dx = -1, 1 do
    for dy = -1, 1 do
      local tile = g_map.getTile({x = position.x + dx, y = position.y + dy, z = position.z})
      if tile then
        for _, thing in ipairs(tile:getItems()) do
          if isLootableCorpse(thing) then
            table.insert(corpses, thing)
          end
        end
      end
    end
  end

  if #corpses == 0 then
    return nothingToLoot()
  end

  if player:getFreeCapacity() <= 0 then
    return showFailure('You have no capacity left to loot.')
  end

  loot = {queue = corpses, corpses = {}, destinations = {}, heavyFails = 0, fullFails = 0}
  buildDestinations(function(destinations)
    if not loot then
      return
    end

    loot.destinations = destinations
    loot.hasBag = #destinations > 1
    lootNextCorpse()
  end)
end
