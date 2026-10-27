-- The Spells window: only the spells of the character's vocation, grouped and sorted by level, with filters (attack,
-- healing, support, runes, what the character can already cast, a search). Clicking a spell shows its details and
-- plays a demo of it (spelldemo.lua).
--
-- The old protocol does not tell the client the vocation or the spells a character learned, so the website API does
-- (action "spells", the same call the action bars make). Until it answers, or when it cannot be reached, every spell
-- is listed.

local SPELLS_API = Services.website .. "/index.php/api/store"
local VOCATIONS = {'Sorcerer', 'Druid', 'Paladin', 'Knight'}
local CATEGORIES = {
  {id = 'all', text = 'All'},
  {id = 'attack', text = 'Attack', group = 1},
  {id = 'healing', text = 'Healing', group = 2},
  {id = 'support', text = 'Support', group = 3},
  {id = 'runes', text = 'Runes'},
}
-- the level groups of the list
local BRACKETS = {
  {0, 'Level 1 to 19'}, {20, 'Level 20 to 49'}, {50, 'Level 50 to 99'}, {100, 'Level 100 to 999'},
  {1000, 'Level 1,000 to 9,999'}, {10000, 'Level 10,000 to 29,999'}, {30000, 'Level 30,000 to 59,999'},
  {60000, 'Level 60,000 and up'},
}

spelllistWindow = nil
spelllistButton = nil
local spellList, details, demoPlayer
local categoryButtons = {}
local state = {category = 'all', castableOnly = false, search = '', character = nil, info = nil, selected = nil}

local function normalize(name)
  return name:lower():gsub('[^a-z0-9]', '')
end

local function thousands(n)
  local s = tostring(n)
  while true do
    local done
    s, done = s:gsub('^(%d+)(%d%d%d)', '%1,%2')
    if done == 0 then return s end
  end
end

-- the vocations a spell must list to be one of the character's: the base vocation and, when promoted, the promoted one
local function characterVocations()
  local info = state.info
  if not info or info.vocation < 1 then return nil end
  local list = {info.vocation, info.vocation + 4}
  return list
end

local function spellFits(spell)
  local vocations = characterVocations()
  if not vocations then return true end
  for _, v in ipairs(vocations) do
    if table.find(spell.vocations, v) then return true end
  end
  return false
end

-- why the character cannot cast the spell yet (nil when it can)
local function blockedReason(spell)
  local player = g_game.getLocalPlayer()
  if not player then return nil end
  if spell.level > player:getLevel() then
    return tr('Needs level %s', thousands(spell.level))
  end
  if (spell.maglevel or 0) > player:getMagicLevel() then
    return tr('Needs magic level %d', spell.maglevel)
  end
  local info = state.info
  if info and info.promotion < 1 and not table.find(spell.vocations, info.vocation) then
    return tr('Needs a promotion')
  end
  if spell.needlearn and info and not info.learned[normalize(spell.name)] then
    return tr('Must be learned first')
  end
  return nil
end

local function inCategory(spell)
  local category = state.category
  if category == 'all' then return true end
  if category == 'runes' then return spell.type == 'Rune' end
  for _, c in ipairs(CATEGORIES) do
    if c.id == category then return spell.group[c.group] ~= nil end
  end
  return true
end

local function matchesSearch(spell)
  if state.search == '' then return true end
  local s = state.search:lower()
  return spell.name:lower():find(s, 1, true) or spell.words:lower():find(s, 1, true)
end

local function iconClip(spell)
  local id = tonumber(spell.icon) or (SpellIcons[spell.icon] and SpellIcons[spell.icon][1]) or 1
  return Spells.getImageClip(id, 'Default')
end

local function spellsToShow()
  local list = {}
  for name, data in pairs(SpellInfo['Default']) do
    local spell = {name = name}
    for k, v in pairs(data) do spell[k] = v end
    if spellFits(spell) and inCategory(spell) and matchesSearch(spell) then
      spell.blocked = blockedReason(spell)
      if not (state.castableOnly and spell.blocked) then
        table.insert(list, spell)
      end
    end
  end
  table.sort(list, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if (a.maglevel or 0) ~= (b.maglevel or 0) then return (a.maglevel or 0) < (b.maglevel or 0) end
    return a.name < b.name
  end)
  return list
end

local function bracketOf(level)
  local found = BRACKETS[1][2]
  for _, b in ipairs(BRACKETS) do
    if level >= b[1] then found = b[2] end
  end
  return found
end

local function updateVocationLabel()
  local label = spelllistWindow:getChildById('vocationLabel')
  local info = state.info
  if info and info.vocation >= 1 then
    local name = VOCATIONS[info.vocation]
    local promoted = info.promotion > 0 and VocationNames[info.vocation + 4] or name
    label:setText(tr('Spells of a %s', promoted))
  elseif state.asked then
    label:setText(tr('Every vocation (yours could not be checked)'))
  else
    label:setText(tr('Checking your vocation...'))
  end
end

function refresh()
  if not spelllistWindow then return end
  local keep = state.selected
  spellList:destroyChildren()
  local first, focused
  local bracket
  for _, spell in ipairs(spellsToShow()) do
    local b = bracketOf(spell.level)
    if b ~= bracket then
      bracket = b
      local header = g_ui.createWidget('SpellGroupHeader', spellList)
      header:setText(tr(b))
    end
    local row = g_ui.createWidget('SpellRow', spellList)
    row.spell = spell
    row.icon:setImageClip(iconClip(spell))
    row.name:setText(spell.name)
    row.words:setText(spell.words)
    row.level:setText(tr('Lv %s', thousands(spell.level)))
    if spell.blocked then
      row:setOpacity(0.5)
      row:setTooltip(spell.blocked)
    end
    first = first or row
    if keep and spell.name == keep then focused = row end
  end
  spelllistWindow:getChildById('emptyLabel'):setVisible(first == nil)
  updateVocationLabel()
  local target = focused or first
  if target then
    spellList:focusChild(target, KeyboardFocusReason)
    spellList:ensureChildVisible(target)
  else
    showSpell(nil)
  end
end

local function infoRow(key, value)
  local row = g_ui.createWidget('SpellInfoRow', details.info)
  row.key:setText(key)
  row.value:setText(value)
end

function showSpell(spell)
  state.selected = spell and spell.name or nil
  details.info:destroyChildren()
  if not spell then
    details.icon:hide()
    details.name:setText('')
    details.words:setText('')
    demoPlayer:stop()
    spelllistWindow:recursiveGetChildById('demoHint'):show()
    return
  end
  details.icon:show()
  details.icon:setImageClip(iconClip(spell))
  details.name:setText(spell.name)
  details.words:setText('"' .. spell.words .. '"')

  local groups = {}
  for id, name in ipairs(SpellGroups) do
    if spell.group[id] then table.insert(groups, tr(name)) end
  end
  local level = thousands(spell.level)
  if (spell.maglevel or 0) > 0 then
    level = level .. '  ' .. tr('(magic level %d)', spell.maglevel)
  end
  infoRow(tr('Level') .. ':', level)
  infoRow(tr('Kind') .. ':', table.concat(groups, ', ') .. (spell.type == 'Rune' and (' ' .. tr('rune')) or ''))
  infoRow(tr('Mana') .. ':', spell.mana > 0 and thousands(spell.mana) or '-')
  infoRow(tr('Cooldown') .. ':', (spell.exhaustion / 1000) .. 's' .. (spell.blocked and ('   ' .. spell.blocked) or ''))

  spelllistWindow:recursiveGetChildById('demoHint'):hide()
  demoPlayer:play(SpellDemos[spell.name])
end

function replay()
  local row = spellList:getFocusedChild()
  if row and row.spell then showSpell(row.spell) end
end

function setCategory(id)
  state.category = id
  for cid, button in pairs(categoryButtons) do
    button:setOn(cid == id)
  end
  refresh()
end

function setCastableOnly(checked)
  state.castableOnly = checked
  refresh()
end

function setSearch(text)
  state.search = text or ''
  refresh()
end

-- asks the website which vocation the character has and which spells it learned (once per character)
local function askVocation()
  local player = g_game.getLocalPlayer()
  local character = player and player:getName() or ''
  if state.character == character and (state.info or state.asking) then return end
  state.character, state.info, state.asking, state.asked = character, nil, true, false
  local body = {action = 'spells', character = character, account = G.account, password = G.password}
  HTTP.postJSON(SPELLS_API, body, function(data, err)
    if state.character ~= character then return end
    state.asking, state.asked = false, true
    if type(data) == 'table' and data.ok then
      local learned = {}
      for _, name in ipairs(data.learned or {}) do
        learned[normalize(name)] = true
      end
      state.info = {vocation = tonumber(data.vocation) or 0, promotion = tonumber(data.promotion) or 0, learned = learned}
    end
    if spelllistWindow:isVisible() then refresh() end
  end)
end

function online()
  spelllistButton:show()
  state.character, state.info, state.asking, state.asked = nil, nil, false, false
end

function offline()
  if spelllistWindow:isVisible() then toggle() end
  demoPlayer:stop()
end

function init()
  connect(g_game, {onGameStart = online, onGameEnd = offline})

  spelllistWindow = g_ui.displayUI('spelllist', modules.game_interface.getRightPanel())
  spelllistWindow:hide()
  spelllistButton = modules.client_topmenu.addRightGameToggleButton('spelllistButton', tr('Spells'), '/images/topbuttons/spelllist', toggle, false, 4)
  spelllistButton:setOn(false)

  spellList = spelllistWindow:getChildById('spellList')
  details = spelllistWindow:getChildById('details')
  demoPlayer = SpellDemoPlayer.create(details.demo)

  local bar = spelllistWindow:getChildById('categories')
  for _, c in ipairs(CATEGORIES) do
    local button = g_ui.createWidget('SpellCategoryButton', bar)
    button:setText(tr(c.text))
    button.onClick = function() setCategory(c.id) end
    categoryButtons[c.id] = button
  end
  categoryButtons[state.category]:setOn(true)

  connect(spellList, {onChildFocusChange = function(_, focused)
    if focused and focused.spell then showSpell(focused.spell) end
  end})
  g_keyboard.bindKeyPress('Down', function() spellList:focusNextChild(KeyboardFocusReason) end, spelllistWindow)
  g_keyboard.bindKeyPress('Up', function() spellList:focusPreviousChild(KeyboardFocusReason) end, spelllistWindow)

  if g_game.isOnline() then online() end
end

function terminate()
  disconnect(g_game, {onGameStart = online, onGameEnd = offline})
  demoPlayer:stop()
  spelllistWindow:destroy()
  spelllistButton:destroy()
end

function toggle()
  if spelllistWindow:isVisible() then
    spelllistButton:setOn(false)
    demoPlayer:stop()
    spelllistWindow:hide()
  else
    spelllistButton:setOn(true)
    spelllistWindow:show()
    spelllistWindow:raise()
    spelllistWindow:focus()
    askVocation()
    refresh()
  end
end
