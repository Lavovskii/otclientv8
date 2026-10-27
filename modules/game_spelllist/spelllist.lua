-- The Spells window: only the spells of the character's vocation, grouped and sorted by level, with filters (attack,
-- healing, support, what the character can already cast, a search). Runes are not listed (they are items). Clicking a spell shows its details and
-- plays a demo of it (spelldemo.lua).
--
-- The old protocol does not tell the client the vocation or the spells a character learned, so the website API does
-- (action "spells", the same call the action bars make). Until it answers, or when it cannot be reached, every spell
-- is listed.
--
-- The list itself is kept on the server, like the Store: the admins add, edit and delete spells in this window
-- (web API actions admin_spell_*, table client_spells) and every client applies those changes over the list built
-- into it (gamelib/spells.lua) when the character logs in. A deleted spell is only hidden: action bar slots that
-- hold it keep working.

local SPELLS_API = Services.website .. "/index.php/api/store"
local VOCATIONS = {'Sorcerer', 'Druid', 'Paladin', 'Knight'}
local CATEGORIES = {
  {id = 'all', text = 'All'},
  {id = 'attack', text = 'Attack', group = 1},
  {id = 'healing', text = 'Healing', group = 2},
  {id = 'support', text = 'Support', group = 3},
}
-- the level groups of the list
local BRACKETS = {
  {0, 'Level 1 to 19'}, {20, 'Level 20 to 49'}, {50, 'Level 50 to 99'}, {100, 'Level 100 to 999'},
  {1000, 'Level 1,000 to 9,999'}, {10000, 'Level 10,000 to 29,999'}, {30000, 'Level 30,000 to 59,999'},
  {60000, 'Level 60,000 and up'},
}
-- spells added by the admins get ids far after the built-in ones (ids are saved in action bar slots)
local ADDED_SPELL_IDS = 10000

spelllistWindow = nil
spelllistButton = nil
local spellList, details, demoPlayer
local categoryButtons = {}
local state = {category = 'all', castableOnly = false, search = '', character = nil, info = nil, selected = nil,
               admin = false, showDeleted = false, editor = nil, builtIn = nil}

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
      spelllistWindow:getChildById('adminBar'):setVisible(state.admin)
    end
    if after then after() end
  end)
end

-- the character's vocation ----------------------------------------------------------------------------------------------

-- the vocations a spell must list to be one of the character's: the base vocation and the promoted one
local function characterVocations()
  local info = state.info
  if not info or info.vocation < 1 then return nil end
  return {info.vocation, info.vocation + 4}
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

local function spellsToShow()
  local list = {}
  for name, data in pairs(SpellInfo['Default']) do
    local spell = {name = name}
    for k, v in pairs(data) do spell[k] = v end
    spell.name = name
    local visible = (not spell.hidden or (state.admin and state.showDeleted)) and spell.type ~= 'Rune'
    if visible and spellFits(spell) and inCategory(spell) and matchesSearch(spell) then
      spell.blocked = blockedReason(spell)
      if not (state.castableOnly and spell.blocked) then
        table.insert(list, spell)
      end
    end
  end
  table.sort(list, function(a, b)
    if a.level ~= b.level then return a.level < b.level end
    if (a.maglevel or 0) ~= (b.maglevel or 0) then return (a.maglevel or 0) < (b.maglevel or 0) end
    return titleOf(a) < titleOf(b)
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
    row.name:setText(titleOf(spell))
    row.words:setText(spell.words)
    row.level:setText(tr('Lv %s', thousands(spell.level)))
    if spell.hidden then
      row.name:setColor('#e05a4a')
      row.name:setText(titleOf(spell) .. '  ' .. tr('(deleted)'))
      row:setOpacity(0.6)
    elseif spell.blocked then
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
  updateAdminButtons()
end

local function infoRow(key, value)
  local row = g_ui.createWidget('SpellInfoRow', details.info)
  row.key:setText(key)
  row.value:setText(value)
end

function showSpell(spell)
  state.selected = spell and spell.name or nil
  details.info:destroyChildren()
  local hint = spelllistWindow:recursiveGetChildById('demoHint')
  if not spell then
    details.icon:hide()
    details.name:setText('')
    details.words:setText('')
    demoPlayer:stop()
    hint:setText(tr('Click a spell to see it cast.'))
    hint:show()
    return
  end
  details.icon:show()
  details.icon:setImageClip(iconClip(spell))
  details.name:setText(titleOf(spell))
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
  infoRow(tr('Kind') .. ':', table.concat(groups, ', '))
  infoRow(tr('Mana') .. ':', spell.mana > 0 and thousands(spell.mana) or '-')
  infoRow(tr('Cooldown') .. ':', (spell.exhaustion / 1000) .. 's' .. (spell.blocked and ('   ' .. spell.blocked) or ''))

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
    for v = 1, 8 do if w['voc' .. v]:isChecked() then table.insert(vocations, v) end end
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

-- asks the website which vocation the character has and which spells it learned (once per character)
local function askVocation()
  local player = g_game.getLocalPlayer()
  local character = player and player:getName() or ''
  if state.character == character and (state.info or state.asking) then return end
  state.character, state.info, state.asking, state.asked = character, nil, true, false
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
  spelllistButton:show()
  state.character, state.info, state.asking, state.asked = nil, nil, false, false
  fetchServerList()
end

function offline()
  if spelllistWindow:isVisible() then toggle() end
  if state.editor then state.editor:destroy() state.editor = nil end
  state.admin = false
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
    updateAdminButtons()
  end})
  g_keyboard.bindKeyPress('Down', function() spellList:focusNextChild(KeyboardFocusReason) end, spelllistWindow)
  g_keyboard.bindKeyPress('Up', function() spellList:focusPreviousChild(KeyboardFocusReason) end, spelllistWindow)

  if g_game.isOnline() then online() end
end

function terminate()
  disconnect(g_game, {onGameStart = online, onGameEnd = offline})
  if state.editor then state.editor:destroy() state.editor = nil end
  demoPlayer:stop()
  -- leave the global list as it was built into the client
  if state.builtIn then applyServerList({}) end
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
    fetchServerList(refresh)
  end
end
