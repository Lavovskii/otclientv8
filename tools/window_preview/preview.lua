-- Preview only: no login, no network to the game. Opens every window of the client with made-up data, takes screenshots, closes.
-- only.txt (names separated by spaces) limits the run to those steps; size.txt gives the window size.
local steps = {}
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
      {id = 5, name = 'Upgrades & Gems'}, {id = 6, name = 'Mounts'}, {id = 7, name = 'Boosts'}, {id = 8, name = 'Premium'}, {id = 9, name = 'Decoration'}, {id = 10, name = 'Misc'}},
    offers = {
      offer(1, 1, 'Rich Helmet', 5, 3351, 1, 'Arm: 1000, It gives 8% protection against everything.'),
      offer(2, 1, 'Rich Armor', 5, 3357, 1, 'Arm: 1000, It gives 8% protection against everything.'),
      offer(3, 1, 'Rich Legs', 5, 3358, 1, 'Arm: 1000.'),
      offer(4, 1, 'Rich Boots', 5, 3079, 1, 'Arm: 1000.'),
      offer(5, 1, 'Rich Shield', 5, 3420, 1, 'Def: 1000.'),
      offer(6, 1, "Wayme's Backpack", 10, 2854, 1, 'Holds more than any other.'),
      offer(7, 1, 'Weekly Tasks Expansion', 900, 3041, 1, 'Opens the last 3 kill tasks and the last 3 delivery tasks of the Weekly Tasks.'),
      offer(8, 1, 'Ultimate Health Potions', 20, 3031, 100, '100 ultimate health potions.'),
    }})
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

local function define()
  step('login', function() end, 1000)
  step('char_list', function()
    local enter = byId('enterGame')
    CharacterList.create(characters(), {premDays = 30, status = 0, subStatus = 1, premium = true})
    CharacterList.setVipDays({25, 3, 0, 12})
    if enter then enter:hide() end
    CharacterList.show()
  end)
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
    stand:addAnchor(AnchorLeft, 'gameMapPanel', AnchorLeft)
    stand:addAnchor(AnchorRight, 'gameMapPanel', AnchorRight)
    stand:addAnchor(AnchorTop, 'gameMapPanel', AnchorTop)
    stand:addAnchor(AnchorBottom, 'gameMapPanel', AnchorBottom)
    stand:setImageSource('/images/game/floor')
    stand:setImageRepeated(true)
    stand:setImageColor('#6a8a5a')
    stand:setPhantom(true)
    modules.game_interface.getRootPanel():lowerChild(stand)
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
      modules.game_console.addTabText('19:12 You see a rich helmet (Arm:1000).', {color = '#33FF33'}, tab)
      modules.game_console.addTabText('19:13 You advanced to level 6445.', {color = '#FFFFFF'}, tab)
      modules.game_console.addTabText('19:13 Loot of a hell boy: 10 crystal coins.', {color = '#33FF33'}, tab)
    end
  end, 1200)
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
  step('store', function()
    modules.game_guides.hide()
    modules.game_store.show()
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
  if only and not only[s.name] and s.name ~= 'online' then
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
