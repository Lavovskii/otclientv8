-- The sacred fountain: one promotion, chosen once and for good between the offensive and the defensive path of the
-- player's vocation. The rules are all in the server (data/lib/131-promotion.lua): it sends what to show in lines of fields
-- split by | (extended opcode 36) when the fountain is used, and this window draws them; it asks with "open" and
-- "choose|<vocation id>".
--   S|player name|level|level needed|base vocation name|current vocation id|promoted 0/1
--   P|vocation id|name|offensive or defensive|looktype|damage %|defense %|skill rate|kind:benefit~kind:benefit~...
--   D|vocation id|name        (the choice was made)
--   N|a notice
local OPCODE = 36

local window
local state = {}
local paths = {}
local pending -- the path waiting for "ACCEPT MY FATE"

local KINDS = {
  offensive = {ribbon = '/images/taskboard/ribbon', label = 'OFFENSIVE PATH', color = '#e8964a'},
  defensive = {ribbon = '/images/taskboard/ribbon_silver', label = 'DEFENSIVE PATH', color = '#a9c4e0'},
}

local ICONS = {
  dmg = '/images/taskboard/damage36',
  def = '/images/taskboard/shield28',
  skill = '/images/taskboard/star16',
  base = '/images/taskboard/seal18',
  extra = '/images/taskboard/points14',
}

-- a path's outfit is shown with every addon, in the player's own colours
local DEFAULT_COLORS = {head = 78, body = 69, legs = 58, feet = 76}

local function playerColors()
  local player = g_game.getLocalPlayer()
  local outfit = player and player.getOutfit and player:getOutfit()
  if type(outfit) ~= 'table' or not outfit.head then
    return DEFAULT_COLORS
  end
  return {head = outfit.head, body = outfit.body, legs = outfit.legs, feet = outfit.feet}
end

local function send(text)
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE, text)
  end
end

local function split(line, separator)
  local parts = {}
  for part in (line .. separator):gmatch('([^' .. separator .. ']*)' .. separator) do
    parts[#parts + 1] = part
  end
  return parts
end

local function thousands(value)
  local text = tostring(math.floor(tonumber(value) or 0))
  local result = text:reverse():gsub('(%d%d%d)', '%1,'):reverse()
  return (result:gsub('^,', ''))
end

local function article(name)
  return name:match('^[AEIOUaeiou]') and 'an' or 'a'
end

local function hideConfirm()
  pending = nil
  if window then
    window.confirm:hide()
  end
end

local function canChoose()
  return not state.promoted and (state.level or 0) >= (state.needed or 0)
end

local function drawHeader()
  local base = state.base or ''
  if state.promoted then
    local current
    for _, path in ipairs(paths) do
      if path.id == state.current then current = path end
    end
    local name = current and current.name or tr('your path')
    window.header.caption:setText(tr('Your path'))
    window.intro:setText(tr('You walk the path of the %s. Your fate is sealed.', name))
    window.requirement:setText(tr('This choice can never be undone.'))
    window.requirement:setColor('#9a9a9a')
  else
    window.header.caption:setText(tr('Choose your path'))
    window.intro:setText(tr('Choose the path of your %s. You choose once, and forever.', base))
    if canChoose() then
      window.requirement:setText(tr('Level %s needed: you are level %s. The fountain is ready for you.', thousands(state.needed), thousands(state.level)))
      window.requirement:setColor('#8fd48f')
    else
      window.requirement:setText(tr('Level %s needed: you are level %s.', thousands(state.needed), thousands(state.level)))
      window.requirement:setColor('#e07070')
    end
  end
end

local function drawBenefits(card, path)
  card.benefits:destroyChildren()
  for _, entry in ipairs(path.benefits) do
    local kind, text = entry:match('^(%a+):(.*)$')
    if not kind then
      kind, text = 'extra', entry
    end
    local row = g_ui.createWidget('PromotionBenefit', card.benefits)
    row.icon:setImageSource(ICONS[kind] or ICONS.extra)
    row.text:setText(text)
    if kind == 'dmg' or kind == 'def' then
      row.text:setColor('#f4d68c')
    elseif kind == 'extra' then
      row.text:setColor('#9a9a9a')
    end
  end
end

local function drawCard(card, path)
  if not path then
    card:hide()
    return
  end
  card:show()
  local kind = KINDS[path.kind] or KINDS.offensive
  card.ribbon:setImageSource(kind.ribbon)
  card.ribbon.name:setText(path.name:upper())
  card.kind:setText(tr(kind.label))
  card.kind:setColor(kind.color)

  local colors = playerColors()
  card.portrait.creature:setOutfit({type = path.looktype, head = colors.head, body = colors.body, legs = colors.legs,
    feet = colors.feet, addons = 3})
  card.portrait.creature:setDirection(2)
  card.portrait.creature:setAnimate(true)
  drawBenefits(card, path)

  local chosen = state.promoted and state.current == path.id
  local other = state.promoted and not chosen
  card:setOpacity(other and 0.45 or 1)
  card.chooseButton:setVisible(not state.promoted)
  card.status:setVisible(state.promoted)
  card.seal:setVisible(chosen)
  if chosen then
    card.status:setText(tr('YOUR PATH'))
    card.status:setColor('#f4d68c')
  elseif other then
    card.status:setText(tr('The path not taken'))
    card.status:setColor('#9a9a9a')
  end

  card.chooseButton:setText(tr('Choose %s', path.name))
  card.chooseButton:setEnabled(canChoose())
  if canChoose() then
    card.chooseButton:setTooltip('')
  else
    card.chooseButton:setTooltip(tr('Reach level %s to choose your path.', thousands(state.needed)))
  end
  card.chooseButton.onClick = function()
    if canChoose() then
      showConfirm(path)
    end
  end
end

local function draw()
  if not window then return end
  drawHeader()
  drawCard(window.card1, paths[1])
  drawCard(window.card2, paths[2])
end

function showConfirm(path)
  if not window or not path then return end
  pending = path
  local box = window.confirm.box
  box.caption:setText(tr('Your final choice'))
  box.ribbon.name:setText(path.name:upper())
  box.question:setText(tr('IS THIS YOUR FINAL CHOICE, %s?', (state.name or ''):upper()))
  box.warning:setText(tr('ONCE YOU BECOME %s %s, THERE IS NO TURNING BACK. THIS PATH CAN NEVER BE UNDONE.',
    article(path.name):upper(), path.name:upper()))
  window.confirm:show()
  window.confirm:raise()
  window.confirm:focus()
end

local function accept()
  if not pending or not canChoose() then
    hideConfirm()
    return
  end
  local id = pending.id
  window.confirm.box.acceptButton:setEnabled(false)
  send('choose|' .. id)
end

function onPromotionMessage(protocol, opcode, buffer)
  if not window then return end
  local newPaths, open = {}, false
  for line in buffer:gmatch('[^\n]+') do
    local parts = split(line, '|')
    if parts[1] == 'S' then
      state = {name = parts[2] or '', level = tonumber(parts[3]) or 0, needed = tonumber(parts[4]) or 0, base = parts[5] or '',
        current = tonumber(parts[6]) or 0, promoted = parts[7] == '1'}
      open = true
    elseif parts[1] == 'P' then
      newPaths[#newPaths + 1] = {id = tonumber(parts[2]) or 0, name = parts[3] or '', kind = parts[4] or 'offensive',
        looktype = tonumber(parts[5]) or 128, damage = tonumber(parts[6]) or 0, defense = tonumber(parts[7]) or 0,
        rate = tonumber(parts[8]) or 1, benefits = parts[9] and parts[9] ~= '' and split(parts[9], '~') or {}}
    elseif parts[1] == 'D' then
      state.promoted = true
      state.current = tonumber(parts[2]) or state.current
      hideConfirm()
      draw()
      displayInfoBox(tr('The Sacred Fountain'), tr('You are now %s %s. Your fate is sealed.', article(parts[3] or ''), parts[3] or ''))
    elseif parts[1] == 'N' then
      hideConfirm()
      displayInfoBox(tr('The Sacred Fountain'), parts[2] or '')
    end
  end
  if #newPaths > 0 then
    paths = newPaths
  end
  if open then
    hideConfirm()
    draw()
    show()
  end
  if window then
    window.confirm.box.acceptButton:setEnabled(true)
  end
end

local lastEscape = 0

function onEscape()
  lastEscape = g_clock.millis()
  if window and window.confirm:isVisible() then
    hideConfirm()
  else
    hide()
  end
end

-- Escape closes it even when the game, not the window, has the keyboard; walking away closes it too
local function onKeyEscape()
  -- the window's own Escape already ran when it has the keyboard: one Escape, one step back
  if window and window:isVisible() and g_clock.millis() - lastEscape > 100 then onEscape() end
end

local function onWalk(creature, newPos, oldPos)
  if window and window:isVisible() and oldPos and newPos then hide() end
end

function show()
  if not window then return end
  window:show()
  window:raise()
  window:focus()
end

function hide()
  hideConfirm()
  if window then window:hide() end
end

local function onGameEnd()
  hide()
end

function init()
  window = g_ui.displayUI('promotion')
  window:hide()
  window.header.caption:setText(tr('Choose your path'))
  window.confirm.box.acceptButton.onClick = accept
  window.confirm.box.cancelButton.onClick = hideConfirm
  -- no button: the window opens only when the player uses a sacred fountain in the game (the server sends it)
  ProtocolGame.registerExtendedOpcode(OPCODE, onPromotionMessage)
  connect(g_game, {onGameEnd = onGameEnd})
  connect(LocalPlayer, {onPositionChange = onWalk})
  g_keyboard.bindKeyDown('Escape', onKeyEscape)
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd = onGameEnd})
  disconnect(LocalPlayer, {onPositionChange = onWalk})
  g_keyboard.unbindKeyDown('Escape', onKeyEscape)
  if window then window:destroy() end
  window = nil
  paths, state, pending = {}, {}, nil
end
