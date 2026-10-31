-- The launcher of the installed client (it runs from data.zip, see init.lua): before the login it compares the
-- client with the update manifest of the website (Services.updater, written by tools/build_release.py). Like the
-- launcher of any game it updates the client by itself, nothing to click:
--   up to date        Play opens the login;
--   an update is out  it starts at once: only the changed files are downloaded and written into a new data.zip in the
--                     user's folder (AppData/OTClientV8/ForgottenL); new game graphics (Tibia.dat/spr of the the860
--                     assets, kept outside data.zip in that folder) come in zipped parts written straight into their
--                     files; then the client restarts by itself, up to date. Play waits until then.
-- When the website can't be reached, Play stays possible (with Try again). Only a client that can't write the graphics
-- itself (no Lua io, a folder it can't open) is sent to the full installer (Download the installer).
Updater = { }

Updater.maxRetries = 5

local launcher
local logo
local backToLogin -- shows the login again when Play closes a launcher the login brought back
local loadModulesFunction
local scheduledEvent
local httpOperationId = 0
local update -- what the update downloads: {url, files = {{path, checksum}}, finalFiles, binary, graphics}
-- each graphics part is downloaded under this name: the client keeps a download in memory, the next part replaces it
local GRAPHICS_DOWNLOAD = "graphics-part.zip"

local function onLog(level, message, time)
  if level == LogError then
    Updater.error(message)
    g_logger.setOnLog(nil)
  end
end

local function initAppWindow()
  if g_resources.getLayout() == "mobile" then
    g_window.setMinimumSize({ width = 640, height = 360 })
  else
    g_window.setMinimumSize({ width = 800, height = 640 })
  end

  -- window size
  local size = { width = 1024, height = 600 }
  size = g_settings.getSize('window-size', size)
  g_window.resize(size)

  -- window position, default is the screen center
  local displaySize = g_window.getDisplaySize()
  local defaultPos = { x = (displaySize.width - size.width)/2,
                       y = (displaySize.height - size.height)/2 }
  local pos = g_settings.getPoint('window-pos', defaultPos)
  pos.x = math.max(pos.x, 0)
  pos.y = math.max(pos.y, 0)
  g_window.move(pos)

  -- window maximized?
  local maximized = g_settings.getBoolean('window-maximized', false)
  if maximized then g_window.maximize() end

  g_window.setTitle(g_app.getName())
  g_window.setIcon('/images/clienticon')

  if g_app.isMobile() then
    scheduleEvent(function()
      g_app.scale(5.0)
    end, 10)
  end
end

local function loadModules()
  if loadModulesFunction then
    local tmpLoadFunc = loadModulesFunction
    loadModulesFunction = nil
    tmpLoadFunc()
  end
end

-- what the launcher shows: the status text and which button (play, download, retry) is there
local function show(status, buttons, progress)
  if not launcher then return end
  launcher.status:setText(status)
  buttons = buttons or {}
  launcher.playButton:setVisible(buttons.play ~= nil)
  launcher.playButton:setEnabled(buttons.play == true)
  launcher.downloadButton:setVisible(buttons.download == true)
  launcher.retryButton:setVisible(buttons.retry == true)
  launcher.mainProgress:setVisible(progress == true)
  launcher.downloadProgress:setVisible(progress == true)
  launcher.downloadStatus:setVisible(progress == true)
end

local function downloadFiles(url, files, index, retries, doneCallback)
  if not launcher then return end
  local entry = files[index]
  if not entry then -- finished
    return doneCallback()
  end
  local file = entry[1]
  local file_checksum = entry[2]

  if retries > 0 then
    launcher.downloadStatus:setText(tr("Downloading (%i retry):\n%s", retries, file))
  else
    launcher.downloadStatus:setText(tr("Downloading:\n%s", file))
  end
  launcher.downloadProgress:setPercent(0)
  launcher.mainProgress:setPercent(math.floor(100 * index / #files))

  -- the checksum in the address keeps any cache from handing back an older copy
  httpOperationId = HTTP.download(url .. file .. "?" .. file_checksum, file,
    function (file, checksum, err)
      if not err and checksum ~= file_checksum then
        err = "Invalid checksum of: " .. file .. ".\nShould be " .. file_checksum .. ", is: " .. checksum
      end
      if err then
        if retries >= Updater.maxRetries then
          Updater.error("Can't download file: " .. file .. ".\nError: " .. err)
        else
          scheduledEvent = scheduleEvent(function()
            downloadFiles(url, files, index, retries + 1, doneCallback)
          end, 250)
        end
        return
      end
      downloadFiles(url, files, index + 1, 0, doneCallback)
    end,
    function (progress, speed)
      if not launcher then return end
      launcher.downloadProgress:setPercent(progress)
      launcher.downloadProgress:setText(speed .. " kbps")
    end)
end

-- the folder the game graphics are written into (the client's folder in the user's AppData, g_resources.getWriteDir)
-- as a path Lua's io can open; nil when this client can't write them itself
local function graphicsDir(folder)
  if type(io) ~= "table" or type(io.open) ~= "function" or type(os.rename) ~= "function" or not g_resources.getWriteDir then
    return nil
  end
  local base = g_resources.getWriteDir()
  if type(base) ~= "string" or not (base:match("^%a:[/\\]") or base:match("^/.")) then
    return nil
  end
  g_resources.makeDir(folder)
  local dir = base:gsub("[/\\]+$", "") .. "/" .. folder .. "/"
  -- a test file: a path io can't open (a user name outside the system's code page, a read-only folder) gives nil
  local test = io.open(dir .. "write-test.tmp", "wb")
  if not test then
    return nil
  end
  test:close()
  os.remove(dir .. "write-test.tmp")
  return dir
end

-- the parts of the new game graphics, one after the other: each is checked (checksum, size), unpacked and written at
-- the end of <name>.new in the graphics folder; out is the open .new file of the part's file
local function downloadGraphics(graphics, dir, parts, index, retries, out, doneCallback)
  if not launcher then
    if out then out:close() end
    return
  end
  local entry = parts[index]
  if not entry then -- finished
    return doneCallback()
  end
  local name, part = entry.file["name"], entry.part

  local status = tr("Downloading the new game graphics:\n%s (%i of %i)", name, entry.number, #entry.file["parts"])
  if retries > 0 then
    status = status .. " " .. tr("(%i retry)", retries)
  end
  launcher.downloadStatus:setText(status)
  launcher.downloadProgress:setPercent(0)
  launcher.mainProgress:setPercent(math.floor(100 * (index - 1) / #parts))

  httpOperationId = HTTP.download(graphics["url"] .. part["file"] .. "?" .. part["checksum"], GRAPHICS_DOWNLOAD,
    function(file, checksum, err)
      if not err and checksum ~= part["checksum"] then
        err = "Invalid checksum of: " .. part["file"] .. ".\nShould be " .. part["checksum"] .. ", is: " .. checksum
      end
      if err then
        if retries >= Updater.maxRetries then
          if out then out:close() end
          return Updater.error("Can't download file: " .. part["file"] .. ".\nError: " .. err)
        end
        scheduledEvent = scheduleEvent(function()
          downloadGraphics(graphics, dir, parts, index, retries + 1, out, doneCallback)
        end, 250)
        return
      end

      -- the part's bytes (the one entry of its zip), written at the end of the new file
      local ok, data = pcall(function()
        local unpacked = g_resources.decompressArchive(g_resources.readFileContents("/downloads/" .. GRAPHICS_DOWNLOAD))
        for _, content in pairs(unpacked) do
          return content
        end
      end)
      if not ok or type(data) ~= "string" or #data ~= part["size"] then
        if out then out:close() end
        return Updater.graphicsFailed()
      end
      if entry.number == 1 then
        out = io.open(dir .. name .. ".new", "wb")
      end
      if not out or not out:write(data) then
        if out then out:close() end
        return Updater.error(tr("Can't write the new game graphics into:\n%s", dir .. name))
      end
      data = nil
      collectgarbage()
      if entry.number == #entry.file["parts"] then
        out:close()
        out = nil
      end
      downloadGraphics(graphics, dir, parts, index + 1, 0, out, doneCallback)
    end,
    function(progress, speed)
      if not launcher then return end
      launcher.downloadProgress:setPercent(progress)
      launcher.downloadProgress:setText(speed .. " kbps")
    end)
end

-- new game graphics: their parts are downloaded into <name>.new files; once all are there they take the place of the
-- old files and version.txt names the new version. It is written last, so until then the old graphics stay whole
-- and an update cut halfway starts again at the next start.
local function installGraphics(graphics, doneCallback)
  local dir = graphicsDir("data/things/" .. graphics["folder"])
  local parts = {}
  for _, file in ipairs(type(graphics["files"]) == "table" and graphics["files"] or {}) do
    if type(file["name"]) ~= "string" or not file["name"]:match("^[%w%._%-]+$") or type(file["parts"]) ~= "table" then
      return Updater.graphicsFailed()
    end
    for number, part in ipairs(file["parts"]) do
      table.insert(parts, { file = file, part = part, number = number })
    end
  end
  if not dir or #parts == 0 then
    return Updater.graphicsFailed()
  end

  downloadGraphics(graphics, dir, parts, 1, 0, nil, function()
    for _, file in ipairs(graphics["files"]) do
      local name = dir .. file["name"]
      os.remove(name)
      if not os.rename(name .. ".new", name) then
        return Updater.error(tr("Can't write the new game graphics into:\n%s", name))
      end
    end
    local marker = io.open(dir .. "version.txt", "wb")
    if not marker or not marker:write(graphics["version"] .. "\n") then
      if marker then marker:close() end
      return Updater.error(tr("Can't write the new game graphics into:\n%s", dir .. "version.txt"))
    end
    marker:close()
    doneCallback()
  end)
end

-- the manifest against this client: {kind = "play"}, {kind = "update", update = ...} (files, new game graphics or
-- both) or {kind = "invalid"}
local function evaluate(data)
  if type(data) ~= "table" or type(data["files"]) ~= "table" or type(data["url"]) ~= 'string' or data["url"]:len() < 4 then
    return { kind = "invalid" }
  end
  local version = type(data["version"]) == 'string' and data["version"] or ""

  -- the game graphics live outside data.zip; version.txt next to them (from the installer or the last update) says
  -- which ones they are
  local graphics = nil
  local manifestGraphics = data["graphics"]
  if type(manifestGraphics) == "table" and type(manifestGraphics["folder"]) == 'string'
     and type(manifestGraphics["version"]) == 'string' and type(manifestGraphics["url"]) == 'string' then
    local marker = "/data/things/" .. manifestGraphics["folder"] .. "/version.txt"
    local installed = g_resources.fileExists(marker) and g_resources.readFileContents(marker):trim() or ""
    if installed ~= manifestGraphics["version"] then
      graphics = manifestGraphics
    end
  end

  local localFiles = g_resources.filesChecksums()
  local files, finalFiles = {}, {}
  for file, checksum in pairs(data["files"]) do
    table.insert(finalFiles, file)
    if localFiles[file] ~= checksum then
      table.insert(files, {file, checksum})
    end
  end
  if data["keepFiles"] then
    for file, checksum in pairs(localFiles) do
      if not data["files"][file] then
        table.insert(finalFiles, file)
      end
    end
  end

  local binary = nil
  if type(data["binary"]) == "table" and type(data["binary"]["file"]) == 'string' and data["binary"]["file"]:len() > 1 then
    local selfChecksum = g_resources.selfChecksum()
    if selfChecksum:len() > 0 and selfChecksum ~= data["binary"]["checksum"] then
      binary = data["binary"]["file"]
      table.insert(files, {binary, data["binary"]["checksum"]})
    end
  end

  if #files == 0 and not graphics then
    return { kind = "play", version = version }
  end
  return { kind = "update", version = version,
           update = { url = data["url"], files = files, finalFiles = finalFiles, binary = binary, graphics = graphics } }
end

-- the launcher shows what evaluate found; an update starts at once
local function compare(data)
  if not launcher then return end
  local result = evaluate(data)
  if result.kind == "invalid" then
    return Updater.error(tr("Invalid data from the update server."))
  end
  launcher.version:setText(tr("Client version %s", result.version))
  Updater.installer = data["installer"]
  if result.kind == "play" then
    update = nil
    return show(tr("Your client is up to date."), { play = true })
  end
  update = result.update
  Updater.update()
end

-- the logo and the launcher window
local function open()
  if not logo then
    logo = g_ui.displayUI('/modules/client_entergame/forgottenl_logo')
  end
  if not launcher then
    launcher = g_ui.displayUI('updater')
    launcher:show()
    launcher:raise()
    launcher:focus()
  end
end

-- public functions
function Updater.init(loadModulesFunc)
  g_logger.setOnLog(onLog)
  loadModulesFunction = loadModulesFunc
  initAppWindow()
  g_ui.importStyle('/modules/client_entergame/forgottenl_style')
  Updater.check()
end

function Updater.terminate()
  loadModulesFunction = nil
  Updater.abort()
end

-- Play (or nothing to do): the launcher goes away and the client (login) loads
function Updater.abort()
  HTTP.cancel(httpOperationId)
  removeEvent(scheduledEvent)
  if launcher then
    launcher:destroy()
    launcher = nil
  end
  if logo then
    logo:destroy()
    logo = nil
  end
  loadModules()
end

function Updater.check()
  removeEvent(scheduledEvent)
  open()
  update = nil
  show(tr("Checking for updates..."))

  -- the time in the address keeps any cache from handing back an older manifest
  httpOperationId = HTTP.getJSON(Services.updater .. "?t=" .. os.time(), function(data, err)
    if err then
      return Updater.error(tr("The update server can't be reached:\n%s", err))
    end
    compare(data)
  end)
end

function Updater.play()
  if update then return end -- an update has to come first
  local back = backToLogin
  backToLogin = nil
  Updater.abort()
  if back then back() end
end

-- every login asks again (client_entergame, EnterGame.doLogin): onReady when the client is still up to date (or the
-- update server can't be reached); with an update onBlocked hides the login and the launcher comes back and updates
-- the client (Play stays off); onBack shows the login again if Play becomes possible after all (an error)
function Updater.checkBeforeLogin(onReady, onBlocked, onBack)
  httpOperationId = HTTP.getJSON(Services.updater .. "?t=" .. os.time(), function(data, err)
    local result = not err and evaluate(data) or { kind = "invalid" }
    if result.kind == "play" or result.kind == "invalid" then
      return onReady()
    end
    onBlocked()
    backToLogin = onBack
    open()
    compare(data)
  end)
end

-- the update: the new game graphics first (the big part), then the changed files go into a new data.zip, and the
-- client restarts by itself
function Updater.update()
  if not launcher or not update then return end
  local todo = update
  launcher.mainProgress:setPercent(0)
  launcher.downloadProgress:setPercent(0)

  local function install()
    show(tr("Installing the update, the client restarts..."), {}, false)
    scheduledEvent = scheduleEvent(function()
      if #todo.files > 0 then
        g_resources.updateData(todo.finalFiles, false)
      end
      if todo.binary then
        g_resources.updateExecutable(todo.binary)
      end
      g_app.restart()
    end, 100)
  end
  local function files()
    if #todo.files == 0 then
      return install()
    end
    show(tr("Updating the client (%i files)...", #todo.files), {}, true)
    downloadFiles(todo.url, todo.files, 1, 0, install)
  end

  if todo.graphics then
    show(tr("Updating the client: new game graphics..."), {}, true)
    return installGraphics(todo.graphics, files)
  end
  files()
end

-- this client can't write the new game graphics itself: the full installer is the way
function Updater.graphicsFailed()
  removeEvent(scheduledEvent)
  if not launcher then return end
  update = nil
  show(tr("New game graphics are out, but this computer can't install them by itself.\nDownload and run the installer to keep playing."),
       { play = false, download = true })
end

-- the download of the full installer (Updater.graphicsFailed)
function Updater.download()
  g_platform.openUrl(Updater.installer or (Services.website .. "/downloads/ForgottenL-Client-Setup.exe"))
end

function Updater.error(message)
  removeEvent(scheduledEvent)
  if not launcher then return end
  update = nil
  show(message, { play = true, retry = true })
end
