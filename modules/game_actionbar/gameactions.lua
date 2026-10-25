-- Game actions that can be assigned to an action button ("Assign Action"):
--   attackNext  attack the next creature of the battle list (so its filters and sorting apply), optionally players only
--               or monsters only
--   loot        the server moves everything from the corpses around the player (and the containers inside them, never
--               the containers) to the loot bag (right click a backpack -> "Set as loot bag") or the main backpack,
--               except the items on the ignore loot list (right click an item -> "Add to ignore loot list")
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
  sendIgnoreList()
end

-- loot ---------------------------------------------------------------------------------------------------------
--
-- The loot hotkey is done by the server (auto loot, an OTClient extended opcode): one packet and the server moves the
-- loot of every corpse around the player (and of the containers inside them, never the containers) into the loot bag,
-- the backpacks inside it, and finally the main backpack, with the real capacity and slot checks. No container is opened,
-- nothing is moved item by item and the player never walks to a corpse. The server answers with the lines for the Loot
-- channel and the messages. See Game::playerExtendedOpcode in the server (game.cpp).
--   client -> server  1 loot, 2 ignore list "id,id,...", 3 set the loot bag "x,y,z,spriteId", 4 unset the loot bag
--   server -> client  1 lines: "L|text" Loot channel, "I|text" info, "F|text" failure, "N|" nothing to loot

local OPCODE_LOOT = 1
local OPCODE_IGNORE = 2
local OPCODE_SET_BAG = 3
local OPCODE_CLEAR_BAG = 4

local lastLoot = 0

local function sendOpcode(opcode, buffer)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(opcode, buffer or '')
  end
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

-- the server keeps the ignore list in memory only: send it at login and whenever it changes
function sendIgnoreList()
  local ids = {}
  for id in pairs(getSettings().ignoreLoot or {}) do
    table.insert(ids, id)
  end

  sendOpcode(OPCODE_IGNORE, table.concat(ids, ','))
end

function syncLootSettings()
  scheduleEvent(sendIgnoreList, 1500) -- after the server's extended opcode handshake
end

function initGameActions()
  ProtocolGame.registerExtendedOpcode(OPCODE_LOOT, onLootReply)
  connect(g_game, {onGameStart = syncLootSettings})
  if g_game.isOnline() then
    syncLootSettings()
  end
end

function terminateGameActions()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_LOOT)
  disconnect(g_game, {onGameStart = syncLootSettings})
end

function lootAround()
  local now = g_clock.millis()
  if now - lastLoot < 100 then
    return
  end

  lastLoot = now
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
