-- ForgottenL guides: a window with one tab per subject; every tab is a list of cards, each with a drawing (an Art*
-- style of guides.otui) and a few words. The button sits next to the Quest Tracker.

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
       text = 'Assign Action: loot, attack the next target, open or close a door, stop attacking, use what is under you. Point at one to see what it does.'},
      {art = 'ArtHotkey', title = 'Hotkey',
       text = 'Right click a slot, choose Assign Hotkey and press any key or combination (Ctrl, Shift, Alt).'},
      {art = 'ArtChat', title = 'Chat On / Off',
       text = 'You start with the chat off: letters, numbers and Space run your hotkeys and W A S D walk. Press Enter to say one thing. Click Chat Off to keep the chat on. F1-F12 always work.'},
      {art = 'ArtTips', title = 'Tips',
       text = 'Lock a bar so nothing moves by mistake. Drag a slot onto another to swap them. Options > Custom shows up to 9 bars.'},
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
       text = 'Everything you loot is written in the Loot channel.'},
    }
  },
  {
    name = 'Items',
    cards = {
      {art = 'ArtBrowse', title = 'Browse Field',
       text = 'Right click a tile next to you and choose Browse Field to see every item on it, 40 per page.'},
      {art = 'ArtStacks', title = 'Stacks',
       text = 'Dragging moves the whole stack. Hold Ctrl while you drag to choose how many.'},
      {art = 'ArtEmpty', title = 'Empty backpack',
       text = 'Right click a backpack and choose Empty backpack: everything inside drops on the floor (it asks first).'},
    }
  },
}

-- the item sprites of a drawing (set from Lua: the OTUI only names them)
local function fillArt(art)
  for _, child in ipairs(art:recursiveGetChildren()) do
    if child.itemId then
      child:setItemId(tonumber(child.itemId))
      if child.itemCount then
        child:setItemCount(tonumber(child.itemCount))
      end
    end
  end
end

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
      fillArt(g_ui.createWidget(info.art, card.art))
    end
    tabBar:addTab(tr(guide.name), page)
  end
end

function init()
  guidesButton = modules.client_topmenu.addLeftGameButton('guidesButton', tr('Guides'), '/images/topbuttons/guides', toggle, false, 10)
  connect(g_game, {onGameEnd = hide})
end

function terminate()
  disconnect(g_game, {onGameEnd = hide})
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
