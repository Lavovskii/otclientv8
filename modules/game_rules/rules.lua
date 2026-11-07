-- ForgottenL: the !rules window (opcode RULES_OPCODE "open") and the Yes/No questions the server asks (opcode
-- CONFIRM_OPCODE "<id>\t<title>\t<text>", answered with "<id>\tyes" or "<id>\tno"). Server side:
-- data/lib/119-confirm-and-rules.lua.

CONFIRM_OPCODE = 21
RULES_OPCODE = 22

local rulesWindow
local confirmBox

local SECTIONS = {
  {
    name = 'Game Rules',
    text = [[
GAME RULES

1. Fair play
- No bots, macros, auto-clickers, cheats, modified clients or any third-party software that plays for you or gives you an advantage.
- No abuse of bugs, errors or exploits. If you find one, report it to the staff (Ctrl+Z) instead of using it.
- Do not try to attack, overload or break into the server, the website or other players' accounts.

2. Conduct
- Respect other players and the staff. No insults, harassment, threats, racism, hate speech or discrimination.
- No spam, flooding, advertising of other servers, or links to malicious or adult content.
- Do not pretend to be a member of the staff.
- Names of characters and guilds must not be offensive, sexual, political or religious, and must not imitate the staff.

3. Trading and scams
- Trades between players are at their own risk. The staff does not refund scams, bad trades or broken promises.
- Selling characters, items or in-game goods for real money outside the official donation system is not allowed.

4. Staff decisions
- The staff may warn, mute, kick, freeze, ban or delete characters and accounts that break these rules.
- The staff decides each case; the decision is final.
- These rules may change at any time. The version in this window is the one in force.]]
  },
  {
    name = 'Responsibility',
    text = [[
PLAYER RESPONSIBILITY

By playing ForgottenL you accept that you are the only one responsible for your account, your characters and everything they carry.

- Everything you do in the game is done by your own choice and at your own risk.
- Before using chests, rewards, upgrades, NPC trades, the Store or any action that gives or takes items, make sure you have free slots and enough capacity. Items that do not fit may fall to the floor, where other players or the server can take or remove them.
- Read every confirmation window before you press Yes. Pressing Yes means you understood and accepted it.
- Keep your password and recovery details safe. The staff will never ask for your password.
- Anything that happens while someone else uses your account, with or without your permission, is your responsibility.

The game is offered "as it is", without any guarantee that it will always be online, free of errors or the same in the future. ForgottenL and its staff are not liable for any loss, direct or indirect, that comes from using the game, within the limits allowed by law.]]
  },
  {
    name = 'Items & Losses',
    text = [[
ITEMS AND LOSSES

Items, gold, points and characters are part of a game. They have no real-world value, they cannot be exchanged for money, and they are not your property: you receive a personal, revocable right to use them inside the game.

The staff does NOT return, replace or compensate items, gold, experience or points lost because of:
- deaths, PvP, monsters, traps or skulls;
- items that fell to the floor because of full backpacks, no free slots or no capacity;
- items thrown away, sold, traded, given away or destroyed by mistake;
- scams, bad trades or deals between players;
- disconnections, lag, power cuts, client crashes or problems with your computer or internet;
- someone else using your account;
- breaking the rules, including bans and deleted characters.

Only a confirmed error of the server itself may be corrected, at the sole decision of the staff, and only when the server logs prove it. Asking repeatedly for items back, or lying about a loss, may lead to a punishment.]]
  },
  {
    name = 'Donations',
    text = [[
DONATIONS

- Donations are voluntary support to keep ForgottenL online. They are not the purchase of goods, property or services in the real world.
- In return the server may give points or in-game items as a thank you. These follow the same terms as every other item: they have no real value and may be changed, rebalanced or removed to keep the game fair.
- Points and items are delivered at once. By donating you ask for this immediate delivery of digital content and you accept that, once it starts, you lose the right to cancel or withdraw and to get your money back.
- Donations are not refundable, also when an account or character is banned for breaking the rules, deleted, or when the server closes or changes.
- A chargeback, payment dispute or fraudulent payment leads to the permanent ban of the accounts involved.
- If you are under the age of majority in your country, you need the permission of your parent or legal guardian to donate.
- Payments are handled by external payment providers; their own terms also apply. ForgottenL never sees your card details.]]
  },
  {
    name = 'Accounts',
    text = [[
ACCOUNTS AND PRIVACY

- One person is responsible for each account. Sharing an account, or giving away its password, is at your own risk.
- The staff may lock, ban or delete accounts and characters that break the rules or that stay inactive for a long time.
- To keep the game safe, the server records game actions (trades, items, deaths, logins, chats) and the IP addresses used. These records are used only to run the game, investigate problems and enforce the rules, and they are not sold to anyone.
- If you want your account and personal data removed, ask the staff.]]
  },
  {
    name = 'Staff',
    text = [[
STAFF AND REPORTS

- The staff (shown with red names) runs the game. Follow their instructions in the game.
- Report players who break the rules, and bugs, through the report window (Ctrl+Z) or to the staff, with as many details as you can (time, place, names).
- Do not ask the staff for items, levels, gold or special treatment.
- False reports and abuse of the report system can be punished.
- The staff may change these rules, the game and its content at any time to keep it fair and working.]]
  },
}

function init()
  ProtocolGame.registerExtendedOpcode(RULES_OPCODE, onRulesOpcode)
  ProtocolGame.registerExtendedOpcode(CONFIRM_OPCODE, onConfirmOpcode)
  connect(g_game, { onGameEnd = onGameEnd })
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(RULES_OPCODE)
  ProtocolGame.unregisterExtendedOpcode(CONFIRM_OPCODE)
  disconnect(g_game, { onGameEnd = onGameEnd })
  onGameEnd()
end

function onGameEnd()
  hide()
  if confirmBox then
    confirmBox:destroy()
    confirmBox = nil
  end
end

function hide()
  if rulesWindow then
    rulesWindow:destroy()
    rulesWindow = nil
  end
end

function show()
  hide()
  rulesWindow = g_ui.createWidget('RulesWindow', rootWidget)
  local tabBar = rulesWindow:getChildById('tabBar')
  local text = rulesWindow:getChildById('text')
  local tabs = {}
  for i, section in ipairs(SECTIONS) do
    local tab = tabBar:addTab(tr(section.name))
    tabs[tab] = section
  end
  tabBar.onTabChange = function(_, tab)
    local section = tabs[tab]
    if section then
      text:setText(section.text)
      text:setCursorPos(0)
    end
  end
  text:setText(SECTIONS[1].text)
  rulesWindow:raise()
  rulesWindow:focus()
end

function onRulesOpcode(protocol, opcode, buffer)
  show()
end

local function answer(id, yes)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(CONFIRM_OPCODE, id .. '\t' .. (yes and 'yes' or 'no'))
  end
  if confirmBox then
    confirmBox:destroy()
    confirmBox = nil
  end
end

function onConfirmOpcode(protocol, opcode, buffer)
  local id, title, text = buffer:match('^([^\t]+)\t([^\t]*)\t(.*)$')
  if not id then return end
  if confirmBox then
    confirmBox:destroy()
    confirmBox = nil
  end
  local yes = function() answer(id, true) end
  local no = function() answer(id, false) end
  confirmBox = displayGeneralBox(title, text, {{text = tr('Yes, I confirm'), callback = yes}, {text = tr('No'), callback = no}}, nil, no)
end
