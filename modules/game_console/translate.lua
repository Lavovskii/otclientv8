-- The Translate button of the chat (the owner, 2026-11-16). Every line a player says in a chat where players talk
-- (Default: say, whisper, yell; private messages; the channels) ends with a small blue [Translate]. A click asks
-- MyMemory (api.mymemory.translated.net), which finds the language by itself and answers in English; the English
-- line is written under the message.
--
-- Nothing of it goes through the game server: the client asks the translator straight away, and only when a player
-- clicks. The button is part of the line's own text (no widget of its own), so 1000 players talking cost nothing more
-- than the chat already costs. Answers are kept (TRANSLATE_CACHE_SIZE texts), one click at a time per line, and at most
-- TRANSLATE_PER_MINUTE asks a minute (the free translator gives each player's address 5000 characters a day).

TRANSLATE_URL = 'https://api.mymemory.translated.net/get?langpair=autodetect%7Cen&q='
TRANSLATE_BUTTON = '[Translate]'
TRANSLATE_BUTTON_COLOR = '#5fb4ff'
TRANSLATE_WAIT_COLOR = '#8a8a8a'
TRANSLATE_RESULT_COLOR = '#a8e0ff'
TRANSLATE_MAX_TEXT = 450 -- bytes the translator takes in one ask (its limit is 500 in UTF-8)
TRANSLATE_CACHE_SIZE = 300
TRANSLATE_PER_MINUTE = 20

-- the modes of a player talking (not NPCs, monsters, spells, server messages or loot)
TRANSLATE_MODES = {
  [MessageModes.Say] = true,
  [MessageModes.Whisper] = true,
  [MessageModes.Yell] = true,
  [MessageModes.PrivateFrom] = true,
  [MessageModes.Channel] = true,
  [MessageModes.ChannelHighlight] = true,
  [MessageModes.GamemasterChannel] = true,
  [MessageModes.GamemasterPrivateFrom] = true,
}

local cache = {} -- message -> {text = English, from = language code} or {english = true}
local cacheOrder = {}
local asks = {} -- os.time() of the recent asks
local nextToken = 0

-- may this message get a button: a player's words, not one's own, with at least two letters
function translateWanted(mode, name, message)
  if not TRANSLATE_MODES[mode] or type(message) ~= 'string' then
    return false
  end
  if name and name == g_game.getCharacterName() then
    return false
  end
  local _, letters = message:gsub('%a', '')
  if letters < 2 then
    local _, high = message:gsub('[\128-\255]', '')
    return high >= 2
  end
  return true
end

-- the game's texts are latin1; the translator speaks UTF-8
local function latin1ToUtf8(text)
  return (text:gsub('[\128-\255]', function(c)
    local b = c:byte()
    return string.char(0xC0 + math.floor(b / 64), 0x80 + b % 64)
  end))
end

local function utf8ToLatin1(text)
  local out, i, n = {}, 1, #text
  while i <= n do
    local b = text:byte(i)
    local code, size
    if b < 0x80 then code, size = b, 1
    elseif b >= 0xF0 then code, size = -1, 4
    elseif b >= 0xE0 then
      local b2, b3 = text:byte(i + 1) or 0, text:byte(i + 2) or 0
      code, size = (b % 16) * 4096 + (b2 % 64) * 64 + (b3 % 64), 3
    elseif b >= 0xC0 then
      local b2 = text:byte(i + 1) or 0
      code, size = (b % 32) * 64 + (b2 % 64), 2
    else code, size = -1, 1 end
    if code == 0x2019 or code == 0x2018 then code = 39 -- ' '
    elseif code == 0x201C or code == 0x201D then code = 34 -- " "
    elseif code == 0x2026 then out[#out + 1] = '...'; code = nil
    elseif code == 0x2013 or code == 0x2014 then code = 45 end
    if code then
      out[#out + 1] = (code >= 0 and code <= 255) and string.char(code) or '?'
    end
    i = i + size
  end
  return table.concat(out)
end

local function urlEncode(text)
  return (text:gsub('[^%w%-%._~]', function(c) return string.format('%%%02X', c:byte()) end))
end

-- the translator writes some characters as HTML entities
local function unescape(text)
  text = text:gsub('&#(%d+);', function(n)
    n = tonumber(n)
    return (n and n < 256) and string.char(n) or '?'
  end)
  return (text:gsub('&quot;', '"'):gsub('&#39;', "'"):gsub('&lt;', '<'):gsub('&gt;', '>'):gsub('&amp;', '&'))
end

local function remember(message, value)
  if not cache[message] then
    cacheOrder[#cacheOrder + 1] = message
    if #cacheOrder > TRANSLATE_CACHE_SIZE then
      cache[table.remove(cacheOrder, 1)] = nil
    end
  end
  cache[message] = value
end

local function mayAsk()
  local now = os.time()
  while asks[1] and now - asks[1] >= 60 do
    table.remove(asks, 1)
  end
  if #asks >= TRANSLATE_PER_MINUTE then
    return false
  end
  asks[#asks + 1] = now
  return true
end

-- draws the line: the message, then the button (or what it became), and the English under it when there is one
local function draw(label)
  local t = label.translate
  if not t then return end
  local data = {}
  for i = 1, #t.base, 2 do
    data[#data + 1] = t.base[i]
    data[#data + 1] = t.base[i + 1]
  end
  local shown = t.plain .. ' '
  data[#data + 1] = ' '
  data[#data + 1] = t.color
  local button, color = TRANSLATE_BUTTON, TRANSLATE_BUTTON_COLOR
  if t.state == 'wait' then
    button, color = '[...]', TRANSLATE_WAIT_COLOR
  elseif t.state == 'english' then
    button, color = '[English]', TRANSLATE_WAIT_COLOR
  elseif t.state == 'done' then
    button, color = '[' .. (t.from or '?'):upper() .. ']', TRANSLATE_WAIT_COLOR
  elseif t.state == 'failed' then
    button, color = '[Translate failed, click to try again]', '#e07070'
  end
  t.first = #shown
  t.last = #shown + #button - 1
  shown = shown .. button
  data[#data + 1] = button
  data[#data + 1] = color
  if t.state == 'done' and t.english then
    local line = '\n   ' .. t.english
    shown = shown .. line
    data[#data + 1] = line
    data[#data + 1] = TRANSLATE_RESULT_COLOR
  end
  label:setText(shown)
  label:setColoredText(data)
end

-- called by addTabText for every line: puts the button on a player's line, takes it off a reused label
function translateDecorate(label, plain, color, coloredData, message)
  label.translate = nil
  if not message then
    return
  end
  label.translate = {plain = plain, color = color, base = coloredData or {plain, color}, message = message, state = 'idle'}
  local known = cache[message]
  if known then
    label.translate.state = known.english and 'english' or 'done'
    label.translate.english = known.text
    label.translate.from = known.from
  end
  draw(label)
end

local function finish(label, token, state, english, from)
  if not label or label:isDestroyed() or not label.translate or label.translate.token ~= token then
    return -- the line was reused for another message meanwhile
  end
  label.translate.state = state
  label.translate.english = english
  label.translate.from = from
  draw(label)
end

local function ask(label)
  local t = label.translate
  local message = t.message
  if #message > TRANSLATE_MAX_TEXT then
    message = message:sub(1, TRANSLATE_MAX_TEXT)
  end
  nextToken = nextToken + 1
  local token = nextToken
  t.token = token
  t.state = 'wait'
  draw(label)

  local ok = pcall(HTTP.get, TRANSLATE_URL .. urlEncode(latin1ToUtf8(message)), function(body, err)
    if err or type(body) ~= 'string' then
      return finish(label, token, 'failed')
    end
    local good, data = pcall(json.decode, body)
    if not good or type(data) ~= 'table' or type(data.responseData) ~= 'table' then
      return finish(label, token, 'failed')
    end
    local details = tostring(data.responseDetails or '')
    if details:find('DISTINCT LANGUAGES', 1, true) then
      remember(t.message, {english = true})
      return finish(label, token, 'english')
    end
    local status = tonumber(data.responseStatus) or 0
    local text = data.responseData.translatedText
    if status ~= 200 or type(text) ~= 'string' or #text == 0 then
      return finish(label, token, 'failed')
    end
    local from = tostring(data.responseData.detectedLanguage or ''):match('^(%a+)') or '?'
    if from:lower() == 'en' then
      remember(t.message, {english = true})
      return finish(label, token, 'english')
    end
    text = unescape(utf8ToLatin1(text))
    remember(t.message, {text = text, from = from})
    finish(label, token, 'done', text, from)
  end)
  if not ok then
    finish(label, token, 'failed')
  end
end

-- a left click on a line: true when it was on the button (and it did something)
function translateClick(label, mousePos)
  local t = label.translate
  if not t or not t.first then return false end
  local selection = label.getSelection and label:getSelection() or ''
  if selection and #selection > 0 then return false end
  local pos = label:getTextPos(mousePos)
  if not pos or pos < t.first or pos > t.last then return false end
  return translateLabel(label)
end

-- the button of this line was clicked (also used by tools/window_preview)
function translateLabel(label)
  local t = label and label.translate
  if not t then return false end
  if t.state ~= 'idle' and t.state ~= 'failed' then return true end
  local known = cache[t.message]
  if known then
    t.state = known.english and 'english' or 'done'
    t.english, t.from = known.text, known.from
    draw(label)
    return true
  end
  if not mayAsk() then
    modules.game_textmessage.displayFailureMessage(tr('Too many translations: wait a moment.'))
    return true
  end
  ask(label)
  return true
end
