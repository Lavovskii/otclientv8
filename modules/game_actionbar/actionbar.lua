local actionBars = {}
local settings = {}
local settingsFile = ""
local cachedSettings = nil
local window = nil
local mouseGrabberWidget = nil
local applyingBars = false

local TYPE = {
  BLANK = 0,
  TEXT = 1,
  SPELL = 2,
  ITEM = 3,
  ACTION = 4 -- see gameactions.lua
}

local ACTION = {
  BLANK = 0,
  EQUIP = 1,
  USE = 2,
  USE_SELF = 3,
  USE_TARGET = 4,
  USE_CROSS = 5
}

-- removes the key binding of a button: setupAction binds a new callback every time a button is set up, so the
-- old one has to go first or the key would run the action twice
local function unbindButton(widget)
  if widget.keyCallback and widget.hotkey and widget.hotkey:len() > 0 then
    g_keyboard.unbindKeyPress(widget.hotkey, widget.keyCallback, modules.game_interface.getRootPanel())
  end
  widget.keyCallback = nil
  widget.callback = nil
end

-- while the chat is open a key that writes text (a letter, with or without Shift) belongs to the chat; with the option
-- "Disable action bar hotkeys when chat mode is on" every action bar key waits until the chat is closed
local function keyBelongsToChat(hotkey)
  if not (modules.game_console and modules.game_console.isChatEnabled()) then
    return false
  end

  if modules.client_options and modules.client_options.getOption('actionbarLock') then
    return true
  end

  return hotkey:gsub('^Shift%+', ''):len() == 1
end

-- the cooldown groups of a spell as a list (SpellInfo keeps them as {[groupId] = ms}; it is shared with the spell
-- list module, so it is never changed here)
local function spellGroups(spellData)
  local groups = {}
  for groupId in pairs(spellData.group or {}) do
    table.insert(groups, groupId)
  end
  return groups
end

-- the settings are written a second after the last change (and at logout), so a crash keeps the bars
local saveEvent = nil
function scheduleSave()
  removeEvent(saveEvent)
  saveEvent = scheduleEvent(function()
    saveEvent = nil
    save()
  end, 1000)
end

local function isSpell(text) -- returns bool or table (spelldata, param text)
  text = text:lower():trim()

  for spellName, spellData in pairs(SpellInfo['Default']) do
    local words = spellData.words
    local param = spellData.parameter
    local data = spellData
    data.spellName = spellName

    if not param then
      if words == text then
        return {data=data}
      end
    else
      if text:find(words) then
        text = text:gsub(words, ""):trim()
        text = text:gsub('"', "")
        text = text:gsub("'", "")
        return {data=data, param=text}
      end
    end
  end

  return false
end

function init()
  initGameActions()
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onSpellGroupCooldown = onSpellGroupCooldown,
    onSpellCooldown = onSpellCooldown
  })

  if g_game.isOnline() then
    online()
  end

  -- taken from game_hotkeys
  mouseGrabberWidget = g_ui.createWidget('UIWidget')
  mouseGrabberWidget:setVisible(false)
  mouseGrabberWidget:setFocusable(false)
  mouseGrabberWidget.onMouseRelease = onDropActionButton
end

function terminate()
  if g_game.isOnline() then
    offline()
  end
  if mouseGrabberWidget then
    mouseGrabberWidget:destroy()
    mouseGrabberWidget = nil
  end
  terminateGameActions()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline,
    onSpellGroupCooldown = onSpellGroupCooldown,
    onSpellCooldown = onSpellCooldown
  })
end

function createActionBars()
  local bottomPanel = modules.game_interface.getBottomActionPanel()
  local leftPanel = modules.game_interface.getLeftActionPanel()
  local rightPanel = modules.game_interface.getRightActionPanel()

  -- 1-3: bottom
  -- 4-6: left
  -- 7-9: right
  for i=1,9 do
    local parent
    local index
    local layout

    if i <= 3 then
      parent = bottomPanel
      index = i
      layout = 'actionbar'
    elseif i <= 6 then
      parent = leftPanel
      index = i - 3
      layout = 'sideactionbar'
    else
      parent = rightPanel
      index = i - 6
      layout = 'sideactionbar'
    end

    actionBars[i] = g_ui.loadUI(layout, parent)
    actionBars[i]:setId("actionbar."..i)
    actionBars[i].n = i
    parent:moveChildToIndex(actionBars[i], index)
  end
end

function offline()
  -- save settings to json
  removeEvent(saveEvent)
  saveEvent = nil
  save()

  -- destroy windows
  destroyAssignWindows()

  -- remove binds
  for index, actionbar in ipairs(actionBars) do
    if actionbar.tabBar then
      for i, actionButton in ipairs(actionbar.tabBar:getChildren()) do
        unbindButton(actionButton)
      end
    end
  end

  -- destroy actionbars
  for i, panel in ipairs(actionBars) do
    panel:destroy()
  end
  actionBars = {}
end

-- what a character starts with (applied once per character, never over a slot or a key the player already uses):
-- F1 to F12 on the first 12 slots of the bottom bar, and every game action on the left bar, without keys (the tooltip
-- of an action tells the player to give it one)
local DEFAULTS_VERSION = 1
local DEFAULT_ACTIONS = {
  {action = 'loot'},
  {action = 'attackNext', filter = 'all'},
  {action = 'attackNext', filter = 'monsters'},
  {action = 'attackNext', filter = 'players'},
  {action = 'stopAttack'},
  {action = 'openDoor'},
  {action = 'useUnder'}
}

local function applyDefaults()
  if (settings.defaultsVersion or 0) >= DEFAULTS_VERSION then
    return
  end
  settings.defaultsVersion = DEFAULTS_VERSION

  local usedKeys, usedActions = {}, {}
  for _, config in pairs(settings) do
    if type(config) == 'table' then
      if config.hotkey and config.hotkey ~= '' then
        usedKeys[config.hotkey] = true
      end
      if config.type == TYPE.ACTION then
        usedActions[tostring(config.gameAction) .. ':' .. tostring(config.gameFilter)] = true
      end
    end
  end

  for i = 1, 12 do
    local id, key = '1.' .. i, 'F' .. i
    settings[id] = settings[id] or {}
    if (settings[id].hotkey or '') == '' and not usedKeys[key] then
      settings[id].hotkey = key
      usedKeys[key] = true
    end
  end

  local slot = 1
  for _, default in ipairs(DEFAULT_ACTIONS) do
    local filter = default.action == 'attackNext' and default.filter or nil
    if not usedActions[default.action .. ':' .. tostring(filter)] then
      while slot <= 50 and settings['4.' .. slot] and settings['4.' .. slot].type do
        slot = slot + 1
      end
      if slot > 50 then
        break
      end
      local id = '4.' .. slot
      settings[id] = settings[id] or {}
      settings[id].type = TYPE.ACTION
      settings[id].gameAction = default.action
      settings[id].gameFilter = filter
      slot = slot + 1
    end
  end
end

function online()
  settingsFile = modules.client_profiles.getSettingsFilePath("actionbar_v2.json")
  -- load settings
  load()
  applyDefaults()

  -- the bars this character had open (options are global, so push them into the options first); a character that has
  -- no saved bars starts with the default: one at the bottom and one on each side
  local bars = settings.bars or {['1'] = true, ['4'] = true, ['7'] = true}
  applyingBars = true -- setOption calls show(), which must wait until the bars exist
  for i = 1, 9 do
    modules.client_options.setOption('actionbar'..i, bars[tostring(i)] == true, true)
  end
  applyingBars = false

  -- create actionbars
  createActionBars()

  -- show & setup actionbars
  show()

  destroyAssignWindows()
end

function show()
  if applyingBars then
    return
  end

  for i=1,#actionBars do
    local actionbar = actionBars[i]
    local enabled = g_settings.getBoolean("actionbar"..i, false)
    settings.bars = settings.bars or {}
    settings.bars[tostring(i)] = enabled or nil

    actionbar:setOn(enabled)
    setupActionBar(i)
  end
end

function refresh()
  -- first save
  save()

  -- recheck file
  settingsFile = modules.client_profiles.getSettingsFilePath("actionbar_v2.json")

  -- load settings
  load()

  -- setup actionbars
  show()

  destroyAssignWindows()
end

function translateHotkeyDesc(text)
  -- formatting similar to cip Tibia 12
  if not text then 
    return ""
  end

  local values = {
    {"Shift", "S"},
    {"Ctrl", "C"},
    {"+", ""},
    {"PageUp", "PgUp"},
    {"PageDown", "PgDown"},
    {"Enter", "Return"},
    {"Insert", "Ins"},
    {"Delete", "Del"},
    {"Escape", "Esc"}
  }

  for i, v in pairs(values) do
    text = text:gsub(v[1], v[2])
  end

  if text:len() > 6 then
    text = text:sub(text:len()-3,text:len())
    text = "..."..text
  end

  return text
end

function destroyAssignWindows()
  local windows = {
    'assignItemWindow',
    'assignSpellWindow',
    'assignTextWindow',
    'assignHotkeyWindow',
    'assignActionWindow'
  }

  local rootWidget = g_ui.getRootWidget()
  for i, id in ipairs(windows) do
    local widget = rootWidget[id]

    if widget then
      widget:destroy()
    end
  end
end

function changeLockState(widget)
  local actionbar = widget:getParent():getParent()

  widget:setOn(not widget:isOn())
  widget.image:setOn(widget:isOn())
  actionbar.locked = not widget:isOn()

  settings[actionbar:getId()] = not widget:isOn() or nil
end

function moveActionButtons(widget)
  local dir = widget:getId()
  local actionBar = widget:getParent():getParent()
  local scroll = actionBar.actionScroll
  local buttons = {actionBar.prevPanel.prev, actionBar.prevPanel.first, actionBar.nextPanel.next, actionBar.nextPanel.last}

  if dir == "next" then
    scroll:increment(37)
  elseif dir == "last" then
    scroll:setValue(scroll:getMaximum())
  elseif dir == "prev" then
    scroll:decrement(37)
  else
    scroll:setValue(scroll:getMinimum())
  end

  local prevEnabled = scroll:getValue() > 0
  local nextEnabled = scroll:getValue() < scroll:getMaximum()
  
  buttons[1]:setOn(prevEnabled)
  buttons[2]:setOn(prevEnabled)
  buttons[3]:setOn(nextEnabled)
  buttons[4]:setOn(nextEnabled)
  buttons[1].image:setOn(prevEnabled)
  buttons[2].image:setOn(prevEnabled)
  buttons[3].image:setOn(nextEnabled)
  buttons[4].image:setOn(nextEnabled)
end

function onDropActionButton(self, mousePosition, mouseButton)
  if not g_ui.isMouseGrabbed() then return end

  local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
  if clickedWidget and clickedWidget:getParent() and clickedWidget:getParent():getStyleName():find('ActionButton') then
    if cachedSettings then
      clickedWidget = clickedWidget:getParent()
      if clickedWidget ~= cachedSettings.widget then
        local clickedHotkey = clickedWidget.hotkey
        local cachedHotkey = cachedSettings.widget.hotkey

        settings[cachedSettings.id] = settings[clickedWidget:getId()]
        settings[clickedWidget:getId()] = cachedSettings.data
        
        local clickedTill = clickedWidget.cooldownTill or 0
        local clickedStart = clickedWidget.cooldownStart or 0
        local cachedTill = cachedSettings.widget.cooldownTill or 0
        local cachedStart = cachedSettings.widget.cooldownStart or 0

        cachedSettings.widget.cooldownTill = clickedTill
        cachedSettings.widget.cooldownStart = clickedStart
        clickedWidget.cooldownTill = cachedTill
        clickedWidget.cooldownStart = cachedStart

        -- hotkeys remain unchanged
        settings[cachedSettings.id] = settings[cachedSettings.id] or {}
        settings[cachedSettings.id].hotkey = cachedHotkey
        settings[clickedWidget:getId()] = settings[clickedWidget:getId()] or {}
        settings[clickedWidget:getId()].hotkey = clickedHotkey

        updateCooldown(clickedWidget)
        updateCooldown(cachedSettings.widget)
        setupButton(cachedSettings.widget)
        setupButton(clickedWidget)
      end
    end
  end

  cachedSettings.widget.item:setBorderColor('#00000000')
  cachedSettings = nil
  g_mouse.popCursor('target')
  self:ungrabMouse()
end

function setupActionBar(n)
  local actionbar = actionBars[n]
  local visible = actionbar:isVisible()
  locked = settings[actionbar:getId()]
  actionbar.tabBar.onMouseWheel = nil -- disable scroll wheel

  actionbar.locked = locked
  actionbar.nextPanel.lock:setOn(not locked)
  actionbar.nextPanel.lock.image:setOn(not locked)

  -- the old buttons go away: their keys first
  for _, child in ipairs(actionbar.tabBar:getChildren()) do
    unbindButton(child)
  end

  if not visible then
    return actionbar.tabBar:destroyChildren() -- will hopefully lower stress
  else
    actionbar.tabBar:destroyChildren()
    for i=1,50 do
      local layout = n < 4 and 'ActionButton' or 'SideActionButton'
      local widget = g_ui.createWidget(layout, actionbar.tabBar)
      widget:setId(actionbar.n.."."..i)

      setupButton(widget)
    end
  end
end

function setupButton(widget)
  local id = widget:getId()
  local config = settings[id]
  local actionbar = widget:getParent():getParent()

  -- disable count
  widget.item:setShowCount(false)

  -- remove callback to avoid recurrency
  widget.item.onItemChange = nil

  -- clear settings
  widget.type = TYPE.BLANK
  widget.text:setText("")
  widget.parameterText:setText("")
  if widget.item:getItemId() ~= 0 then
    widget.item:setItemId(0)
  end
  widget.item:setOn(false)
  widget.autoSay = nil
  widget.action = ACTION.BLANK
  widget.spellData = nil
  widget.gameAction = nil
  widget.gameFilter = nil
  widget.item:setItemVisible(true)
  widget.text:setImageSource('')
  unbindButton(widget)
  widget.hotkey = config and config.hotkey or ""

  -- add new settings
  if config and config.type then
    widget.item:setOn(true)
    widget.type = config.type
    widget.text:setText(config.sayText or "")
    if widget.item:getItemId() ~= (config.itemId and config.itemId > 100 and config.itemId or 0) then
      widget.item:setItem(Item.create(config.itemId, 50))
    end
    widget.sayText = config.sayText
    widget.autoSay = config.autoSay
    widget.action = config.action
    widget.spellData = config.spellData
    widget.gameAction = config.gameAction
    widget.gameFilter = config.gameFilter
    if config.type ~= 0 and config.type ~= 3 then
      widget.item:setItemVisible(false)
    end
  end

  -- callback
  setupAction(widget)
  if not applyingBars then
    scheduleSave()
  end

  if widget.type == TYPE.ACTION then
    widget.text:setText(gameActionLabel(widget.gameAction, widget.gameFilter))
  end

  --hotkey
  widget.hotkeyLabel:setText(translateHotkeyDesc(widget.hotkey))
  
  if widget.spellData then
    --image
    widget.text:setImageSource(widget.spellData.source)
    widget.text:setImageClip(widget.spellData.clip)

    --param
    local param = widget.spellData.param
    if param and param:len() > 6 then
      param = param:sub(1,5) .. "..."
    end
    widget.parameterText:setText(param or "")
  else
    widget.text:setImageSource('')
  end

  widget.item.onDragEnter = function(self)
    if g_ui.isMouseGrabbed() or actionbar.locked then return end
    mouseGrabberWidget:grabMouse()
    g_mouse.pushCursor('target')

    self:setBorderColor('#FFFFFF')
    cachedSettings = {id=widget:getId(), data=settings[widget:getId()], widget=widget}
  end

  -- popupmenu & execute action
  widget.onMouseRelease = function(widget, mousePos, mouseButton)
    if mouseButton == MouseRightButton then 

      local menu = g_ui.createWidget('PopupMenu')
      menu:setGameMenu(true)
      menu:addOption(widget.spellData and tr('Edit Spell') or tr('Assign Spell'), function() assignSpell(widget) end)
      menu:addOption(widget.item:getItemId() > 100 and tr('Edit Object') or tr('Assign Object'), function() assignItem(widget) end)
      menu:addOption(widget.text:getText():len() > 0 and tr('Edit Text') or tr('Assign Text'), function() assignText(widget) end)
      menu:addOption(widget.gameAction and tr('Edit Action') or tr('Assign Action'), function() assignGameAction(widget) end)
      menu:addOption(widget.hotkey ~= '' and tr('Edit Hotkey') or tr('Assign Hotkey'), function() assignHotkey(widget) end)

      if widget.type > 0 then
        menu:addSeparator()
        menu:addOption(tr('Clear Action'), function() resetSlot(widget) end)
      end
      menu:display(mousePos)
    elseif mouseButton == MouseLeftButton and widget.callback then 
      widget.callback()
    end
  end

  widget.item.onItemChange = function(widget)
    widget:setOn(true)
    assignItem(widget:getParent())
  end

  -- tooltip
  local itemAction
  if widget.type == TYPE.ITEM then
    if widget.action == ACTION.EQUIP then
      itemAction = "Equip/Unequip this object"
    elseif widget.action == ACTION.USE then
      itemAction = "Use this object"
    elseif widget.action == ACTION.USE_SELF then
      itemAction = "Use this object on Yourself"
    elseif widget.action == ACTION.USE_TARGET then
      itemAction = "Use this object on Attack Target"
    elseif widget.action == ACTION.USE_CROSS then
      itemAction = "Use this object with Crosshair"
    end
  end

  local actionDesc
  local spellData = widget.spellData
  if widget.type == TYPE.BLANK then
    actionDesc = "None"
  elseif widget.type == TYPE.TEXT then
    actionDesc = 'Say: "'..widget.text:getText()..'"\n'
    actionDesc = actionDesc.. "Auto sent:  " .. (widget.autoSay and "Yes" or "No")
  elseif widget.type == TYPE.SPELL then
    local paramText 
    if spellData.param and spellData.param:len() > 0 then
      paramText = ' "'.. spellData.param ..'"' 
    else 
      paramText = ""
    end
    actionDesc = "Cast " .. spellData.name .."\n"
    actionDesc = actionDesc.. "Formula:  ".. spellData.words .. paramText.."\n"
    actionDesc = actionDesc.. "Cooldown:  "..spellData.cd.."s\n"
    actionDesc = actionDesc.. "Mana:  "..spellData.mana
  elseif widget.type == TYPE.ITEM then
    actionDesc = itemAction
  elseif widget.type == TYPE.ACTION then
    actionDesc = gameActionDescription(widget.gameAction, widget.gameFilter)
  end

  local hotkeyDesc = widget.hotkey and widget.hotkey:len() > 0 and widget.hotkey or "None"
  local tooltip = "Action Button "..id
  tooltip = tooltip.."\n\n\tAction:  ".. actionDesc
  tooltip = tooltip.."\nHotkeys:  ".. hotkeyDesc
  if widget.type == TYPE.ACTION then
    tooltip = gameActionHelp(widget.gameAction, widget.gameFilter)
    if hotkeyDesc == "None" then
      tooltip = tooltip.."\n\nNo key yet: right click this slot and choose Assign Hotkey."
    else
      tooltip = tooltip.."\n\nKey: "..hotkeyDesc
    end
  end

  widget.item:setTooltip(tooltip)
end

function resetSlot(widget)
  local hotkey = settings[widget:getId()] and settings[widget:getId()].hotkey or nil
  if hotkey and hotkey:len() > 0 and widget.callback then
    local gameRootPanel = modules.game_interface.getRootPanel()
    g_keyboard.unbindKeyPress(widget.hotkey, widget.callback, gameRootPanel)
  end
  
  if hotkey then
    settings[widget:getId()] = {hotkey=hotkey}
  else
    settings[widget:getId()] = nil
  end

  setupButton(widget)
end

function assignItem(widget)
  destroyAssignWindows()
  local radio = UIRadioGroup.create()
  local item = widget.item:getItem()
  local id = widget.item:getItemId()

  -- check if item wasn't cleared
  if id == 0 and widget.item:isOn() then
    return resetSlot(widget) 
  end

  -- create window
  window = g_ui.loadUI('object', g_ui.getRootWidget())
  window:show()
  window:raise()
  window:focus()

  -- basics
  window:setText("Assign Object to Action Button "..widget:getId())
  window:setId("assignItemWindow")

  -- select item
  window.select.onClick = function()
    modules.game_itemselector.show(widget.item)
  end

  -- checks
  window.item:setShowCount(false)
  window.item.onItemChange = function(widget)
    local item = window.item:getItem()

    if item then
      for i, child in ipairs(window.checks:getChildren()) do
        -- add to radio grouo
        radio:addWidget(child)

        -- enabled
        if item:getId() < 100 then
          child:setEnabled(false)
        elseif i < 4 then
          local check = item:isMultiUse()
          child:setEnabled(check)
          if check then
            radio:selectWidget(child)
          end
        elseif g_game.getClientVersion() >= 910 then
          if i == 4 then
  --           local check = item:getClothSlot() > 0
            local check = true -- unfortunately two handed weapons returns cloth 0, so we have to disable this check
            child:setEnabled(check)
            if check then
              radio:selectWidget(child)
            end
          else
            child:setEnabled(true)
            radio:selectWidget(child)
          end
        else
          child:setVisible(false)
        end
      end
    end

    -- validation
    window.buttonOk:setEnabled(item and item:getId() > 100)
    window.buttonApply:setEnabled(item and item:getId() > 100)
  end

  window.item:setItemId(id)

  -- select current action, if exists
  local actionType = widget.action or 0
  if actionType > ACTION.BLANK then
    local id
    if actionType == ACTION.USE_SELF then
      id = "useSelf"
    elseif actionType == ACTION.USE_TARGET then
      id = "useTarget"
    elseif actionType == ACTION.USE_CROSS then
      id = "useCross"
    elseif actionType == ACTION.EQUIP then
      id = "equip"
    elseif actionType == ACTION.USE then
      id = "use"
    end

    for i, child in ipairs(radio.widgets) do
      local childId = child:getId()
      if childId == id then
        radio:selectWidget(child)
        break
      end
    end
  end

  -- functions
  local okFunc = function(destroy)
    local hotkey = settings[widget:getId()] and settings[widget:getId()].hotkey
    if hotkey and hotkey:len() > 0 and widget.callback then
      local gameRootPanel = modules.game_interface.getRootPanel()
      g_keyboard.unbindKeyPress(widget.hotkey, widget.callback, gameRootPanel)
    end

    settings[widget:getId()] = {hotkey=hotkey}
    settings[widget:getId()].itemId = window.item:getItemId()
    settings[widget:getId()].type = TYPE.ITEM

    local selected = radio:getSelectedWidget():getId()
    if selected == "useSelf" then
      settings[widget:getId()].action = ACTION.USE_SELF
    elseif selected == "useTarget" then
      settings[widget:getId()].action = ACTION.USE_TARGET
    elseif selected == "useCross" then
      settings[widget:getId()].action = ACTION.USE_CROSS
    elseif selected == "equip" then
      settings[widget:getId()].action = ACTION.EQUIP
    else
      settings[widget:getId()].action = ACTION.USE
    end

    if destroy then
      window:destroy()
      radio:destroy()
    end
    setupButton(widget)
  end

  local cancelFunc = function()
    setupButton(widget)
    window:destroy()
    radio:destroy()
  end

  -- callbacks
  window.buttonOk.onClick = function() okFunc(true) end
  window.onEnter = function() okFunc(true) end
  window.buttonApply.onClick = function() okFunc(false) end
  window.buttonClose.onClick = cancelFunc
  window.onEscape = cancelFunc

  local actionbar = widget:getParent():getParent()
  if actionbar.locked then
    cancelFunc()
  end
end

function assignText(widget)
  destroyAssignWindows()

  -- create window
  window = g_ui.loadUI('text', g_ui.getRootWidget())
  window:show()
  window:raise()
  window:focus()

  window.text.onTextChange = function(self, text)
    window.buttonOk:setEnabled(text:len() > 0)
    window.buttonApply:setEnabled(text:len() > 0)
  end

  -- copy settings from current widget
  window.text:setText(widget.text:getText())
  if widget.type > 0 then
    window.checkPanel.tick:setChecked(widget.autoSay)
  end

  -- functions
  local okFunc = function(destroy) 
    local autoSay = window.checkPanel.tick:isChecked()
    local text = window.text:getText()

    local hotkey = settings[widget:getId()] and settings[widget:getId()].hotkey
    if hotkey and hotkey:len() > 0 and widget.callback then
      local gameRootPanel = modules.game_interface.getRootPanel()
      g_keyboard.unbindKeyPress(hotkey, widget.callback, gameRootPanel)
    end

    settings[widget:getId()] = {hotkey=hotkey}

    local spell = isSpell(text)
    if spell then -- entered text is spell
      local paramText = spell.param
      local spellData = spell.data

  
      settings[widget:getId()].type = TYPE.SPELL
      settings[widget:getId()].spellData = {
        words = spellData.words,
        cd = spellData.exhaustion/1000,
        mana = spellData.mana,
        source = SpelllistSettings['Default'].iconFile,
        clip = Spells.getImageClip(SpellIcons[spellData.icon][1], 'Default'),
        name = spellData.spellName,
        param = paramText,
        group = spellGroups(spellData),
        id = spellData.id
      }
    else -- is just text
      settings[widget:getId()].sayText = text
      settings[widget:getId()].type = TYPE.TEXT
      settings[widget:getId()].autoSay = autoSay
    end
  
    if destroy then
      window:destroy()
    end
    setupButton(widget)
  end
  local cancelFunc = function()
    window:destroy()
    setupButton(widget)
  end

  -- buttons
  window.buttonOk.onClick = function() okFunc(true) end
  window.buttonApply.onClick = function() okFunc(false) end
  window.buttonClose.onClick = cancelFunc
  window.onEscape = cancelFunc
  window.onEnter = function() okFunc(true) end

  local actionbar = widget:getParent():getParent()
  if actionbar.locked then
    cancelFunc()
  end
end

function getSettings()
  return settings
end

function assignGameAction(widget)
  destroyAssignWindows()

  window = g_ui.loadUI('action', g_ui.getRootWidget())
  window:show()
  window:raise()
  window:focus()

  local actionRadio = UIRadioGroup.create()
  local filterRadio = UIRadioGroup.create()
  for _, id in ipairs({GAME_ACTION.ATTACK_NEXT, GAME_ACTION.LOOT, GAME_ACTION.STOP_ATTACK, GAME_ACTION.USE_UNDER, GAME_ACTION.OPEN_DOOR}) do
    actionRadio:addWidget(window.actions:getChildById(id))
  end
  filterRadio:addWidget(window.filters.filterAll)
  filterRadio:addWidget(window.filters.filterPlayers)
  filterRadio:addWidget(window.filters.filterMonsters)

  local filterIds = {
    [TARGET_FILTER.ALL] = window.filters.filterAll,
    [TARGET_FILTER.PLAYERS] = window.filters.filterPlayers,
    [TARGET_FILTER.MONSTERS] = window.filters.filterMonsters
  }

  -- the target filter only matters for "Attack next target"
  actionRadio.onSelectionChange = function(group, selected)
    local attack = selected and selected:getId() == GAME_ACTION.ATTACK_NEXT
    window.filterLabel:setEnabled(attack)
    for _, radioWidget in pairs(filterIds) do
      radioWidget:setEnabled(attack)
    end
  end

  -- copy settings from the current widget
  actionRadio:selectWidget(window.actions:getChildById(widget.gameAction or GAME_ACTION.ATTACK_NEXT))
  filterRadio:selectWidget(filterIds[widget.gameFilter] or window.filters.filterAll)

  local closeWindow = function()
    actionRadio:destroy()
    filterRadio:destroy()
    window:destroy()
  end

  local okFunc = function(destroy)
    local selected = actionRadio:getSelectedWidget()
    local filter = TARGET_FILTER.ALL
    for value, radioWidget in pairs(filterIds) do
      if filterRadio:getSelectedWidget() == radioWidget then
        filter = value
      end
    end

    local hotkey = settings[widget:getId()] and settings[widget:getId()].hotkey
    if hotkey and hotkey:len() > 0 and widget.callback then
      local gameRootPanel = modules.game_interface.getRootPanel()
      g_keyboard.unbindKeyPress(hotkey, widget.callback, gameRootPanel)
    end

    settings[widget:getId()] = {
      hotkey = hotkey,
      type = TYPE.ACTION,
      gameAction = selected:getId(),
      gameFilter = selected:getId() == GAME_ACTION.ATTACK_NEXT and filter or nil
    }

    if destroy then
      closeWindow()
    end
    setupButton(widget)
  end
  local cancelFunc = function()
    closeWindow()
    setupButton(widget)
  end

  window.buttonOk.onClick = function() okFunc(true) end
  window.buttonApply.onClick = function() okFunc(false) end
  window.buttonClose.onClick = cancelFunc
  window.onEscape = cancelFunc
  window.onEnter = function() okFunc(true) end

  local actionbar = widget:getParent():getParent()
  if actionbar.locked then
    cancelFunc()
  end
end

-- The old protocol does not tell the client the vocation or the spells a character learned, so the website API does
-- (action "spells", same login as the store). Only castable (instant) spells of the character's vocation that it can
-- already use (level, magic level, and learned when the spell has to be learned) are listed, sorted by level.
local SPELLS_API = Services.website .. "/index.php/api/store"

local function normalizeSpellName(name)
  return name:lower():gsub('[^a-z0-9]', '')
end

local function canUseSpell(spell, info, player)
  if spell.type ~= 'Instant' then
    return false
  end

  if spell.level > player:getLevel() or (spell.maglevel or 0) > player:getMagicLevel() then
    return false
  end

  if not info then
    return true -- the server could not be asked: fall back to level and magic level only
  end

  local vocations = {info.vocation}
  if info.promotion and info.promotion > 0 then
    table.insert(vocations, info.vocation + 4 * info.promotion)
  end

  local fits = false
  for _, vocation in ipairs(vocations) do
    if table.find(spell.vocations, vocation) then
      fits = true
    end
  end

  if not fits then
    return false
  end

  if spell.needlearn then
    return info.learned[normalizeSpellName(spell.name)] == true
  end

  return true
end

function assignSpell(widget)
  destroyAssignWindows()
  local radio = UIRadioGroup.create()

  -- create window
  window = g_ui.loadUI('spell', g_ui.getRootWidget())
  window:show()
  window:raise()
  window:focus()

  window:setText("Assign Spell to Action Button "..widget:getId())
  window.checkPanel:setVisible(false)

  local spellWindow = window
  local player = g_game.getLocalPlayer()

  local function populate(info)
    if spellWindow:isDestroyed() then
      return -- the window was closed while the server answered
    end

    local spells = modules.gamelib.SpellInfo['Default']
    for spellName, spellData in pairs(spells) do
      local candidate = {name = spellName, type = spellData.type, level = spellData.level, maglevel = spellData.maglevel,
        vocations = spellData.vocations, needlearn = spellData.needlearn}
      if canUseSpell(candidate, info, player) then
        local spellWidget = g_ui.createWidget('SpellPreview', spellWindow.spellList)
        -- radio
        radio:addWidget(spellWidget)

        spellWidget:setId(spellData.id)
        spellWidget:setText(spellName.."\n"..spellData.words.."  -  Level "..spellData.level..((spellData.maglevel or 0) > 0 and (", ML "..spellData.maglevel) or ""))
        spellWidget.level = spellData.level
        spellWidget.maglevel = spellData.maglevel or 0
        spellWidget.voc = spellData.vocations
        spellWidget.param = spellData.parameter
        spellWidget.source = SpelllistSettings['Default'].iconFile
        spellWidget.clip = Spells.getImageClip(SpellIcons[spellData.icon][1], 'Default')
        spellWidget.image:setImageSource(spellWidget.source)
        spellWidget.image:setImageClip(spellWidget.clip)

        spellWidget.spellData = {
          words = spellData.words,
          cd = spellData.exhaustion/1000,
          mana = spellData.mana,
          source = spellWidget.source,
          clip = spellWidget.clip,
          name = spellName,
          param = spellData.parameter,
          group = spellGroups(spellData),
          id = spellData.id
        }
      end
    end

    -- sort by level, then magic level, then name
    local widgets = spellWindow.spellList:getChildren()
    table.sort(widgets, function(a, b)
      if a.level ~= b.level then return a.level < b.level end
      if a.maglevel ~= b.maglevel then return a.maglevel < b.maglevel end
      return a.spellData.name < b.spellData.name
    end)
    for i, child in ipairs(widgets) do
      spellWindow.spellList:moveChildToIndex(child, i)
    end

    -- select the spell this button already has, or the first one
    if #widgets > 0 then
      radio:selectWidget(widgets[1])
    end

    local currentSpell = widget.spellData and widget.spellData.id or 0
    if currentSpell > 0 then
      for i, child in ipairs(radio.widgets) do
        if child.spellData.id == currentSpell then
          spellWindow.spellList:ensureChildVisible(child)
          radio:selectWidget(child)
          break
        end
      end
    end
  end

  -- ask the server which spells the character knows
  local body = {action = 'spells', character = player and player:getName() or '', account = G.account, password = G.password}
  HTTP.postJSON(SPELLS_API, body, function(data, err)
    if type(data) == 'table' and data.ok then
      local learned = {}
      for _, name in ipairs(data.learned or {}) do
        learned[normalizeSpellName(name)] = true
      end
      populate({vocation = tonumber(data.vocation) or 0, promotion = tonumber(data.promotion) or 0, learned = learned})
    else
      populate(nil)
    end
  end)

  -- callback
  radio.onSelectionChange = function(widget, selected)
    if selected then
      local name = selected:getText()
      local source = selected.source
      local clip = selected.clip
      local param = selected.param

      -- preview
      window.preview:setText(name)
      window.preview.image:setImageSource(source)
      window.preview.image:setImageClip(clip)

      -- param
      window.paramLabel:setOn(param)
      window.paramText:setEnabled(param)
      window.spellList:ensureChildVisible(widget)
    end
  end

  local okFunc = function(destroy)
    local selected = radio:getSelectedWidget()
    local paramWidgetText = window.paramText:getText()
    if not selected then return end

    selected.spellData.param = paramWidgetText

    local hotkey = settings[widget:getId()] and settings[widget:getId()].hotkey
    if hotkey and hotkey:len() > 0 and widget.callback then
      local gameRootPanel = modules.game_interface.getRootPanel()
      g_keyboard.unbindKeyPress(widget.hotkey, widget.callback, gameRootPanel)
    end

    settings[widget:getId()] = {hotkey=hotkey}
    settings[widget:getId()].spellData = selected.spellData
    settings[widget:getId()].type = TYPE.SPELL

    if destroy then
      window:destroy()
    end
    setupButton(widget)
  end
  local cancelFunc = function()
    window:destroy()
    setupButton(widget)
  end

  window.buttonOk.onClick = function() okFunc(true) end
  window.buttonApply.onClick = function() okFunc(false) end
  window.buttonClose.onClick = cancelFunc
  window.onEscape = cancelFunc
  window.onEnter = function() okFunc(true) end

  local actionbar = widget:getParent():getParent()
  if actionbar.locked then
    cancelFunc()
  end
end

function assignHotkey(widget)
  destroyAssignWindows()

  -- create window
  window = g_ui.loadUI('hotkey', g_ui.getRootWidget())
  window:show()
  window:raise()
  window:focus()

  local barN = widget:getParent():getParent().n
  local barDesc
  if barN < 4 then
    barDesc = "Bottom"
  elseif barN < 7 then
    barDesc = "Left"
  else
    barDesc = "Right"
  end

  -- things
  barDesc = barDesc.." Action Bar: Action Button "..widget:getId()
  window:setText('Edit Hotkey for "'..barDesc)
  window.desc:setText(window.desc:getText()..barDesc..'"')
  window.display:setText(widget.hotkey or "")
  
  -- hotkey
  window:grabKeyboard()
  window.onKeyDown = function(window, keyCode, keyboardModifiers)
    local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers)
    window.display:setText(keyCombo)
    return true
  end

  local okFunc = function() 
    local hotkey = window.display:getText()

    unbindButton(widget)
    settings[widget:getId()] = settings[widget:getId()] or {}
    settings[widget:getId()].hotkey = hotkey
  
    window:destroy()
    setupButton(widget)
  end
  local clearFunc = function() 
    window.display:setText('')
    local hotkey = window.display:getText()

    unbindButton(widget)
    settings[widget:getId()] = settings[widget:getId()] or {}
    settings[widget:getId()].hotkey = hotkey
  
    window:destroy()
    setupButton(widget)
  end
  local closeFunc = function() 
    window:destroy()
    setupButton(widget)
  end

  window.buttonOk.onClick = okFunc
  window.buttonClear.onClick = clearFunc
  window.buttonClose.onClick = closeFunc

  local actionbar = widget:getParent():getParent()
  if actionbar.locked then
    closeFunc()
  end
end

function setupAction(widget)
  if widget.type == TYPE.BLANK then 
    return
  end
  if widget.type == TYPE.TEXT then
    widget.callback = function()
      if modules.game_interface.isChatVisible() then
        if widget.autoSay then
          modules.game_console.sendMessage(widget.sayText)
        else
          modules.game_console.setTextEditText(widget.sayText)
        end
      elseif widget.autoSay then
        g_game.talk(widget.sayText)
      end
    end
  elseif widget.type == TYPE.ACTION then
    widget.callback = function()
      runGameAction(widget.gameAction, widget.gameFilter)
    end
  elseif widget.type == TYPE.SPELL then
    widget.callback = function()
      if g_app.isMobile() then -- turn to direction of targer
        local target = g_game.getAttackingCreature()
        if target then
          local pos = g_game.getLocalPlayer():getPosition()
          local tpos = target:getPosition()
          if pos and tpos then
            local offx = tpos.x - pos.x
            local offy = tpos.y - pos.y
            if offy < 0 and offx <= 0 and math.abs(offx) < math.abs(offy) then
              g_game.turn(Directions.North)
            elseif offy > 0 and offx >= 0 and math.abs(offx) < math.abs(offy) then
              g_game.turn(Directions.South)
            elseif offx < 0 and offy <= 0 and math.abs(offx) > math.abs(offy) then
              g_game.turn(Directions.West)
            elseif offx > 0 and offy >= 0 and math.abs(offx) > math.abs(offy) then
              g_game.turn(Directions.East)
            end
          end
        end
      end
      local paramText 
      if widget.spellData.param and widget.spellData.param:len() > 0 then
        paramText = ' "'.. widget.spellData.param ..'"' 
      else 
        paramText = ""
      end
      g_game.talk(widget.spellData.words..paramText)
    end
  elseif widget.type == TYPE.ITEM then
    widget.callback = function()
      if widget.action == ACTION.BLANK then
        return
      elseif widget.action == ACTION.EQUIP then
        if g_game.getClientVersion() >= 910 then
          local item = Item.create(widget.item:getItemId())
          return g_game.equipItem(item)
        end
      elseif widget.action == ACTION.USE then
        if g_game.getClientVersion() < 780 then
          local item = g_game.findPlayerItem(widget.item:getItemId(), widget.item:getItemSubType() or -1)
          if item then
            g_game.use(item)
          end
        else
          g_game.useInventoryItem(widget.item:getItemId())
        end
      elseif widget.action == ACTION.USE_SELF then
        if g_game.getClientVersion() < 780 then
          local item = g_game.findPlayerItem(widget.item:getItemId(), widget.item:getItemSubType() or -1)
          if item then
            g_game.useWith(item, g_game.getLocalPlayer())
          end
        else
          g_game.useInventoryItemWith(widget.item:getItemId(), g_game.getLocalPlayer(), widget.item:getItemSubType() or -1)
        end
      elseif widget.action == ACTION.USE_TARGET then
        local attackingCreature = g_game.getAttackingCreature()
        if not attackingCreature then
          local item = Item.create(widget.item:getItemId())
          if g_game.getClientVersion() < 780 then
            local tmpItem = g_game.findPlayerItem(widget.item:getItemId(), widget.item:getItemSubType() or -1)
            if not tmpItem then return end
            item = tmpItem
          end
          modules.game_interface.startUseWith(item, widget.item:getItemSubType() or - 1)
          return
        end
        if not attackingCreature:getTile() then return end
        if g_game.getClientVersion() < 780 then
          local item = g_game.findPlayerItem(widget.item:getItemId(), widget.item:getItemSubType() or -1)
          if item then
            g_game.useWith(item, attackingCreature, widget.item:getItemSubType() or -1)
          end
        else
          g_game.useInventoryItemWith(widget.item:getItemId(), attackingCreature, widget.item:getItemSubType() or -1)
        end
      elseif widget.action == ACTION.USE_CROSS then
        local item = Item.create(widget.item:getItemId())
        if g_game.getClientVersion() < 780 then
          local tmpItem = g_game.findPlayerItem(widget.item:getItemId(), widget.item:getItemSubType() or -1)
          if not tmpItem then return true end
          item = tmpItem
        end
        modules.game_interface.startUseWith(item, widget.item:getItemSubType() or - 1)
      end
    end
  end

  if widget.hotkey and widget.hotkey:len() > 0 and widget.callback then
    local action, hotkey = widget.callback, widget.hotkey
    widget.keyCallback = function()
      if not keyBelongsToChat(hotkey) then
        action()
      end
    end
    g_keyboard.bindKeyPress(hotkey, widget.keyCallback, modules.game_interface.getRootPanel())
  end
end

function onSpellCooldown(iconId, duration)
  for index, actionbar in ipairs(actionBars) do
    for i, child in ipairs(actionbar.tabBar:getChildren()) do
      if child.type == 2 and child.spellData.id == iconId then
        startCooldown(child, duration)
      end
    end
  end
end

function onSpellGroupCooldown(groupId, duration)
  for index, actionbar in ipairs(actionBars) do
    for i, child in ipairs(actionbar.tabBar:getChildren()) do
      if child.type == 2 and child.spellData.group then
        for i, group in ipairs(child.spellData.group) do
          if groupId == group then
            startCooldown(child, duration)
          end
        end
      end
    end
  end
end

function startCooldown(action, duration)
  if type(action.cooldownTill) == 'number' and action.cooldownTill > g_clock.millis() + duration then
    return -- already has cooldown with greater duration
  end
  action.cooldownStart = g_clock.millis()
  action.cooldownTill = g_clock.millis() + duration
  updateCooldown(action)
end

function updateCooldown(action)
  if not action or not action.cooldownTill then return end
  local timeleft = action.cooldownTill - g_clock.millis()
  if timeleft <= 50 then
    action.cooldown:setPercent(100)
    action.cooldownEvent = nil
    action.cooldown:setText("")
    return
  end
  local duration = action.cooldownTill - action.cooldownStart
  local formattedText
  if timeleft > 60000 then
    formattedText = math.floor(timeleft / 60000) .. "m"
  else
    formattedText = timeleft/1000
    formattedText = math.floor(formattedText * 10) / 10
    formattedText = math.floor(formattedText) .. "." .. math.floor(formattedText * 10) % 10
  end

  local retry
  if timeleft > 60000 then
    retry = math.min(math.floor(timeleft * 0.1), 60 * 1000) -- max 1min
    retry = math.max(retry, 100) -- min 100
  elseif timeleft > 1000 then
    retry = 100
  else
    retry = 30
  end
  action.cooldown:setText(formattedText) 
  action.cooldown:setPercent(100 - math.floor(100 * timeleft / duration))
  action.cooldownEvent = scheduleEvent(function() updateCooldown(action) end, retry)
end

function save()
  if settingsFile == "" then
    return
  end

  local status, result = pcall(function() return json.encode(settings, 2) end)
  if not status then
      return g_logger.error(
                 "Error while saving top bar settings. Data won't be saved. Details: " ..
                     result)
  end

  if result:len() > 100 * 1024 * 1024 then
      return g_logger.error(
                 "Something went wrong, file is above 100MB, won't be saved")
  end

  g_resources.writeFileContents(settingsFile, result)
end

function load()
  if g_resources.fileExists(settingsFile) then
      local status, result = pcall(function()
          return json.decode(g_resources.readFileContents(settingsFile))
      end)
      if not status then
          return g_logger.error(
                     "Error while reading top bar settings file. To fix this problem you can delete storage.json. Details: " ..
                         result)
      end
      settings = result
  else
      settings = {}
  end
end