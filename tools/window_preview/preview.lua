-- Preview only: no login, no network to the game. Opens every window of the client with made-up data, takes screenshots, closes.
-- only.txt (names separated by spaces) limits the run to those steps; size.txt gives the window size.
local steps = {}
-- the ForgottenL General Store's test catalogue (made from data/lib/127-general-store.lua)
GSTORE = "O|0|3043|59453|ForgottenL General Store\nC|equipment|Equipment|55686\nC|weapons|Weapons|55690\nC|runes|Runes|3155\nC|tools|Tools|3003\nC|supplies|Supplies|60022\nC|backpacks|Backpacks|2854\nC|others|Others|2854\nI|equipment|59730|55685|Beginner Helmet|20000|gold|1|1|10000\nI|equipment|59731|55686|Beginner Armor|30000|gold|1|1|15000\nI|equipment|59732|55687|Beginner Legs|25000|gold|1|1|12500\nI|equipment|59733|55688|Beginner Boots|15000|gold|1|1|7500\nI|equipment|59734|55689|Beginner Shield|20000|gold|1|1|10000\nI|equipment|60554|56509|Beginner Mage Helmet|20000|gold|1|1|10000\nI|equipment|60555|56510|Beginner Mage Armor|30000|gold|1|1|15000\nI|equipment|60556|56511|Beginner Mage Legs|25000|gold|1|1|12500\nI|equipment|60557|56512|Beginner Mage Boots|15000|gold|1|1|7500\nI|equipment|60558|56513|Beginner Mage Spellbook|20000|gold|1|1|10000\nI|equipment|60170|56125|Beginner Helmet|20000|gold|1|1|10000\nI|equipment|60171|56126|Beginner Armor|30000|gold|1|1|15000\nI|equipment|60172|56127|Beginner Legs|25000|gold|1|1|12500\nI|equipment|60173|56128|Beginner Boots|15000|gold|1|1|7500\nI|equipment|60174|56129|Beginner Quiver|20000|gold|1|1|10000\nI|weapons|59735|55690|Beginner Sword|40000|gold|1|1|20000\nI|weapons|59736|55691|Beginner Axe|40000|gold|1|1|20000\nI|weapons|59737|55692|Beginner Club|40000|gold|1|1|20000\nI|weapons|60175|56130|Beginner Slingshot|40000|gold|1|1|20000\nI|weapons|60559|56514|Beginner Mage Wand|40000|gold|1|1|20000\nI|equipment|59786|55741|Cursed Helmet|5|buffary|1|1|2\nI|equipment|59787|55742|Cursed Armor|8|buffary|1|1|4\nI|runes|64061|60016|small healing rune|10000|gold|1|1|5000\nI|runes|64062|60017|strong healing rune|50000|gold|1|1|25000\nI|runes|64063|60018|great healing rune|150000|gold|1|1|75000\nI|runes|64067|60022|small manarune|10000|gold|1|1|5000\nI|runes|64068|60023|strong manarune|50000|gold|1|1|25000\nI|runes|64069|60024|great manarune|150000|gold|1|1|75000\nI|runes|2268|3155|sudden death rune|135|gold|1|1|67\nI|runes|2301|3188|fire field rune|28|gold|1|1|14\nI|runes|2277|3164|energy field rune|38|gold|1|1|19\nI|runes|2285|3172|poison field rune|21|gold|1|1|10\nI|runes|2305|3192|firebomb rune|147|gold|1|1|73\nI|runes|2262|3149|energy bomb rune|203|gold|1|1|101\nI|runes|2286|3173|poison bomb rune|85|gold|1|1|42\nI|runes|2303|3190|fire wall rune|61|gold|1|1|30\nI|runes|2279|3166|energy wall rune|85|gold|1|1|42\nI|runes|2289|3176|poison wall rune|52|gold|1|1|26\nI|runes|2293|3180|magic wall rune|116|gold|1|1|58\nI|runes|2269|3156|wild growth rune|160|gold|1|1|80\nI|runes|2261|3148|destroy field rune|15|gold|1|1|7\nI|runes|2308|3195|soulfire rune|46|gold|1|1|23\nI|tools|2120|3003|rope|50|gold|1|1|25\nI|tools|2554|3457|shovel|50|gold|1|1|25\nI|tools|2553|3456|pick|50|gold|1|1|25\nI|tools|2420|3308|machete|40|gold|1|1|20\nI|tools|2580|3483|fishing rod|150|gold|1|1|75\nI|supplies|2789|3725|brown mushroom|10|gold|1|1|5\nI|supplies|2666|3577|meat|5|gold|1|1|2\nI|backpacks|1988|2854|backpack|20|gold|1|1|10\nI|backpacks|61487|57442|Gucci Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61488|57443|Louis Vuitton Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61489|57444|Chanel Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61490|57445|Dior Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61491|57446|Prada Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61492|57447|Versace Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61493|57448|Burberry Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61494|57449|Fendi Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61495|57450|Hermes Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61496|57451|Bottega Veneta Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61497|57452|Goyard Backpack|100000000|gold|1|1|50000000|1800|100\nI|backpacks|61498|57453|Valentino Backpack|100000000|gold|1|1|50000000|1800|100\nI|others|2595|3503|parcel|100|gold|1|1|50\nF|1410162608|100|25\nH|64067|3\nH|59730|1\nE"
local function step(name, f, wait)
  table.insert(steps, {name = name, f = f, wait = wait or 450})
end

local only
local function readFile(path)
  if g_resources.fileExists(path) then
    return g_resources.readFileContents(path)
  end
end

local function log(text)
  print('[preview] ' .. text)
end

local function shot(name)
  g_app.doScreenshot('rb_' .. name .. '.png')
end

local function fire(signal, ...)
  if type(signal) == 'function' then
    local ok, err = pcall(signal, ...)
    if not ok then log('signal: ' .. tostring(err)) end
  elseif type(signal) == 'table' then
    for _, f in pairs(signal) do
      local ok, err = pcall(f, ...)
      if not ok then log('signal: ' .. tostring(err)) end
    end
  end
end

local function byId(id)
  return rootWidget:recursiveGetChildById(id)
end

-- every window that is open floats over the others: this keeps one at a time
local KEEP = {}
local function rememberKept()
  for _, child in ipairs(rootWidget:getChildren()) do
    if child:isVisible() then KEEP[child] = true end
  end
end
local function closeWindows()
  for _, child in ipairs(rootWidget:getChildren()) do
    if child:isVisible() and not KEEP[child] then
      local id = child:getId()
      if id ~= 'gameRootPanel' and id ~= 'topMenu' and id ~= 'background' then
        child:hide()
      end
    end
  end
end

local function shotTabs(barId, prefix)
  local bar = byId(barId)
  if not bar then log('no tab bar ' .. barId) return end
  for index, tab in ipairs(bar:getTabs()) do
    step(prefix .. '_' .. index, function() bar:selectTab(tab) end)
  end
end

-- a player that answers everything the windows ask
local VALUES = {
  getName = 'Dev', getLevel = 6445, getLevelPercent = 42, getHealth = 8200, getMaxHealth = 10000, getMana = 5300, getMaxMana = 9000,
  getExperience = 123456789012, getMagicLevel = 120, getMagicLevelPercent = 33, getBaseMagicLevel = 110, getFreeCapacity = 14000,
  getTotalCapacity = 20000, getSoul = 100, getStamina = 2400, getVocation = 4, getId = 268435500, getSpeed = 900, getBaseSpeed = 800,
  getStates = 0, isLocalPlayer = true, isPremium = true, getSkillLevel = 85, getSkillBaseLevel = 80, getSkillLevelPercent = 37,
  getOfflineTrainingTime = 600, getRegenerationTime = 300, getHealthPercent = 82, getManaPercent = 58, getWalkTicksLeft = 0,
}
local inventory = {3351, 3041, 3357, 2854, 3280, 3420, 3358, 3079, 3043, 3031}
local player = setmetatable({}, {__index = function(self, key)
  if key == 'getPosition' then return function() return {x = 1000, y = 1000, z = 7} end end
  if key == 'getOutfit' then return function() return {type = 128, head = 78, body = 69, legs = 58, feet = 76, addons = 3, mount = 0} end end
  if key == 'getInventoryItem' then
    return function(_, slot)
      local id = inventory[slot]
      return id and Item.create(id) or nil
    end
  end
  if VALUES[key] ~= nil then
    return function() return VALUES[key] end
  end
  if key:sub(1, 2) == 'is' or key:sub(1, 3) == 'has' then return function() return false end end
  if key:sub(1, 3) == 'get' then return function() return 0 end end
  if key:sub(1, 3) == 'set' or key:sub(1, 3) == 'can' then return function() return nil end end
  return nil
end})

local TASKS = table.concat({
  'S',
  'P|6445|3|10|1|500000|0|1142567|5|2|800|2|100|3|75|20|900',
  'B|Hell Boy|132|589|Gold|4417500|108|221|0|94|81|79|0|0',
  'K|1|Evul Frog|600|600|0|226|0|109|14|109|114|0',
  'K|2|Hell Boy|0|676|0|221|0|94|81|79|0|0',
  'K|3|Tanya|12|352|0|139|0|95|85|97|114|3',
  'K|4|Bat Digga|3|53|0|307|0|0|0|0|0|0',
  'K|5|MindFreak|320|533|0|201|0|0|0|0|0|0',
  'K|6|Baby Boo|0|424|0|312|0|0|0|0|0|0',
  'K|7|Egyptian Mummy|0|678|1|87|0|0|0|0|0|0',
  'K|8|Shorty|0|412|1|228|0|0|0|0|0|0',
  'K|9|Captain Freak|0|500|1|134|0|78|69|58|76|0',
  'D|1|ham|3582|12|37|0|0',
  'D|2|worm|3492|194|194|0|0',
  'D|3|small diamond|3028|3|14|0|0',
  'D|4|skull|3031|0|16|1|0',
  'D|5|plate armor|3357|1|5|0|0',
  'D|6|fire sword|3280|0|13|0|0',
  'D|7|black pearl|3027|0|39|0|1',
  'D|8|banana|3587|0|70|0|1',
  'D|9|soul orb|5944|0|12|0|1',
}, '\n')

local function storeAnswer(url, body, cb)
  if body.action ~= 'info' then
    return cb({ok = true, points = 11240, message = 'Purchased. It will be delivered within seconds.'})
  end
  local offer = function(id, category, name, price, client, count, description)
    return {id = id, category = category, name = name, price = price, item = client, clientItem = client, count = count, amount = 1, type = 'item', description = description}
  end
  cb({ok = true, points = 1011, admin = false, characters = {'Dev', 'Second Character'},
    categories = {{id = 1, name = 'Equipment'}, {id = 2, name = 'Weapons'}, {id = 3, name = 'Consumables'}, {id = 4, name = 'Runes'},
      {id = 5, name = 'Upgrades & Gems'}, {id = 6, name = 'Mounts'}, {id = 7, name = 'Boosts'}, {id = 8, name = 'Premium'}, {id = 9, name = 'Decoration'}, {id = 10, name = 'Misc'}, {id = 11, name = 'Outfits'}},
    offers = {
      offer(1, 1, 'Prestige Helmet', 5, 3351, 1, 'Arm: 1000, It gives 8% protection against everything.'),
      offer(2, 1, 'Prestige Armor', 5, 3357, 1, 'Arm: 1000, It gives 8% protection against everything.'),
      offer(3, 1, 'Prestige Legs', 5, 3358, 1, 'Arm: 1000.'),
      offer(4, 1, 'Prestige Boots', 5, 3079, 1, 'Arm: 1000.'),
      offer(5, 1, 'Prestige Shield', 5, 3420, 1, 'Def: 1000.'),
      offer(6, 1, "Wayme's Backpack", 10, 2854, 1, 'Holds more than any other.'),
      offer(7, 1, 'Weekly Tasks Expansion', 900, 3041, 1, 'Opens the last 3 kill tasks and the last 3 delivery tasks of the Weekly Tasks.'),
      offer(8, 1, 'Ultimate Health Potions', 20, 3031, 100, '100 ultimate health potions.'),
      {id = 9, category = 11, name = 'Full Arbalester Outfit', price = 600, item = 45, count = 3, amount = 1, type = 2, looks = {1450, 1449},
       description = 'Armed with a powerful crossbow. Includes the outfit and both addons.'},
      {id = 10, category = 11, name = 'Full Sun Priest Outfit', price = 750, item = 80, count = 3, amount = 1, type = 2, looks = {1024, 1023},
       description = 'Includes the outfit and both addons.'},
      {id = 11, category = 6, name = 'Armoured War Horse', price = 870, item = 24, count = 1, amount = 1, type = 3, looks = {426},
       description = 'The Armoured War Horse is a dangerous black beauty!'},
      {id = 12, category = 7, name = 'XP Boost', price = 30, item = 0, count = 1, amount = 1, type = 4,
       description = 'Increases the experience your character gains by 50% for 1 hour.'},
      offer(13, 8, 'VIP Medal', 125, 5785, 1, '+15 VIP days.'),
    },
    sexes = {Dev = 1, ['Second Character'] = 0},
    xpBoost = {Dev = {bought = 1, price = 45, active = false}, ['Second Character'] = {bought = 0, price = 30, active = false}}})
end

local function fakeContainer(id, name, itemIds, capacity)
  local items = {}
  for i, itemId in ipairs(itemIds) do items[i] = Item.create(itemId) end
  local self = {}
  function self:getId() return id end
  function self:getName() return name end
  function self:getCapacity() return capacity end
  function self:getItems() return items end
  function self:getItem(_) return items[1] end
  function self:getContainerItem() return Item.create(2854) end
  function self:getSlotPosition(slot) return {x = 65535, y = 64 + id, z = slot} end
  function self:hasParent() return false end
  function self:hasPages() return false end
  function self:isUnlocked() return true end
  function self:getSize() return #items end
  function self:getFirstIndex() return 0 end
  self.window = nil
  return self
end

local function characters()
  local list = {}
  for index, name in ipairs({'Dev', 'Test', 'Lord Valerius', 'Morgana', 'Kael the Red', 'Sir Aldric', 'Nyx', 'Bartholomew'}) do
    list[index] = {name = name, worldName = 'ForgottenL', worldIp = '127.0.0.1', worldPort = 1, level = 100 * index, vocation = 'Elite Knight',
      outfit = {type = 128 + index, head = 78, body = 69, legs = 58, feet = 76, addons = 0}}
  end
  return list
end

local DAILY = table.concat({
  'S|9|0|38135|10|2|5000|10|1',
  'R|1|item|3043|10|done|0|10 crystal coins',
  'R|2|item|3040|2|done|0|2 gold nuggets',
  'R|3|scroll|43948|1|today|1|1 Magic Level Scroll, bound to you',
  'R|4|item|3040|5|locked|0|5 gold nuggets',
  'R|5|item|9057|2|locked|1|2 Buffary Coins, bound to you',
  'R|6|item|3040|10|locked|0|10 gold nuggets',
  'R|7|item|11587|1|locked|1|1 ForgottenL Coin, bound to you',
  'B|2|7643|1|+1,000 health and mana every 2 seconds while your streak is 2 or more',
  'B|4|7643|1|+4,000 health and mana every 2 seconds while your streak is 4 or more',
  'B|6|7440|1|+10% experience while your streak is 6 or more',
}, '\n')
local DAILY_NEW = table.concat({
  'S|0|0|38135|1|1|0|0|1',
  'R|1|item|3043|10|today|0|10 crystal coins',
  'R|2|bonus|7643|1|locked|0|+1,000 health and mana every 2 seconds while your streak is 2 or more',
  'R|3|scroll|43946|1|locked|1|1 Melee Scroll, bound to you',
  'R|4|bonus|7643|1|locked|0|+4,000 health and mana every 2 seconds while your streak is 4 or more',
  'R|5|item|9057|2|locked|1|2 Buffary Coins, bound to you',
  'R|6|bonus|7440|1|locked|0|+10% experience while your streak is 6 or more',
  'R|7|item|11587|1|locked|1|1 ForgottenL Coin, bound to you',
  'B|2|7643|0|+1,000 health and mana every 2 seconds while your streak is 2 or more',
  'B|4|7643|0|+4,000 health and mana every 2 seconds while your streak is 4 or more',
  'B|6|7440|0|+10% experience while your streak is 6 or more',
}, '\n')

local function define()
  step('login', function() end, 1000)
  step('char_list', function()
    local enter = byId('enterGame')
    CharacterList.create(characters(), {premDays = 30, status = 0, subStatus = 1, premium = true})
    CharacterList.setVipDays({25, 3, 0, 12})
    if enter then enter:hide() end
    CharacterList.show()
  end)
  step('updater', function()
    closeWindows()
    g_ui.importStyle('/modules/client_entergame/forgottenl_style')
    local w = g_ui.displayUI('/modules/updater/updater')
    w.version:setText('Client version 1.0.7 build 39')
    w.status:setText('Updating the client: new game graphics...')
    w.mainProgress:setPercent(21)
    w.mainProgress:getChildById('caption'):setText('21%')
    w.downloadStatus:setText('Tibia.spr: part 19 of 87')
    w.downloadProgress:setPercent(60)
    w.downloadInfo:setText('25.3 MB of 117.2 MB (2.7 MB/s)')
    for _, id in ipairs({'mainProgress', 'downloadProgress', 'downloadStatus', 'downloadInfo'}) do w[id]:setVisible(true) end
    w:setId('previewUpdater')
  end, 800)
  step('updater_end', function()
    local w = byId('previewUpdater')
    if w then w:destroy() end
  end)
  step('daily_new', function()
    closeWindows()
    modules.game_dailyrewards.onDailyMessage(nil, 30, DAILY_NEW)
  end, 700)
  step('daily_week2', function()
    modules.game_dailyrewards.onDailyMessage(nil, 30, DAILY)
  end, 700)
  step('daily_end', function() modules.game_dailyrewards.hide() end)
  step('msgbox', function()
    closeWindows()
    displayInfoBox('Restart required', 'The interface layout was changed.\nRestart the client for the change to take effect.')
  end)
  step('msgbox_cancel', function()
    closeWindows()
    displayCancelBox('Please wait', 'Connecting to the login server...')
  end)
  step('locales', function()
    closeWindows()
    modules.client_locales.createWindow()
  end)
  step('options_1', function()
    closeWindows()
    modules.client_options.show()
    shotTabsDone = true
  end)
  for index = 2, 6 do
    step('options_' .. index, function()
      local bar = byId('optionsTabBar')
      local tab = bar and bar:getTabs()[index]
      if tab then bar:selectTab(tab) end
    end)
  end
  step('options_end', function() modules.client_options.hide() closeWindows() end, 100)

  -- from here the client believes it is online
  step('online', function()
    closeWindows()
    local enter = byId('enterGame')
    if enter then enter:hide() end
    g_game.setClientVersion(870)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(870))
    g_game.isOnline = function() return true end
    g_game.getLocalPlayer = function() return player end
    g_game.getCharacterName = function() return 'Dev' end
    g_game.getServerBeat = function() return 50 end
    HTTP.postJSON = storeAnswer
    local map = modules.game_interface.getMapPanel()
    map:hide() -- the engine can't draw the map without a real player
    local stand = g_ui.createWidget('UIWidget', modules.game_interface.getRootPanel())
    stand:setId('previewMap')
    stand:setImageSource('/images/game/floor')
    stand:setImageRepeated(true)
    stand:setImageColor('#6a8a5a')
    stand:setPhantom(true)
    -- it stands where the map would, on what the layout shows beside the map
    local dummy = g_ui.createWidget('UICreature', stand)
    dummy:setOutfit({type = 128, head = 78, body = 69, legs = 58, feet = 76, addons = 3, mount = 0})
    local function placeStand()
      local rect = modules.game_interface.getMapRect()
      stand:setRect(rect)
      local tile = rect.height / 11
      dummy:setSize({width = tile * 2, height = tile * 2})
      dummy:setPosition({x = rect.x + rect.width / 2 - tile * 1.5, y = rect.y + rect.height / 2 - tile * 1.5})
    end
    connect(map, {onGeometryChange = placeStand})
    placeStand()
    local panel = modules.game_interface.getRootPanel()
    panel:lowerChild(stand)
    panel:lowerChild(panel:getChildById('gameMapBackdrop'))
    modules.game_interface.updateMapBackdrop()
    -- the answer to the ping, late by previewPingDelay ms, or never when it is nil
    g_game.getProtocolGame = function()
      return {
        isConnecting = function() return false end,
        sendExtendedOpcode = function(self, opcode)
          if opcode == 12 and previewPingDelay then
            scheduleEvent(function() ProtocolGame.onExtendedOpcode(self, 12, '') end, previewPingDelay)
          end
        end
      }
    end
    g_game.close = function() end
    g_game.open = function() end
    for _, child in ipairs(rootWidget:getChildren()) do
      if child:isVisible() then log('visible: ' .. child:getId()) end
    end
    map.followCreature = function() end
    fire(g_game.onGameStart)
  end, 1500)
  step('game_full', function()
    local names = {'Rat', 'Hell Boy', 'Evul Frog', 'Tanya', 'Bat Digga', 'MindFreak'}
    if modules.game_skills.skillsWindow then modules.game_skills.skillsWindow:open() end
    if modules.game_battle.battleWindow then modules.game_battle.battleWindow:open() end
    if modules.game_viplist.vipWindow then modules.game_viplist.vipWindow:open() end
    if modules.game_console.addText then
      local tab = modules.game_console.getCurrentTab and modules.game_console.getCurrentTab()
      modules.game_console.addTabText('19:12 Dev [6445]: Reborn looks good', {color = '#F0F000'}, tab)
      modules.game_console.addTabText('19:12 You see a prestige helmet (Arm:1000).', {color = '#33FF33'}, tab)
      modules.game_console.addTabText('19:13 You advanced to level 6445.', {color = '#FFFFFF'}, tab)
      modules.game_console.addTabText('19:13 Loot of a hell boy: 10 crystal coins.', {color = '#33FF33'}, tab)
    end
  end, 1200)
  -- the boss bar in the topbar: a world boss, then an event boss after a hit (the lighter part is the damage just taken)
  step('bossbar', function()
    modules.game_bossbar.preview('S|1|Orshabaal|world|2450|13888|22400', {type = 201})
  end, 900)
  step('bossbar_event', function()
    modules.game_bossbar.preview('S|2|Penguin Summoner|event|0|300000000|300000000', {type = 255})
    modules.game_bossbar.preview('H|2|171000000|300000000')
  end, 300)
  -- what adds up to each stat, with an answer shaped like the server's
  step('skills_tips', function()
    closeWindows()
    local answer = table.concat({
      'rate=150', 'vocation=Elite Knight', 'premium=65535', 'bank=1000', 'vip=86400', 'supervip=1', 'viptp=1', 'potion=0', 'paper=0', 'boost=0',
      'boostpercent=5', 'boostactive=0', 'expburst=1', 'healthbooster=200000', 'manabooster=50000', 'blockorb=0', 'reflectorb=0',
      'element=8,50', 'attack=1500', 'defense=340', 'armor=95', 'critical=6,1.2', 'absorb=1,12', 'absorb=8,20', 'reflect=8,5,20',
      'increment=30,10,0,5', 'food=3600', 'regen=250,125',
      'src=attack,weapon,1000', 'src=attack,ammo,500', 'src=element,weapon,50', 'src=defense,shield,300', 'src=defense,weapon,40',
      'src=armor,helmet,20', 'src=armor,armor,40', 'src=armor,legs,20', 'src=armor,boots,15', 'src=hpboost,small,50000', 'src=hpboost,scroll,150000',
      'src=mpboost,small,50000', 'src=skill2,base,110', 'src=skill2,ring,5', 'src=skill2,weapon,10', 'src=skill2,others,3', 'src=health,level,12000',
      'src=health,booster,200000', 'src=health,armor,1000', 'src=mana,level,3000', 'src=mana,booster,50000', 'src=magic,base,18', 'src=magic,necklace,2',
      'src=soul,base,100', 'src=speed,level,1300', 'src=speed,boots,40', 'src=speed,mount,20', 'src=speed,others,70', 'src=hpregen,vocation,50',
      'src=hpregen,ring,200', 'src=mpregen,vocation,25', 'src=mpregen,ring,100', 'src=abs1,armor,5', 'src=abs1,legs,7', 'src=abs8,armor,8', 'src=abs8,ring,2',
      'src=abs8,vocation,10', 'src=ref8,armor,5,20', 'src=healv,necklace,30', 'src=healp,ring,10', 'src=mdmgp,necklace,5', 'src=capacity,total,20000', 'src=capacity,carried,-6000',
    }, '\n')
    modules.game_skills.skillsWindow:open()
    modules.game_skills.skillsWindow:maximize()
    modules.game_skills.onStats(nil, 8, answer)
    for _, panelId in ipairs({'combatPanel', 'protectionPanel', 'bonusPanel'}) do
      for _, row in ipairs(byId(panelId):getChildren()) do
        log('tip ' .. row.name:getText() .. ' = ' .. tostring(row:getTooltip()):gsub('\n', ' | '))
      end
    end
    for _, id in ipairs({'health', 'mana', 'soul', 'capacity', 'speed', 'magiclevel', 'skillId2'}) do
      log('tip ' .. id .. ' = ' .. tostring(byId(id):getTooltip()):gsub('\n', ' | '))
    end
    g_tooltip.display(byId('combatPanel'):getChildren()[1]:getTooltip())
  end, 700)
  step('skills_tips_defense', function()
    g_tooltip.hide()
    g_tooltip.display(byId('combatPanel'):getChildren()[3]:getTooltip())
  end, 400)
  step('skills_tips_speed', function()
    g_tooltip.hide()
    g_tooltip.display(byId('speed'):getTooltip())
  end, 400)
  step('skills_tips_fire', function()
    g_tooltip.hide()
    g_tooltip.display(byId('protectionPanel'):getChildren()[2]:getTooltip())
  end, 400)
  -- the banner of a complete set
  step('setbonus', function()
    closeWindows()
    local banner = modules.game_setbonus.banner
    local rootPanel = modules.game_interface.getRootPanel()
    local rect = modules.game_interface.getMapRect()
    banner:setParent(rootPanel)
    banner:breakAnchors()
    banner:setPosition({x = rect.x + math.floor((rect.width - banner:getWidth()) / 2), y = rect.y + 62})
    modules.game_setbonus.onSetBonus(nil, 13, 'on|Corrupted Prestige Archer|28')
  end, 700)
  step('setbonus_tip', function()
    local answer = 'attack=7000\ndefense=1250\narmor=5000\nsetname=Hellborn\nsetprotection=10\nabsorb=8,10\nregen=25,33\nsrc=attack,weapon,7000\nsrc=abs8,set,10\n'
    modules.game_skills.skillsWindow:open()
    modules.game_skills.skillsWindow:maximize()
    modules.game_skills.onStats(nil, 8, answer)
    g_tooltip.display(byId('protectionPanel'):getChildren()[1]:getTooltip())
  end, 500)
  -- the frame rate and the ping
  local function plate(name, wait, setup)
    step(name, setup, wait)
  end
  plate('stats_wait', 600, function()
    previewPingDelay = nil
    local ui = modules.game_stats.ui
    local rootPanel = modules.game_interface.getRootPanel()
    local rect = modules.game_interface.getMapPanel():getRect()
    ui:setParent(rootPanel)
    ui:setMarginLeft(rect.x - rootPanel:getX() + 5)
    ui:setMarginTop(rect.y - rootPanel:getY() + 5)
    modules.game_stats.show()
  end)
  plate('stats_good', 4600, function()
    previewPingDelay = 34
    modules.game_stats.show()
  end)
  plate('stats_fair', 4600, function()
    previewPingDelay = 310
    g_app.getFps = function() return 24 end
  end)
  plate('stats_bad', 4600, function()
    previewPingDelay = 780
    g_app.getFps = function() return 11 end
  end)
  plate('stats_frozen', 5200, function() previewPingDelay = nil end)
  plate('stats_back', 12000, function()
    previewPingDelay = 34
    g_app.getFps = function() return 60 end
  end)
  plate('stats_no_ping', 500, function() modules.game_stats.setRowVisible('ping', false) end)
  plate('stats_none', 500, function() modules.game_stats.setRowVisible('fps', false) end)
  plate('stats_both', 700, function()
    modules.game_stats.setRowVisible('fps', true)
    modules.game_stats.setRowVisible('ping', true)
  end)
  -- the health and mana circles and their controls
  step('circles', function()
    closeWindows()
    modules.game_healthinfo.onHealthChange(player, 8200, 10000)
    modules.game_healthinfo.onManaChange(player, 5300, 9000)
    modules.game_healthinfo.placeCircles()
    modules.game_interface.updateMapBackdrop()
  end, 600)
  step('circles_edit', function()
    log('circle editor opens: ' .. tostring(modules.game_healthinfo.openCircleEditor()))
  end, 500)
  step('circles_mana', function()
    byId('manaTab').onClick(byId('manaTab'))
  end, 300)
  step('circles_big', function()
    byId('sizeBar'):setValue(150)
    byId('opacityBar'):setValue(60)
  end, 400)
  step('circles_small', function()
    byId('sizeBar'):setValue(50)
    byId('opacityBar'):setValue(100)
  end, 400)
  step('circles_75', function()
    byId('sizeBar'):setValue(75)
  end, 400)
  step('circles_200', function()
    byId('sizeBar'):setValue(200)
  end, 400)
  step('circles_apart', function()
    byId('together'):setChecked(false)
    byId('sizeBar'):setValue(100)
    byId('healthTab').onClick(byId('healthTab'))
    byId('sizeBar'):setValue(125)
    byId('opacityBar'):setValue(40)
    local widget = byId('healthCircle')
    local pos = {x = widget:getX() + 20, y = widget:getY() + 100}
    log('drag enter: ' .. tostring(widget:onDragEnter(pos)))
    log('drag move: ' .. tostring(widget:onDragMove({x = 300, y = 200})))
    log('drag leave: ' .. tostring(widget:onDragLeave(nil, {x = 300, y = 200})))
  end, 500)
  step('circles_wheel', function()
    local health, mana = byId('healthCircle'), byId('manaCircle')
    local pos = {x = health:getX() + 10, y = health:getY() + 10}
    local report = function(what)
      log(what .. ': health ' .. health:getWidth() .. 'x' .. health:getHeight() .. ' opacity ' .. health:getOpacity() ..
        ', mana ' .. mana:getWidth() .. ' opacity ' .. mana:getOpacity() .. ' at ' .. mana:getX() .. ',' .. mana:getY())
    end
    report('before')
    health:onMouseWheel(pos, MouseWheelUp)
    report('wheel up')
    for _ = 1, 40 do health:onMouseWheel(pos, MouseWheelUp) end
    report('wheel up to the top')
    for _ = 1, 60 do health:onMouseWheel(pos, MouseWheelDown) end
    report('wheel down to the bottom')
    local ctrl = g_keyboard.isCtrlPressed
    g_keyboard.isCtrlPressed = function() return true end
    for _ = 1, 40 do health:onMouseWheel(pos, MouseWheelDown) end
    report('ctrl and wheel down to the bottom')
    g_keyboard.isCtrlPressed = ctrl
    -- with Shift both move
    local shift = g_keyboard.isShiftPressed
    g_keyboard.isShiftPressed = function() return true end
    local start = {x = health:getX() + 5, y = health:getY() + 5}
    health:onDragEnter(start)
    health:onDragMove({x = start.x + 40, y = start.y + 30})
    health:onDragLeave(nil, start)
    g_keyboard.isShiftPressed = shift
    report('dragged 40,30 with Shift')
  end, 300)
  step('circles_reset', function()
    byId('reset').onClick(byId('reset'))
    byId('manaTab').onClick(byId('manaTab'))
    byId('reset').onClick(byId('reset'))
    byId('together'):setChecked(true)
    log('saved: ' .. tostring(g_settings.getNode('healthCircles') ~= nil))
  end, 500)
  step('circles_low', function()
    modules.game_healthinfo.closeCircleEditor()
    VALUES.getHealthPercent = 22
    modules.game_healthinfo.onHealthChange(player, 2200, 10000)
    modules.game_healthinfo.onManaChange(player, 900, 9000)
  end, 400)
  -- only when asked for by name: it waits for real window messages (a test script sends them to this window alone)
  step('circles_input', function()
    closeWindows()
    modules.game_healthinfo.onHealthChange(player, 8200, 10000)
    modules.game_healthinfo.onManaChange(player, 5300, 9000)
    local widget = byId('healthCircle')
    local rect = widget:getRect()
    local x, y = rect.x + math.floor(rect.width * 0.27), rect.y + math.floor(rect.height * 0.5)
    g_resources.writeFileContents('/input_ready.txt', table.concat({x, y, x - 200, y - 180, 900, 200}, ' '))
    -- the engine reads the real state of the keyboard, which messages don't change: the script sets these through files
    g_keyboard.isAltPressed = function() return g_resources.fileExists('/alt_on.txt') end
    g_keyboard.isCtrlPressed = function() return g_resources.fileExists('/ctrl_on.txt') end
    g_window.hasFocus = function() return true end
    local started = g_clock.millis()
    local function report()
      local editor = byId('circleEditor')
      local r = widget:getRect()
      log(string.format('t=%d mouse=%d,%d alt=%s circle=%d,%d %dx%d opacity=%.2f editor=%s phantom=%s', g_clock.millis() - started,
        g_window.getMousePosition().x, g_window.getMousePosition().y, tostring(g_keyboard.isAltPressed()), r.x, r.y, r.width, r.height,
        widget:getOpacity(), tostring(editor and editor:isVisible()), tostring(widget:isPhantom())))
      if g_clock.millis() - started < 12000 then scheduleEvent(report, 400) end
    end
    report()
    scheduleEvent(function() shot('circles_input_open') end, 2600)
  end, 13000)
  steps[#steps].explicit = true
  step('containers', function()
    local a = fakeContainer(0, 'backpack of holding', {3160, 3351, 3357, 3358, 3079, 3420, 3280, 3043, 3031, 3028, 3582, 3492}, 20)
    local b = fakeContainer(1, 'bag', {3027, 5944, 3587}, 8)
    modules.game_containers.onContainerOpen(a)
    modules.game_containers.onContainerOpen(b)
  end, 800)
  step('inventory', function()
    if modules.game_inventory.inventoryWindow then modules.game_inventory.inventoryWindow:open() end
    if modules.game_inventory.refresh then modules.game_inventory.refresh() end
  end)
  step('inventory_empty', function()
    inventory = {}
    if modules.game_inventory.refresh then modules.game_inventory.refresh() end
  end)
  step('guides', function()
    modules.game_guides.show()
  end)
  for index = 2, 7 do
    step('guides_' .. index, function()
      local bar = byId('guidesTabBar')
      local tab = bar and bar:getTabs()[index]
      if tab then bar:selectTab(tab) end
    end)
  end
  step('guides_5b', function()
    local bar = byId('guidesTabBar')
    bar:selectTab(bar:getTabs()[5])
    local panel = bar:getCurrentTabPanel()
    local cards = panel:recursiveGetChildById('cards')
    local children = cards:getChildren()
    cards:ensureChildVisible(children[#children])
  end, 700)
  -- the Boss bar card of the Interface tab
  step('guides_bossbar', function()
    local bar = byId('guidesTabBar')
    bar:selectTab(bar:getTabs()[5])
    local cards = bar:getCurrentTabPanel():recursiveGetChildById('cards')
    local children = cards:getChildren()
    for i, card in ipairs(children) do
      local title = card:recursiveGetChildById('title')
      if title and title:getText() == 'Boss bar' then
        cards:ensureChildVisible(children[math.min(#children, i + 1)])
      end
    end
  end, 700)
  -- the card of a title, in whichever tab has it
  step('guides_bignames', function()
    local bar = byId('guidesTabBar')
    for _, tab in ipairs(bar:getTabs()) do
      bar:selectTab(tab)
      local cards = bar:getCurrentTabPanel():recursiveGetChildById('cards')
      local children = cards and cards:getChildren() or {}
      for i, card in ipairs(children) do
        local title = card:recursiveGetChildById('title')
        if title and title:getText() == 'Names on big outfits' then for k = i, math.min(#children, i + 5) do cards:ensureChildVisible(children[k]) end return end
      end
    end
  end, 700)
  step('guides_tiers', function()
    local bar = byId('guidesTabBar')
    for _, tab in ipairs(bar:getTabs()) do
      bar:selectTab(tab)
      local cards = bar:getCurrentTabPanel():recursiveGetChildById('cards')
      local children = cards and cards:getChildren() or {}
      for i, card in ipairs(children) do
        local title = card:recursiveGetChildById('title')
        if title and title:getText() == 'Item tiers' then for k = i, math.min(#children, i + 4) do cards:ensureChildVisible(children[k]) end return end
      end
    end
  end, 700)
  step('guides_hands', function()
    local bar = byId('guidesTabBar')
    for _, tab in ipairs(bar:getTabs()) do
      if tab:getText() == 'Interface' then bar:selectTab(tab) end
    end
    local cards = bar:getCurrentTabPanel():recursiveGetChildById('cards')
    for _, card in ipairs(cards:getChildren()) do
      if card.text and card.text:getText():find('Weapons go in the left hand', 1, true) then cards:ensureChildVisible(card) end
    end
  end, 700)
  step('guides_check', function()
    local bar = byId('guidesTabBar')
    for index, tab in ipairs(bar:getTabs()) do
      bar:selectTab(tab)
      local cards = bar:getCurrentTabPanel():recursiveGetChildById('cards')
      for _, card in ipairs(cards:getChildren()) do
        local used = card.text:getY() + card.text:getHeight() - card:getY()
        print('[guidecheck] ' .. tab:getText() .. ' | ' .. card.title:getText() .. ' | ' .. used .. ' of ' .. card:getHeight())
      end
    end
  end, 300)
  -- /checkall: its Items tab and the sub tabs from the map editor's tabs
  local function checkAllSubTab(name)
    local bar = byId('checkAllWindow') and byId('checkAllWindow'):getChildById('subTabBar')
    for _, tab in ipairs(bar and bar:getTabs() or {}) do
      if tab:getText() == name then bar:selectTab(tab) end
    end
  end
  step('checkall', function()
    closeWindows()
    modules.game_checkall.show()
  end, 900)
  step('checkall_sets', function() checkAllSubTab('Sets') end)
  step('checkall_weapons', function() checkAllSubTab('Weapons') end)
  step('checkall_spells', function() checkAllSubTab('Spells') end)
  step('checkall_close', function() modules.game_checkall.hide() end, 100)
  step('store', function()
    modules.game_guides.hide()
    modules.game_store.show()
  end, 900)
  step('bossicons_api', function()
    -- game_bossicons draws with Creature.setIconTexture: say whether this client has it, and whether the pictures load
    log('bossicons: Creature.setIconTexture ' .. tostring(Creature.setIconTexture ~= nil) .. ', module ' ..
      tostring(modules.game_bossicons ~= nil) .. ', echo icon ' .. tostring(g_resources.fileExists('/images/game/bosses/echo.png')))
  end)
  step('store_outfit', function() modules.game_store.hide() modules.game_store.show('Full Arbalester Outfit') end, 900)
  step('store_outfit_female', function()
    local w = byId('storeWindow')
    if w then w:recursiveGetChildById('charBox'):setCurrentOption('Second Character') end
  end, 600)
  step('store_mount', function() modules.game_store.hide() modules.game_store.show('Armoured War Horse') end, 900)
  step('store_boost', function() modules.game_store.hide() modules.game_store.show('XP Boost') end, 900)
  step('store_premium', function() modules.game_store.hide() modules.game_store.show('VIP Medal') end, 900)
  step('gstore_buy', function()
    modules.game_store.hide()
    modules.game_generalstore.onMessage(nil, 32, GSTORE)
  end, 900)
  step('gstore_runes', function() modules.game_generalstore.showCategory('runes') modules.game_generalstore.selectItem(64067) end, 700)
  step('gstore_backpacks', function() modules.game_generalstore.showCategory('backpacks') modules.game_generalstore.selectItem(61487) end, 700)
  step('gstore_sell', function() modules.game_generalstore.setTab('sell') end, 700)
  step('gstore_sell_runes', function() modules.game_generalstore.showCategory('runes') modules.game_generalstore.selectItem(64067) end, 700)
  step('gstore_end', function() modules.game_generalstore.hide() end, 100)
  -- the supply stash with a few items, then the amount question for one of them
  step('stash_open', function()
    modules.game_stash.onMessage(nil, 34, table.concat({'O',
      'I|2789|3725|brown mushroom|1660|others|5', 'I|2376|3264|sword|4|swords|100', 'I|2389|3277|spear|1|distance|3',
      'I|64067|60022|small manarune|11000|runes|5000', 'I|64069|60024|great manarune|27|runes|125000',
      'I|2493|3387|demon helmet|2|helmets|20000', 'I|2472|3366|magic plate armor|1|armors|1500000',
      'I|2195|3079|boots of haste|3|boots|15000', 'I|2123|3006|ring of the sky|9|rings|0',
      'I|2173|3057|amulet of loss|5|amulets|5000', 'I|2301|3188|fire field rune|239|runes|14', 'E'}, '\n'))
  end, 700)
  step('stash_amount', function()
    local w = rootWidget:recursiveGetChildById('stashWindow')
    local first = w and w:recursiveGetChildById('items'):getChildren()[1]
    if first and first.onClick then first.onClick() end
  end, 500)
  step('stash_tip_rune', function()
    modules.game_stash.closeAmount()
    modules.game_stash.showTip({clientId = 3188, name = 'fire field rune', category = 'runes', count = 239, pays = 14,
      look = 'a fire field rune("adevo grav flam").\nIt can only be used with level 15 and magic level 1 or higher.\nIt weighs 1.20 oz.'})
  end, 400)
  step('stash_tip_sword', function()
    modules.game_stash.showTip({clientId = 55746, name = 'Cursed Sword', category = 'swords', count = 3, pays = 0,
      look = 'a Cursed Sword (Atk:1125, Def:40, protection physical +5%).\nIt can only be wielded properly by knights of level 100 or higher.\nIt weighs 180.00 oz.\nTier 2.\nA tier 2 weapon of the Cursed line. Weapons of this line hit harder the deeper you hunt.'})
  end, 400)
  step('stash_end', function() modules.game_stash.hide() end, 100)
  -- an NPC message with blue words in the NPCs tab; the log says which text each clickable word covers
  step('npc_keywords', function()
    local c = modules.game_console
    local tab = c.getTab('NPCs') or c.addTab('NPCs', true)
    tab.npcChat = true
    c.addTabText('ForgottenL General Store: Welcome, Dev! I sell and buy everything: say {trade}. Or {travel}, {passage}.',
      c.SpeakTypesSettings.privateNpcToPlayer, tab, 'ForgottenL General Store')
    local buffer = c.consoleTabBar and c.consoleTabBar:getTabPanel(tab):getChildById('consoleBuffer')
    local label = buffer and buffer:getLastChild()
    for _, span in ipairs(label and label.npcKeywords or {}) do
      g_logger.info('[preview] keyword ' .. span.word .. ' shows as "' .. label:getText():sub(span.first + 1, span.last + 1) .. '"')
    end
  end, 300)
  -- the hidden text edit used to find a word of an NPC's speech on the screen: glyphs laid out while invisible?
  step('npc_screen_measure', function()
    local st = StaticText.create()
    st:addColoredMessage('ForgottenL General Store', MessageModes.NpcFrom, {'Welcome to the ForgottenL General Store, Dev! I sell and buy everything: say ', '#5FF7F7', 'trade', '#1f9ffe', '.', '#5FF7F7'})
    local text = st:getText()
    local m = g_ui.createWidget('UITextEdit', rootWidget)
    m:setFont('verdana-11px-rounded') m:setTextAlign(AlignCenter) m:setEditable(false) m:setPhantom(true) m:setVisible(false)
    m:setText(text)
    local size = m:getTextSize()
    m:setRect({x = 100, y = 100, width = size.width, height = size.height})
    m:setText('') m:setText(text)
    local first = text:find('trade', 1, true)
    g_logger.info('[preview] screen text ' .. size.width .. 'x' .. size.height .. ' lines ' .. select(2, text:gsub('\n', '')) + 1 .. ': ' .. text:gsub('\n', ' / '))
    for x = 100, 100 + size.width, 8 do
      local at = m:getTextPos({x = x, y = 100 + size.height - 6})
      g_logger.info('[preview] x ' .. x .. ' -> ' .. tostring(at) .. ' ' .. (at and at >= 0 and text:sub(at + 1, at + 1) or ''))
    end
    g_logger.info('[preview] trade starts at index ' .. tostring(first - 1))
    m:destroy()
  end, 100)
  step('inspect_player', function()
    modules.game_inspect.onMessage(nil, 33, [[P|268435500|Lord Paladin|31250|Royal Paladin|412000|455000|98000|120000|42|1480|100
K|0|10
K|1|12
K|2|14
K|3|10
K|4|128
K|5|95
K|6|10
Q|1|59346|Prestige Helmet|1
Q|4|59351|Mythic Armor|1
Q|7|55797|Legs|1
Q|8|56297|Boots|1
Q|3|2854|backpack|1
Q|6|55690|Beginner Sword|1
Q|2|3043|crystal coin|7
attack=1500
defense=320
armor=48
increment=0,0,0,0,7
absorb=1,12
absorb=2048,5
absorb=8,-4
absorb=1024,9
reflect=8,20,10
setname=Beginner
setprotection=5]])
  end, 700)
  step('inspect_monster', function()
    modules.game_inspect.onMessage(nil, 33, [[M|1073741900|Dragon Lord [L. 120]|120
L|3031|gold coin
L|3043|crystal coin
L|60022|small manarune
L|55685|Beginner Helmet
L|55686|Beginner Armor
L|55741|t2
L|55797|t3
L|56297|t4
L|59346|t5
L|59351|t6
L|3155|sudden death rune]])
  end, 700)
  step('loot_colors', function()
    modules.game_inspect.hide()
    modules.game_textmessage.displayMessage(MessageModes.Loot, 'Loot of a dragon lord: [c=c]93 gold coins[/c], [c=u]a dragon scale mail[/c], [c=r]a royal helmet[/c], [c=v]a dragon lord trophy[/c], [c=q]a Bronze Key[/c].')
  end, 900)
  step('taskboard_bounty', function()
    modules.game_store.hide()
    modules.game_taskboard.onTaskMessage(nil, 11, TASKS)
    modules.game_taskboard.showTab('bounty')
  end)
  step('taskboard_weekly', function() modules.game_taskboard.showTab('weekly') end)
  step('taskboard_shop', function() modules.game_taskboard.showTab('shop') end)
  step('outfit', function()
    closeWindows()
    local current = {type = 128, head = 78, body = 69, legs = 58, feet = 76, addons = 3, mount = 0, wings = 0, aura = 0, shader = '', healthBar = 0, manaBar = 0}
    local outfits = {{128, 'Citizen', 3}, {129, 'Hunter', 3}, {130, 'Mage', 3}, {131, 'Knight', 3}}
    local mounts = {{368, 'Widow Queen'}}
    modules.game_outfit.create(current, outfits, mounts, {}, {}, {}, {}, {})
  end, 800)
  step('npctrade', function()
    closeWindows()
    if modules.game_outfit.destroy then modules.game_outfit.destroy() end
    local items = {}
    for i, id in ipairs({3351, 3357, 3358, 3079, 3420, 3280, 3043, 3031, 3028, 3160, 3582, 3492}) do
      items[i] = {Item.create(id), 'trade item ' .. i, 1200 + i * 30, 100 * i, 50 * i}
    end
    modules.game_npctrade.onOpenNpcTrade(items)
  end, 800)
  step('playertrade', function()
    modules.game_npctrade.hide()
    local items = {Item.create(3351), Item.create(3357), Item.create(3043)}
    modules.game_playertrade.onGameOwnTrade('Dev', items)
    modules.game_playertrade.onGameCounterTrade('Morgana', {Item.create(3280), Item.create(3031)})
  end, 500)
  step('questlog', function()
    modules.game_playertrade.onGameCloseTrade()
    modules.game_questlog.onGameQuestLog({{1, 'The Ancient Tombs', false}, {2, 'Demon Helmet Quest', true}, {3, 'The Inquisition', false}, {4, 'Annihilator', true}})
  end)
  step('textwindow', function()
    closeWindows()
    modules.game_textwindow.onGameEditText(1, 2854, 500, 'The dragon sleeps under the old keep.\nBring fire.', 'Morgana', '2026-11-04 01:00')
  end)
  step('playerdeath', function()
    closeWindows()
    modules.game_playerdeath.openWindow(0, 10)
  end)
  step('channels', function()
    closeWindows()
    modules.game_console.onChannelList({{1, 'Help'}, {2, 'Trade'}, {3, 'Game Chat'}, {4, 'Advertising'}})
  end)
  step('addvip', function()
    closeWindows()
    modules.game_viplist.createAddWindow()
  end)
  step('spelllist', function()
    closeWindows()
    if modules.game_spelllist.toggle then modules.game_spelllist.toggle() end
  end, 700)
  step('bugreport', function()
    closeWindows()
    if modules.game_spelllist.toggle then pcall(modules.game_spelllist.toggle) end
    modules.game_bugreport.show()
  end)
  step('textedit', function()
    closeWindows()
    modules.client_textedit.show('Some text', {title = 'Enter text', description = 'Write something here', multiline = true}, function() end)
  end)
  step('terminal', function()
    closeWindows()
    modules.client_textedit.hide()
    if modules.client_terminal.setAllowed then modules.client_terminal.setAllowed(true) end
    modules.client_terminal.show()
  end)
  step('menu', function()
    modules.client_terminal.hide()
    closeWindows()
    local menu = g_ui.createWidget('PopupMenu')
    menu:addOption('Look', function() end)
    menu:addOption('Use', function() end)
    menu:addSeparator()
    menu:addOption('Attack', function() end)
    menu:addOption('Follow', function() end)
    menu:display({x = 500, y = 300})
  end)
  step('prey', function()
    rootWidget:focus()
    modules.game_prey.show()
  end)
  step('imbuing', function()
    modules.game_prey.hide()
    modules.game_imbuing.show()
  end)
  step('game_clean', function()
    modules.game_imbuing.hide()
    closeWindows()
    modules.game_healthinfo.onHealthChange(player, 8200, 10000)
    modules.game_healthinfo.onManaChange(player, 5300, 9000)
  end, 500)
  local function ui(name, path, wait)
    step(name, function()
      closeWindows()
      local window = g_ui.displayUI(path)
      window:show()
      window:raise()
    end, wait)
  end
  ui('waiting', '/modules/client_entergame/waitinglist')
  ui('bar_hotkey', '/modules/game_actionbar/hotkey')
  ui('bar_action', '/modules/game_actionbar/action')
  ui('bar_object', '/modules/game_actionbar/object')
  ui('bar_text', '/modules/game_actionbar/text')
  ui('communication', '/modules/game_console/communicationwindow')
  ui('violation', '/modules/game_console/violationwindow')
  ui('editvip', '/modules/game_viplist/editvip')
  ui('flagwindow', '/modules/game_minimap/flagwindow')
  step('ruleviolation', function()
    closeWindows()
    modules.game_ruleviolation.show('Morgana', 'bad words')
  end)
  step('feedback', function()
    closeWindows()
    modules.client_feedback.show()
  end)
  step('debuginfo', function()
    closeWindows()
    modules.client_stats.toggle()
  end)
  step('unjust', function()
    closeWindows()
    modules.game_unjustifiedpoints.toggle()
  end)
  step('checkall', function()
    closeWindows()
    modules.game_checkall.show()
  end, 900)
  step('modal', function()
    modules.game_checkall.hide()
    closeWindows()
    modules.game_modaldialog.onModalDialog(1, 'Choose your path', 'The ancient gate asks you for your choice.', {{1, 'Ok'}, {2, 'Cancel'}}, 1, 2, {{1, 'The path of fire'}, {2, 'The path of ice'}, {3, 'The path of shadows'}}, false)
  end)
  step('tooltip', function()
    closeWindows()
    g_tooltip.display('Attack Value: 1000\nThe higher the better.')
  end)
  step('minimized', function()
    g_tooltip.hide()
    if modules.game_viplist.vipWindow then modules.game_viplist.vipWindow:minimize() end
    if modules.game_skills.skillsWindow then modules.game_skills.skillsWindow:minimize() end
    modules.client_options.setOption('topHealtManaBar', true)
  end)
  step('combo_open', function()
    g_tooltip.hide()
    modules.client_options.show()
    local bar = byId('optionsTabBar')
    bar:selectTab(bar:getTabs()[2])
    local combo = byId('layout')
    combo:onMousePress({x = combo:getX() + 5, y = combo:getY() + 5}, MouseLeftButton)
  end)
  step('options_end2', function()
    rootWidget:focus()
    modules.client_options.hide()
    closeWindows()
  end)
end

local function run(i)
  local s = steps[i]
  if not s then
    log('done')
    return g_app.exit()
  end
  if (only and not only[s.name] and s.name ~= 'online') or (s.explicit and not only) then
    return run(i + 1)
  end
  local ok, err = pcall(s.f)
  if not ok then
    log(s.name .. ' FAILED: ' .. tostring(err))
  else
    log(s.name .. ' ok')
  end
  scheduleEvent(function()
    if s.name ~= 'online' and s.name ~= 'options_end' then shot(s.name) end
    scheduleEvent(function() run(i + 1) end, 250)
  end, s.wait)
end

function init()
  local text = readFile('/modules/zz_preview/only.txt')
  if text and text:trim():len() > 0 then
    only = {}
    for name in text:gmatch('%S+') do only[name] = true end
  end
  local size = readFile('/modules/zz_preview/size.txt')
  local w, h = 1280, 800
  if size then
    local a, b = size:match('(%d+)%s+(%d+)')
    if a then w, h = tonumber(a), tonumber(b) end
  end
  define()
  scheduleEvent(function()
    g_window.resize({width = w, height = h})
    scheduleEvent(function() run(1) end, 600)
  end, 1500)
end
