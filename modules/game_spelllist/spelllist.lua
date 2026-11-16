-- The Spells window: only the spells of the character's vocation, grouped and sorted by level, with filters (attack,
-- healing, support, what the character can already cast, a search). Runes are not listed (they are items). Clicking a spell
-- shows its card (level, mana, cooldown, element, area, waves, the damage it does now and the level where it stops
-- growing) and plays a demo of it: the vocations' area spells play their real design (spelldemodesign.lua, the same one
-- game_spellfx draws in the game), the others the demos of tools/gen_spell_demos.py (spelldemo.lua). It opens from an
-- action bar slot (right click, Assign Spell) and with the !spells command; any spell of the list can be dragged onto any
-- slot, or be assigned to the slot it was opened from.
--
-- The server tells the window the character's vocation and the damage of its spells (extended opcode 41, data/lib/
-- 142-spell-window.lua): the client asks "get" when the window opens and the server answers
--   V|<base vocation 1-4>|<promotion 0-2>       the character
--   D|<spell name>|<average damage of a cast to one target>
--   H|<spell name>|<average heal>
--   E                                            the end
-- and !spells sends "O" first, which opens the window. Without that answer (an older server) the website API is asked
-- for the vocation (action "spells", the same call the action bars make); without either every spell is listed.
--
-- The list itself is kept on the server, like the Store: the admins add, edit and delete spells in this window
-- (web API actions admin_spell_*, table client_spells) and every client applies those changes over the list built
-- into it (gamelib/spells.lua) when the character logs in. A deleted spell is only hidden: action bar slots that
-- hold it keep working.

local SPELLS_API = Services.website .. "/index.php/api/store"
local SPELLS_OPCODE = 41
local MAX_MESSAGE = 16384
local VOCATIONS = {'Sorcerer', 'Druid', 'Paladin', 'Knight'}
local CATEGORIES = {
  {id = 'all', text = 'All'},
  {id = 'attack', text = 'Attack', group = 1},
  {id = 'healing', text = 'Healing', group = 2},
  {id = 'support', text = 'Support', group = 3},
}
-- the level groups of the list
local BRACKETS = {
  {0, 'Level 1 to 499'}, {500, 'Level 500 to 999'}, {1000, 'Level 1,000 to 9,999'}, {10000, 'Level 10,000 to 29,999'},
  {30000, 'Level 30,000 to 59,999'}, {60000, 'Level 60,000 to 89,999'}, {90000, 'Level 90,000 and up'},
}
local ELEMENTS = {
  fire = {'Fire', '#ff8a4a'}, ice = {'Ice', '#8fd8ff'}, energy = {'Energy', '#c79bff'}, earth = {'Earth', '#86d66a'},
  death = {'Death', '#d06ad8'}, holy = {'Holy', '#ffe27a'}, physical = {'Physical', '#d8d8d8'},
  wind = {'Wind (ice)', '#a8f0dc'},
}
local KIND_COLORS = {[1] = '#ff9a7a', [2] = '#8fd48f', [3] = '#9cc4ff'}
local READY_COLOR, LEVEL_COLOR, BLOCKED_COLOR = '#8fd48f', '#e8b04a', '#e06a5a'
-- spells added by the admins get ids far after the built-in ones (ids are saved in action bar slots)
local ADDED_SPELL_IDS = 10000

spelllistWindow = nil
local spellList, demoPlayer, dragIcon
local categoryButtons = {}
local state = {category = 'all', castableOnly = false, search = '', character = nil, info = nil, selected = nil,
               admin = false, showDeleted = false, editor = nil, builtIn = nil, slot = nil,
               server = nil, incoming = nil}

local function normalize(name)
  return tostring(name):lower():gsub('[^a-z0-9]', '')
end

local function thousands(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  while true do
    local done
    s, done = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    if done == 0 then return s end
  end
end

local function call(body, cb)
  body.account = G.account
  body.password = G.password
  HTTP.postJSON(SPELLS_API, body, function(data, err)
    if type(data) ~= 'table' or not data.ok then
      cb(nil, type(data) == 'table' and data.error or tostring(err or 'no answer'))
    else
      cb(data)
    end
  end)
end

local function windowInfo(spell)
  return type(SpellWindowInfo) == 'table' and spell and SpellWindowInfo[spell.name] or nil
end

-- the server's changes to the list ------------------------------------------------------------------------------------

-- one spell as the admins set it, over the built-in spell of the same name (or a new spell)
local function applyEdit(spell, d)
  spell.title = (d.name and d.name ~= spell.name) and d.name or nil
  spell.words = d.words or spell.words
  spell.level = tonumber(d.level) or spell.level
  spell.maglevel = tonumber(d.maglevel) or spell.maglevel
  spell.mana = tonumber(d.mana) or spell.mana
  spell.soul = tonumber(d.soul) or spell.soul
  spell.exhaustion = tonumber(d.exhaustion) or spell.exhaustion
  spell.type = d.type or spell.type
  spell.icon = d.icon or spell.icon
  spell.premium = d.premium == true
  spell.needlearn = d.needlearn == true or nil
  spell.demo = (d.demo and d.demo ~= '') and d.demo or nil
  if type(d.groups) == 'table' then
    spell.group = {}
    for _, g in ipairs(d.groups) do spell.group[tonumber(g)] = spell.exhaustion end
  end
  if type(d.vocations) == 'table' then
    spell.vocations = {}
    for _, v in ipairs(d.vocations) do table.insert(spell.vocations, tonumber(v)) end
  end
end

-- rebuilds the global list (SpellInfo, used by this window and by Assign Spell) from the built-in one and the rows
-- of the server; the table is refilled in place so every module keeps its reference
local function applyServerList(rows)
  local list = SpellInfo['Default']
  if not state.builtIn then
    state.builtIn = table.recursivecopy(list)
  end
  for name in pairs(list) do list[name] = nil end
  for name, spell in pairs(state.builtIn) do list[name] = table.recursivecopy(spell) end
  for _, row in ipairs(rows or {}) do
    local key = row.key
    local spell = list[key]
    if not spell and row.data then
      spell = {id = ADDED_SPELL_IDS + (tonumber(row.id) or 0), words = '', exhaustion = 1000, premium = false,
               type = 'Instant', icon = 'energybeam', mana = 0, level = 0, maglevel = 0, soul = 0,
               group = {[1] = 1000}, vocations = {}, added = true}
      list[key] = spell
    end
    if spell then
      spell.name = key
      if row.data then applyEdit(spell, row.data) end
      spell.edited = true
      spell.hidden = row.deleted == true or nil
    end
  end
end

-- asks the server for the admins' changes (and whether this account is one of them), then redraws the window
function fetchServerList(after)
  call({action = 'spell_list'}, function(data)
    if data then
      applyServerList(data.spells)
      state.admin = data.admin == true
    end
    if spelllistWindow then
      -- the admins' buttons take the place of the drag hint
      spelllistWindow:getChildById('adminBar'):setVisible(state.admin)
      spelllistWindow:getChildById('dragIcon'):setVisible(not state.admin)
      spelllistWindow:getChildById('dragHint'):setVisible(not state.admin)
    end
    if after then after() end
  end)
end

-- the character's vocation ----------------------------------------------------------------------------------------------

-- the vocation the window lists: the game server's answer first, then the website's
local function vocationInfo()
  local info = state.server or state.info
  if info and (tonumber(info.vocation) or 0) >= 1 and info.vocation <= 4 then
    return info
  end
  return nil
end

-- the vocations a spell must list to be one of the character's: the base vocation and its promotions
local function characterVocations()
  local info = vocationInfo()
  if not info then return nil end
  return {info.vocation, info.vocation + 4, info.vocation + 8}
end

local function spellFits(spell)
  local vocations = characterVocations()
  if not vocations then return true end
  for _, v in ipairs(vocations) do
    if table.find(spell.vocations, v) then return true end
  end
  return false
end

local function playerLevel()
  local player = g_game.getLocalPlayer()
  local ok, level = pcall(function() return player and player:getLevel() end)
  return ok and tonumber(level) or nil
end

local function playerMagicLevel()
  local player = g_game.getLocalPlayer()
  local ok, level = pcall(function() return player and player:getMagicLevel() end)
  return ok and tonumber(level) or nil
end

-- why the character cannot cast the spell yet (nil when it can) and what kind of reason it is ('level' or 'other')
local function blockedReason(spell)
  local level = playerLevel()
  if not level then return nil end
  if spell.level > level then
    return tr('Needs level %s', thousands(spell.level)), 'level'
  end
  local magic = playerMagicLevel()
  if magic and (spell.maglevel or 0) > magic then
    return tr('Needs magic level %d', spell.maglevel), 'level'
  end
  local info = vocationInfo()
  if info and not spellFits(spell) then
    return tr('Not for a %s', VOCATIONS[info.vocation] or tr('your vocation')), 'other'
  end
  local learned = state.info and state.info.learned
  if spell.needlearn and learned and not learned[normalize(spell.name)] then
    return tr('Must be learned first'), 'other'
  end
  return nil
end

local function inCategory(spell, category)
  category = category or state.category
  if category == 'all' then return true end
  for _, c in ipairs(CATEGORIES) do
    if c.id == category then return spell.group[c.group] ~= nil end
  end
  return true
end

local function titleOf(spell)
  return spell.title or spell.name
end

local function matchesSearch(spell)
  if state.search == '' then return true end
  local s = state.search:lower()
  return titleOf(spell):lower():find(s, 1, true) or spell.words:lower():find(s, 1, true)
end

local function iconId(icon)
  return tonumber(icon) or (SpellIcons[icon] and SpellIcons[icon][1]) or 1
end

local function iconClip(spell)
  return Spells.getImageClip(iconId(spell.icon), 'Default')
end

-- every spell the window may list for this character (its vocation's, not hidden, no runes), whatever the filters
local function ownSpells()
  local list = {}
  for name, data in pairs(SpellInfo['Default']) do
    local spell = {name = name}
    for k, v in pairs(data) do spell[k] = v end
    spell.name = name
    local visible = (not spell.hidden or (state.admin and state.showDeleted)) and spell.type ~= 'Rune'
    if visible and spellFits(spell) then
      spell.blocked, spell.blockedKind = blockedReason(spell)
      table.insert(list, spell)
    end
  end
  table.sort(list, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if (a.maglevel or 0) ~= (b.maglevel or 0) then return (a.maglevel or 0) < (b.maglevel or 0) end
    return titleOf(a) < titleOf(b)
  end)
  return list
end

local function spellsToShow(own)
  local list = {}
  for _, spell in ipairs(own) do
    if inCategory(spell) and matchesSearch(spell) and not (state.castableOnly and spell.blocked) then
      table.insert(list, spell)
    end
  end
  return list
end

local function bracketOf(level)
  local found = BRACKETS[1][2]
  for _, b in ipairs(BRACKETS) do
    if level >= b[1] then found = b[2] end
  end
  return found
end

-- the header: the character, how many of its spells it can cast, and the next one ------------------------------------

local function updateHeader(own)
  local info = vocationInfo()
  local label = spelllistWindow:getChildById('vocationLabel')
  if info then
    local promotion = math.min(math.max(tonumber(info.promotion) or 0, 0), 2)
    local name = VocationNames[info.vocation + 4 * promotion] or VOCATIONS[info.vocation]
    label:setText(tr('%s Spells', name))
  elseif state.asked then
    label:setText(tr('Spells of every vocation'))
  else
    label:setText(tr('Spells'))
  end

  local ready, total, nextSpell, lastLevel = 0, 0, nil, 1
  local level = playerLevel() or 0
  for _, spell in ipairs(own) do
    if not spell.hidden then
      total = total + 1
      if not spell.blocked then
        ready = ready + 1
        lastLevel = math.max(lastLevel, spell.level)
      elseif spell.blockedKind == 'level' and spell.level > level and (not nextSpell or spell.level < nextSpell.level) then
        nextSpell = spell
      end
    end
  end
  local summary = tr('%d of %d spells ready', ready, total)
  if level > 0 then
    local magic = playerMagicLevel()
    summary = tr('Level %s', thousands(level)) .. (magic and ('   ' .. tr('Magic level %d', magic)) or '') ..
              '   ' .. summary
  end
  if not info and state.asked then
    summary = summary .. '   ' .. tr('(your vocation could not be checked)')
  end
  spelllistWindow:getChildById('summaryLabel'):setText(summary)

  local creature = spelllistWindow:recursiveGetChildById('creature')
  local player = g_game.getLocalPlayer()
  local ok, outfit = pcall(function() return player and player:getOutfit() end)
  if ok and type(outfit) == 'table' then
    creature:setOutfit(outfit)
    if creature.setDirection then creature:setDirection(Directions.South) end
    creature:show()
  else
    creature:hide()
  end

  local nextLabel = spelllistWindow:getChildById('nextLabel')
  local bar = spelllistWindow:getChildById('nextBar')
  if nextSpell then
    nextLabel:setText(tr('Next: %s at level %s', titleOf(nextSpell), thousands(nextSpell.level)))
    local span = math.max(1, nextSpell.level - lastLevel)
    local done = math.max(0, math.min(span, level - lastLevel))
    bar.bar:setPercent(math.floor(done * 100 / span))
    bar.count:setText(tr('%s levels to go', thousands(nextSpell.level - level)))
    bar:show()
  elseif total > 0 and ready == total then
    nextLabel:setText(tr('Every spell of your vocation is yours.'))
    bar.bar:setPercent(100)
    bar.count:setText(tr('All %d', total))
    bar:show()
  else
    nextLabel:setText('')
    bar:hide()
  end

  for _, c in ipairs(CATEGORIES) do
    local count = 0
    for _, spell in ipairs(own) do
      if inCategory(spell, c.id) then count = count + 1 end
    end
    categoryButtons[c.id]:setText(tr(c.text) .. '  ' .. count)
  end
end

-- the window ------------------------------------------------------------------------------------------------------------

local function selectedSpell()
  local row = spellList and spellList:getFocusedChild()
  return row and row.spell or nil
end

local function updateAdminButtons()
  local bar = spelllistWindow:getChildById('adminBar')
  local spell = selectedSpell()
  bar.editButton:setEnabled(spell ~= nil)
  bar.deleteButton:setEnabled(spell ~= nil)
  bar.deleteButton:setText(spell and spell.hidden and tr('Restore') or tr('Delete'))
end

-- what the spell's words take after them, for a spell that wants it
local function paramFor(spell)
  if spell and spell.parameter then
    local text = spelllistWindow:getChildById('paramText'):getText()
    return text ~= '' and text or nil
  end
  return nil
end

local function stopDragging()
  if dragIcon then
    dragIcon:destroy()
    dragIcon = nil
    g_mouse.popCursor('target')
  end
end

local function makeDraggable(row)
  row:setDraggable(true)
  row.onDragEnter = function(self, mousePos)
    stopDragging()
    dragIcon = g_ui.createWidget('SpellDragIcon', rootWidget)
    dragIcon:setImageClip(iconClip(self.spell))
    dragIcon:setPosition({x = mousePos.x - 16, y = mousePos.y - 16})
    g_mouse.pushCursor('target')
    return true
  end
  row.onDragMove = function(self, mousePos)
    if dragIcon then
      dragIcon:setPosition({x = mousePos.x - 16, y = mousePos.y - 16})
    end
    return true
  end
  row.onDragLeave = function(self, droppedWidget, mousePos)
    if dragIcon then
      stopDragging()
      if modules.game_actionbar then
        modules.game_actionbar.dropSpell(mousePos, self.spell.name, paramFor(self.spell))
      end
    end
    return true
  end
  row.onDoubleClick = function(self)
    assignSelected()
    return true
  end
end

function refresh()
  if not spelllistWindow then return end
  stopDragging()
  local keep = state.selected
  spellList:destroyChildren()
  local own = ownSpells()
  updateHeader(own)
  local first, focused
  local header, bracket
  for _, spell in ipairs(spellsToShow(own)) do
    local b = bracketOf(spell.level)
    if b ~= bracket then
      bracket = b
      header = g_ui.createWidget('SpellGroupHeader', spellList)
      header.caption:setText(tr(b))
      header.readyCount, header.count = 0, 0
    end
    header.count = header.count + 1
    if not spell.blocked then header.readyCount = header.readyCount + 1 end
    header.ready:setText(tr('%d / %d ready', header.readyCount, header.count))
    header.ready:setColor(header.readyCount == header.count and READY_COLOR or '#a0a0a0')

    local row = g_ui.createWidget('SpellRow', spellList)
    row.spell = spell
    row.icon:setImageClip(iconClip(spell))
    row.name:setText(titleOf(spell))
    row.words:setText(spell.words)
    row.level:setText(tr('Level %s', thousands(spell.level)))
    makeDraggable(row)
    if spell.hidden then
      row.name:setColor(BLOCKED_COLOR)
      row.name:setText(titleOf(spell) .. '  ' .. tr('(deleted)'))
      row.status:setText('')
      row:setOpacity(0.6)
    elseif spell.blocked then
      row.icon:setOpacity(0.45)
      row.lock:show()
      row.name:setColor('#a8a8a8')
      row.status:setText(spell.blockedKind == 'level' and tr('Locked') or tr('Not yours'))
      row.status:setColor(spell.blockedKind == 'level' and LEVEL_COLOR or BLOCKED_COLOR)
      row:setTooltip(spell.blocked)
    else
      row.status:setText(tr('Ready'))
      row.status:setColor(READY_COLOR)
    end
    first = first or row
    if keep and spell.name == keep then focused = row end
  end
  spelllistWindow:getChildById('emptyLabel'):setVisible(first == nil)
  local target = focused or first
  if target then
    spellList:focusChild(target, KeyboardFocusReason)
    spellList:ensureChildVisible(target)
  else
    showSpell(nil)
  end
  updateAdminButtons()
end

local function addFact(key, value, tooltip, color)
  local fact = g_ui.createWidget('SpellFact', spelllistWindow:getChildById('facts'))
  fact.key:setText(key:upper())
  fact.value:setText(value)
  if color then fact.value:setColor(color) end
  if tooltip then fact:setTooltip(tooltip) end
end

local function addChip(text, color)
  local chip = g_ui.createWidget('SpellChip', spelllistWindow:getChildById('chips'))
  chip:setText(text)
  chip:setColor(color)
end

local function seconds(ms)
  local s = string.format('%.2f', (tonumber(ms) or 0) / 1000):gsub('0+$', ''):gsub('%.$', '')
  return s .. 's'
end

-- what the spell does to one target now (the server's numbers, before boosts and the target's resistances)
local function powerFact(spell, info)
  local server = state.server
  local damage = server and server.damage[spell.name]
  local heal = server and server.heal[spell.name]
  if damage then
    return tr('Damage now'), '~' .. thousands(damage),
      tr('One cast on one target: %s to %s (your promotion counted; boosts, tasks and resistances not).',
         thousands(damage * 0.9), thousands(damage * 1.1)), '#ffb070'
  elseif heal then
    return tr('Heals now'), '~' .. thousands(heal),
      tr('One cast: %s to %s.', thousands(heal * 0.9), thousands(heal * 1.1)), READY_COLOR
  elseif info then
    return tr('Damage now'), '-', tr('Grows with your level and magic level (knights: melee skill, paladins: distance).')
  end
  return tr('Damage now'), '-', nil
end

function showSpell(spell)
  state.selected = spell and spell.name or nil
  local facts = spelllistWindow:getChildById('facts')
  local chips = spelllistWindow:getChildById('chips')
  facts:destroyChildren()
  chips:destroyChildren()
  spelllistWindow:getChildById('paramText'):setVisible(spell ~= nil and spell.parameter and true or false)
  spelllistWindow:getChildById('assignButton'):setEnabled(spell ~= nil and state.slot ~= nil)
  local hint = spelllistWindow:getChildById('demoHint')
  local status = spelllistWindow:getChildById('statusLabel')
  local icon = spelllistWindow:getChildById('icon')
  if not spell then
    icon:hide()
    spelllistWindow:getChildById('name'):setText('')
    spelllistWindow:getChildById('words'):setText('')
    status:setText('')
    demoPlayer:stop()
    hint:setText(tr('Click a spell to see it cast.'))
    hint:show()
    return
  end
  icon:show()
  icon:setImageClip(iconClip(spell))
  spelllistWindow:getChildById('name'):setText(titleOf(spell))
  spelllistWindow:getChildById('words'):setText('"' .. spell.words .. '"' .. (spell.parameter and ' "name' or ''))

  local info = windowInfo(spell)
  for id, name in ipairs(SpellGroups) do
    if spell.group[id] then addChip(tr(name), KIND_COLORS[id] or '#d8d8d8') end
  end
  local element = info and ELEMENTS[info.element]
  if element then addChip(tr(element[1]), element[2]) end

  local level = thousands(spell.level)
  if (spell.maglevel or 0) > 0 then
    level = level .. ' / ML ' .. spell.maglevel
  end
  addFact(tr('Level'), level)
  addFact(tr('Mana'), spell.mana > 0 and thousands(spell.mana) or tr('Part of max'),
          spell.mana > 0 and nil or tr('This spell costs a share of your maximum mana.'))
  addFact(tr('Cooldown'), seconds(spell.exhaustion))
  if info then
    local shape = info.shape == 'square' and tr('Square') or tr('Circle')
    addFact(tr('Area'), tr('%s, %d sqm', shape, info.radius),
            tr('Hits %d tiles around you, up to %d tiles away.', math.floor(#(info.tiles or {}) / 2), info.radius))
    addFact(tr('Waves'), tr('%d in %s', info.waves, seconds(info.ends)),
            tr('The damage is split over the waves; every wave hits the whole area.'))
  else
    addFact(tr('Area'), '-')
    addFact(tr('Waves'), '-')
  end
  local key, value, tooltip, color = powerFact(spell, info)
  addFact(key, value, tooltip, color)
  if info then
    addFact(tr('Grows until'), info.nextLevel and tr('Level %s', thousands(info.nextLevel)) or tr('No limit'),
            tr('Your level counts up to the level of the next spell; magic level and skills always count.'))
  else
    addFact(tr('Grows until'), '-')
  end
  local kinds = {}
  for id, name in ipairs(SpellGroups) do
    if spell.group[id] then table.insert(kinds, tr(name)) end
  end
  addFact(tr('Kind'), #kinds > 0 and table.concat(kinds, ', ') or '-')

  if spell.hidden then
    status:setText(tr('Deleted: only admins see this spell.'))
    status:setColor(BLOCKED_COLOR)
  elseif spell.blocked then
    local text = spell.blocked
    local now = playerLevel()
    if spell.blockedKind == 'level' and now and spell.level > now then
      text = tr('Needs level %s: %s levels to go.', thousands(spell.level), thousands(spell.level - now))
    end
    status:setText(text)
    status:setColor(spell.blockedKind == 'level' and LEVEL_COLOR or BLOCKED_COLOR)
  else
    status:setText(tr('You can cast it now: say "%s" or put it on an action bar.', spell.words))
    status:setColor(READY_COLOR)
  end

  local design = info and SpellDemoPlayer.designOf(info.design)
  if design and demoPlayer:playDesign(design, info) then
    hint:hide()
    return
  end
  local demo = SpellDemos[spell.demo or spell.name]
  if demo then
    hint:hide()
    demoPlayer:play(demo)
  else
    demoPlayer:stop()
    hint:setText(tr('No demo for this spell.'))
    hint:show()
  end
end

function replay()
  local spell = selectedSpell()
  if spell then showSpell(spell) end
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

function setShowDeleted(checked)
  state.showDeleted = checked
  refresh()
end

-- admin tools (the server checks the admin right again on every call) ---------------------------------------------------

local function adminCall(body, done)
  call(body, function(data, err)
    if not data then
      displayErrorBox(tr('Spells'), err or tr('The server did not answer.'))
      return
    end
    fetchServerList(function()
      if done then done() end
      refresh()
    end)
  end)
end

local function sortedIcons()
  local icons = {}
  for key in pairs(SpellIcons) do table.insert(icons, key) end
  table.sort(icons)
  return icons
end

local function numberOf(widget)
  return math.max(0, math.floor(tonumber(widget:getText()) or 0))
end

function adminEdit(editing)
  if not state.admin or state.editor then return end
  local spell = editing and selectedSpell() or nil
  if editing and not spell then return end

  local w = g_ui.createWidget('SpellEditWindow', rootWidget)
  state.editor = w
  w:setText(spell and tr('Edit spell') or tr('Add a spell'))

  local icons = sortedIcons()
  local iconIndex = 1
  local function showIcon()
    w.icon:setImageClip(Spells.getImageClip(iconId(icons[iconIndex]), 'Default'))
    w.iconName:setText(icons[iconIndex])
  end
  w.iconPrev.onClick = function() iconIndex = (iconIndex - 2) % #icons + 1 showIcon() end
  w.iconNext.onClick = function() iconIndex = iconIndex % #icons + 1 showIcon() end

  local function fill(s)
    w.name:setText(titleOf(s))
    w.words:setText(s.words or '')
    w.level:setText(tostring(s.level or 0))
    w.maglevel:setText(tostring(s.maglevel or 0))
    w.mana:setText(tostring(s.mana or 0))
    w.exhaustion:setText(tostring(s.exhaustion or 1000))
    w.demo:setText(s.demo or '')
    for g = 1, 3 do w['group' .. g]:setChecked(s.group and s.group[g] ~= nil) end
    for v = 1, 8 do w['voc' .. v]:setChecked(s.vocations and table.find(s.vocations, v) ~= nil) end
    w.premium:setChecked(s.premium == true)
    w.needlearn:setChecked(s.needlearn == true)
    iconIndex = table.find(icons, s.icon) or 1
    showIcon()
  end
  if spell then
    fill(spell)
  else
    fill({level = 1, exhaustion = 1000, group = {[1] = 1000}, vocations = {}, icon = 'energybeam', words = ''})
  end

  local function close() w:destroy() state.editor = nil end
  w.cancelButton.onClick = close
  w.onEscape = close

  -- a changed built-in spell can go back to the client's values; a spell an admin added can be removed for good
  local builtIn = spell and state.builtIn and state.builtIn[spell.name]
  w.resetButton:setVisible(spell ~= nil and spell.edited == true)
  if spell and not builtIn then
    w.resetButton:setText(tr('Remove for good'))
    w.resetButton:setTooltip(tr('Remove this spell from the list for good (Delete only hides it)'))
  end
  w.resetButton.onClick = function()
    close()
    adminCall({action = 'admin_spell_reset', key = spell.name})
  end

  w.okButton.onClick = function()
    local groups, vocations = {}, {}
    for g = 1, 3 do if w['group' .. g]:isChecked() then table.insert(groups, g) end end
    for v = 1, 8 do
      if w['voc' .. v]:isChecked() then
        table.insert(vocations, v)
        -- the promoted boxes stand for both paths of the promotion (5-8 offensive, 9-12 defensive)
        if v > 4 then table.insert(vocations, v + 4) end
      end
    end
    local data = {
      name = w.name:getText():trim(), words = w.words:getText():trim(), type = 'Instant',
      level = numberOf(w.level), maglevel = numberOf(w.maglevel), mana = numberOf(w.mana), soul = spell and spell.soul or 0,
      exhaustion = numberOf(w.exhaustion), groups = groups, vocations = vocations, icon = icons[iconIndex],
      premium = w.premium:isChecked(), needlearn = w.needlearn:isChecked(), demo = w.demo:getText():trim()
    }
    if data.name == '' or data.words == '' or #groups == 0 or #vocations == 0 then
      displayErrorBox(tr('Spells'), tr('A spell needs a name, words, at least one kind and one vocation.'))
      return
    end
    if not spell and SpellInfo['Default'][data.name] then
      displayErrorBox(tr('Spells'), tr('There is already a spell called %s: edit it instead.', data.name))
      return
    end
    close()
    state.selected = spell and spell.name or data.name
    adminCall({action = 'admin_spell_save', key = spell and spell.name or '', spell = data})
  end
  w:raise()
  w:focus()
  w.name:focus()
end

function adminDelete()
  local spell = selectedSpell()
  if not state.admin or not spell then return end
  if spell.hidden then
    adminCall({action = 'admin_spell_restore', key = spell.name})
    return
  end
  local box
  local function yes()
    box:destroy()
    adminCall({action = 'admin_spell_delete', key = spell.name})
  end
  local function no() box:destroy() end
  box = displayGeneralBox(tr('Delete spell'),
    tr('Delete "%s" from the spell list of every player?\nAdmins can bring it back with Show deleted.', titleOf(spell)),
    {{text = tr('Yes'), callback = yes}, {text = tr('No'), callback = no}, anchor = AnchorHorizontalCenter}, yes, no)
end

-- the game server's answer (opcode 41) ---------------------------------------------------------------------------------

local function askServer()
  local protocol = g_game.getProtocolGame()
  if protocol and g_game.isOnline() then
    pcall(function() protocol:sendExtendedOpcode(SPELLS_OPCODE, 'get') end)
  end
end

local function onSpellsOpcode(protocol, opcode, buffer)
  if type(buffer) ~= 'string' or #buffer > MAX_MESSAGE then return end
  local open = false
  for line in buffer:gmatch('[^\n]+') do
    local parts = line:split('|')
    local kind = parts[1]
    if kind == 'O' then
      open = true
    elseif kind == 'V' then
      local vocation = tonumber(parts[2]) or 0
      if vocation >= 1 and vocation <= 4 then
        state.incoming = {vocation = vocation, promotion = math.max(0, math.min(2, tonumber(parts[3]) or 0)),
                          damage = {}, heal = {}}
      end
    elseif (kind == 'D' or kind == 'H') and state.incoming and parts[2] then
      local amount = tonumber(parts[3])
      if amount and amount >= 0 then
        state.incoming[kind == 'D' and 'damage' or 'heal'][parts[2]] = math.floor(amount)
      end
    elseif kind == 'E' and state.incoming then
      state.server, state.incoming = state.incoming, nil
      state.asked = true
      if spelllistWindow and spelllistWindow:isVisible() then refresh() end
    end
  end
  if open then
    show()
  end
end

-- asks the website which vocation the character has and which spells it learned (once per character); only used
-- while the game server has not answered
local function askVocation()
  local player = g_game.getLocalPlayer()
  local character = player and player:getName() or ''
  if state.character == character and (state.info or state.asking) then return end
  state.character, state.info, state.asking, state.asked = character, nil, true, state.server ~= nil
  call({action = 'spells', character = character}, function(data)
    if state.character ~= character then return end
    state.asking, state.asked = false, true
    if data then
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
  state.character, state.info, state.asking, state.asked = nil, nil, false, false
  state.server, state.incoming = nil, nil
  fetchServerList()
end

function offline()
  if spelllistWindow:isVisible() then toggle() end
  if state.editor then state.editor:destroy() state.editor = nil end
  state.admin = false
  state.server, state.incoming = nil, nil
  demoPlayer:stop()
end

function init()
  connect(g_game, {onGameStart = online, onGameEnd = offline})
  ProtocolGame.registerExtendedOpcode(SPELLS_OPCODE, function(protocol, opcode, buffer)
    local ok, err = pcall(onSpellsOpcode, protocol, opcode, buffer)
    if not ok then g_logger.error('[game_spelllist] ' .. tostring(err)) end
  end)

  spelllistWindow = g_ui.displayUI('spelllist', modules.game_interface.getRightPanel())
  spelllistWindow:hide()

  spellList = spelllistWindow:getChildById('spellList')
  demoPlayer = SpellDemoPlayer.create(spelllistWindow:getChildById('demo'))

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
    updateAdminButtons()
  end})
  g_keyboard.bindKeyPress('Down', function() spellList:focusNextChild(KeyboardFocusReason) end, spelllistWindow)
  g_keyboard.bindKeyPress('Up', function() spellList:focusPreviousChild(KeyboardFocusReason) end, spelllistWindow)

  if g_game.isOnline() then online() end
end

function terminate()
  disconnect(g_game, {onGameStart = online, onGameEnd = offline})
  ProtocolGame.unregisterExtendedOpcode(SPELLS_OPCODE)
  if state.editor then state.editor:destroy() state.editor = nil end
  demoPlayer:stop()
  stopDragging()
  -- leave the global list as it was built into the client
  if state.builtIn then applyServerList({}) end
  spelllistWindow:destroy()
end

-- the spell in the list goes to the slot the window was opened for
function assignSelected()
  local spell = selectedSpell()
  local slot = state.slot
  if spell and slot and not slot:isDestroyed() and modules.game_actionbar
    and modules.game_actionbar.setSlotSpell(slot, spell.name, paramFor(spell)) then
    toggle()
  end
end

local function updateAssignMode()
  local assigning = state.slot ~= nil
  spelllistWindow:setText(assigning and tr('Assign Spell') or tr('Spells'))
  spelllistWindow:getChildById('assignButton'):setVisible(assigning)
  spelllistWindow:getChildById('dragHint'):setText(assigning and
    tr('Double click a spell to put it on the slot, or drag it onto any slot.') or tr('Drag a spell onto an action bar.'))
end

-- right click on an action bar slot: its spell, if it has one, comes selected
function assignTo(slot)
  state.slot = slot
  updateAssignMode()
  local current = slot.spellData
  local param = spelllistWindow:getChildById('paramText')
  param:setText(current and current.param or '')
  if current then
    for name, spell in pairs(SpellInfo['Default']) do
      if spell.id == current.id then
        state.selected = name
      end
    end
  end
  if spelllistWindow:isVisible() then
    refresh()
    spelllistWindow:raise()
    spelllistWindow:focus()
  else
    toggle()
  end
end

-- shows this spell, if the list holds it (tests, the Guides)
function selectSpell(name)
  for _, row in ipairs(spellList:getChildren()) do
    if row.spell and row.spell.name == name then
      spellList:focusChild(row, KeyboardFocusReason)
      spellList:ensureChildVisible(row)
      return true
    end
  end
  return false
end

-- the !spells command (and anything else that only wants to look): the window without a slot to fill
function show()
  if not spelllistWindow:isVisible() then
    state.slot = nil
    toggle()
  else
    spelllistWindow:raise()
    spelllistWindow:focus()
  end
end

function toggle()
  if spelllistWindow:isVisible() then
    stopDragging()
    demoPlayer:stop()
    state.slot = nil
    spelllistWindow:hide()
  else
    updateAssignMode()
    spelllistWindow:show()
    spelllistWindow:raise()
    spelllistWindow:focus()
    askServer()
    askVocation()
    refresh()
    fetchServerList(refresh)
  end
end
