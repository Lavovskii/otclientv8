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
       text = 'Right click a slot and choose Assign Spell: your spells open. Drag any of them onto a slot of any bar, or pick one and press Assign.'},
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
      {art = 'ArtKeys', title = 'Rules', keys = {{'!rules', 'Rules and terms'}},
       text = 'Say !rules in any chat to open the rules of the game, your responsibility for your items, and the donation terms.'},
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
       text = 'Everything about your character, in sections: skills, combat (attack, defence, armor, protections), VIP and boosters. A green number is raised by something: hold the mouse over it to see where each part comes from. The experience rate adds up like in Tibia: Raw Exp Rate 100%%, Stamina Bonus +50%% (VIP, 39 hours or more), Daily Streak Bonus and Exp Boost.'},
      {art = 'ArtStats', title = 'Real health, mana and stats',
       text = 'Your true numbers, also above 65,535. The circles around you show health and mana in percent (Ctrl+Shift+B hides or shows them); capacity shows 14k for 14,000.'},
      {art = 'ArtSetBonus', title = 'Set bonus',
       text = 'Wear every piece of a set of your vocation, its helmet, armor, legs, boots and shield (a quiver for paladins, a spellbook for mages), and its bonus turns on: protection against all damage. A banner tells you, the Skills window shows it, and taking off any piece turns it off. Your weapon does not count. Against a knight, a paladin has 25%% less defence and 25%% more damage, a mage 50%%. Sets go from tier 1 to tier 6, and monsters of higher levels drop higher tiers.'},
      {art = 'ArtHands', title = 'Your hands',
       text = 'Weapons go in the left hand, and shields, quivers and spellbooks in the right. Every weapon takes one hand, bows too. A bow or a crossbow fires by itself: you need no arrows or bolts. The wands of the sets use no mana.'},
      {art = 'ArtPlate', title = 'Frame rate and ping',
       text = 'The plate in the corner of the map. FPS: the pictures your client draws each second. Ping: how long a message takes to reach the server and come back. More bars are better, one red bar means lag. Options, Graphics and Interface can hide them.'},
      {art = 'ArtCircles', title = 'Your circles, your way',
       text = 'Hold Alt with the mouse over a health or mana circle: a small window opens. Drag the circle anywhere on the screen, with Shift to move both. The wheel changes its size and Ctrl with the wheel how see-through it is. Reset puts it back. The same window is under Options, Custom.'},
      {art = 'ArtGuidesButton', title = 'Guides',
       text = 'The golden button, first of the buttons window, opens these guides. The inventory has a Guides button too, under Options.'},
      {art = 'ArtMonsterLevel', title = 'Monster levels',
       text = 'Each monster of a hunt has its own level next to its name, like MindFreak [L. 4691]. A higher level means more health and damage, but also more experience and a better chance of loot.'},
      {art = 'ArtEchoes', title = 'Echoes',
       text = 'A monster you kill may leave an echo on the ground for 2 minutes. Step on it: usually 6 stronger monsters of that kind wake up, rarely one boss with a red glow, 10x the experience and much better loot.'},
      {art = 'ArtBossReward', title = 'Boss loot',
       text = 'Everyone who fights a boss gets their own loot. Open the bag in its corpse and take items one by one, or right click the bag and choose Loot all. What you leave waits 7 days in the reward chest, in the depot room under the temple, with one bag for each boss. The bags themselves stay where they are.'},
      {art = 'ArtChess', title = 'Chess Arena',
       text = 'Use a chessboard to open the Chess Arena: the top 5 of every mode, Find Match for a random player (Bullet, Blitz, Rapid, Classic, Chess960) or Player vs Co.Op against the house. A win gives minigame points: 5 against a player, 3 against Co.Op, if the game was a real one. You never meet the same player twice in a row. Settings: your pieces, your board and how the game helps you.'},
      {art = 'ArtBlessings', title = 'Blessings',
       text = 'The small ankh beside the minimize button of your inventory shows your blessings: red with none, yellow with some, green with all five. Click it to see each one. With all five you keep every item when you die; they are lost with the death. Buy them with !bless or in the Store.'},
      {art = 'ArtBossBar', title = 'Boss bar',
       text = 'Attack a boss and a big bar fades in at the top of the game, where your health and mana bars were: its picture, its kind (World, Event, Quest, Echo...), its name, its level and its health, exact. The lighter part is the damage just done. Stop attacking, or kill it, and the bar fades away. Your own health and mana stay beside your inventory and in the circles.'},
      {art = 'ArtMagicChest', title = 'Magic chest',
       text = 'One floor above the temple stands the magic chest. Use a key from the hunts on it, or standing beside it: its lid floats open and gives you set pieces and weapons of the tier of the key, in a backpack. Bronze 10 of tier 1, Iron 8 of tier 2, Silver 6 of tier 3, Gold 4 of tier 4, Prestige 2 of tier 5, Corrupt Prestige 1 of tier 6. The key is used up.'},
      {art = 'ArtDailyRewards', title = 'Daily Rewards',
       text = 'Use a reward shrine to open Daily Rewards and claim one reward a day, between two server saves (08:00 UTC). Days in a row build your streak, and its bonuses (more health and mana, +10%% experience) last while it does. Miss a day and you start again at day 1. Bound rewards stay with you.'},
      {art = 'ArtPromotion', title = 'Promotion',
       text = 'From level 30,000, use the sacred fountain to choose your promotion: the offensive path (+12%% damage) or the defensive path (+6%% damage and 6%% less damage taken). Both raise skills and magic level twice as fast and keep every spell, rune and item of your vocation. You choose once, and forever.'},
      {art = 'ArtTiers', title = 'Item tiers',
       text = 'Every item with a tier shows it everywhere (backpacks, inventory, Inspect, stash, loot): its slot takes the tier\'s colour, with a bright edge and corners. Tier 1 white, tier 2 green, tier 3 blue, tier 4 purple, tier 5 gold, tier 6 red.'},
      {art = 'ArtStash', title = 'Depot, stash and inbox',
       text = 'Every depot locker is the same depot, in any town. It holds the depot chest with 20 depot boxes, your inbox and your supply stash. Mail and parcels arrive in the inbox (only the name on the letter is needed); take things out of it, nothing can be put in. Next to a locker, right click an item you carry and choose Stow (or Stow all items of this type, or Stow container\'s content): the supply stash keeps any number of items in unused condition and does not count for the depot limit. Use the supply stash to search, filter, sort and take items out.'},
      {art = 'ArtGeneralStore', title = 'ForgottenL General Store',
       text = 'Say hi and then trade to the ForgottenL General Store: its window has BUY and SELL, each with the same categories (Equipment, Weapons, Runes, Tools...). Some things cost gold, others Buffary Coins. Gold is taken from what you carry and then from your bank. The store buys at a third of the price, from your backpack only, and gold goes to your bank. VIP players sell at two thirds.'},
      {art = 'ArtInspect', title = 'Inspect',
       text = 'Right click a player or a monster on your screen (or in the battle list) and choose Inspect. A player: everything it wears and its stats (level, health, mana, skills, attack, defence, protections, set bonus). A monster: every item it can drop, the loot keys too, without the chances.'},
      {art = 'ArtLootColors', title = 'Loot colours',
       text = 'In every loot message each item has the colour of its rarity: green common, blue uncommon, purple rare, gold very rare, pink unique or bound to you. Every monster can drop magic chest keys: Bronze from any monster, Iron above level 100, Silver above 1,000, Gold above 10,000, Prestige above 50,000 and Corrupt Prestige only from world bosses.'},
      {art = 'ArtNpcTalk', title = 'Talk to NPCs',
       text = 'Right click an NPC to greet it, as if you said hi: the conversation starts in the NPC channel. Stand within 3 sqm of it. With classic controls off, right click an NPC and choose Talk. Then click the blue words of its answer (trade, travel, passage...) to say them, no keyboard needed.'},
      {art = 'ArtBigNames', title = 'Names on big outfits',
       text = 'Big creatures, NPCs, mounts and outfits have their name and health bar on top of their head, not in the middle of their body, as on a normal character.'},
      {art = 'ArtTaskBoard', title = 'Task Board',
       text = 'Open it in the top menu. Bounty: one random creature, claim the reward when it is done, and claim one free reroll a day. Weekly: 6 creatures and 6 items to deliver, 9 of each with the Weekly Tasks Expansion in the Store. You deal 20%% more damage to the creatures of your open tasks. Tasks pay experience and Task Points for the Task Shop: 2 for every kill task, the bounty too, and 1 for every delivery. The Task Shop sells the Mini Health and Mini Mana Booster for 10 Task Points and the Mini Ozzo Booster for 15.'},
      {art = 'ArtVipDays', title = 'VIP days',
       text = 'Before you log in, the character list shows how many VIP days the selected character has left. In red when 7 or fewer remain.'},
      {art = 'ArtStaffName', title = 'The staff',
       text = 'A name in red gothic letters with a gold health bar is a member of the staff: gamemasters and above. Nobody else can have it, and the staff never asks for your password.'},
      {art = 'ArtReborn', title = 'The Reborn look',
       text = 'Stone, bronze and gold in every window: this is the look of ForgottenL now. If you prefer the old grey one, choose Retro under Options, Interface, Layout, and restart the client.'},
      {art = 'ArtUpdater', title = 'Updates',
       text = 'Each time you open the client or log in it looks for an update and installs it by itself, new game graphics too: only what changed is downloaded, then the client restarts on its own. Nothing to click or install.'},
    }
  },
  {
    name = 'Spells',
    cards = {
      {art = 'ArtSpells', title = 'Your spells',
       text = 'Assign Spell, on the right click of an action bar slot, lists only the spells of your vocation, by level. The tabs show Attack, Healing or Support. Faded spells need a higher level.'},
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
       text = 'Your donation points are at the top of the Store and beside every price, with the red ForgottenL Coin. Buy Points opens the website, where you get more. A ForgottenL Coin you loot or win is used from your backpack: it adds its points to your account.'},
      {art = 'ArtStoreBuy', title = 'Choose and buy',
       text = 'Pick a category and click an offer to see its price and what it does. Buy asks before it takes your points.'},
      {art = 'ArtStoreDelivery', title = 'Delivery',
       text = 'Choose which of your characters gets it: it lands in their backpack within seconds, or at their next login. No room or capacity? It waits and arrives by itself.'},
      {art = 'ArtStoreBuy', title = 'Outfits, mounts and XP Boost',
       text = 'Outfits come with both addons and mounts are ready to ride: open Set Outfit after buying. Something the character already has is refunded. The XP Boost gives 50%% more experience for an hour; it costs 30, 45, 90, 180 and 360 points for the 1st to 5th of the day, and resets at 10:00.'},
      {art = 'ArtStoreBuy', title = 'Extras and VIP time',
       text = 'Extras has a Name Change (a scroll: say !newname Your New Name), a Sex Change (you are logged out and come back changed), All Blessings, the Temple Teleport scroll and the Gold Converter (use it on coins). Premium sells VIP time for 30 to 360 days.'},
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
    if child.statsFps and modules.game_stats and modules.game_stats.drawPlate then
      modules.game_stats.drawPlate(child, child.statsFps, child.statsPing)
    end
    if child.circleKey and modules.game_healthinfo and modules.game_healthinfo.drawCircleInto then
      modules.game_healthinfo.drawCircleInto(child, child.circleKey, 100, tonumber(child.circleLevel) or 100, tostring(child.circleColor))
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

-- a long text makes its card taller: the height in the OTUI holds four lines, and a label only knows its height once drawn
local function fitCards()
  local tabBar = guidesWindow and guidesWindow:getChildById('guidesTabBar')
  local page = tabBar and tabBar:getCurrentTabPanel()
  if not page or not page.cards then return end
  for _, card in ipairs(page.cards:getChildren()) do
    local needed = card.text:getY() - card:getY() + card.text:getHeight() + 8
    if needed > card:getHeight() then
      card:setHeight(needed)
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
      local art = g_ui.createWidget(info.art, card.art)
      fillArt(art)
      if info.keys then
        fillKeys(art, info.keys)
      end
    end
    guideTabs[guide.name] = tabBar:addTab(tr(guide.name), page)
  end
  tabBar.onTabChange = function() scheduleEvent(fitCards, 60) end
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
  scheduleEvent(fitCards, 60)
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
