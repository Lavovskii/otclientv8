-- Game actions that can be assigned to an action button ("Assign Action"):
--   attackNext  attack the next creature of the battle list (so its filters and sorting apply), optionally players only
--               or monsters only
--   loot        open the corpses around the player and move their items to the loot bag (right click a backpack ->
--               "Set as loot bag"), then to the main backpack, except the items on the ignore loot list (right click
--               an item -> "Add to ignore loot list"); it stops when capacity or slots run out
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
-- How the server answers a move (kept in sync with the server, see player.cpp sendCancelMessage):
--   * dropping on a container that is full  -> "You cannot put more objects in this container."
--   * not enough capacity                   -> "This object is too heavy for you to carry."
--   * dropping on the inventory "capacity" position (x = 65535, y = 0) lets the server pick the first backpack, or
--     bag inside a backpack, that has room.
-- Items go to the loot bag first (set with right click -> "Set as loot bag"). When it is full they go to the next backpack
-- inside it, then to the main backpack (server routing) with a warning, until nothing has slots left.

local LOOT_STEP_DELAY = 250     -- ms between two item moves, keeps the server action limits happy
local LOOT_OPEN_TIMEOUT = 1500  -- ms to wait for a container to open before giving up on it
local FAIL_FULL = 'You cannot put more objects in this container.'
local FAIL_HEAVY = 'This object is too heavy for you to carry.'
local FAIL_ROOM = 'There is not enough room.'
local AUTO_POSITION = {x = 65535, y = 0, z = 0}

local loot = nil        -- running loot job
local pendingOpen = nil -- container we asked the server to open: {item, callback, event}
local lastFailure = nil -- last move failure told by the server ('full', 'heavy' or 'other')

function initGameActions()
  connect(Container, { onOpen = onLootContainerOpen })
  registerMessageMode(MessageModes.Failure, onLootFailureMessage)
end

function terminateGameActions()
  disconnect(Container, { onOpen = onLootContainerOpen })
  unregisterMessageMode(MessageModes.Failure, onLootFailureMessage)
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

local function isLootableCorpse(thing)
  return thing:isItem() and thing:isContainer() and not thing:isPickupable() and not thing:isNotMoveable()
end

local function samePosition(a, b)
  return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function sameItem(a, b)
  return a:getId() == b:getId() and samePosition(a:getPosition(), b:getPosition())
end

function onLootFailureMessage(mode, text)
  if not loot then
    return
  end

  -- a corpse that cannot be opened ("You are not the owner.", "Too far away."...): skip it right away
  if pendingOpen then
    local callback = pendingOpen.callback
    removeEvent(pendingOpen.event)
    pendingOpen = nil
    return callback(nil)
  end

  if text == FAIL_FULL or text == FAIL_ROOM then
    lastFailure = 'full'
  elseif text == FAIL_HEAVY then
    lastFailure = 'heavy'
  else
    lastFailure = 'other'
  end
end

function stopLooting()
  if loot then
    removeEvent(loot.event)
    if loot.container then
      g_game.close(loot.container)
    end
  end

  if pendingOpen then
    removeEvent(pendingOpen.event)
    pendingOpen = nil
  end

  loot = nil
end

-- the item held by an open container has no position in the client (it is created from the open packet), so open
-- containers are told apart by their id: the client picks the first free container id for the one it asks to open
local function findEmptyContainerId()
  local open = g_game.getContainers()
  local id = 0
  while open[id] do
    id = id + 1
  end
  return id
end

local function findOpenContainer(item)
  for _, container in pairs(g_game.getContainers()) do
    local held = container:getContainerItem()
    if held and held:getId() == item:getId() then
      return container
    end
  end
end

-- opens the container held by an item (or reuses its window when a container of that kind is already open, opening it
-- again would close it) and calls callback(container), or callback(nil) when the server did not open it in time
local function openContainerItem(item, callback)
  local open = findOpenContainer(item)
  if open then
    return callback(open)
  end

  if pendingOpen then
    removeEvent(pendingOpen.event)
  end

  pendingOpen = {containerId = findEmptyContainerId(), callback = callback}
  pendingOpen.event = scheduleEvent(function()
    local cb = pendingOpen and pendingOpen.callback
    pendingOpen = nil
    if cb then
      cb(nil)
    end
  end, LOOT_OPEN_TIMEOUT)
  g_game.open(item)
end

function onLootContainerOpen(container, previousContainer)
  if not pendingOpen or container:getId() ~= pendingOpen.containerId then
    return
  end

  local callback = pendingOpen.callback
  removeEvent(pendingOpen.event)
  pendingOpen = nil
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
        local position = item:getPosition()
        if position.z == ref.index then
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

-- destinations, in the order they are tried: {position, bag = true/false}
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

    local destinations = {{position = bagItem:getPosition(), bag = true}}
    for _, item in ipairs(bagContainer:getItems()) do
      if item:isContainer() then
        table.insert(destinations, {position = item:getPosition(), bag = true})
      end
    end

    table.insert(destinations, {position = AUTO_POSITION})
    callback(destinations)
  end)
end

-- running a loot job -------------------------------------------------------------------------------------------

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

-- "a sword", "3 gold coins"
local function lootItemText(id, count)
  local info = ITEM_NAMES and ITEM_NAMES[id]
  local name = info and info[1] or ('item ' .. id)
  if count > 1 then
    return count .. ' ' .. ((info and info[2]) or name)
  end

  return (name:match('^[aeiouAEIOU]') and 'an ' or 'a ') .. name
end

-- one line per corpse: "Loot of a dead rat: 2 gold coins, a cheese"
local function logCorpseLoot()
  if not loot or not loot.corpse or #loot.log == 0 then
    return
  end

  local order, totals = {}, {}
  for _, entry in ipairs(loot.log) do
    if not totals[entry.id] then
      totals[entry.id] = 0
      table.insert(order, entry.id)
    end
    totals[entry.id] = totals[entry.id] + entry.count
  end

  local parts = {}
  for _, id in ipairs(order) do
    table.insert(parts, lootItemText(id, totals[id]))
  end

  logLoot('Loot of ' .. lootItemText(loot.corpse:getId(), 1) .. ': ' .. table.concat(parts, ', '))
  loot.log = {}
end

local function finishLoot(reason)
  logCorpseLoot()
  local job = loot
  stopLooting()
  if not job then
    return
  end

  if reason then
    showFailure(reason)
  end

  if job.count == 0 and job.heavy == 0 and not reason then
    return nothingToLoot()
  end

  if job.count > 0 then
    local text = 'Looted ' .. job.count .. (job.count == 1 and ' item.' or ' items.')
    if job.heavy > 0 then
      text = text .. ' ' .. job.heavy .. ' too heavy to carry.'
    end
    showInfo(text)
    logLoot(text)
  elseif job.heavy > 0 then
    showFailure('You have no capacity left to loot.')
  end
end

local lootNextCorpse

-- sends the next item of the open corpse to the current destination, then checks how the server answered
local function lootNextItem(container, items)
  if not loot or loot.container ~= container then
    return
  end

  local item = items[#items]
  if not item then
    logCorpseLoot()
    g_game.close(container)
    loot.container = nil
    loot.event = scheduleEvent(lootNextCorpse, LOOT_STEP_DELAY)
    return
  end

  local player = g_game.getLocalPlayer()
  if player and player:getFreeCapacity() <= 0 then
    return finishLoot('You have no capacity left to loot.')
  end

  local destination = loot.destinations[loot.current]
  local before = #container:getItems()
  local record = {id = item:getId(), count = item:getCount()}
  lastFailure = nil
  g_game.move(item, destination.position, item:getCount())

  loot.event = scheduleEvent(function()
    if not loot or loot.container ~= container then
      return
    end

    local moved = #container:getItems() < before
    if moved then
      table.remove(items)
      loot.count = loot.count + 1
      table.insert(loot.log, record)
    elseif lastFailure == 'full' then
      -- this bag has no slots left: next backpack inside the loot bag, then the main backpack
      loot.current = loot.current + 1
      local nextDestination = loot.destinations[loot.current]
      if not nextDestination then
        return finishLoot('You have no slots left.')
      end

      if destination.bag and not nextDestination.bag and not loot.warned then
        loot.warned = true
        showFailure('Your loot bag has no slots left.')
      end
    elseif lastFailure == 'heavy' then
      table.remove(items)
      loot.heavy = loot.heavy + 1
    else
      -- the server refused it (too far, not allowed...): leave it in the corpse
      table.remove(items)
    end

    lootNextItem(container, items)
  end, LOOT_STEP_DELAY)
end

lootNextCorpse = function()
  if not loot then
    return
  end

  local corpse = table.remove(loot.queue, 1)
  if not corpse then
    return finishLoot()
  end

  openContainerItem(corpse, function(container)
    if not loot then
      return
    end

    if not container then
      return lootNextCorpse()
    end

    loot.container = container
    loot.corpse = corpse
    loot.log = {}
    local items = {}
    for _, item in ipairs(container:getItems()) do
      if not isIgnoredLoot(item:getId()) then
        table.insert(items, item)
      end
    end

    lootNextItem(container, items)
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

  loot = {queue = corpses, count = 0, heavy = 0, current = 1, destinations = {}, log = {}}
  buildDestinations(function(destinations)
    if not loot then
      return
    end

    loot.destinations = destinations
    lootNextCorpse()
  end)
end
