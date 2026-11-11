-- A copy of the server's data/lib/133-chess-engine.lua: keep the two the same.
-- The rules of chess, shared by the server (data/lib/134-chess.lua) and the client (modules/game_chess/engine.lua, the same file):
-- legal moves, check, mate, stalemate, castling (also Chess960's), en passant, promotion, the 50-move rule, threefold repetition,
-- insufficient material, FEN, UCI and SAN. Plain Lua 5.1, no bit operations, no globals but CHESS.
--
-- A square is 1..64: (rank - 1) * 8 + file, file 1 = a, rank 1 = White's first rank. A piece is a letter, upper case White:
-- P N B R Q K. A position: {board = {[sq] = piece}, turn = "w"|"b", castle = {K=file|nil, Q=file|nil, k=..., q=...} (the file of
-- the rook that may still castle), ep = square|nil, half = moves since a capture or pawn move, full = move number}.
-- A move: {from, to, promo = "q"|"r"|"b"|"n"|nil, castle = "K"|"Q"|nil (to = the king's square after it), rook = the rook's
-- square for castling, ep = true for en passant}.
CHESS = CHESS or {}
local C = CHESS

local function sq(file, rank)
	return (rank - 1) * 8 + file
end
local function fileOf(s) return (s - 1) % 8 + 1 end
local function rankOf(s) return math.floor((s - 1) / 8) + 1 end
C.sq, C.fileOf, C.rankOf = sq, fileOf, rankOf

local function isWhite(p) return p ~= nil and p == p:upper() end
local function colorOf(p) if not p then return nil end return isWhite(p) and "w" or "b" end
local function other(c) return c == "w" and "b" or "w" end
C.colorOf, C.other = colorOf, other

local function copy(pos)
	local b = {}
	for k, v in pairs(pos.board) do b[k] = v end
	return {board = b, turn = pos.turn, castle = {K = pos.castle.K, Q = pos.castle.Q, k = pos.castle.k, q = pos.castle.q},
		ep = pos.ep, half = pos.half, full = pos.full, chess960 = pos.chess960}
end
C.copy = copy

-- ------------------------------------------------------------------------------------------------ FEN
C.START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

function C.fromFen(fen)
	local placement, turn, castle, ep, half, full = tostring(fen):match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%d*)%s*(%d*)")
	if not placement then return nil end
	local pos = {board = {}, turn = turn == "b" and "b" or "w", castle = {}, ep = nil, half = tonumber(half) or 0, full = tonumber(full) or 1}
	local rank, file = 8, 1
	for ch in placement:gmatch(".") do
		if ch == "/" then
			rank, file = rank - 1, 1
		elseif ch:match("%d") then
			file = file + tonumber(ch)
		elseif ch:match("[pnbrqkPNBRQK]") then
			if file <= 8 and rank >= 1 then pos.board[sq(file, rank)] = ch end
			file = file + 1
		end
	end
	-- castling: KQkq, or the rook's file (Shredder-FEN, Chess960): HAha
	local function kingFile(color)
		for s, p in pairs(pos.board) do
			if p == (color == "w" and "K" or "k") then return fileOf(s) end
		end
	end
	local function outerRook(color, side)
		local r = color == "w" and 1 or 8
		local kf = kingFile(color) or 5
		local from, to, step = side == "K" and 8 or 1, kf, side == "K" and -1 or 1
		for f = from, to, step do
			if pos.board[sq(f, r)] == (color == "w" and "R" or "r") then return f end
		end
	end
	for ch in castle:gmatch(".") do
		if ch == "K" then pos.castle.K = outerRook("w", "K")
		elseif ch == "Q" then pos.castle.Q = outerRook("w", "Q")
		elseif ch == "k" then pos.castle.k = outerRook("b", "K")
		elseif ch == "q" then pos.castle.q = outerRook("b", "Q")
		elseif ch:match("[A-H]") then
			local f, kf = ch:byte() - 64, kingFile("w") or 5
			if f > kf then pos.castle.K = f else pos.castle.Q = f end
			pos.chess960 = true
		elseif ch:match("[a-h]") then
			local f, kf = ch:byte() - 96, kingFile("b") or 5
			if f > kf then pos.castle.k = f else pos.castle.q = f end
			pos.chess960 = true
		end
	end
	if ep and ep:match("^[a-h][36]$") then
		pos.ep = sq(ep:byte(1) - 96, tonumber(ep:sub(2)))
	end
	return pos
end

function C.toFen(pos)
	local rows = {}
	for rank = 8, 1, -1 do
		local row, empty = "", 0
		for file = 1, 8 do
			local p = pos.board[sq(file, rank)]
			if p then
				if empty > 0 then row = row .. empty; empty = 0 end
				row = row .. p
			else
				empty = empty + 1
			end
		end
		if empty > 0 then row = row .. empty end
		table.insert(rows, row)
	end
	local c = ""
	local letters = pos.chess960 and {K = function(f) return string.char(64 + f) end, Q = function(f) return string.char(64 + f) end,
		k = function(f) return string.char(96 + f) end, q = function(f) return string.char(96 + f) end} or nil
	for _, k in ipairs({"K", "Q", "k", "q"}) do
		if pos.castle[k] then c = c .. (letters and letters[k](pos.castle[k]) or k) end
	end
	local ep = pos.ep and (string.char(96 + fileOf(pos.ep)) .. rankOf(pos.ep)) or "-"
	return table.concat(rows, "/") .. " " .. pos.turn .. " " .. (c == "" and "-" or c) .. " " .. ep .. " " .. pos.half .. " " .. pos.full
end

-- Chess960: one of the 960 back ranks (n = 0..959, the standard numbering; 518 is the usual one)
function C.start960(n)
	n = math.max(0, math.min(959, math.floor(tonumber(n) or 518)))
	local rank = {}
	local function freeSquares()
		local t = {}
		for f = 1, 8 do if not rank[f] then table.insert(t, f) end end
		return t
	end
	local light, dark = {2, 4, 6, 8}, {1, 3, 5, 7}
	rank[light[n % 4 + 1]] = "B"; n = math.floor(n / 4)
	rank[dark[n % 4 + 1]] = "B"; n = math.floor(n / 4)
	rank[freeSquares()[n % 6 + 1]] = "Q"; n = math.floor(n / 6)
	local knights = {{1, 2}, {1, 3}, {1, 4}, {1, 5}, {2, 3}, {2, 4}, {2, 5}, {3, 4}, {3, 5}, {4, 5}}
	local free, pair = freeSquares(), knights[n + 1]
	rank[free[pair[1]]] = "N"; rank[free[pair[2]]] = "N"
	free = freeSquares()
	rank[free[1]] = "R"; rank[free[2]] = "K"; rank[free[3]] = "R"
	local white = table.concat(rank)
	local fen = white:lower() .. "/pppppppp/8/8/8/8/PPPPPPPP/" .. white .. " w "
	local castling = string.char(64 + free[3]) .. string.char(64 + free[1]) .. string.char(96 + free[3]) .. string.char(96 + free[1])
	local pos = C.fromFen(fen .. castling .. " - 0 1")
	pos.chess960 = true
	return pos
end

-- ------------------------------------------------------------------------------------------------ attacks and moves
local KNIGHT = {{1, 2}, {2, 1}, {2, -1}, {1, -2}, {-1, -2}, {-2, -1}, {-2, 1}, {-1, 2}}
local KING = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}}
local ROOK = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
local BISHOP = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function onBoard(f, r) return f >= 1 and f <= 8 and r >= 1 and r <= 8 end

-- is square s attacked by a piece of color "by"?
function C.attacked(pos, s, by)
	local b, f, r = pos.board, fileOf(s), rankOf(s)
	local up = by == "w" and "" or nil
	local function is(p, letter) return p and colorOf(p) == by and p:upper() == letter end
	-- pawns
	local dr = by == "w" and -1 or 1
	for _, df in ipairs({-1, 1}) do
		if onBoard(f + df, r + dr) and is(b[sq(f + df, r + dr)], "P") then return true end
	end
	for _, d in ipairs(KNIGHT) do
		if onBoard(f + d[1], r + d[2]) and is(b[sq(f + d[1], r + d[2])], "N") then return true end
	end
	for _, d in ipairs(KING) do
		if onBoard(f + d[1], r + d[2]) and is(b[sq(f + d[1], r + d[2])], "K") then return true end
	end
	for _, d in ipairs(ROOK) do
		local x, y = f + d[1], r + d[2]
		while onBoard(x, y) do
			local p = b[sq(x, y)]
			if p then
				if is(p, "R") or is(p, "Q") then return true end
				break
			end
			x, y = x + d[1], y + d[2]
		end
	end
	for _, d in ipairs(BISHOP) do
		local x, y = f + d[1], r + d[2]
		while onBoard(x, y) do
			local p = b[sq(x, y)]
			if p then
				if is(p, "B") or is(p, "Q") then return true end
				break
			end
			x, y = x + d[1], y + d[2]
		end
	end
	return false
end

function C.kingSquare(pos, color)
	local k = color == "w" and "K" or "k"
	for s, p in pairs(pos.board) do
		if p == k then return s end
	end
end

function C.inCheck(pos, color)
	color = color or pos.turn
	local k = C.kingSquare(pos, color)
	return k ~= nil and C.attacked(pos, k, other(color))
end

-- the moves of the side to move, before checking that its king is safe
local function pseudo(pos)
	local moves, b, us = {}, pos.board, pos.turn
	local function add(from, to, extra)
		local m = {from = from, to = to}
		if extra then for k, v in pairs(extra) do m[k] = v end end
		table.insert(moves, m)
	end
	for s, p in pairs(b) do
		if colorOf(p) == us then
			local f, r, kind = fileOf(s), rankOf(s), p:upper()
			if kind == "P" then
				local dir, startRank, lastRank = us == "w" and 1 or -1, us == "w" and 2 or 7, us == "w" and 8 or 1
				local function pawnTo(to, extra)
					if rankOf(to) == lastRank then
						for _, promo in ipairs({"q", "r", "b", "n"}) do
							local e = {promo = promo}
							if extra then for k, v in pairs(extra) do e[k] = v end end
							add(s, to, e)
						end
					else
						add(s, to, extra)
					end
				end
				if onBoard(f, r + dir) and not b[sq(f, r + dir)] then
					pawnTo(sq(f, r + dir))
					if r == startRank and not b[sq(f, r + 2 * dir)] then add(s, sq(f, r + 2 * dir)) end
				end
				for _, df in ipairs({-1, 1}) do
					if onBoard(f + df, r + dir) then
						local to = sq(f + df, r + dir)
						if b[to] and colorOf(b[to]) ~= us then
							pawnTo(to)
						elseif pos.ep == to then
							add(s, to, {ep = true})
						end
					end
				end
			elseif kind == "N" or kind == "K" then
				for _, d in ipairs(kind == "N" and KNIGHT or KING) do
					if onBoard(f + d[1], r + d[2]) then
						local to = sq(f + d[1], r + d[2])
						if not b[to] or colorOf(b[to]) ~= us then add(s, to) end
					end
				end
			else
				local dirs = kind == "R" and ROOK or (kind == "B" and BISHOP or nil)
				local list = dirs and {dirs} or {ROOK, BISHOP}
				for _, group in ipairs(list) do
					for _, d in ipairs(group) do
						local x, y = f + d[1], r + d[2]
						while onBoard(x, y) do
							local to = sq(x, y)
							if b[to] then
								if colorOf(b[to]) ~= us then add(s, to) end
								break
							end
							add(s, to)
							x, y = x + d[1], y + d[2]
						end
					end
				end
			end
		end
	end
	-- castling, Chess960's rules too: king and rook end on g/f (short) or c/d (long); every square either crosses must be empty
	-- but for the two of them, and the king may not be in check or cross or land on an attacked square
	local rank = us == "w" and 1 or 8
	local ks = C.kingSquare(pos, us)
	if ks and rankOf(ks) == rank and not C.attacked(pos, ks, other(us)) then
		for _, side in ipairs({"K", "Q"}) do
			local key = us == "w" and side or side:lower()
			local rookFile = pos.castle[key]
			if rookFile then
				local rookSq = sq(rookFile, rank)
				local kf = fileOf(ks)
				local kingTo, rookTo = side == "K" and 7 or 3, side == "K" and 6 or 4
				if b[rookSq] == (us == "w" and "R" or "r") then
					local ok = true
					local lo = math.min(kf, rookFile, kingTo, rookTo)
					local hi = math.max(kf, rookFile, kingTo, rookTo)
					for x = lo, hi do
						local s = sq(x, rank)
						if s ~= ks and s ~= rookSq and b[s] then ok = false end
					end
					if ok then
						local a, z = math.min(kf, kingTo), math.max(kf, kingTo)
						for x = a, z do
							if C.attacked(pos, sq(x, rank), other(us)) then ok = false end
						end
					end
					if ok then add(ks, sq(kingTo, rank), {castle = side, rook = rookSq}) end
				end
			end
		end
	end
	return moves
end

-- the position after a move (no check that it is legal)
function C.apply(pos, m)
	local n = copy(pos)
	local b, us = n.board, pos.turn
	local piece = b[m.from]
	local captured = b[m.to]
	n.ep = nil
	if m.castle then
		local rank = us == "w" and 1 or 8
		local rookPiece = b[m.rook]
		b[m.from] = nil; b[m.rook] = nil
		b[m.to] = piece
		b[sq(m.castle == "K" and 6 or 4, rank)] = rookPiece
		captured = nil
	else
		b[m.from] = nil
		if m.ep then
			b[sq(fileOf(m.to), rankOf(m.from))] = nil
			captured = us == "w" and "p" or "P"
		end
		b[m.to] = m.promo and (us == "w" and m.promo:upper() or m.promo) or piece
		if piece:upper() == "P" and math.abs(rankOf(m.to) - rankOf(m.from)) == 2 then
			n.ep = sq(fileOf(m.from), (rankOf(m.from) + rankOf(m.to)) / 2)
		end
	end
	-- castling rights: a king that moves loses both, a rook that moves or is taken loses its side
	if piece:upper() == "K" then
		if us == "w" then n.castle.K, n.castle.Q = nil, nil else n.castle.k, n.castle.q = nil, nil end
	end
	for key, f in pairs({K = n.castle.K, Q = n.castle.Q, k = n.castle.k, q = n.castle.q}) do
		local rs = sq(f, (key == "K" or key == "Q") and 1 or 8)
		if (m.from == rs and not m.castle) or m.to == rs and not m.castle then n.castle[key] = nil end
	end
	n.half = (piece:upper() == "P" or captured) and 0 or pos.half + 1
	if us == "b" then n.full = pos.full + 1 end
	n.turn = other(us)
	n.lastCapture = captured
	return n
end

function C.legalMoves(pos)
	local out = {}
	for _, m in ipairs(pseudo(pos)) do
		local n = C.apply(pos, m)
		if not C.inCheck(n, pos.turn) then table.insert(out, m) end
	end
	return out
end

-- ------------------------------------------------------------------------------------------------ notation
local function name(s) return string.char(96 + fileOf(s)) .. rankOf(s) end
C.squareName = name
function C.parseSquare(t)
	if type(t) ~= "string" or not t:match("^[a-h][1-8]$") then return nil end
	return sq(t:byte(1) - 96, tonumber(t:sub(2)))
end

-- UCI: e2e4, e7e8q; castling as the king's two squares (e1g1), or king-takes-rook in Chess960 (UCI_Chess960)
function C.toUci(m, chess960)
	local to = (m.castle and chess960) and m.rook or m.to
	return name(m.from) .. name(to) .. (m.promo or "")
end

function C.findMove(pos, text)
	if type(text) ~= "string" then return nil end
	local from, to, promo = C.parseSquare(text:sub(1, 2)), C.parseSquare(text:sub(3, 4)), text:sub(5, 5)
	if not from or not to then return nil end
	promo = promo ~= "" and promo:lower() or nil
	for _, m in ipairs(C.legalMoves(pos)) do
		if m.from == from and (m.to == to or (m.castle and m.rook == to)) and (m.promo == promo or (m.promo and not promo and m.promo == "q")) then
			return m
		end
	end
end

-- SAN: Nf3, exd5, O-O, e8=Q+, Qh4#
function C.toSan(pos, m)
	local san
	if m.castle then
		san = m.castle == "K" and "O-O" or "O-O-O"
	else
		local piece = pos.board[m.from]:upper()
		local capture = pos.board[m.to] ~= nil or m.ep
		if piece == "P" then
			san = (capture and string.char(96 + fileOf(m.from)) .. "x" or "") .. name(m.to) .. (m.promo and "=" .. m.promo:upper() or "")
		else
			local sameFile, sameRank, others = false, false, false
			for _, o in ipairs(C.legalMoves(pos)) do
				if o.to == m.to and o.from ~= m.from and pos.board[o.from] == pos.board[m.from] then
					others = true
					if fileOf(o.from) == fileOf(m.from) then sameFile = true end
					if rankOf(o.from) == rankOf(m.from) then sameRank = true end
				end
			end
			local dis = ""
			if others then
				if not sameFile then dis = string.char(96 + fileOf(m.from))
				elseif not sameRank then dis = tostring(rankOf(m.from))
				else dis = name(m.from) end
			end
			san = piece .. dis .. (capture and "x" or "") .. name(m.to)
		end
	end
	local n = C.apply(pos, m)
	if C.inCheck(n) then
		san = san .. (#C.legalMoves(n) == 0 and "#" or "+")
	end
	return san
end

-- ------------------------------------------------------------------------------------------------ the end of a game
-- the key of a position for repetition: placement, turn, castling, en passant
function C.key(pos)
	local fen = C.toFen(pos)
	return fen:match("^(%S+ %S+ %S+ %S+)")
end

local function insufficient(pos)
	local minors, bishops = {}, {}
	for s, p in pairs(pos.board) do
		local k = p:upper()
		if k == "P" or k == "R" or k == "Q" then return false end
		if k == "B" or k == "N" then
			table.insert(minors, k)
			if k == "B" then table.insert(bishops, (fileOf(s) + rankOf(s)) % 2) end
		end
	end
	if #minors <= 1 then return true end
	-- only bishops, all on squares of one colour
	if #bishops == #minors then
		for i = 2, #bishops do
			if bishops[i] ~= bishops[1] then return false end
		end
		return true
	end
	return false
end

-- nil while the game goes on, or "checkmate" | "stalemate" | "fifty" | "repetition" | "material"; history = {key = count}
function C.result(pos, history)
	if #C.legalMoves(pos) == 0 then
		return C.inCheck(pos) and "checkmate" or "stalemate"
	end
	if pos.half >= 100 then return "fifty" end
	if history and (history[C.key(pos)] or 0) >= 3 then return "repetition" end
	if insufficient(pos) then return "material" end
	return nil
end
