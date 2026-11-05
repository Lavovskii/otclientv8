-- The banner when the last piece of a set goes on. Player::updateSetBonus in the server sends extended opcode 13: "on|Hellborn|10" when a
-- set's bonus turns on and "off|Hellborn" when a piece comes off. Both also write a line in the console.
local OPCODE = 13
local SHOW_FOR = 3500 -- ms
local FADE_IN, FADE_OUT = 250, 700
local TITLE_ROOM = 205 -- between the banner's wings

banner = nil
local hideEvent

local function hideBanner()
  removeEvent(hideEvent)
  hideEvent = nil
  if banner then
    g_effects.cancelFade(banner)
    banner:hide()
  end
end

function onSetBonus(protocol, opcode, buffer)
  local state, name, percent = tostring(buffer):match('^(%a+)|([^|]*)|?(%d*)$')
  if state ~= 'on' then
    hideBanner()
    return
  end
  hideBanner()
  local title = banner:getChildById('title')
  title:setFont('sans-bold-16px')
  title:setText(tr('%s Set', name))
  if title:getTextSize().width > TITLE_ROOM then
    title:setFont('verdana-11px-rounded')
  end
  banner:getChildById('bonus'):setText(tr('Protection All +%d%%', tonumber(percent) or 0))
  banner:raise()
  banner:show()
  g_effects.fadeIn(banner, FADE_IN)
  hideEvent = scheduleEvent(function()
    g_effects.fadeOut(banner, FADE_OUT)
    hideEvent = scheduleEvent(hideBanner, FADE_OUT + 60)
  end, SHOW_FOR)
end

function init()
  banner = g_ui.loadUI('setbonus', modules.game_interface.getMapPanel())
  banner:hide()
  ProtocolGame.registerExtendedOpcode(OPCODE, onSetBonus)
  connect(g_game, { onGameEnd = hideBanner })
end

function terminate()
  hideBanner()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, { onGameEnd = hideBanner })
  if banner then
    banner:destroy()
    banner = nil
  end
end
