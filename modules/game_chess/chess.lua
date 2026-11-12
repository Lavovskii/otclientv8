-- The chess minigame (the owner, 2026-11-11): a chessboard in the game (action id 45300) opens this window. The lobby shows the
-- top 5 of every mode and the buttons to look for an opponent or to play Co.Op; the game page has the board, the clocks and the
-- moves. The server (data/lib/134-chess.lua) holds the game: this window shows it, works out the legal moves with the same rules
-- (engine.lua, a copy of the server's 133-chess-engine.lua) and sends the move the player makes. Extended opcode 38, see the server.
local OPCODE = 38
local SQUARE = 52
local MODES = {'bullet', 'blitz', 'rapid', 'classic', 'chess960', 'coop'}
local REASONS = {checkmate = 'by checkmate', resignation = 'by resignation', time = 'on time', abandon = 'the opponent left',
  stalemate = 'by stalemate', fifty = 'by the 50-move rule', repetition = 'by threefold repetition', material = 'insufficient material',
  agreement = 'by agreement'}

local window
local lobby = {cards = {}, points = 0, queue = nil, queueSince = 0}
local game -- the game on the board, or nil
local squares = {} -- square number -> widget
local selected
local clockEvent, queueEvent

-- what each player sets for himself (Settings), kept in this client's settings under "chess"
local PIECE_SETS = {{id = 'A', name = 'Kingdom'}, {id = 'B', name = 'Marble'}, {id = 'C', name = 'Dwarves'}, {id = 'D', name = 'Ice & Fire'}}
local THEMES = {{id = 'classic', name = 'Classic'}, {id = 'stone', name = 'Stone'}, {id = 'emerald', name = 'Emerald'},
  {id = 'ocean', name = 'Ocean'}, {id = 'royal', name = 'Royal'}, {id = 'night', name = 'Night'}}
local OPTIONS = {{id = 'legal', text = 'Show the legal moves of a piece'}, {id = 'last', text = 'Highlight the last move'},
  {id = 'coords', text = 'Show the coordinates (a-h, 1-8)'}, {id = 'queen', text = 'Always promote to a queen'},
  {id = 'confirm', text = 'Ask before resigning'}}
local DEFAULTS = {pieces = 'A', board = 'classic', legal = true, last = true, coords = true, queen = false, confirm = true}
local settings = {}

local function loadSettings()
  local saved = g_settings.getNode('chess') or {}
  settings = {}
  for k, v in pairs(DEFAULTS) do
    if saved[k] ~= nil then settings[k] = saved[k] else settings[k] = v end
  end
  local valid = false
  for _, p in ipairs(PIECE_SETS) do if p.id == settings.pieces then valid = true end end
  if not valid then settings.pieces = DEFAULTS.pieces end
  valid = false
  for _, t in ipairs(THEMES) do if t.id == settings.board then valid = true end end
  if not valid then settings.board = DEFAULTS.board end
end

local function saveSettings()
  g_settings.setNode('chess', settings)
end

local function pieceImage(color, kind, set)
  return '/images/game/chess/pieces/' .. (set or settings.pieces) .. '/' .. color .. kind:upper()
end

local function squareImage(light, theme)
  return '/images/game/chess/themes/' .. (theme or settings.board) .. '/' .. (light and 'light' or 'dark')
end

local function send(text)
  local protocol = g_game.getProtocolGame()
  if protocol then protocol:sendExtendedOpcode(OPCODE, text) end
end

local function split(line)
  local out = {}
  for part in (line .. '|'):gmatch('([^|]*)|') do table.insert(out, part) end
  return out
end

local function comma(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  return (s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

local function clockText(ms)
  ms = math.max(0, ms)
  local s = math.floor(ms / 1000)
  if s < 20 then
    return string.format('%d:%02d.%d', math.floor(s / 60), s % 60, math.floor(ms % 1000 / 100))
  end
  return string.format('%d:%02d', math.floor(s / 60), s % 60)
end

-- ------------------------------------------------------------------------------------------------------------------- lobby
local function drawQueue()
  if not window then return end
  local bar = window.lobby.queueBar
  if lobby.queue then
    local seconds = os.time() - lobby.queueSince
    local card = lobby.cards[lobby.queue]
    bar.text:setText(tr('Looking for a %s opponent... %d:%02d', card and card.label or lobby.queue, math.floor(seconds / 60), seconds % 60))
    bar:show()
  else
    bar:hide()
  end
  for id, card in pairs(lobby.cards) do
    if card.widget and card.widget.playButton then
      card.widget.playButton:setEnabled(not lobby.queue and not lobby.inGame)
      card.widget.botButton:setEnabled(not lobby.queue and not lobby.inGame)
    end
  end
end

local function tickQueue()
  queueEvent = nil
  drawQueue()
  if lobby.queue and window and window:isVisible() then queueEvent = scheduleEvent(tickQueue, 1000) end
end

local function drawLobby()
  if not window then return end
  window.lobby.header.points.value:setText(tr('Minigame Points: %s', comma(lobby.points)))
  local holder = window.lobby.cards
  for _, id in ipairs(MODES) do
    local card = lobby.cards[id]
    if card then
      if not card.widget then
        card.widget = g_ui.createWidget('ChessModeCard', holder)
        card.widget.playButton.onClick = function() send('queue|' .. id) end
        card.widget.botButton.onClick = function() send('bot|' .. id) end
        if id == 'coop' then
          card.widget.playButton:hide()
          card.widget.botButton:hide()
          card.widget.ribbon:setImageSource('/images/taskboard/ribbon_silver')
        end
      end
      local w = card.widget
      w.ribbon.title:setText(id == 'coop' and tr('Player vs Co.Op') or (card.label .. '  ' .. card.clock))
      w.table.rows:destroyChildren()
      for i, e in ipairs(card.top) do
        local row = g_ui.createWidget('ChessRankRow', w.table.rows)
        row.rank:setText(i .. '.')
        row.name:setText(e.name)
        row.score:setText(id == 'coop' and tr('%d wins', e.wins) or tostring(e.rating))
        if e.name == lobby.me then row.name:setColor('#f4d68c') end
      end
      w.table.empty:setVisible(#card.top == 0)
      if id == 'coop' then
        w.mine:setText(tr('You: %dW %dL', card.wins, card.losses))
        w.waiting:setText(tr('3 points a win'))
      else
        w.mine:setText(tr('You: %d  (%dW %dL %dD)', card.rating, card.wins, card.losses, card.draws))
        w.waiting:setText(card.waiting > 0 and tr('%d waiting', card.waiting) or tr('nobody waiting'))
        w.waiting:setColor(card.waiting > 0 and '#8fd48f' or '#8a8a8a')
      end
    end
  end
  drawQueue()
end

local function onHome(lines)
  local h = split(lines[1])
  lobby.points = tonumber(h[2]) or 0
  lobby.queue = h[3] ~= '-' and h[3] or nil
  lobby.queueSince = os.time() - (tonumber(h[4]) or 0)
  lobby.inGame = h[5] == '1'
  lobby.me = h[6]
  for _, card in pairs(lobby.cards) do card.top = {} end
  for i = 2, #lines do
    local f = split(lines[i])
    if f[1] == 'R' then
      local card = lobby.cards[f[2]] or {}
      lobby.cards[f[2]] = card
      card.label, card.clock, card.waiting = f[3], f[4], tonumber(f[5]) or 0
      card.rating, card.wins, card.losses, card.draws = tonumber(f[6]) or 1200, tonumber(f[7]) or 0, tonumber(f[8]) or 0, tonumber(f[9]) or 0
      card.top = {}
    elseif f[1] == 'P' and lobby.cards[f[2]] then
      table.insert(lobby.cards[f[2]].top, {name = f[4], rating = tonumber(f[5]) or 0, wins = tonumber(f[6]) or 0})
    end
  end
  drawLobby()
  removeEvent(queueEvent)
  queueEvent = lobby.queue and scheduleEvent(tickQueue, 1000) or nil
end

function leaveQueue()
  send('leave')
end

-- ------------------------------------------------------------------------------------------------------------------- the board
local function flipped() return game and game.color == 'b' end

local function squareAt(col, row)
  -- col, row from the top-left of the drawn board, 1..8
  if flipped() then return CHESS.sq(9 - col, row) end
  return CHESS.sq(col, 9 - row)
end

local function buildBoard()
  local board = window.game.boardFrame.board
  board:destroyChildren()
  squares = {}
  for row = 1, 8 do
    for col = 1, 8 do
      local s = squareAt(col, row)
      local w = g_ui.createWidget('ChessSquare', board)
      w:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      w:addAnchor(AnchorTop, 'parent', AnchorTop)
      w:setMarginLeft((col - 1) * SQUARE)
      w:setMarginTop((row - 1) * SQUARE)
      local light = (CHESS.fileOf(s) + CHESS.rankOf(s)) % 2 == 1
      w:setImageSource(squareImage(light))
      w.light = light
      w.onClick = function() modules.game_chess.clickSquare(s) end
      w.onHoverChange = function(widget, hovered)
        if hovered and game and game.mine then widget.hint:setImageSource('/images/game/chess/hover')
        elseif not hovered then widget.hint:setImageSource('') end
      end
      squares[s] = w
    end
  end
  local ranks, files = window.game.boardFrame.ranks, window.game.boardFrame.files
  ranks:setVisible(settings.coords)
  files:setVisible(settings.coords)
  ranks:destroyChildren()
  files:destroyChildren()
  for i = 1, 8 do
    local r = g_ui.createWidget('Label', ranks)
    r:addAnchor(AnchorTop, 'parent', AnchorTop)
    r:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    r:setMarginTop((i - 1) * SQUARE + 19)
    r:setText(tostring(flipped() and i or 9 - i))
    r:setFont('verdana-11px-rounded')
    r:setColor('#c9a86a')
    local f = g_ui.createWidget('Label', files)
    f:addAnchor(AnchorTop, 'parent', AnchorTop)
    f:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    f:setMarginLeft((i - 1) * SQUARE + 22)
    f:setMarginTop(2)
    f:setText(string.char(96 + (flipped() and 9 - i or i)))
    f:setFont('verdana-11px-rounded')
    f:setColor('#c9a86a')
  end
end

local function legalFrom(s)
  local out = {}
  if not game or not game.pos then return out end
  for _, m in ipairs(CHESS.legalMoves(game.pos)) do
    if m.from == s then table.insert(out, m) end
  end
  return out
end

local function drawPieces()
  if not game then return end
  local pos = game.pos
  local last = game.uci[#game.uci]
  local lastFrom, lastTo = last and CHESS.parseSquare(last:sub(1, 2)), last and CHESS.parseSquare(last:sub(3, 4))
  local checkSq = CHESS.inCheck(pos) and CHESS.kingSquare(pos, pos.turn) or nil
  local targets = {}
  if selected and settings.legal then
    for _, m in ipairs(legalFrom(selected)) do targets[m.castle and m.to or m.to] = pos.board[m.to] and 'capture' or 'move' end
  end
  for s, w in pairs(squares) do
    local p = pos.board[s]
    w.piece:setImageSource(p and pieceImage(p == p:upper() and 'w' or 'b', p) or '')
    w:setImageSource(squareImage(w.light))
    local mark = ''
    if s == selected then mark = 'selected'
    elseif s == checkSq then mark = 'check'
    elseif settings.last and (s == lastFrom or s == lastTo) then mark = 'last' end
    w.mark:setImageSource(mark ~= '' and ('/images/game/chess/' .. mark) or '')
    w.hint:setImageSource(targets[s] and ('/images/game/chess/' .. targets[s]) or '')
  end
end

local function drawMoves()
  local list = window.game.movesBox.moves
  list:destroyChildren()
  for i = 1, #game.san, 2 do
    local item = g_ui.createWidget('ChessMoveRow', list)
    item.num:setText((math.floor(i / 2) + 1) .. '.')
    item.white:setText(game.san[i])
    item.black:setText(game.san[i + 1] or '')
  end
  local children = list:getChildren()
  if #children > 0 then list:ensureChildVisible(children[#children]) end
end

local function drawPlayers()
  local g = window.game
  local mine = game.color
  local function fill(box, color)
    local isWhite = color == 'w'
    local name = isWhite and game.white or game.black
    local rating = isWhite and game.whiteRating or game.blackRating
    box.name:setText(name)
    box.info:setText(game.bot and (name == 'Co.Op' and tr('Co.Op') or tr('You')) or tr('%s  -  rating %d', isWhite and tr('White') or tr('Black'), rating))
  end
  fill(g.bottomPlayer, mine)
  fill(g.topPlayer, mine == 'w' and 'b' or 'w')
  g.buttons.drawButton:setVisible(not game.bot and not game.over)
  g.buttons.resignButton:setVisible(not game.over)
end

local function drawClocks()
  if not game or not window then return end
  local g = window.game
  local function ms(color)
    local base = color == 'w' and game.wMs or game.bMs
    if game.over or game.pos.turn ~= color then return base end
    return base - (g_clock.millis() - game.syncAt)
  end
  local function set(box, color)
    local left = ms(color)
    box.clockBox.clock:setText(clockText(left))
    local active = not game.over and game.pos.turn == color
    box.clockBox.clock:setColor(active and (left < 20000 and '#ff6a5a' or '#ffffff') or '#7a7a7a')
  end
  set(g.bottomPlayer, game.color)
  set(g.topPlayer, game.color == 'w' and 'b' or 'w')
end

local function tickClock()
  clockEvent = nil
  drawClocks()
  if game and not game.over then clockEvent = scheduleEvent(tickClock, 100) end
end

local function drawStatus()
  local text
  if game.over then
    text = ''
  elseif game.pos.turn == game.color then
    text = CHESS.inCheck(game.pos) and tr('Check! Your move.') or tr('Your move.')
  else
    text = game.bot and tr('Co.Op is thinking...') or tr('Waiting for %s...', game.color == 'w' and game.black or game.white)
  end
  window.game.status:setText(text)
end

local function drawGame()
  game.mine = not game.over and game.pos.turn == game.color
  drawPieces()
  drawMoves()
  drawPlayers()
  drawStatus()
  drawClocks()
  removeEvent(clockEvent)
  clockEvent = scheduleEvent(tickClock, 100)
end

local function showPage(page)
  window.lobby:setVisible(page == 'lobby')
  window.game:setVisible(page == 'game')
end

local function onGame(f)
  game = {id = tonumber(f[2]), mode = f[3], color = f[4], white = f[5], black = f[6], pos = CHESS.fromFen(f[7]),
    wMs = tonumber(f[8]) or 0, bMs = tonumber(f[9]) or 0, bot = f[10] == '1', startFen = f[11], uci = {}, san = {},
    whiteRating = tonumber(f[14]) or 0, blackRating = tonumber(f[15]) or 0, syncAt = g_clock.millis()}
  for m in (f[12] or ''):gmatch('%S+') do table.insert(game.uci, m) end
  for m in (f[13] or ''):gmatch('%S+') do table.insert(game.san, m) end
  selected = nil
  lobby.queue = nil
  window.game.boardFrame.resultLayer:hide()
  window.game.boardFrame.promotion:hide()
  window.game.drawBox:hide()
  buildBoard()
  showPage('game')
  drawGame()
  show()
end

local function onMove(f)
  if not game then return send('game') end
  table.insert(game.uci, f[2])
  table.insert(game.san, f[3])
  game.pos = CHESS.fromFen(f[4])
  game.wMs, game.bMs, game.syncAt = tonumber(f[5]) or 0, tonumber(f[6]) or 0, g_clock.millis()
  selected = nil
  window.game.drawBox:hide()
  drawGame()
end

local function onEnd(f)
  if not game then return end
  game.over = true
  local result, reason, points, delta = f[2], f[3], tonumber(f[4]) or 0, tonumber(f[5]) or 0
  lobby.points = tonumber(f[6]) or lobby.points
  local won = (result == '1-0' and game.color == 'w') or (result == '0-1' and game.color == 'b')
  local layer = window.game.boardFrame.resultLayer
  local box = layer.panel
  box.title:setText(result == '1/2' and tr('Draw') or (won and tr('Victory!') or tr('Defeat')))
  box.title:setColor(result == '1/2' and '#d8d8d8' or (won and '#f4d68c' or '#e06a5a'))
  box.reason:setText(tr(REASONS[reason] or reason))
  local reward = {}
  if points > 0 then table.insert(reward, tr('+%d minigame points', points)) end
  if not game.bot and delta ~= 0 then table.insert(reward, tr('rating %s%d', delta > 0 and '+' or '', delta)) end
  if won and points == 0 then table.insert(reward, tr('no points: the game was too short')) end
  box.reward:setText(table.concat(reward, '  -  '))
  box.reward:setColor(points > 0 and '#8fd48f' or '#a8a8a8')
  layer:show()
  layer:raise()
  window.game.drawBox:hide()
  drawGame()
end

function backToLobby()
  game = nil
  showPage('lobby')
  send('home')
end

-- ------------------------------------------------------------------------------------------------------------------- moving
local function choosePromotion(from, to)
  local box = window.game.boardFrame.promotion
  box.choices:destroyChildren()
  for _, kind in ipairs({'q', 'r', 'b', 'n'}) do
    local b = g_ui.createWidget('UIButton', box.choices)
    b:setSize({width = 48, height = 48})
    b:setImageSource(pieceImage(game.color, kind))
    b.onClick = function()
      box:hide()
      send('move|' .. CHESS.squareName(from) .. CHESS.squareName(to) .. kind)
    end
  end
  box:show()
  box:raise()
end

function clickSquare(s)
  if not game or game.over or game.pos.turn ~= game.color then return end
  local p = game.pos.board[s]
  if selected then
    for _, m in ipairs(legalFrom(selected)) do
      if m.to == s then
        local from = selected
        selected = nil
        if m.promo then
          drawPieces()
          if settings.queen then return send('move|' .. CHESS.squareName(from) .. CHESS.squareName(s) .. 'q') end
          return choosePromotion(from, s)
        end
        send('move|' .. CHESS.squareName(from) .. CHESS.squareName(m.castle and m.to or s))
        drawPieces()
        return
      end
    end
  end
  if p and CHESS.colorOf(p) == game.color then
    selected = s ~= selected and s or nil
  else
    selected = nil
  end
  drawPieces()
end

function resign()
  if not game or game.over then return end
  local button = window.game.buttons.resignButton
  if not settings.confirm then return send('resign') end
  if button.confirm then
    button.confirm = nil
    button:setText(tr('Resign'))
    send('resign')
  else
    button.confirm = true
    button:setText(tr('Sure?'))
    scheduleEvent(function()
      if button and not button:isDestroyed() then button.confirm = nil; button:setText(tr('Resign')) end
    end, 3000)
  end
end

function offerDraw()
  if game and not game.over and not game.bot then send('draw') end
end

function answerDraw(yes)
  window.game.drawBox:hide()
  send(yes and 'draw|yes' or 'draw|no')
end

-- ------------------------------------------------------------------------------------------------------------------- settings
local function drawSettings()
  local box = window.settings.box
  for _, w in ipairs(box.pieces:getChildren()) do w.ring:setVisible(w.choice == settings.pieces) end
  for _, w in ipairs(box.boards:getChildren()) do w.ring:setVisible(w.choice == settings.board) end
  for _, w in ipairs(box.options:getChildren()) do w:setChecked(settings[w.option] and true or false) end
end

local function applySettings()
  saveSettings()
  drawSettings()
  if game and window.game:isVisible() then
    buildBoard()
    drawPieces()
  end
end

local function buildSettings()
  local box = window.settings.box
  box.pieces:destroyChildren()
  for _, set in ipairs(PIECE_SETS) do
    local w = g_ui.createWidget('ChessChoice', box.pieces)
    w:setWidth(140)
    w.choice = set.id
    w.pic1:setImageSource(pieceImage('w', 'K', set.id))
    w.pic2:setImageSource(pieceImage('b', 'N', set.id))
    w.label:setText(set.id .. ' - ' .. tr(set.name))
    w.onClick = function() settings.pieces = set.id; applySettings() end
  end
  box.boards:destroyChildren()
  for _, theme in ipairs(THEMES) do
    local w = g_ui.createWidget('ChessChoice', box.boards)
    w.choice = theme.id
    w.pic1:setImageSource(squareImage(true, theme.id))
    w.pic2:setImageSource(squareImage(false, theme.id))
    w.label:setText(tr(theme.name))
    w.onClick = function() settings.board = theme.id; applySettings() end
  end
  box.options:destroyChildren()
  for _, option in ipairs(OPTIONS) do
    local w = g_ui.createWidget('ChessOption', box.options)
    w.option = option.id
    w:setText(tr(option.text))
    w.onCheckChange = function(widget, checked)
      if settings[option.id] ~= checked then
        settings[option.id] = checked
        applySettings()
      end
    end
  end
end

function showSettings()
  if not window then return end
  drawSettings()
  window.settings:show()
  window.settings:raise()
end

function hideSettings()
  if window then window.settings:hide() end
end

-- ------------------------------------------------------------------------------------------------------------------- messages
local function onMessage(protocol, opcode, buffer)
  local lines = {}
  for line in tostring(buffer or ''):gmatch('[^\n]+') do table.insert(lines, line) end
  if #lines == 0 or not window then return end
  local f = split(lines[1])
  local kind = f[1]
  if kind == 'O' then
    show()
    if not game or game.over then showPage('lobby') end
    send('home')
  elseif kind == 'H' then
    onHome(lines)
  elseif kind == 'Q' then
    lobby.queue = f[2] ~= '-' and f[2] or nil
    lobby.queueSince = os.time() - (tonumber(f[3]) or 0)
    drawQueue()
    removeEvent(queueEvent)
    queueEvent = lobby.queue and scheduleEvent(tickQueue, 1000) or nil
  elseif kind == 'G' then
    onGame(f)
  elseif kind == 'M' then
    onMove(f)
  elseif kind == 'E' then
    onEnd(f)
  elseif kind == 'D' then
    if f[2] == 'offered' and game and not game.over then
      window.game.drawBox:show()
    elseif f[2] == 'declined' then
      window.game.status:setText(tr('Your draw offer was declined.'))
    end
  elseif kind == 'N' then
    if game and window.game:isVisible() then
      window.game.status:setText(f[2] or '')
    else
      displayInfoBox(tr('Chess Arena'), f[2] or '')
    end
  end
end

-- ------------------------------------------------------------------------------------------------------------------- window
function show()
  if not window then return end
  window:show()
  window:raise()
  window:focus()
end

function hide()
  if window then
    window.settings:hide()
    window:hide()
  end
  removeEvent(queueEvent)
  queueEvent = nil
end

-- walking away closes the lobby, never a game in progress
local function onWalk(creature, newPos, oldPos)
  if window and window:isVisible() and oldPos and newPos and not (game and not game.over) then hide() end
end

local function onGameEnd()
  hide()
  game, selected = nil, nil
  lobby.queue = nil
end

-- for the window preview
function preview(text)
  onMessage(nil, OPCODE, text)
end

function init()
  window = g_ui.displayUI('chess')
  window:hide()
  loadSettings()
  buildSettings()
  ProtocolGame.registerExtendedOpcode(OPCODE, onMessage)
  connect(g_game, {onGameEnd = onGameEnd})
  connect(LocalPlayer, {onPositionChange = onWalk})
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, {onGameEnd = onGameEnd})
  disconnect(LocalPlayer, {onPositionChange = onWalk})
  removeEvent(clockEvent)
  removeEvent(queueEvent)
  if window then window:destroy() end
  window, game = nil, nil
  lobby = {cards = {}, points = 0}
end
