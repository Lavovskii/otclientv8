local ARC_W, ARC_H = 56, 380
local MARGIN = 10

local mapPanel
local bars = {}

local function group(n)
  local s = tostring(math.floor(n or 0))
  local r = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
  return (r:gsub('^,', ''))
end

local function createBar(side, fillImage, frameImage)
  local bar = {}
  bar.frame = g_ui.createWidget('CurvedArc', mapPanel)
  bar.frame:setImageSource(frameImage)
  bar.fill = g_ui.createWidget('CurvedFill', bar.frame)
  bar.fill:setImageSource(fillImage)
  bar.fill:setVisible(false)
  bar.percent = g_ui.createWidget('CurvedText', mapPanel)
  bar.values = g_ui.createWidget('CurvedText', mapPanel)

  bar.frame:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
  bar.frame:addAnchor(side == 'left' and AnchorLeft or AnchorRight, 'parent', side == 'left' and AnchorLeft or AnchorRight)
  bar.frame:setMarginLeft(side == 'left' and MARGIN or 0)
  bar.frame:setMarginRight(side == 'right' and MARGIN or 0)

  return bar
end

local function setFill(bar, current, maximum)
  current = math.max(0, current or 0)
  maximum = math.max(1, maximum or 1)
  local pct = math.min(1, current / maximum)
  local h = math.floor(ARC_H * pct + 0.5)
  if current > 0 and h < 2 then h = 2 end
  bar.fill:setVisible(h > 0)
  if h > 0 then
    bar.fill:setHeight(h)
    bar.fill:setImageClip(torect(0, ARC_H - h, ARC_W, h))
  end
  bar.percent:setText(string.format('%d%%', math.floor(pct * 100 + 0.5)))
  bar.values:setText(group(current) .. ' / ' .. group(maximum))
end

local function place(bar, side)
  -- text sits just outside the arc, percent on the upper half, numbers on the lower half
  local frame = bar.frame
  local anchor = side == 'left' and AnchorLeft or AnchorRight
  local inner = side == 'left' and AnchorRight or AnchorLeft
  bar.percent:breakAnchors()
  bar.values:breakAnchors()
  bar.percent:addAnchor(anchor, frame:getId(), inner)
  bar.values:addAnchor(anchor, frame:getId(), inner)
  bar.percent:addAnchor(AnchorBottom, frame:getId(), AnchorVerticalCenter)
  bar.values:addAnchor(AnchorTop, frame:getId(), AnchorVerticalCenter)
  bar.percent:setMarginBottom(2)
  bar.values:setMarginTop(2)
  if side == 'left' then
    bar.percent:setMarginLeft(-14)
    bar.values:setMarginLeft(-14)
  else
    bar.percent:setMarginRight(-14)
    bar.values:setMarginRight(-14)
  end
end

function onHealthChange(localPlayer, health, maxHealth)
  if bars.hp then setFill(bars.hp, health, maxHealth) end
end

function onManaChange(localPlayer, mana, maxMana)
  if bars.mp then setFill(bars.mp, mana, maxMana) end
end

-- the map is drawn centred inside the (wider) map panel with a fixed aspect ratio: keep the arcs on its edges
function reposition()
  if not mapPanel or not bars.hp then return end
  local dim = mapPanel:getVisibleDimension()
  local width, height = mapPanel:getWidth(), mapPanel:getHeight()
  local offset = 0
  if dim and dim.height > 0 and dim.width > 0 then
    offset = math.max(0, math.floor((width - math.min(width, height * dim.width / dim.height)) / 2))
  end
  bars.hp.frame:setMarginLeft(offset + MARGIN)
  bars.mp.frame:setMarginRight(offset + MARGIN)
end

local function destroyBars()
  if mapPanel then
    disconnect(mapPanel, { onGeometryChange = reposition })
  end
  for _, bar in pairs(bars) do
    bar.percent:destroy()
    bar.values:destroy()
    bar.frame:destroy()
  end
  bars = {}
end

function online()
  destroyBars()
  mapPanel = modules.game_interface.getMapPanel()
  if not mapPanel then return end

  local base = '/images/game/curved/'
  bars.hp = createBar('left', base .. 'hp_fill_left', base .. 'frame_left')
  bars.mp = createBar('right', base .. 'mp_fill_right', base .. 'frame_right')
  bars.hp.frame:setId('curvedHpArc')
  bars.mp.frame:setId('curvedMpArc')
  place(bars.hp, 'left')
  place(bars.mp, 'right')

  connect(mapPanel, { onGeometryChange = reposition })
  reposition()

  local player = g_game.getLocalPlayer()
  if player then
    onHealthChange(player, player:getHealth(), player:getMaxHealth())
    onManaChange(player, player:getMana(), player:getMaxMana())
  end
end

function offline()
  destroyBars()
end

function init()
  g_ui.importStyle('curvedbars')
  connect(LocalPlayer, { onHealthChange = onHealthChange, onManaChange = onManaChange })
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(LocalPlayer, { onHealthChange = onHealthChange, onManaChange = onManaChange })
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
  destroyBars()
end
