-- Game actions that can be assigned to an action button ("Assign Action"):
--   attackNext  attack the next creature of the battle list (so its filters and sorting apply), optionally players only
--               or monsters only
--   attackPrevious  the same, going up the battle list
--   loot        the server moves everything from the corpses around the player (and the containers inside them, never
--               the containers) to the loot bag (right click a backpack -> "Set as loot bag") or the main backpack,
--               except the items on the ignore loot list (right click an item -> "Add to ignore loot list")
--   stopAttack  stop attacking (and following)
--   useUnder    use the item under the player (climb a ladder, use stairs, a lever, a hole...)
--   openDoor    open the closed door next to the player, or close the open one (the door in front first); with no door
--               around, use the item under the player (stairs, ladders)

GAME_ACTION = {
  ATTACK_NEXT = 'attackNext',
  ATTACK_PREVIOUS = 'attackPrevious',
  LOOT = 'loot',
  STOP_ATTACK = 'stopAttack',
  USE_UNDER = 'useUnder',
  OPEN_DOOR = 'openDoor'
}

TARGET_FILTER = {
  ALL = 'all',
  PLAYERS = 'players',
  MONSTERS = 'monsters'
}

-- attackNext and attackPrevious are the actions that have a target filter
function isTargetAction(action)
  return action == GAME_ACTION.ATTACK_NEXT or action == GAME_ACTION.ATTACK_PREVIOUS
end

function gameActionLabel(action, filter)
  if isTargetAction(action) then
    local way = action == GAME_ACTION.ATTACK_PREVIOUS and 'Prev' or 'Next'
    if filter == TARGET_FILTER.PLAYERS then return way .. '\nPlayer' end
    if filter == TARGET_FILTER.MONSTERS then return way .. '\nMonster' end
    return way .. '\nTarget'
  elseif action == GAME_ACTION.LOOT then
    return 'Loot'
  elseif action == GAME_ACTION.STOP_ATTACK then
    return 'Stop\nAttack'
  elseif action == GAME_ACTION.USE_UNDER then
    return 'Use\nUnder'
  elseif action == GAME_ACTION.OPEN_DOOR then
    return 'Open\nClose'
  end
  return ''
end

function gameActionDescription(action, filter)
  if isTargetAction(action) then
    local what = 'creature'
    if filter == TARGET_FILTER.PLAYERS then what = 'player' elseif filter == TARGET_FILTER.MONSTERS then what = 'monster' end
    local way = action == GAME_ACTION.ATTACK_PREVIOUS and 'previous' or 'next'
    return 'Attack the ' .. way .. ' ' .. what .. ' of the battle list'
  elseif action == GAME_ACTION.LOOT then
    return 'Loot the creatures around you into your loot bag (items on the ignore loot list are left behind)'
  elseif action == GAME_ACTION.STOP_ATTACK then
    return 'Stop attacking'
  elseif action == GAME_ACTION.USE_UNDER then
    return 'Use the item under you (ladders, stairs, levers...)'
  elseif action == GAME_ACTION.OPEN_DOOR then
    return 'Open or close the door next to you (or use the stairs under you)'
  end
  return 'None'
end

-- the tooltip of an action button: what it does, in a few lines
function gameActionHelp(action, filter)
  if isTargetAction(action) then
    local who = 'creature'
    if filter == TARGET_FILTER.PLAYERS then who = 'player' elseif filter == TARGET_FILTER.MONSTERS then who = 'monster' end
    if action == GAME_ACTION.ATTACK_PREVIOUS then
      return 'PREVIOUS TARGET\nAttacks the previous ' .. who .. ' of your battle list.\nPress again to go to the one above it.'
    end
    return 'NEXT TARGET\nAttacks the next ' .. who .. ' of your battle list.\nPress again to go to the one after it.'
  elseif action == GAME_ACTION.LOOT then
    return 'LOOT\nLoots the monsters you killed around you,\nstraight into your loot bag.\nRight click a backpack: Set as loot bag.\nRight click an item: Add to ignore loot list.'
  elseif action == GAME_ACTION.STOP_ATTACK then
    return 'STOP ATTACK\nStops attacking and following.'
  elseif action == GAME_ACTION.USE_UNDER then
    return 'USE UNDER\nUses what you stand on:\nladders, stairs, levers, holes.'
  elseif action == GAME_ACTION.OPEN_DOOR then
    return 'OPEN / CLOSE DOOR\nOpens the closed door next to you,\nor closes it again once you are through\n(the door in front of you first).\nNo door around: takes the stairs or ladder under you.'
  end
  return ''
end

-- The game window repeats a held key every few milliseconds (that is what makes walking smooth), so an action must not
-- follow every repeat or a held key would send dozens of packets a second. The loot paces itself (lootAround); every
-- other action runs once per press however long the key is held, and a key pressed again and again waits its interval:
-- using a door or the stairs gets the server's action time (config.lua timeBetweenActions, 100 ms) plus room for the
-- ping, and switching targets gets a pace the server and the battle list keep up with.
local ACTION_INTERVAL = {
  [GAME_ACTION.ATTACK_NEXT] = 250,
  [GAME_ACTION.ATTACK_PREVIOUS] = 250,
  [GAME_ACTION.STOP_ATTACK] = 250,
  [GAME_ACTION.USE_UNDER] = 300,
  [GAME_ACTION.OPEN_DOOR] = 300
}
local lastRun = {}

-- repeated: the key is held (an automatic repeat of the press)
function runGameAction(action, filter, repeated)
  if not g_game.isOnline() then
    return
  end

  local interval = ACTION_INTERVAL[action]
  if interval then
    local now = g_clock.millis()
    if repeated or now - (lastRun[action] or 0) < interval then
      return
    end
    lastRun[action] = now
  end

  if isTargetAction(action) then
    attackNextTarget(filter, action == GAME_ACTION.ATTACK_PREVIOUS and -1 or 1)
  elseif action == GAME_ACTION.LOOT then
    lootAround()
  elseif action == GAME_ACTION.STOP_ATTACK then
    g_game.cancelAttackAndFollow()
  elseif action == GAME_ACTION.USE_UNDER then
    useItemUnderPlayer()
  elseif action == GAME_ACTION.OPEN_DOOR then
    openDoorAround()
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

-- open / close door ----------------------------------------------------------------------------------------------

-- the tile the player faces is tried first, then the straight ones, then the diagonals
local FACING_OFFSET = {
  [North] = {x = 0, y = -1}, [East] = {x = 1, y = 0}, [South] = {x = 0, y = 1}, [West] = {x = -1, y = 0}
}
local AROUND = {{x = 0, y = -1}, {x = 1, y = 0}, {x = 0, y = 1}, {x = -1, y = 0},
  {x = -1, y = -1}, {x = 1, y = -1}, {x = 1, y = 1}, {x = -1, y = 1}}

-- the door of the tile next to the player (doors.lua, generated from the server): a closed one, or an open one nobody
-- stands in (using an open door with someone in it would push them out); the second value tells if it is open
local function findDoor(position, offset)
  local tile = g_map.getTile({x = position.x + offset.x, y = position.y + offset.y, z = position.z})
  if not tile then
    return nil
  end

  for _, item in ipairs(tile:getItems()) do
    local id = item:getId()
    if DOOR_IDS[id] then
      return item, false
    elseif OPEN_DOOR_IDS[id] and #tile:getCreatures() == 0 then
      return item, true
    end
  end
end

-- the door in front of the player whatever its state; otherwise a closed door around is opened first and, with none,
-- an open one is closed (the door just walked through)
function openDoorAround()
  local player = g_game.getLocalPlayer()
  if not player then
    return
  end

  local position = player:getPosition()
  local facing = FACING_OFFSET[player:getDirection()]
  local door = facing and findDoor(position, facing)
  local openDoor = nil
  for _, offset in ipairs(AROUND) do
    if door then
      break
    end
    local found, isOpen = findDoor(position, offset)
    if found and not isOpen then
      door = found
    elseif found and not openDoor then
      openDoor = found
    end
  end
  door = door or openDoor

  if door then
    g_game.use(door)
  else
    useItemUnderPlayer()
  end
end

-- attack -------------------------------------------------------------------------------------------------------

-- attacking the creature already attacked would cancel the attack, so a list of one creature keeps it
function attackNextTarget(filter, step)
  step = step or 1
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

  -- step 1 goes down the list, -1 goes up; with no target yet they start at the first and at the last creature
  if index == 0 then
    index = step > 0 and 1 or #candidates
  else
    index = (index - 1 + step) % #candidates + 1
  end
  local target = candidates[index]
  if target ~= current then
    g_game.attack(target)
  end
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
  sendIgnoreList()
end

-- loot ---------------------------------------------------------------------------------------------------------
--
-- The loot hotkey is done by the server (auto loot, an OTClient extended opcode): one packet and the server moves the
-- loot of every corpse around the player (and of the containers inside them, never the containers) into the loot bag,
-- the backpacks inside it, and finally the main backpack, with the real capacity and slot checks. No container is opened,
-- nothing is moved item by item and the player never walks to a corpse. The server answers with the lines for the Loot
-- channel and the messages. See Game::playerExtendedOpcode in the server (game.cpp).
--   client -> server  1 loot, 2 ignore list "id,id,...", 3 set the loot bag "x,y,z,spriteId", 4 unset the loot bag,
--                     5 empty a backpack (drops its items on the floor)
--   server -> client  1 lines: "L|text" Loot channel, "I|text" info, "F|text" failure, "N|" nothing to loot

local OPCODE_LOOT = 1
local OPCODE_IGNORE = 2
local OPCODE_SET_BAG = 3
local OPCODE_CLEAR_BAG = 4
local OPCODE_EMPTY = 5

local lastLoot = 0

local function sendOpcode(opcode, buffer)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(opcode, buffer or '')
  end
end

local function showFailure(text)
  if modules.game_textmessage then
    modules.game_textmessage.displayBroadcastMessage(text) -- MessageModes.Warning: red, centre of the screen
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

function onLootReply(protocol, opcode, buffer)
  for line in buffer:gmatch('[^\n]+') do
    local tag, text = line:match('^(%a)|(.*)$')
    if tag == 'L' then
      logLoot(text)
    elseif tag == 'I' then
      showInfo(text)
    elseif tag == 'F' then
      showFailure(text)
    elseif tag == 'N' then
      nothingToLoot()
    end
  end
end

-- the server keeps the ignore list in memory only: send it at login and whenever it changes (and before the first
-- loot of a session, in case the login send came before the server's extended opcode handshake)
local ignoreSent = false
local emptyConfirm = nil
local syncEvent = nil

function sendIgnoreList()
  local ids = {}
  for id in pairs(getSettings().ignoreLoot or {}) do
    table.insert(ids, id)
  end

  sendOpcode(OPCODE_IGNORE, table.concat(ids, ','))
  ignoreSent = true
end

function syncLootSettings()
  ignoreSent = false
  removeEvent(syncEvent)
  syncEvent = scheduleEvent(function()
    syncEvent = nil
    sendIgnoreList()
  end, 1500) -- after the server's extended opcode handshake
end

local function closeEmptyConfirm()
  if emptyConfirm then
    emptyConfirm:destroy()
    emptyConfirm = nil
  end
end

-- what belongs to the session ends with it (the "Empty backpack" question would point at an item of the old one)
function endGameActions()
  removeEvent(syncEvent)
  syncEvent = nil
  closeEmptyConfirm()
end

function initGameActions()
  ProtocolGame.registerExtendedOpcode(OPCODE_LOOT, onLootReply)
  connect(g_game, {onGameStart = syncLootSettings, onGameEnd = endGameActions})
  if g_game.isOnline() then
    syncLootSettings()
  end
end

function terminateGameActions()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_LOOT)
  disconnect(g_game, {onGameStart = syncLootSettings, onGameEnd = endGameActions})
  endGameActions()
end

function lootAround()
  local now = g_clock.millis()
  if now - lastLoot < 100 then
    return
  end

  lastLoot = now
  if not ignoreSent then
    sendIgnoreList()
  end
  sendOpcode(OPCODE_LOOT)
end

-- loot bag -----------------------------------------------------------------------------------------------------

-- the server remembers the loot bag itself (it is marked on the item); the client only keeps where it saw it, to
-- offer "Unset loot bag" in the right click menu of that backpack
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
  local position = item:getPosition()
  sendOpcode(OPCODE_SET_BAG, position.x .. ',' .. position.y .. ',' .. position.z .. ',' .. item:getId())
end

function clearLootBag()
  getSettings().lootBag = nil
  save()
  sendOpcode(OPCODE_CLEAR_BAG)
end

-- empty backpack -----------------------------------------------------------------------------------------------

-- right click -> "Empty backpack": always asks first, the server then drops everything that is inside on the floor
function emptyBackpack(item)
  closeEmptyConfirm()

  local function yes()
    closeEmptyConfirm()
    local position = item:getPosition()
    if position and position.x == 65535 then
      sendOpcode(OPCODE_EMPTY, position.x .. ',' .. position.y .. ',' .. position.z .. ',' .. item:getId())
    end
  end

  emptyConfirm = displayGeneralBox(tr('Empty backpack'),
    tr('Do you really want to drop everything that is inside this backpack?\nAll the items will be dropped on the floor.'), {
      { text = tr('Yes'), callback = yes },
      { text = tr('No'), callback = closeEmptyConfirm },
      anchor = AnchorHorizontalCenter }, yes, closeEmptyConfirm)
end
