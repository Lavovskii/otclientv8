-- ForgottenL guides: a window with one tab per subject; every tab is a list of cards, each with a drawing (an Art*
-- style of guides.otui) and a few words. The button is the first of the buttons window, and the inventory has a
-- Guides button too, under Options.

local guidesWindow, guidesButton

local GUIDES = {
  {
    name = 'Action Bars',
    cards = {
      {art = 'ArtBars', title = 'Your action bars',
       text = 'Put spells, runes, items and actions in the slots. Press the key of a slot (or click it) to use it.'},
      {art = 'ArtRightClick', title = 'Fill a slot',
       text = 'Right click any slot and choose what it does.'},
      {art = 'ArtSpell', title = 'Spell',
       text = 'Assign Spell: pick one of your spells. Only the spells your vocation can cast are listed.'},
      {art = 'ArtObject', title = 'Object',
       text = 'Drag a rune, potion or item from your backpack onto a slot, then choose how to use it.'},
      {art = 'ArtText', title = 'Text',
       text = 'Assign Text: the slot says it for you. Tick "Send automatically" to say it at once.'},
      {art = 'ArtAction', title = 'Action',
       text = 'Assign Action: loot, attack the next or previous target, open or close a door, stop attacking, use what is under you. Point at one to see what it does.'},
      {art = 'ArtHotkey', title = 'Hotkey',
       text = 'Right click a slot, choose Assign Hotkey and press any key or combination (Ctrl, Shift, Alt).'},
      {art = 'ArtChat', title = 'Chat On / Off',
       text = 'You start with the chat off: letters, numbers and Space run your hotkeys and W A S D walk. Press Enter to say one thing. Click Chat Off to keep the chat on. F1-F12 always work.'},
      {art = 'ArtTips', title = 'Tips',
       text = 'Lock a bar so nothing moves by mistake. Drag a slot onto another to swap them. Options > Custom shows up to 9 bars.'},
    }
  },
  {
    -- Ctrl+K opens this tab; the drawings are the keys of each card (keys: the shortcut and what it does)
    name = 'Hotkeys',
    cards = {
      {art = 'ArtKeys', title = 'This guide', keys = {{'Ctrl+K', 'Hotkeys guide'}},
       text = 'Ctrl+K opens this tab of the Guides at any time in the game. Press it again to close it.'},
      {art = 'ArtKeys', title = 'Health and mana circles', keys = {{'Ctrl+Shift+B', 'Circles on / off'}},
       text = 'Ctrl+Shift+B hides the health and mana circles around your character. Press it again to bring them back. Options > Custom has the same switch.'},
      {art = 'ArtKeys', title = 'Windows', keys = {{'Ctrl+B', 'Battle'}, {'Ctrl+M', 'Minimap'}, {'Ctrl+P', 'VIP list'}},
       text = 'Each key opens its window, and closes it when it is open. Ctrl+Shift+M shows the whole map; Ctrl+I shows or hides your inventory.'},
      {art = 'ArtKeys', title = 'Chat', keys = {{'Ctrl+O', 'Channels'}, {'Ctrl+E', 'Close channel'}, {'Ctrl+H', 'Help channel'}},
       text = 'Ctrl+O lists the channels you can open; Ctrl+E closes the tab you are in; Ctrl+H opens the Help channel.'},
      {art = 'ArtKeys', title = 'Screen', keys = {{'Ctrl+N', 'Names and bars'}, {'Ctrl+W', 'Clear texts'}, {'Ctrl+Shift+F', 'Full screen'}},
       text = 'Ctrl+N hides the names, then the health bars, then brings them back. Ctrl+W clears the texts on the screen. Ctrl+Shift+F switches full screen.'},
      {art = 'ArtKeys', title = 'Logout', keys = {{'Ctrl+Q', 'Logout'}, {'Ctrl+L', 'Logout'}},
       text = 'Either key logs your character out (not during a fight).'},
    }
  },
  {
    name = 'Loot',
    cards = {
      {art = 'ArtLootKey', title = 'Loot key',
       text = 'Stand next to the monsters you killed and press your Loot key: everything goes to your loot bag at once.'},
      {art = 'ArtLootBag', title = 'Loot bag',
       text = 'Right click the backpack that gets the loot. When it is full, the loot goes to your main backpack.'},
      {art = 'ArtIgnore', title = 'Ignore loot list',
       text = 'Right click an item you never want: the Loot key leaves it behind. Right click it again to take it back.'},
      {art = 'ArtLootChannel', title = 'Loot channel',
       text = 'Everything you loot, and every loot message, is written in the Loot channel, not in Server Log.'},
    }
  },
  {
    name = 'Items',
    cards = {
      {art = 'ArtBrowse', title = 'Browse Field',
       text = 'Right click a tile and choose Browse Field: you walk to it and see every item on it, 40 per page.'},
      {art = 'ArtStacks', title = 'Stacks',
       text = 'Dragging moves the whole stack. Hold Ctrl while you drag to choose how many.'},
      {art = 'ArtEmpty', title = 'Empty backpack',
       text = 'Right click a backpack and choose Empty backpack: everything inside drops on the floor (it asks first).'},
    }
  },
  {
    name = 'Interface',
    cards = {
      {art = 'ArtWindows', title = 'Your screen stays as you left it',
       text = 'Move, resize and minimize your windows and open your backpacks: at the next login, even days later, everything is back in its place. Each character keeps its own.'},
      {art = 'ArtSkills', title = 'Skills window',
       text = 'Everything about your character, in sections: skills, combat (attack, defence, armor, protections), VIP, Super VIP and boosters. Hold the mouse over a line to see what it means.'},
      {art = 'ArtStats', title = 'Real health, mana and stats',
       text = 'Your true numbers, also above 65,535. The circles around you show health and mana in percent (Ctrl+Shift+B hides or shows them); capacity shows 14k for 14,000.'},
      {art = 'ArtGuidesButton', title = 'Guides',
       text = 'The golden button, first of the buttons window, opens these guides. The inventory has a Guides button too, under Options.'},
    }
  },
  {
    name = 'Spells',
    cards = {
      {art = 'ArtSpells', title = 'Your spells',
       text = 'The Spells button lists only the spells of your vocation, by level. The tabs show Attack, Healing or Support. Faded spells need a higher level.'},
      {art = 'ArtSpellDemo', title = 'See a spell',
       text = 'Click a spell: a small demo shows its missile, effect and area as they look in the game. Replay plays it again.'},
    }
  },
  {
    name = 'Store',
    cards = {
      {art = 'ArtStoreButton', title = 'Open the Store',
       text = 'Click the Store button on the right, under your equipment.'},
      {art = 'ArtStorePoints', title = 'Points',
       text = 'Your points are at the top of the Store. Buy Points opens the website, where you get more.'},
      {art = 'ArtStoreBuy', title = 'Choose and buy',
       text = 'Pick a category and click an offer to see its price and what it does. Buy asks before it takes your points.'},
      {art = 'ArtStoreDelivery', title = 'Delivery',
       text = 'Choose which of your characters gets it: it lands in their backpack within seconds, or at their next login. No room or capacity? It waits and arrives by itself.'},
    }
  },
}

-- the item and creature sprites of a drawing (set from Lua: the OTUI only names them)
local function fillArt(art)
  for _, child in ipairs(art:recursiveGetChildren()) do
    if child.itemId then
      child:setItemId(tonumber(child.itemId))
      if child.itemCount then
        child:setItemCount(tonumber(child.itemCount))
      end
    end
    if child.outfitType then
      child:setOutfit({type = tonumber(child.outfitType), head = 78, body = 69, legs = 58, feet = 76})
    end
  end
end

-- the keys of a Hotkeys card: one line per shortcut, its keys ("Ctrl+Shift+B" as Ctrl + Shift + B) and what it does
local function fillKeys(art, keys)
  for _, shortcut in ipairs(keys) do
    local row = g_ui.createWidget('GuideKeyRow', art)
    for i, key in ipairs(shortcut[1]:split('+')) do
      if i > 1 then
        g_ui.createWidget('GuideKeyPlus', row)
      end
      g_ui.createWidget('GuideKey', row):setText(key)
    end
    g_ui.createWidget('GuideKeyNote', row):setText(tr(shortcut[2]))
  end
end

local guideTabs = {}

local function build()
  guidesWindow = g_ui.displayUI('guides')
  guidesWindow:hide()

  local tabBar = guidesWindow:getChildById('guidesTabBar')
  tabBar:setContentWidget(guidesWindow:getChildById('guidesTabContent'))
  for _, guide in ipairs(GUIDES) do
    local page = g_ui.createWidget('GuidePage')
    for _, info in ipairs(guide.cards) do
      local card = g_ui.createWidget('GuideCard', page.cards)
      card.title:setText(tr(info.title))
      card.text:setText(tr(info.text))
      local art = g_ui.createWidget(info.art, card.art)
      fillArt(art)
      if info.keys then
        fillKeys(art, info.keys)
      end
    end
    guideTabs[guide.name] = tabBar:addTab(tr(guide.name), page)
  end
end

-- the Guides button comes first in the buttons window, in a thin golden frame with a shine running around it: the
-- frames of data/images/ui/guides_glow.png (GLOW_FRAMES of GLOW_SIZE x GLOW_SIZE side by side, tools/gen_guides_glow.py)
-- one after the other
local GLOW_FRAMES, GLOW_SIZE, GLOW_FRAME_MS = 42, 24, 45
local glowEvent
local function glow()
  local frame = guidesButton and guidesButton:getChildById('glow')
  if not frame then
    glowEvent = nil
    return
  end
  local i = math.floor(g_clock.millis() / GLOW_FRAME_MS) % GLOW_FRAMES
  frame:setImageClip({x = i * GLOW_SIZE, y = 0, width = GLOW_SIZE, height = GLOW_SIZE})
  glowEvent = scheduleEvent(glow, GLOW_FRAME_MS)
end

local function onGameStart()
  if not glowEvent then glow() end
end

local function onGameEnd()
  removeEvent(glowEvent)
  glowEvent = nil
  hide()
end

function init()
  guidesButton = modules.client_topmenu.addLeftGameButton('guidesButton', tr('Guides'), '/images/topbuttons/guides', toggle, false, 0)
  local frame = g_ui.createWidget('UIWidget', guidesButton)
  frame:setId('glow')
  frame:setPhantom(true)
  frame:setSize({width = GLOW_SIZE, height = GLOW_SIZE})
  frame:setImageSource('/images/ui/guides_glow')
  frame:setImageClip({x = 0, y = 0, width = GLOW_SIZE, height = GLOW_SIZE})
  frame:centerIn('parent')
  connect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  if g_game.isOnline() then onGameStart() end
  g_keyboard.bindKeyDown('Ctrl+K', toggleHotkeys)
end

function terminate()
  g_keyboard.unbindKeyDown('Ctrl+K')
  removeEvent(glowEvent)
  glowEvent = nil
  disconnect(g_game, {onGameStart = onGameStart, onGameEnd = onGameEnd})
  if guidesWindow then
    guidesWindow:destroy()
    guidesWindow = nil
  end
  if guidesButton then
    guidesButton:destroy()
    guidesButton = nil
  end
end

function show()
  if not guidesWindow then
    build() -- built on first use: the sprites need the game data, which is loaded by then
  end
  guidesWindow:show()
  guidesWindow:raise()
  guidesWindow:focus()
end

function hide()
  if guidesWindow then
    guidesWindow:hide()
  end
end

function toggle()
  if guidesWindow and guidesWindow:isVisible() then
    hide()
  else
    show()
  end
end

-- Ctrl+K: the Guides on the Hotkeys tab, or closed when they already show it
function toggleHotkeys()
  if not g_game.isOnline() then
    return
  end
  local tabBar = guidesWindow and guidesWindow:getChildById('guidesTabBar')
  if tabBar and guidesWindow:isVisible() and tabBar:getCurrentTab() == guideTabs['Hotkeys'] then
    hide()
    return
  end
  show()
  guidesWindow:getChildById('guidesTabBar'):selectTab(guideTabs['Hotkeys'])
end
