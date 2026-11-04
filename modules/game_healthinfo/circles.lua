-- The health and mana circles. They float over the game, under the windows, and each player can place and size them: holding Alt
-- with the mouse over one opens the controls, and so does Options, Custom (there the controls stay until they are closed).

local MIN_SIZE, MAX_SIZE, DEFAULT_SIZE = 50, 200, 100
local MIN_OPACITY, MAX_OPACITY, DEFAULT_OPACITY = 15, 100, 90
local WHEEL_STEP = 5
local WATCH_EVERY = 50 -- ms, how often Alt and the mouse are looked at
local ALT_DWELL = 300  -- ms over a circle before the controls open: Alt and a quick click still attack what stands behind it
local CLOSE_AFTER = 700 -- ms outside the controls, after Alt is let go, before they close

-- What the pictures of each look measure. fill, glass: parts of the picture's height, or its width for glassX, on the left side.
-- band: the part of the width the circle fills, from top to bottom in equal rows, so that only the circle itself reacts to the mouse.
-- tools/make_reborn_art.py prints Reborn's.
local PICTURES = {
  reborn = {
    width = 98, height = 232, fillTop = 0.1009, fillBottom = 0.9011, glassX = 0.2711, glassY = 0.4932, glass = 0.1286,
    sizes = { 50, 75, 100, 125, 150, 175, 200 },
    band = { { 0.47, 0.99 }, { 0.36, 1.00 }, { 0.26, 0.92 }, { 0.19, 0.62 }, { 0.13, 0.53 }, { 0.10, 0.46 }, { 0.07, 0.47 }, { 0.00, 0.54 }, { 0.01, 0.53 }, { 0.07, 0.46 }, { 0.10, 0.47 }, { 0.15, 0.54 }, { 0.20, 0.65 }, { 0.27, 0.80 }, { 0.37, 0.93 }, { 0.54, 0.93 } }
  },
  other = {
    width = 84, height = 212, fillTop = 6 / 212, fillBottom = 206 / 212, glassX = 29 / 84, glassY = 0.5, glass = 31 / 212,
    sizes = { 100 }
  }
}

local pictures = PICTURES.other
local layer, editor, watchEvent
local circles = {}
local target = nil        -- the circle the controls change
local pinned = false      -- opened from the options: they stay until closed
local dragging = nil
local together, showPercent = true, true
local hoverSince, hoverCircle = nil, nil
local closeAt = nil

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function round(value)
  return math.floor(value + 0.5)
end

local function picturePath(side, name, size)
  if #pictures.sizes == 1 then
    return '/images/game/circle/' .. side .. '_' .. name
  end
  return '/images/game/circle/' .. side .. '_' .. name .. '_' .. size
end

-- the smallest picture that isn't smaller than what is shown, so it stays sharp
local function pictureFor(size)
  for _, each in ipairs(pictures.sizes) do
    if each >= size then
      return each
    end
  end
  return pictures.sizes[#pictures.sizes]
end

-- ------------------------------------------------------------------------------ drawing one circle
local function drawLevel(view)
  local picture = view.picture or 100
  local pictureWidth = round(pictures.width * picture / 100)
  local pictureHeight = round(pictures.height * picture / 100)
  local top = pictures.fillTop + (pictures.fillBottom - pictures.fillTop) * (1 - clamp(view.level or 0, 0, 100) / 100)
  local clipTop = math.floor(pictureHeight * top)
  local width, height = view.widget:getWidth(), view.widget:getHeight()
  local drawTop = math.floor(height * top)
  local fill = view.widget:getChildById('fill')
  fill:setImageClip({ x = 0, y = clipTop, width = pictureWidth, height = pictureHeight - clipTop })
  fill:setImageRect({ x = 0, y = drawTop, width = width, height = height - drawTop })
end

local function drawPercent(view)
  local label = view.widget:getChildById('percent')
  local glass = pictures.glass * pictures.height * view.size / 100
  label:setVisible(view.showPercent ~= false)
  local level = view.percent or view.level or 0
  if glass >= 42 then
    label:setFont('sans-bold-16px')
    label:setText(level .. '%')
  elseif glass >= 28 then
    label:setFont('verdana-9px-bold')
    label:setText(level .. '%')
  elseif glass >= 21 then
    label:setFont('verdana-9px-bold')
    label:setText(tostring(level))
  else
    label:setFont('small-9px')
    label:setText(tostring(level))
  end
end

local function drawSize(view)
  local widget = view.widget
  local width = round(pictures.width * view.size / 100)
  local height = round(pictures.height * view.size / 100)
  widget:setSize({ width = width, height = height })
  local picture = pictureFor(view.size)
  if view.picture ~= picture then
    view.picture = picture
    for _, name in ipairs({ 'back', 'fill', 'frame' }) do
      widget:getChildById(name):setImageSource(picturePath(view.side, name, picture))
    end
  end
  local label = widget:getChildById('percent')
  local glassX = view.side == 'left' and pictures.glassX or 1 - pictures.glassX
  label:setMarginLeft(round(width * glassX))
  label:setMarginTop(round(height * pictures.glassY))
  drawLevel(view)
  drawPercent(view)
end

-- ------------------------------------------------------------------------------ where they go
local function mapPlace()
  local rect = modules.game_interface.getMapRect()
  local dimension = modules.game_interface.getMapPanel():getVisibleDimension()
  return rect.x + rect.width / 2, rect.y + rect.height / 2, rect.height / math.max(1, dimension.height)
end

-- around the character, whose picture stands up and to the left of its tile; bigger circles stand further apart
local function defaultCenter(circle)
  local x, y, tile = mapPlace()
  local spread = math.max(2.25 * tile, 110) * (0.6 + 0.4 * circle.size / 100)
  local width = circle.widget:getWidth()
  local fromGlass = (0.5 - pictures.glassX) * width
  x = x - 0.27 * tile
  y = y - 0.2 * tile
  if circle.side == 'left' then
    return x - spread + fromGlass, y
  end
  return x + spread - fromGlass, y
end

local function placeCircle(circle)
  local widget = circle.widget
  local x, y
  if circle.x then
    x, y = mapPlace()
    x, y = x + circle.x, y + circle.y
  else
    x, y = defaultCenter(circle)
  end
  local area = layer:getRect()
  widget:setPosition({
    x = clamp(round(x - widget:getWidth() / 2), area.x, math.max(area.x, area.x + area.width - widget:getWidth())),
    y = clamp(round(y - widget:getHeight() / 2), area.y, math.max(area.y, area.y + area.height - widget:getHeight()))
  })
end

function placeCircles()
  if not layer then return end
  for _, circle in pairs(circles) do
    placeCircle(circle)
  end
end

-- remembers where a circle stands now, from the middle of the map
local function keepPlace(circle)
  local x, y = mapPlace()
  local rect = circle.widget:getRect()
  circle.x = round(rect.x + rect.width / 2 - x)
  circle.y = round(rect.y + rect.height / 2 - y)
end

-- ------------------------------------------------------------------------------ saved between sessions
local function saveCircles()
  local node = { together = together, percent = showPercent }
  for key, circle in pairs(circles) do
    -- the place goes as text: a lone 0 or 1 reads back as a boolean
    node[key] = { size = circle.size, opacity = circle.opacity, place = circle.x and (circle.x .. ' ' .. circle.y) or 'default' }
  end
  g_settings.setNode('healthCircles', node)
end

local function loadCircles()
  local node = g_settings.getNode('healthCircles')
  if type(node) ~= 'table' then node = {} end
  together = tostring(node.together) ~= 'false'
  showPercent = tostring(node.percent) ~= 'false'
  for key, circle in pairs(circles) do
    local saved = type(node[key]) == 'table' and node[key] or {}
    circle.size = clamp(tonumber(saved.size) or DEFAULT_SIZE, MIN_SIZE, MAX_SIZE)
    circle.opacity = clamp(tonumber(saved.opacity) or DEFAULT_OPACITY, MIN_OPACITY, MAX_OPACITY)
    local x, y = string.match(tostring(saved.place), '^(-?%d+) (-?%d+)$')
    circle.x, circle.y = tonumber(x), tonumber(y)
  end
end

-- ------------------------------------------------------------------------------ the controls
local function editorOpen()
  return editor and editor:isVisible()
end

local function syncEditor()
  if not editorOpen() or not target then return end
  editor.syncing = true
  editor:getChildById('healthTab'):setOn(target == circles.health)
  editor:getChildById('manaTab'):setOn(target == circles.mana)
  editor:getChildById('sizeBar'):setValue(target.size)
  editor:getChildById('opacityBar'):setValue(target.opacity)
  editor:getChildById('sizeValue'):setText(target.size .. '%')
  editor:getChildById('opacityValue'):setText(target.opacity .. '%')
  editor:getChildById('together'):setChecked(together)
  editor:getChildById('showPercent'):setChecked(showPercent)
  editor.syncing = false
end

local function showOutlines()
  for _, circle in pairs(circles) do
    local outline = circle.widget:getChildById('outline')
    outline:setVisible(circle.editable == true)
    outline:setBorderColor(circle == target and '#f4d68c' or '#8a6a2e')
    outline:setBackgroundColor(circle == target and '#f4d68c18' or '#00000000')
  end
end

local function selectTarget(circle)
  target = circle
  showOutlines()
  syncEditor()
end

local function setEditable(editable)
  for _, circle in pairs(circles) do
    circle.editable = editable
    circle.widget:setPhantom(not editable)
    circle.widget:setDraggable(editable)
  end
  showOutlines()
end

local function each(circle, action)
  action(circle)
  if together then
    for _, other in pairs(circles) do
      if other ~= circle then action(other) end
    end
  end
end

local function changeSize(circle, size)
  size = clamp(round(size), MIN_SIZE, MAX_SIZE)
  each(circle, function(c)
    c.size = size
    drawSize(c)
    placeCircle(c)
  end)
  saveCircles()
  syncEditor()
end

local function changeOpacity(circle, opacity)
  opacity = clamp(round(opacity), MIN_OPACITY, MAX_OPACITY)
  each(circle, function(c)
    c.opacity = opacity
    c.widget:setOpacity(opacity / 100)
  end)
  saveCircles()
  syncEditor()
end

local function resetCircle(circle)
  each(circle, function(c)
    c.size, c.opacity = DEFAULT_SIZE, DEFAULT_OPACITY
    c.x, c.y = nil, nil
    c.widget:setOpacity(c.opacity / 100)
    drawSize(c)
    placeCircle(c)
  end)
  saveCircles()
  syncEditor()
end

local function placeEditor(circle)
  local rect = circle.widget:getRect()
  local root = rootWidget:getRect()
  -- some room for the circle to grow, the window won't move under the mouse while it does
  local gap = 12 + math.min(60, (round(pictures.width * MAX_SIZE / 100) - rect.width) / 2)
  local width, height = editor:getWidth(), editor:getHeight()
  local x = rect.x - width - gap
  if circle.side == 'right' then x = rect.x + rect.width + gap end
  if x < root.x then x = rect.x + rect.width + gap end
  if x + width > root.x + root.width then x = rect.x - width - gap end
  editor:setPosition({
    x = clamp(x, root.x, math.max(root.x, root.x + root.width - width)),
    y = clamp(rect.y + math.floor((rect.height - height) / 2), root.y, math.max(root.y, root.y + root.height - height))
  })
end

function closeCircleEditor()
  if editor then editor:hide() end
  pinned = false
  closeAt = nil
  if next(circles) then setEditable(false) end
end

local function buildEditor()
  editor = g_ui.createWidget('CircleEditor', rootWidget)
  editor:hide()
  editor:getChildById('healthTab').onClick = function() selectTarget(circles.health) end
  editor:getChildById('manaTab').onClick = function() selectTarget(circles.mana) end
  editor:getChildById('sizeBar'):setRange(MIN_SIZE, MAX_SIZE)
  editor:getChildById('opacityBar'):setRange(MIN_OPACITY, MAX_OPACITY)
  editor:getChildById('sizeBar').onValueChange = function(_, value)
    if not editor.syncing and target then changeSize(target, value) end
  end
  editor:getChildById('opacityBar').onValueChange = function(_, value)
    if not editor.syncing and target then changeOpacity(target, value) end
  end
  editor:getChildById('together').onCheckChange = function(_, checked)
    if editor.syncing then return end
    together = checked
    if together and target then
      changeSize(target, target.size)
      changeOpacity(target, target.opacity)
    end
    saveCircles()
  end
  editor:getChildById('showPercent').onCheckChange = function(_, checked)
    if editor.syncing then return end
    showPercent = checked
    for _, circle in pairs(circles) do
      circle.showPercent = checked
      drawPercent(circle)
    end
    saveCircles()
  end
  editor:getChildById('reset').onClick = function()
    if target then resetCircle(target) end
  end
  editor:getChildById('close').onClick = closeCircleEditor
end

local function openEditor(circle, pin)
  if not editor then buildEditor() end
  pinned = pin == true
  closeAt = nil
  setEditable(true)
  editor:show()
  editor:raise()
  placeEditor(circle)
  selectTarget(circle)
end

-- from Options, Custom: no Alt needed
function openCircleEditor()
  if not layer or not g_game.isOnline() or not layer:isVisible() then return false end
  openEditor(circles.health, true)
  return true
end

-- ------------------------------------------------------------------------------ the mouse
local function onCircle(circle, pos)
  local rect = circle.widget:getRect()
  if pos.x < rect.x or pos.y < rect.y or pos.x >= rect.x + rect.width or pos.y >= rect.y + rect.height then
    return false
  end
  local band = pictures.band
  if not band then return true end
  local row = band[clamp(math.floor((pos.y - rect.y) / rect.height * #band) + 1, 1, #band)]
  local x = (pos.x - rect.x) / rect.width
  if circle.side == 'right' then x = 1 - x end
  return x >= row[1] and x <= row[2]
end

local function circleAt(pos)
  for _, circle in pairs(circles) do
    if circle.widget:isVisible() and onCircle(circle, pos) then
      return circle
    end
  end
end

-- no window of the client is in the way
local function overTheGame(pos)
  local children = rootWidget:getChildren()
  for i = #children, 1, -1 do
    local child = children[i]
    if child:isVisible() and not child:isPhantom() and child:containsPoint(pos) then
      return child == modules.game_interface.getRootPanel()
    end
  end
  return false
end

local function watchMouse()
  if not layer or not g_game.isOnline() then return end
  local pos = g_window.getMousePosition()
  local pressed = g_mouse.isPressed(MouseLeftButton)
  if g_keyboard.isAltPressed() and g_window.hasFocus() then
    closeAt = nil
    if layer:isVisible() and not dragging and not pressed then
      local circle = circleAt(pos)
      if circle and overTheGame(pos) then
        if hoverCircle ~= circle then
          hoverCircle, hoverSince = circle, g_clock.millis()
        end
        if editorOpen() then
          if target ~= circle then selectTarget(circle) end
        elseif g_clock.millis() - hoverSince >= ALT_DWELL then
          openEditor(circle)
        end
      else
        hoverCircle, hoverSince = nil, nil
      end
    end
    return
  end
  hoverCircle, hoverSince = nil, nil
  if not editorOpen() or pinned then return end
  if dragging or pressed or editor:containsPoint(pos) or circleAt(pos) then
    closeAt = nil
    return
  end
  closeAt = closeAt or g_clock.millis() + CLOSE_AFTER
  if g_clock.millis() >= closeAt then
    closeCircleEditor()
  end
end

local function other(circle)
  return circle == circles.health and circles.mana or circles.health
end

local function makeCircle(key, side)
  local widget = g_ui.createWidget('HealthManaCircle', layer)
  widget:setId(key .. 'Circle')
  local circle = { key = key, side = side, widget = widget, level = 0, size = DEFAULT_SIZE, opacity = DEFAULT_OPACITY }
  widget.onMousePress = function(self, pos, button)
    if not circle.editable then return false end
    selectTarget(circle)
    return true
  end
  widget.onDragEnter = function(self, pos)
    if not circle.editable then return false end
    self.movingReference = { x = pos.x - self:getX(), y = pos.y - self:getY() }
    dragging = circle
    selectTarget(circle)
    return true
  end
  widget.onDragMove = function(self, pos)
    if dragging ~= circle then return false end
    local area = layer:getRect()
    local x = clamp(pos.x - self.movingReference.x, area.x, math.max(area.x, area.x + area.width - self:getWidth()))
    local y = clamp(pos.y - self.movingReference.y, area.y, math.max(area.y, area.y + area.height - self:getHeight()))
    local dx, dy = x - self:getX(), y - self:getY()
    self:setPosition({ x = x, y = y })
    keepPlace(circle)
    -- with Shift both go
    if g_keyboard.isShiftPressed() then
      local second = other(circle)
      keepPlace(second)
      second.x, second.y = second.x + dx, second.y + dy
      placeCircle(second)
      keepPlace(second)
    end
    return true
  end
  widget.onDragLeave = function(self, droppedWidget, pos)
    dragging = nil
    saveCircles()
    return true
  end
  widget.onMouseWheel = function(self, pos, direction)
    if not circle.editable then return false end
    selectTarget(circle)
    local step = direction == MouseWheelUp and WHEEL_STEP or -WHEEL_STEP
    if g_keyboard.isCtrlPressed() then
      changeOpacity(circle, circle.opacity + step)
    else
      changeSize(circle, circle.size + step)
    end
    return true
  end
  circles[key] = circle
  return circle
end

-- ------------------------------------------------------------------------------ for healthinfo.lua
-- level: how far it is full, percent: the number in the medallion
function setCircleLevel(key, level, percent, color)
  local circle = circles[key]
  if not circle then return end
  circle.level, circle.percent = level, percent
  if color then
    circle.widget:getChildById('fill'):setImageColor(color)
  end
  drawLevel(circle)
  drawPercent(circle)
end

function setCirclesVisible(visible)
  if not layer then return end
  layer:setVisible(visible)
  if not visible then closeCircleEditor() end
end

-- a circle at rest for the drawings of the Guides, the same pictures the game shows, its medallion in the middle of the parent
function drawCircleInto(parent, key, size, level, color)
  local widget = g_ui.createWidget('HealthManaCircle', parent)
  local view = { widget = widget, side = key == 'health' and 'left' or 'right', size = size, level = level, showPercent = true }
  widget:getChildById('fill'):setImageColor(color)
  drawSize(view)
  widget:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  widget:addAnchor(AnchorTop, 'parent', AnchorTop)
  local glassX = view.side == 'left' and pictures.glassX or 1 - pictures.glassX
  widget:setMarginLeft(round(parent:getWidth() / 2 - widget:getWidth() * glassX))
  widget:setMarginTop(round(parent:getHeight() / 2 - widget:getHeight() * pictures.glassY))
  return widget
end

local function startWatching()
  if not watchEvent then
    watchEvent = cycleEvent(watchMouse, WATCH_EVERY)
  end
  addEvent(placeCircles)
end

local function stopWatching()
  if watchEvent then
    removeEvent(watchEvent)
    watchEvent = nil
  end
  closeCircleEditor()
end

function initCircles()
  g_ui.importStyle('circles')
  local look = g_resources.getLayout():lower()
  pictures = PICTURES[look] or PICTURES.other

  layer = g_ui.createWidget('HealthManaCircles', modules.game_interface.getRootPanel())
  makeCircle('health', 'left')
  makeCircle('mana', 'right')
  circles.mana.widget:getChildById('fill'):setImageColor('#3a7bff')
  loadCircles()
  for _, circle in pairs(circles) do
    circle.showPercent = showPercent
    circle.widget:setOpacity(circle.opacity / 100)
    drawSize(circle)
  end
  placeCircles()

  connect(modules.game_interface.getMapPanel(), { onGeometryChange = placeCircles })
  connect(layer, { onGeometryChange = placeCircles })
  connect(g_game, { onGameStart = startWatching, onGameEnd = stopWatching })
  if g_game.isOnline() then startWatching() end
end

function terminateCircles()
  stopWatching()
  disconnect(modules.game_interface.getMapPanel(), { onGeometryChange = placeCircles })
  disconnect(g_game, { onGameStart = startWatching, onGameEnd = stopWatching })
  if editor then
    editor:destroy()
    editor = nil
  end
  if layer then
    layer:destroy()
    layer = nil
  end
  circles = {}
end
