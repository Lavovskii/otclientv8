-- Game actions that can be assigned to an action button ("Assign Action"):
--   attackNext  attack the next creature of the battle list (so its filters and sorting apply), optionally players only
--               or monsters only
--   loot        open the corpses around the player and move their items to the backpack, except the items on the
--               ignore loot list (right click an item -> "Add to ignore loot list")
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

local LOOT_STEP_DELAY = 250   -- ms between two item moves, keeps the server action limits happy
local LOOT_OPEN_TIMEOUT = 1500 -- ms to wait for a corpse to open before skipping it

local loot = nil -- running loot job: {queue = {corpses}, container = corpse container being emptied, event = timeout}

function initGameActions()
  connect(Container, { onOpen = onLootContainerOpen })
end

function terminateGameActions()
  disconnect(Container, { onOpen = onLootContainerOpen })
  stopLooting()
end

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
    return 'Loot the creatures around you (items on the ignore loot list are left behind)'
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

local function isLootableCorpse(thing)
  return thing:isItem() and thing:isContainer() and not thing:isPickupable() and not thing:isNotMoveable()
end

local function sameItem(a, b)
  local pa, pb = a:getPosition(), b:getPosition()
  return a:getId() == b:getId() and pa and pb and pa.x == pb.x and pa.y == pb.y and pa.z == pb.z
end

function stopLooting()
  if loot then
    removeEvent(loot.event)
  end
  loot = nil
end

local function lootNextCorpse()
  if not loot then
    return
  end

  removeEvent(loot.event)
  loot.container = nil
  local corpse = table.remove(loot.queue, 1)
  if not corpse then
    local count = loot.count
    stopLooting()
    if count > 0 and modules.game_textmessage then
      modules.game_textmessage.displayGameMessage('Looted ' .. count .. (count == 1 and ' item.' or ' items.'))
    end
    return
  end

  loot.corpse = corpse
  g_game.open(corpse)
  loot.event = scheduleEvent(lootNextCorpse, LOOT_OPEN_TIMEOUT)
end

local function lootNextItem(container, items, backpack)
  if not loot or loot.container ~= container then
    return
  end

  local item = table.remove(items)
  if not item then
    g_game.close(container)
    loot.event = scheduleEvent(lootNextCorpse, LOOT_STEP_DELAY)
    return
  end

  g_game.move(item, backpack:getPosition(), item:getCount())
  loot.count = loot.count + 1
  loot.event = scheduleEvent(function() lootNextItem(container, items, backpack) end, LOOT_STEP_DELAY)
end

function onLootContainerOpen(container, previousContainer)
  if not loot or not loot.corpse or loot.container then
    return
  end

  local corpse = container:getContainerItem()
  if not corpse or not sameItem(corpse, loot.corpse) then
    return
  end

  removeEvent(loot.event)
  loot.container = container

  local player = g_game.getLocalPlayer()
  local backpack = player and player:getInventoryItem(InventorySlotBack)
  if not backpack then
    stopLooting()
    g_game.close(container)
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('You need a backpack to loot.')
    end
    return
  end

  local items = {}
  for _, item in ipairs(container:getItems()) do
    if not isIgnoredLoot(item:getId()) then
      table.insert(items, item)
    end
  end

  lootNextItem(container, items, backpack)
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
    return
  end

  loot = {queue = corpses, count = 0}
  lootNextCorpse()
end
