-- The Skills window, laid out like today's Tibia. Level, points and skills come with the protocol; everything else
-- (experience rate and boosts, VIP, what the equipment gives in combat, boosters...) is asked from the server through
-- extended opcode 8 (Game::playerExtendedOpcode, sendPlayerStats in the server's game.cpp) as soon as the character
-- logs in, every few seconds while the window is open and when the equipment changes. The server answers with
-- "key=value" lines.
--
-- Every line explains itself when the mouse is over it. Admins (the Store's admin check) get a second explanation over
-- the number: where that value comes from on the server (storage, script, item, config).

skillsWindow = nil
skillsButton = nil

local OPCODE_STATS = 8
local STATS_INTERVAL = 3000
local statsEvent, tickEvent, inventoryEvent, retryEvent
local stats = nil        -- the last answer of the server
local statsTime = 0      -- when it arrived (the timers count down from it)
local rows = {}          -- the fixed lines of the window, by id
local panelKeys = {}     -- the lines each list panel shows now, to update them in place when only values change
local adminShown = nil   -- whether the admin explanations are on
local sections = {}      -- the section titles, by id
local SECTIONS = {characterSection = 'Character', skillsSection = 'Skills', combatSection = 'Combat',
                  protectionSection = 'Protection', bonusSection = 'Bonuses'}

-- combat types of the server (CombatType_t) with their name and the sprite shown in front of them
local ELEMENTS = {
  {type = 1, name = 'Physical', item = 3264},
  {type = 8, name = 'Fire', item = 3191},
  {type = 4, name = 'Earth', item = 3175},
  {type = 2, name = 'Energy', item = 3198},
  {type = 512, name = 'Ice', item = 3161},
  {type = 1024, name = 'Holy', item = 3182},
  {type = 2048, name = 'Death', item = 3155},
  {type = 256, name = 'Drown', item = 110},
  {type = 32, name = 'Life Drain', item = 3039},
  {type = 64, name = 'Mana Drain', item = 3036},
}
local ELEMENT_BY_TYPE = {}
for _, e in ipairs(ELEMENTS) do ELEMENT_BY_TYPE[e.type] = e end

local GREEN, RED, GREY, GOLD, NORMAL = '#44ad25', '#e05a4a', '#9f9f9f', '#e8c66a', '#bbbbbb'

-- what every fixed line means (everyone) and where its value comes from (admins)
local EXPLAIN = {
  level = 'Your level. The bar shows how far you are from the next one.',
  experience = 'Experience points. Killing monsters gives experience; enough of it raises your level.',
  xpRate = 'Experience you get compared with normal: 150%% is one and a half times as much.',
  xpBoost = 'Bonus experience charged with Experience Chargers (events shop). Type !expburst to turn it on or off; its time only runs while it is on.',
  health = 'Hit points. At 0 you die. Red when below 30%%.',
  mana = 'Mana pays for spells. Red when below 30%%.',
  soul = 'Soul points: some spells and runes cost soul. They come back over time while you are fed.',
  capacity = 'Weight you can still carry. Red when almost full.',
  speed = 'How fast you walk. Green when haste or equipment make you faster.',
  food = 'While there is food time left you regain health and mana. Eat to fill it. Red when almost empty.',
  stamina = 'Hours of hunting with full experience and loot. Under 14 hours you get less; it comes back while you are logged out.',
  magiclevel = 'Magic level: makes your spells and runes stronger. It rises as you spend mana.',
  skillId0 = 'Fist fighting: damage and hit chance without a weapon.',
  skillId1 = 'Club fighting: damage and hit chance with clubs, maces and hammers.',
  skillId2 = 'Sword fighting: damage and hit chance with swords.',
  skillId3 = 'Axe fighting: damage and hit chance with axes.',
  skillId4 = 'Distance fighting: damage and hit chance with bows, crossbows, spears and stars.',
  skillId5 = 'Shielding: how much a shield blocks.',
  skillId6 = 'Fishing: chance to catch a fish.',
}
local SOURCE = {
  level = 'Protocol (players.level).',
  experience = 'Protocol (players.experience).',
  xpRate = 'doPlayerSetRate(SKILL__LEVEL), set every minute by globalevents/scripts/boosts/experience_boost_timer.lua and at login (creaturescripts/scripts/player/login.lua): experience potion x1.5 (storage 14035 = end time), experience paper x1.25 (17004 = end time), Experience Boost (17039 on, 17041 type).',
  xpBoost = 'Storages 17040 (seconds left), 17041 (type: x5 %), 17039 (1 = on). Charged by actions/scripts/items/boosters/experience_charger.lua, turned on and off by !expburst (talkactions/scripts/player/expburst.lua, needs 17061).',
  health = 'Protocol. Boosters raise the maximum: storages 17005, 35049, 35055.',
  mana = 'Protocol. Boosters raise the maximum: storages 17006, 35050, 35055.',
  soul = 'Protocol (players.soul).',
  capacity = 'Protocol: free capacity (vocations.xml gaincap, items weight).',
  speed = 'Protocol: speed now (base speed from level, haste conditions, items speed).',
  food = 'Server: time left of the regeneration condition (CONDITION_REGENERATION).',
  stamina = 'Protocol (players.stamina).',
  magiclevel = 'Protocol: magic level (players.maglevel); equipment bonus from items.xml magiclevelpoints.',
  skillId0 = 'Protocol: player_skills (skill 0); equipment bonus from items.xml skillFist.',
  skillId1 = 'Protocol: player_skills (skill 1); equipment bonus from items.xml skillClub.',
  skillId2 = 'Protocol: player_skills (skill 2); equipment bonus from items.xml skillSword.',
  skillId3 = 'Protocol: player_skills (skill 3); equipment bonus from items.xml skillAxe.',
  skillId4 = 'Protocol: player_skills (skill 4); equipment bonus from items.xml skillDist.',
  skillId5 = 'Protocol: player_skills (skill 5); equipment bonus from items.xml skillShield.',
  skillId6 = 'Protocol: player_skills (skill 6); equipment bonus from items.xml skillFish.',
}

local function isAdmin()
  local store = modules.game_store
  return (store ~= nil and store.isAdmin ~= nil and store.isAdmin() == true) == true
end

function init()
  connect(LocalPlayer, {
    onExperienceChange = onExperienceChange,
    onLevelChange = onLevelChange,
    onHealthChange = onHealthChange,
    onManaChange = onManaChange,
    onSoulChange = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange,
    onTotalCapacityChange = onTotalCapacityChange,
    onStaminaChange = onStaminaChange,
    onSpeedChange = onSpeedChange,
    onBaseSpeedChange = onBaseSpeedChange,
    onMagicLevelChange = onMagicLevelChange,
    onBaseMagicLevelChange = onBaseMagicLevelChange,
    onSkillChange = onSkillChange,
    onBaseSkillChange = onBaseSkillChange,
    onInventoryChange = onInventoryChange
  })
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  ProtocolGame.registerExtendedOpcode(OPCODE_STATS, onStats)

  skillsButton = modules.client_topmenu.addRightGameToggleButton('skillsButton', tr('Skills'), '/images/topbuttons/skills', toggle, false, 1)
  skillsButton:setOn(true)
  skillsWindow = g_ui.loadUI('skills', modules.game_interface.getRightPanel())
  for id in pairs(EXPLAIN) do
    rows[id] = skillsWindow:recursiveGetChildById(id)
    rows[id]:setTooltip(tr(EXPLAIN[id]))
  end
  for id, title in pairs(SECTIONS) do
    sections[id] = skillsWindow:recursiveGetChildById(id)
    sections[id]:getChildById('title'):setText(tr(title))
  end

  refresh()
  showStats()
  skillsWindow:setup()
  if g_game.isOnline() then online() end
end

function terminate()
  disconnect(LocalPlayer, {
    onExperienceChange = onExperienceChange,
    onLevelChange = onLevelChange,
    onHealthChange = onHealthChange,
    onManaChange = onManaChange,
    onSoulChange = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange,
    onTotalCapacityChange = onTotalCapacityChange,
    onStaminaChange = onStaminaChange,
    onSpeedChange = onSpeedChange,
    onBaseSpeedChange = onBaseSpeedChange,
    onMagicLevelChange = onMagicLevelChange,
    onBaseMagicLevelChange = onBaseMagicLevelChange,
    onSkillChange = onSkillChange,
    onBaseSkillChange = onBaseSkillChange,
    onInventoryChange = onInventoryChange
  })
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  ProtocolGame.unregisterExtendedOpcode(OPCODE_STATS)
  offline()

  skillsWindow:destroy()
  skillsButton:destroy()
  rows, sections = {}, {}
end

-- the item sprites of the icons (the OTUI only names them); set once in game, when the sprites are loaded
function fillIcons(widget)
  for _, child in ipairs(widget:recursiveGetChildren()) do
    if child.itemId then
      child:setItemId(tonumber(child.itemId))
    end
  end
end

-- the admins' explanation sits on the number of the line (the line keeps the everyday one)
local function setSource(row, source)
  local value = row:getChildById('value')
  if adminShown and source then
    value:setPhantom(false)
    value:setTooltip(tr('Admin - where it comes from:') .. '\n' .. source)
  else
    value:setPhantom(true)
    value:removeTooltip()
  end
end

local function applyAdminTooltips()
  local admin = isAdmin()
  if admin == adminShown then return end
  adminShown = admin
  for id, row in pairs(rows) do
    setSource(row, SOURCE[id])
  end
  panelKeys = {} -- the lists are made again with or without the admin explanations
end

function expForLevel(level)
  return math.floor((50*level*level*level)/3 - 100*level*level + (850*level)/3 - 200)
end

function expToAdvance(currentLevel, currentExp)
  return expForLevel(currentLevel+1) - currentExp
end

function resetSkillColor(id)
  rows[id]:getChildById('value'):setColor(NORMAL)
end

function setSkillBase(id, value, baseValue)
  if baseValue <= 0 or value < 0 then
    return
  end
  local skill = rows[id]
  local widget = skill:getChildById('value')
  local explain = tr(EXPLAIN[id])

  if value > baseValue then
    widget:setColor('#008b00') -- green
    skill:setTooltip(explain .. '\n' .. tr('Yours: %d, +%d from equipment or spells', baseValue, value - baseValue))
  elseif value < baseValue then
    widget:setColor('#b22222') -- red
    skill:setTooltip(explain .. '\n' .. tr('Yours: %d, %d from conditions', baseValue, value - baseValue))
  else
    widget:setColor(NORMAL)
    skill:setTooltip(explain)
  end
end

function setSkillValue(id, value)
  rows[id]:getChildById('value'):setText(value)
end

function setSkillColor(id, value)
  rows[id]:getChildById('value'):setColor(value)
end

function setSkillPercent(id, percent, tooltip, color)
  local widget = rows[id]:getChildById('percent')
  if widget then
    widget:setPercent(math.floor(percent))

    if tooltip then
      widget:setTooltip(tooltip)
    end

    if color then
      widget:setBackgroundColor(color)
    end
  end
end

function checkAlert(id, value, maxValue, threshold, greaterThan)
  if greaterThan == nil then greaterThan = false end
  local alert = false

  -- maxValue can be set to false to check value and threshold
  if type(maxValue) == 'boolean' then
    if maxValue then
      return
    end

    if greaterThan then
      if value > threshold then
        alert = true
      end
    else
      if value < threshold then
        alert = true
      end
    end
  elseif type(maxValue) == 'number' then
    if maxValue < 0 then
      return
    end

    local percent = math.floor((value / maxValue) * 100)
    if greaterThan then
      if percent > threshold then
        alert = true
      end
    else
      if percent < threshold then
        alert = true
      end
    end
  end

  if alert then
    setSkillColor(id, '#b22222') -- red
  else
    resetSkillColor(id)
  end
end

function refresh()
  local player = g_game.getLocalPlayer()
  if not player then return end

  if expSpeedEvent then expSpeedEvent:cancel() end
  expSpeedEvent = cycleEvent(checkExpSpeed, 30*1000)

  onExperienceChange(player, player:getExperience())
  onLevelChange(player, player:getLevel(), player:getLevelPercent())
  onHealthChange(player, player:getHealth(), player:getMaxHealth())
  onManaChange(player, player:getMana(), player:getMaxMana())
  onSoulChange(player, player:getSoul())
  onFreeCapacityChange(player, player:getFreeCapacity())
  onStaminaChange(player, player:getStamina())
  onMagicLevelChange(player, player:getMagicLevel(), player:getMagicLevelPercent())
  onSpeedChange(player, player:getSpeed())

  for i = Skill.Fist, Skill.Fishing do
    onSkillChange(player, i, player:getSkillLevel(i), player:getSkillLevelPercent(i))
    onBaseSkillChange(player, i, player:getSkillBaseLevel(i))
  end

  skillsWindow:setContentMinimumHeight(44)
  skillsWindow:setContentMaximumHeight(1000)
end

-- the stats the server sends ------------------------------------------------------------------------------------------

local function sendStatsRequest()
  local protocol = g_game.getProtocolGame()
  if protocol and g_game.getFeature(GameExtendedOpcode) then
    protocol:sendExtendedOpcode(OPCODE_STATS, '')
  end
end

-- asks again every few seconds while the window is open (the timers count down in between)
local function pollStats()
  statsEvent = nil
  if not g_game.isOnline() then return end
  if skillsWindow:isVisible() then
    sendStatsRequest()
  end
  statsEvent = scheduleEvent(pollStats, STATS_INTERVAL)
end

function parseStats(buffer)
  local s = {absorb = {}, reflect = {}}
  for line in buffer:gmatch('[^\n]+') do
    local key, value = line:match('^(%w+)=(.*)$')
    if key == 'absorb' then
      local t, v = value:match('^(%d+),(%-?%d+)$')
      if t then s.absorb[tonumber(t)] = tonumber(v) end
    elseif key == 'reflect' then
      local t, p, c = value:match('^(%d+),(%-?%d+),(%d+)$')
      if t then s.reflect[tonumber(t)] = {percent = tonumber(p), chance = tonumber(c)} end
    elseif key == 'element' or key == 'critical' or key == 'increment' or key == 'regen' then
      local list = {}
      for v in value:gmatch('[^,]+') do table.insert(list, tonumber(v) or v) end
      s[key] = list
    elseif key == 'vocation' then
      s.vocation = value
    elseif key then
      s[key] = tonumber(value) or value
    end
  end
  return s
end

function onStats(protocol, opcode, buffer)
  stats = parseStats(buffer)
  statsTime = g_clock.seconds()
  removeEvent(retryEvent)
  retryEvent = nil
  if skillsWindow:isVisible() then
    showStats()
  end
end

local function clock(seconds)
  seconds = math.max(0, math.floor(seconds))
  local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
  if h > 0 then
    return string.format('%d:%02d:%02d', h, m, s)
  end
  return string.format('%02d:%02d', m, s)
end

local function days(seconds)
  local d = math.ceil(seconds / 86400)
  return d == 1 and tr('1 day') or tr('%d days', d)
end

-- a timer of the last answer, counted down to now
local function left(key)
  if not stats or not stats[key] then return 0 end
  return math.max(0, stats[key] - (g_clock.seconds() - statsTime))
end

local function percentText(v)
  return (v > 0 and '+' or '') .. v .. '%'
end

-- one line of a list: {key, name, value, color, tip (everyone), source (admins), item or image}
local function line(list, key, name, value, color, tip, source, item, image)
  table.insert(list, {key = key, name = name, value = value, color = color or NORMAL, tip = tip, source = source, item = item, image = image})
end

-- shows the lines of a list panel: the widgets are kept and only their texts change while the same lines are shown
local function fillPanel(panelId, list)
  local panel = skillsWindow:recursiveGetChildById(panelId)
  local keys = {}
  for i, l in ipairs(list) do keys[i] = l.key end
  local same = panelKeys[panelId] and table.concat(panelKeys[panelId], '|') == table.concat(keys, '|')
  if not same then
    panel:destroyChildren()
    for _, l in ipairs(list) do
      local row = g_ui.createWidget(l.image and 'SkillInfoRowImage' or 'SkillInfoRow', panel)
      if l.image then
        row.icon:setImageSource(l.image)
      elseif l.item then
        row.icon:setItemId(l.item)
      else
        row.icon:hide()
        row.icon:setWidth(0)
        row.name:setMarginLeft(0)
      end
      row.name:setText(l.name)
      if l.tip then row:setTooltip(l.tip) end
      setSource(row, l.source)
    end
    panelKeys[panelId] = keys
  end
  local children = panel:getChildren()
  for i, l in ipairs(list) do
    local row = children[i]
    row.value:setText(l.value)
    row.value:setColor(l.color)
    if same and l.tip then row:setTooltip(l.tip) end
  end
end

function showStats()
  applyAdminTooltips()

  -- experience rate and the experience modifiers
  local rate = stats and stats.rate
  setSkillValue('xpRate', rate and (rate .. '%') or '-')
  setSkillColor('xpRate', (rate and rate > 100) and GREEN or NORMAL)
  local sources = {}
  if left('potion') > 0 then table.insert(sources, tr('Experience potion: x1.5 for %s', clock(left('potion')))) end
  if left('paper') > 0 then table.insert(sources, tr('Experience paper: x1.25 for %s', clock(left('paper')))) end
  local boost = stats and stats.boost or 0
  rows.xpBoost:setVisible(boost > 0)
  if boost > 0 then
    local active = stats.boostactive == 1
    setSkillValue('xpBoost', '+' .. stats.boostpercent .. '%  ' .. clock(boost))
    setSkillColor('xpBoost', active and GREEN or GREY)
    rows.xpBoost:setTooltip(tr(EXPLAIN.xpBoost) .. '\n' .. (active and tr('On now: +%d%%, %s left.', stats.boostpercent, clock(boost))
      or tr('Off now: +%d%%, %s charged.', stats.boostpercent, clock(boost))))
    if active then table.insert(sources, tr('Experience Boost: +%d%%', stats.boostpercent)) end
  end
  rows.xpRate:setTooltip(tr(EXPLAIN.xpRate) .. '\n' .. (#sources > 0 and table.concat(sources, '\n') or tr('Nothing raises it now.')))

  local food = left('food')
  setSkillValue('food', stats and clock(food) or '-')
  setSkillColor('food', (stats and food < 60) and RED or NORMAL)

  local combat, protection, bonus = {}, {}, {}
  if not stats then
    line(combat, 'wait', tr('Waiting for the server...'), '', GREY, tr('The server sends these values a moment after you log in.'), nil, 112)
    fillPanel('combatPanel', combat)
    fillPanel('protectionPanel', protection)
    fillPanel('bonusPanel', bonus)
    sections.protectionSection:hide()
    sections.bonusSection:hide()
    return
  end

  -- combat: what the equipment gives
  line(combat, 'attack', tr('Attack Value'), tostring(stats.attack or 0), nil,
    tr('Attack of your weapon (and of its ammunition): the higher, the harder you hit.'),
    'Server: items.xml attack + extraattack of the weapon in your hands (and of the ammunition it fires).', 3278)
  if stats.element then
    local e = ELEMENT_BY_TYPE[stats.element[1]]
    if e then
      line(combat, 'element', '  ' .. tr(e.name) .. ' ' .. tr('damage'), '+' .. stats.element[2], GOLD,
        tr('Your weapon also deals %d %s damage with every hit.', stats.element[2], tr(e.name):lower()),
        'Server: items.xml element' .. e.name:gsub(' ', '') .. ' of the weapon.', e.item)
    end
  end
  line(combat, 'defense', tr('Defence Value'), tostring(stats.defense or 0), nil,
    tr('Defence of your shield (or of your weapon without one): blocks part of every melee hit.'),
    'Server: items.xml defense + extradef of your shield or weapon.', 3414)
  line(combat, 'armor', tr('Armor Value'), tostring(stats.armor or 0), nil,
    tr('Armor of everything you wear: takes away part of the physical damage you get.'),
    'Server: Player::getArmor, items.xml armor of what you wear (x vocations.xml armor multiplier).', 3366)
  -- the server's critical hit (weapons only, weapons.cpp) raises the maximum damage to the power of
  -- criticalHitMultiplier when random(1, 100) < criticalHitChance: with a multiplier of 1 it does nothing
  local critChance, critPower = stats.critical and (stats.critical[1] or 0) - 1 or 0, stats.critical and stats.critical[2] or 1
  if critChance > 0 and critPower > 1 then
    line(combat, 'crit', tr('Critical Hit Chance'), critChance .. '%', nil,
      tr('Chance that a weapon hit (not a spell) is a critical hit.'),
      'Server: config.lua criticalHitChance (the same for every player; the server checks random(1, 100) < it, so it is one less).', 3037)
    line(combat, 'critx', tr('Critical Damage'), '^' .. critPower, nil,
      tr('A critical hit raises your maximum damage to the power of %s: the stronger you hit, the more it adds.', critPower),
      'Server: config.lua criticalHitMultiplier (weapons.cpp: maxDamage ^ multiplier).', 3037)
  end
  local inc = stats.increment or {}
  if (inc[4] or 0) ~= 0 then line(combat, 'mdmgp', tr('Magic Damage'), percentText(inc[4]), GREEN, tr('Your equipment makes your attack spells and runes stronger.'), 'Server: items.xml increaseMagicPercent of what you wear.', 3071) end
  if (inc[3] or 0) ~= 0 then line(combat, 'mdmgv', tr('Magic Damage'), '+' .. inc[3], GREEN, tr('Your equipment adds damage to your attack spells and runes.'), 'Server: items.xml increaseMagicValue of what you wear.', 3071) end
  if (inc[2] or 0) ~= 0 then line(combat, 'healp', tr('Healing'), percentText(inc[2]), GREEN, tr('Your equipment makes your healing stronger.'), 'Server: items.xml increaseHealingPercent of what you wear.', 3160) end
  if (inc[1] or 0) ~= 0 then line(combat, 'healv', tr('Healing'), '+' .. inc[1], GREEN, tr('Your equipment adds to your healing.'), 'Server: items.xml increaseHealingValue of what you wear.', 3160) end
  local regen = stats.regen or {}
  line(combat, 'hpregen', tr('Health Regen.'), string.format('%.1f/s', (regen[1] or 0) / 10), nil,
    tr('Health you regain every second while you have food time.'),
    'Server: vocations.xml gainhpamount / gainhpticks + items.xml healthGain / healthTicks of what you wear.', 3052)
  line(combat, 'mpregen', tr('Mana Regen.'), string.format('%.1f/s', (regen[2] or 0) / 10), nil,
    tr('Mana you regain every second while you have food time.'),
    'Server: vocations.xml gainmanaamount / gainmanaticks + items.xml manaGain / manaTicks of what you wear.', 3098)

  -- protections (equipment and vocation) and reflection
  for _, e in ipairs(ELEMENTS) do
    local v = stats.absorb[e.type]
    if v and v ~= 0 then
      line(protection, 'abs' .. e.type, tr(e.name), percentText(v), v > 0 and GREEN or RED,
        v > 0 and tr('You take %d%% less %s damage.', v, tr(e.name):lower()) or tr('You take %d%% more %s damage.', -v, tr(e.name):lower()),
        'Server: items.xml absorbPercent' .. e.name:gsub(' ', '') .. ' (or absorbPercentAll) of what you wear + vocations.xml absorb.', e.item)
    end
  end
  for _, e in ipairs(ELEMENTS) do
    local r = stats.reflect[e.type]
    if r then
      line(protection, 'ref' .. e.type, tr('Reflect') .. ' ' .. tr(e.name), r.percent .. '% (' .. r.chance .. '%)', GOLD,
        tr('%d%% chance to send %d%% of the %s damage back to the attacker.', r.chance, r.percent, tr(e.name):lower()),
        'Server: items.xml reflectPercent' .. e.name:gsub(' ', '') .. ' / reflectChance' .. e.name:gsub(' ', '') .. ' of what you wear.', e.item)
    end
  end
  if #protection == 0 then
    line(protection, 'none', tr('Protection'), tr('none'), GREY, tr('Equipment that protects you from damage shows here.'),
      'Server: absorbPercent* and reflect* of the worn items (none now).', 3084)
  end
  sections.protectionSection:show()
  sections.bonusSection:show()

  -- the character's bonuses
  local vip = left('vip')
  line(bonus, 'vip', tr('VIP'), vip > 0 and days(vip) or tr('No'), vip > 0 and GREEN or GREY,
    vip > 0 and tr('VIP for %s more: VIP areas and doors, !vipstatus. A VIP Medal adds 15 days.', days(vip))
      or tr('Not VIP. A VIP Medal gives 15 days of VIP: VIP areas and doors.'),
    'Storage 11552 = time the VIP ends (data/lib/101-vip.lua). VIP Medal: actions/scripts/items/vip/vip_medal.lua (+15 days).', 5785)
  line(bonus, 'svip', tr('Super VIP'), stats.supervip == 1 and tr('Forever') or tr('No'), stats.supervip == 1 and GOLD or GREY,
    stats.supervip == 1 and tr('Super VIP for ever.') or tr('Not Super VIP. The Super VIP Medal gives it for ever (you must be VIP to use it).'),
    'Storage 17009 = 1. Super VIP Medal: actions/scripts/items/vip/super_vip.lua.', 9218)
  if stats.viptp == 1 then
    line(bonus, 'viptp', tr('VIP Teleport'), tr('Yes'), GREEN, tr('You can use !viptp.'),
      'Storage 17016 = 1. VIP Scroll: actions/scripts/items/vip/vip_scroll.lua.', 5957)
  end
  if (stats.premium or 0) > 0 then
    local unlimited = stats.premium >= 65535 -- the server's way of saying premium for ever (free premium)
    line(bonus, 'prem', tr('Premium'), unlimited and tr('Unlimited') or days(stats.premium * 86400), GREEN,
      unlimited and tr('Your account is premium for ever.') or tr('Premium days left on your account.'),
      'Account: accounts.premdays (65535 = for ever, or config.lua freePremium).', 3011)
  end
  line(bonus, 'burst', tr('Exp Burst'), stats.expburst == 1 and tr('Unlocked') or tr('Locked'), stats.expburst == 1 and GREEN or GREY,
    stats.expburst == 1 and tr('Type !expburst to turn your Experience Boost on and off.') or tr('Finish the !expburst quest to be able to turn on your Experience Boost.'),
    'Storage 17061 = 1 (the !expburst quest). Command: talkactions/scripts/player/expburst.lua.', 138)
  if (stats.healthbooster or 0) > 0 then
    line(bonus, 'hpboost', tr('Health Boosters'), '+' .. comma_value(stats.healthbooster), GREEN, tr('Hit points the boosters you used added for good.'),
      'Storages 17005 (+50,000 each, up to 3), 35049 (+150,000 scroll), 35055 (+150,000 Ozzo scroll): actions/scripts/items/boosters/.', 236)
  end
  if (stats.manabooster or 0) > 0 then
    line(bonus, 'mpboost', tr('Mana Boosters'), '+' .. comma_value(stats.manabooster), GREEN, tr('Mana the boosters you used added for good.'),
      'Storages 17006 (+50,000 each, up to 3), 35050 (+150,000 scroll), 35055 (+150,000 Ozzo scroll): actions/scripts/items/boosters/.', 238)
  end
  if stats.blockorb == 1 then line(bonus, 'block', tr('Block Orb'), tr('On'), GREEN, tr('Your Block Orb is protecting you.'), 'Storage 17025 = 1 (reset to 0 at login).', 3084) end
  if stats.reflectorb == 1 then line(bonus, 'reflect', tr('Reflect Orb'), tr('On'), GREEN, tr('Your Reflect Orb sends damage back.'), 'Storage 17027 = 1 (reset to 0 at login).', 3014) end
  line(bonus, 'bank', tr('Bank'), comma_value(stats.bank or 0) .. ' gp', nil, tr('Gold in your bank account. Bankers keep it for you.'), 'Player: players.balance.', 3043)

  fillPanel('combatPanel', combat)
  fillPanel('protectionPanel', protection)
  fillPanel('bonusPanel', bonus)
end

-- counts the timers down every second, and asks again when the equipment changes
local function tick()
  tickEvent = scheduleEvent(tick, 1000)
  if skillsWindow:isVisible() and isAdmin() ~= adminShown then
    showStats() -- the Store found out (or forgot) that this account is an admin
  end
  if stats and skillsWindow:isVisible() then
    local food = left('food')
    setSkillValue('food', clock(food))
    setSkillColor('food', food < 60 and RED or NORMAL)
    if (stats.boost or 0) > 0 then setSkillValue('xpBoost', '+' .. stats.boostpercent .. '%  ' .. clock(stats.boost)) end
  end
end

function onInventoryChange()
  removeEvent(inventoryEvent)
  inventoryEvent = scheduleEvent(sendStatsRequest, 300)
end

function online()
  fillIcons(skillsWindow)
  refresh()
  stats = nil
  adminShown = nil
  panelKeys = {}
  showStats()
  removeEvent(statsEvent)
  removeEvent(tickEvent)
  removeEvent(retryEvent)
  -- ask as soon as the server takes extended opcodes (it says so right after the login), again in a moment if it did
  -- not answer yet, then every few seconds while the window is open
  retryEvent = scheduleEvent(function()
    sendStatsRequest()
    retryEvent = scheduleEvent(function() retryEvent = nil if not stats then sendStatsRequest() end end, 1000)
  end, 400)
  statsEvent = scheduleEvent(pollStats, STATS_INTERVAL)
  tickEvent = scheduleEvent(tick, 1000)
end

function offline()
  if expSpeedEvent then expSpeedEvent:cancel() expSpeedEvent = nil end
  removeEvent(statsEvent)
  removeEvent(tickEvent)
  removeEvent(inventoryEvent)
  removeEvent(retryEvent)
  statsEvent, tickEvent, inventoryEvent, retryEvent = nil, nil, nil, nil
  stats = nil
end

function toggle()
  if skillsButton:isOn() then
    skillsWindow:close()
    skillsButton:setOn(false)
  else
    skillsWindow:open()
    skillsButton:setOn(true)
    showStats()
    sendStatsRequest()
  end
end

function checkExpSpeed()
  local player = g_game.getLocalPlayer()
  if not player then return end

  local currentExp = player:getExperience()
  local currentTime = g_clock.seconds()
  if player.lastExps ~= nil then
    player.expSpeed = (currentExp - player.lastExps[1][1])/(currentTime - player.lastExps[1][2])
    onLevelChange(player, player:getLevel(), player:getLevelPercent())
  else
    player.lastExps = {}
  end
  table.insert(player.lastExps, {currentExp, currentTime})
  if #player.lastExps > 30 then
    table.remove(player.lastExps, 1)
  end
end

function onMiniWindowClose()
  skillsButton:setOn(false)
end

function onSkillButtonClick(button)
  local percentBar = button:getChildById('percent')
  if percentBar then
    percentBar:setVisible(not percentBar:isVisible())
    if percentBar:isVisible() then
      button:setHeight(21)
    else
      button:setHeight(21 - 6)
    end
  end
end

function onExperienceChange(localPlayer, value)
  local postFix = ""
  if value > 1e15 then
    postFix = "B"
    value = math.floor(value / 1e9)
  elseif value > 1e12 then
    postFix = "M"
    value = math.floor(value / 1e6)
  elseif value > 1e9 then
    postFix = "K"
    value = math.floor(value / 1e3)
  end
  setSkillValue('experience', comma_value(value) .. postFix)
end

function onLevelChange(localPlayer, value, percent)
  setSkillValue('level', value)
  local text = tr('You have %s percent to go', 100 - percent) .. '\n' ..
               comma_value(expToAdvance(localPlayer:getLevel(), localPlayer:getExperience())) .. tr(' of experience left')

  if localPlayer.expSpeed ~= nil then
     local expPerHour = math.floor(localPlayer.expSpeed * 3600)
     if expPerHour > 0 then
        local nextLevelExp = expForLevel(localPlayer:getLevel()+1)
        local hoursLeft = (nextLevelExp - localPlayer:getExperience()) / expPerHour
        local minutesLeft = math.floor((hoursLeft - math.floor(hoursLeft))*60)
        hoursLeft = math.floor(hoursLeft)
        text = text .. '\n' .. comma_value(expPerHour) .. ' of experience per hour'
        text = text .. '\n' .. tr('Next level in %d hours and %d minutes', hoursLeft, minutesLeft)
     end
  end

  setSkillPercent('level', percent, text)
end

function onHealthChange(localPlayer, health, maxHealth)
  setSkillValue('health', comma_value(health))
  checkAlert('health', health, maxHealth, 30)
end

function onManaChange(localPlayer, mana, maxMana)
  setSkillValue('mana', comma_value(mana))
  checkAlert('mana', mana, maxMana, 30)
end

function onSoulChange(localPlayer, soul)
  setSkillValue('soul', soul)
end

function onFreeCapacityChange(localPlayer, freeCapacity)
  setSkillValue('capacity', formatCapacity(freeCapacity))
  checkAlert('capacity', freeCapacity, localPlayer:getTotalCapacity(), 20)
end

function onTotalCapacityChange(localPlayer, totalCapacity)
  checkAlert('capacity', localPlayer:getFreeCapacity(), totalCapacity, 20)
end

function onStaminaChange(localPlayer, stamina)
  local hours = math.floor(stamina / 60)
  local minutes = stamina % 60
  if minutes < 10 then
    minutes = '0' .. minutes
  end
  local percent = math.floor(100 * stamina / (42 * 60)) -- max is 42 hours

  setSkillValue('stamina', hours .. ":" .. minutes)

  if stamina > 2400 then
    local text = tr("You have %s hours and %s minutes left", hours, minutes) .. '\n' ..
      tr("If you are premium player, you will gain 50%% more experience")
    setSkillPercent('stamina', percent, text, 'green')
  elseif stamina <= 2400 and stamina > 840 then
    setSkillPercent('stamina', percent, tr("You have %s hours and %s minutes left", hours, minutes), 'orange')
  elseif stamina <= 840 and stamina > 0 then
    local text = tr("You have %s hours and %s minutes left", hours, minutes) .. "\n" ..
      tr("You gain only 50%% experience and you don't may gain loot from monsters")
    setSkillPercent('stamina', percent, text, 'red')
  elseif stamina == 0 then
    local text = tr("You have %s hours and %s minutes left", hours, minutes) .. "\n" ..
      tr("You don't may receive experience and loot from monsters")
    setSkillPercent('stamina', percent, text, 'black')
  end
end

function onSpeedChange(localPlayer, speed)
  setSkillValue('speed', speed)

  onBaseSpeedChange(localPlayer, localPlayer:getBaseSpeed())
end

function onBaseSpeedChange(localPlayer, baseSpeed)
  setSkillBase('speed', localPlayer:getSpeed(), baseSpeed)
end

function onMagicLevelChange(localPlayer, magiclevel, percent)
  setSkillValue('magiclevel', magiclevel)
  setSkillPercent('magiclevel', percent, tr('You have %s percent to go', 100 - percent))

  onBaseMagicLevelChange(localPlayer, localPlayer:getBaseMagicLevel())
end

function onBaseMagicLevelChange(localPlayer, baseMagicLevel)
  setSkillBase('magiclevel', localPlayer:getMagicLevel(), baseMagicLevel)
end

function onSkillChange(localPlayer, id, level, percent)
  if id > Skill.Fishing then return end
  setSkillValue('skillId' .. id, level)
  setSkillPercent('skillId' .. id, percent, tr('You have %s percent to go', 100 - percent))

  onBaseSkillChange(localPlayer, id, localPlayer:getSkillBaseLevel(id))
end

function onBaseSkillChange(localPlayer, id, baseLevel)
  if id > Skill.Fishing then return end
  setSkillBase('skillId'..id, localPlayer:getSkillLevel(id), baseLevel)
end
