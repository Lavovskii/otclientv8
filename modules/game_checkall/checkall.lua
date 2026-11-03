-- The staff's Check All window: every item, outfit, mount, effect and shoot effect the client has a picture of.
-- The server's /checkall (data/talkactions/scripts/gamemaster/check_all.lua) opens it and does what a double click asks,
-- so who may use it is decided there. The list, with the names only the server knows, is checkall_data.txt
-- (tools/gen_checkall_data.py in the server's repository).
local MESSAGE_PREFIX = 'Check All: '
local OPENING = 'opening the window'
local DATA_FILE = '/modules/game_checkall/checkall_data.txt'
local DOUBLE_CLICK_MS = 450
local ANIMATE_MS = 100
local FILTER_DELAY_MS = 150
local CELL_BOX, CELL_TILE = 64, 32
local PREVIEW_BOX, PREVIEW_TILE = 128, 64
-- the pattern of a missile's direction, starting at the east and going around
local MISSILE_PATTERNS = {{2, 1}, {2, 2}, {1, 2}, {0, 2}, {0, 1}, {0, 0}, {1, 0}, {2, 0}}
local MISSILE_TICKS_PER_DIRECTION = 4

local KINDS = {
  {key = 'I', title = 'Items', cell = 'CheckAllItemCell', pitchX = 46, pitchY = 55, columns = 12, rows = 8, wheel = 2, action = 'Add to bag'},
  {key = 'O', title = 'Outfits', cell = 'CheckAllOutfitCell', pitchX = 79, pitchY = 88, columns = 7, rows = 5, wheel = 1, action = 'Wear outfit'},
  {key = 'M', title = 'Mounts', cell = 'CheckAllOutfitCell', pitchX = 79, pitchY = 88, columns = 7, rows = 5, wheel = 1, action = 'Wear outfit'},
  {key = 'E', title = 'Effects', cell = 'CheckAllEffectCell', pitchX = 79, pitchY = 88, columns = 7, rows = 5, wheel = 1, action = 'Cast effect', category = ThingCategoryEffect},
  {key = 'S', title = 'Shoot Effects', cell = 'CheckAllEffectCell', pitchX = 79, pitchY = 88, columns = 7, rows = 5, wheel = 1, action = 'Shoot', category = ThingCategoryMissile}
}

local win, lists, kind, view, selected, colors
local cells = {}
local firstRow = 0
local tick = 0
local lastClicked, lastClickTime
local animateEvent, filterEvent

local function setStatus(text)
  if win then win.statusLabel:setText(text) end
end

local function loadLists()
  if lists then return true end
  local ok, text = pcall(g_resources.readFileContents, DATA_FILE)
  if not ok or not text or text == '' then
    perror('Check All: cannot read ' .. DATA_FILE)
    return false
  end
  lists = {}
  for _, k in ipairs(KINDS) do lists[k.key] = {} end
  for key, id, client, name in text:gmatch('(%u)\t(%d+)\t(%d+)\t([^\r\n]*)\r?\n') do
    local list = lists[key]
    if list then
      list[#list + 1] = {id = tonumber(id), client = tonumber(client), name = name, lower = name:lower()}
    end
  end
  return true
end

local function fitsBag(entry)
  if entry.bag == nil then
    entry.bag = g_things.getThingType(entry.client, ThingCategoryItem):isPickupable()
  end
  return entry.bag
end

-- what the sprites of an effect or a missile are, read once
local function thingOf(entry)
  if not entry.thing then
    local t = g_things.getThingType(entry.client, kind.category)
    entry.thing = {w = t:getWidth(), h = t:getHeight(), layers = t:getLayers(), px = t:getNumPatternX(), py = t:getNumPatternY(),
      pz = t:getNumPatternZ(), phases = t:getAnimationPhases(), sprites = t:getSprites()}
  end
  return entry.thing
end

-- a box with one widget for each tile of the thing, tile 0,0 at the bottom right as the client draws it
local function prepareBox(box, thing, boxSize, maxTile)
  if box.thing == thing then return end
  box:destroyChildren()
  box.thing, box.frame, box.tiles = thing, nil, {}
  local tile = math.min(maxTile, math.floor(boxSize / math.max(thing.w, thing.h)))
  local left = math.floor((boxSize - thing.w * tile) / 2)
  local top = math.floor((boxSize - thing.h * tile) / 2)
  for y = 0, thing.h - 1 do
    for x = 0, thing.w - 1 do
      local sprite = g_ui.createWidget('CheckAllSprite', box)
      sprite:setSize({width = tile, height = tile})
      sprite:setMarginLeft(left + (thing.w - 1 - x) * tile)
      sprite:setMarginTop(top + (thing.h - 1 - y) * tile)
      box.tiles[y * thing.w + x] = sprite
    end
  end
end

-- when is nil for the still picture: the middle of an effect, whose first frames can be nearly empty; a missile going east
local function drawThing(box, entry, boxSize, maxTile, when)
  local thing = thingOf(entry)
  prepareBox(box, thing, boxSize, maxTile)
  local phase = when and when % thing.phases or math.floor(thing.phases / 2)
  local patternX, patternY = 0, 0
  if kind.key == 'S' and thing.px >= 3 and thing.py >= 3 then
    local turn = when and math.floor(when / MISSILE_TICKS_PER_DIRECTION) % #MISSILE_PATTERNS or 0
    patternX, patternY = MISSILE_PATTERNS[turn + 1][1], MISSILE_PATTERNS[turn + 1][2]
  end
  local frame = ((phase * thing.pz * thing.py + patternY) * thing.px + patternX) * thing.layers
  if box.frame == frame then return end
  box.frame = frame
  for y = 0, thing.h - 1 do
    for x = 0, thing.w - 1 do
      local spriteId = thing.sprites[(frame * thing.h + y) * thing.w + x + 1] or 0
      local sprite = box.tiles[y * thing.w + x]
      if spriteId > 0 then sprite:setSpriteId(spriteId) else sprite:clearSprite() end
    end
  end
end

local function outfitOf(look)
  return {type = look, head = colors.head, body = colors.body, legs = colors.legs, feet = colors.feet}
end

local function entryLabel(entry)
  return tostring(entry.id)
end

local function entryName(entry)
  return entry.name ~= '' and entry.name or tr('(no name)')
end

local function fillCell(cell, entry)
  cell.entry = entry
  cell:setVisible(entry ~= nil)
  if not entry then return end
  cell:setOn(entry == selected)
  cell.idLabel:setText(entryLabel(entry))
  cell:setTooltip(entryName(entry) .. ' (' .. entryLabel(entry) .. ')')
  cell.moving = nil
  if kind.key == 'I' then
    cell.item:setItemId(entry.client)
  elseif kind.category then
    drawThing(cell.sprites, entry, CELL_BOX, CELL_TILE)
  else
    cell.creature:setOutfit(outfitOf(entry.id))
  end
end

local function fillCells()
  local first = firstRow * kind.columns
  for i, cell in ipairs(cells) do
    fillCell(cell, view[first + i])
  end
end

local function itemFlags(thing)
  local flags = {}
  if thing:isStackable() then flags[#flags + 1] = tr('stackable') end
  if thing:isContainer() then flags[#flags + 1] = tr('container') end
  if thing:isFluidContainer() then flags[#flags + 1] = tr('fluid') end
  if thing:isGround() then flags[#flags + 1] = tr('ground') end
  if thing:isPickupable() then flags[#flags + 1] = tr('goes in a bag') end
  if thing:isNotMoveable() then flags[#flags + 1] = tr('not moveable') end
  return table.concat(flags, ', ')
end

local function detailsText(entry)
  if kind.key == 'I' then
    local thing = g_things.getThingType(entry.client, ThingCategoryItem)
    return tr('Server id: %d\nClient id: %d\nSize: %dx%d\n\n%s', entry.id, entry.client, thing:getWidth(), thing:getHeight(), itemFlags(thing))
  elseif kind.key == 'O' then
    return tr('Looktype: %d', entry.id)
  elseif kind.key == 'M' then
    return tr('Looktype: %d\nMount id: %d', entry.id, entry.client)
  end
  local thing = thingOf(entry)
  return tr('Server id: %d\nClient id: %d\nSize: %dx%d, %d frames', entry.id, entry.client, thing.w, thing.h, thing.phases)
end

local function showDetails(entry)
  local details = win.details
  local box = details.previewBox
  box.previewItem:setVisible(entry ~= nil and kind.key == 'I')
  box.previewCreature:setVisible(entry ~= nil and (kind.key == 'O' or kind.key == 'M'))
  box.previewSprites:setVisible(entry ~= nil and kind.category ~= nil)
  details.actionButton:setText(tr(kind.action))
  details.actionButton:setEnabled(entry ~= nil)
  details.copyButton:setEnabled(entry ~= nil)
  if not entry then
    details.nameLabel:setText('')
    details.infoLabel:setText(tr('Click to see one, double click to use it.'))
    return
  end
  details.nameLabel:setText(entryName(entry))
  details.infoLabel:setText(detailsText(entry))
  if kind.key == 'I' then
    box.previewItem:setItemId(entry.client)
  elseif kind.category then
    drawThing(box.previewSprites, entry, PREVIEW_BOX, PREVIEW_TILE, tick)
  else
    box.previewCreature:setOutfit(outfitOf(entry.id))
  end
end

local function selectEntry(entry)
  selected = entry
  for _, cell in ipairs(cells) do
    cell:setOn(cell.entry ~= nil and cell.entry == selected)
  end
  showDetails(entry)
end

-- the effects move only under the mouse and in the big picture: each new frame is a new texture for every tile
local function animate()
  if not win or not kind.category then return end
  tick = tick + 1
  for _, cell in ipairs(cells) do
    if cell.entry and cell:isHovered() then
      drawThing(cell.sprites, cell.entry, CELL_BOX, CELL_TILE, tick)
      cell.moving = true
    elseif cell.entry and cell.moving then
      cell.moving = nil
      drawThing(cell.sprites, cell.entry, CELL_BOX, CELL_TILE)
    end
  end
  if selected then
    drawThing(win.details.previewBox.previewSprites, selected, PREVIEW_BOX, PREVIEW_TILE, tick)
  end
end

local function applyFilter()
  filterEvent = nil
  if not win then return end
  local source = lists[kind.key]
  local query = win.searchEdit:getText():trim():lower()
  local bagOnly = kind.key == 'I' and win.bagOnly:isChecked()
  if query == '' and not bagOnly then
    view = source
  else
    view = {}
    -- a number is an id: the one with exactly that id comes first, then those that start with it or have it as client id
    local number = query:match('^%d+$') and tonumber(query)
    for _, entry in ipairs(source) do
      local found = query == ''
      if not found and number then
        found = entry.client == number or tostring(entry.id):find(query, 1, true) == 1
      elseif not found then
        found = entry.lower:find(query, 1, true) ~= nil
      end
      if found and (not bagOnly or fitsBag(entry)) then
        if entry.id == number then table.insert(view, 1, entry) else view[#view + 1] = entry end
      end
    end
  end
  win.countLabel:setText(tr('%d of %d', #view, #source))
  win.emptyLabel:setVisible(#view == 0)
  firstRow = 0
  local totalRows = math.ceil(#view / kind.columns)
  win.scroll:setRange(0, math.max(0, totalRows - kind.rows))
  win.scroll:setValue(0)
  fillCells()
end

local function activate(entry)
  if not entry or not g_game.isOnline() then return end
  if kind.key == 'I' then
    g_game.talk('/checkall item,' .. entry.id)
  elseif kind.key == 'O' or kind.key == 'M' then
    g_game.talk('/checkall outfit,' .. entry.id)
  elseif kind.key == 'S' then
    g_game.talk('/checkall shoot,' .. entry.id)
  else
    g_game.talk('/checkall effect,' .. entry.id)
  end
end

local function sendToPlayer(entry)
  displayTextInputBox(tr('Send to player'), tr('Player name:'), function(name)
    name = (name or ''):trim()
    if name ~= '' and g_game.isOnline() then
      g_game.talk('/checkall send,' .. entry.id .. ',' .. name)
    end
  end)
end

local function onCellMouseRelease(cell, mousePos, button)
  local entry = cell.entry
  if button ~= MouseRightButton or not entry or kind.key ~= 'I' then return false end
  selectEntry(entry)
  local menu = g_ui.createWidget('PopupMenu')
  menu:setGameMenu(true)
  menu:addOption(tr('Place in inventory'), function() activate(entry) end)
  menu:addOption(tr('Place in ground'), function() g_game.talk('/checkall ground,' .. entry.id) end)
  menu:addOption(tr('Send to player'), function() sendToPlayer(entry) end)
  menu:display(mousePos)
  return true
end

local function onCellClick(cell)
  local entry = cell.entry
  if not entry then return end
  local now = g_clock.millis()
  if lastClicked == entry and now - lastClickTime <= DOUBLE_CLICK_MS then
    lastClicked = nil
    activate(entry)
    return
  end
  lastClicked, lastClickTime = entry, now
  selectEntry(entry)
end

local function setKind(newKind)
  kind = newKind
  selected, lastClicked = nil, nil
  win.grid:destroyChildren()
  cells = {}
  win.bagOnly:setVisible(kind.key == 'I')
  local marginX = math.floor((win.grid:getWidth() - kind.columns * kind.pitchX) / 2)
  local marginY = math.floor((win.grid:getHeight() - kind.rows * kind.pitchY) / 2)
  for row = 0, kind.rows - 1 do
    for column = 0, kind.columns - 1 do
      local cell = g_ui.createWidget(kind.cell, win.grid)
      cell:setMarginLeft(marginX + column * kind.pitchX)
      cell:setMarginTop(marginY + row * kind.pitchY)
      cell.onClick = onCellClick
      cell.onMouseRelease = onCellMouseRelease
      if cell.creature then
        cell.creature:setCenter(true)
        cell.creature:setAnimate(true)
      end
      cells[#cells + 1] = cell
    end
  end
  showDetails(nil)
  applyFilter()
end

local function create()
  win = g_ui.createWidget('CheckAllWindow', rootWidget)
  win.grid.onMouseWheel = function(_, _, direction)
    win.scroll:setValue(win.scroll:getValue() + (direction == MouseWheelUp and -kind.wheel or kind.wheel))
    return true
  end
  win.scroll.onValueChange = function(_, value)
    firstRow = value
    fillCells()
  end
  win.details.previewBox.previewCreature:setCenter(true)
  win.details.previewBox.previewCreature:setAnimate(true)
  for _, k in ipairs(KINDS) do
    local tab = win.tabBar:addTab(tr(k.title) .. ' (' .. #lists[k.key] .. ')')
    tab.kind = k
  end
  win.tabBar.onTabChange = function(_, tab) setKind(tab.kind) end
  setKind(KINDS[1])
  animateEvent = cycleEvent(animate, ANIMATE_MS)
end

function show()
  if not g_game.isOnline() or not g_game.getLocalPlayer() or not loadLists() then return end
  colors = g_game.getLocalPlayer():getOutfit()
  if not win then create() end
  win:show()
  win:raise()
  win:focus()
  win.searchEdit:focus()
end

function hide()
  removeEvent(animateEvent)
  removeEvent(filterEvent)
  animateEvent, filterEvent = nil, nil
  if win then
    win:destroy()
    win = nil
  end
  cells, view, selected, lastClicked = {}, nil, nil, nil
end

function onSearchChange()
  if not win or not kind then return end
  removeEvent(filterEvent)
  filterEvent = scheduleEvent(applyFilter, FILTER_DELAY_MS)
end

function activateSelected()
  activate(selected)
end

function copySelected()
  if not selected then return end
  g_window.setClipboardText(tostring(selected.id))
  setStatus(tr('Id %d copied.', selected.id))
end

local function onTextMessage(mode, text)
  if text:sub(1, #MESSAGE_PREFIX) ~= MESSAGE_PREFIX then return end
  local message = text:sub(#MESSAGE_PREFIX + 1)
  if message:sub(1, #OPENING) == OPENING then
    show()
  else
    setStatus(message)
  end
end

local function onGameEnd()
  hide()
  lists = nil
end

function init()
  g_ui.importStyle('checkall')
  connect(g_game, {onTextMessage = onTextMessage, onGameEnd = onGameEnd})
end

function terminate()
  disconnect(g_game, {onTextMessage = onTextMessage, onGameEnd = onGameEnd})
  onGameEnd()
end
