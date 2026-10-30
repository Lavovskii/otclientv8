-- The launcher of the installed client (it runs from data.zip, see init.lua): before the login it compares the
-- client's files with the update manifest of the website (Services.updater, written by tools/build_release.py) and
-- shows one button in the middle of the screen:
--   Play      the client is up to date: the login opens;
--   Update    some files changed: only those are downloaded, written into a new data.zip in the user's folder
--             (AppData/OTClientV8/ForgottenL) and the client restarts; Play waits until then;
--   Download  the game graphics (Tibia.dat/spr of the the860 assets, kept outside data.zip) changed: the full
--             installer is needed, the button opens its download.
-- When the website can't be reached, Play stays possible (with Try again).
Updater = { }

Updater.maxRetries = 5

local launcher
local logo
local loadModulesFunction
local scheduledEvent
local httpOperationId = 0
local update -- what Update downloads: {url, files = {{path, checksum}}, finalFiles, binary}

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

-- what the launcher shows: the status text and which button (play, update, download, retry) is there
local function show(status, buttons, progress)
  if not launcher then return end
  launcher.status:setText(status)
  buttons = buttons or {}
  launcher.playButton:setVisible(buttons.play ~= nil)
  launcher.playButton:setEnabled(buttons.play == true)
  launcher.updateButton:setVisible(buttons.update == true)
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

-- the manifest against this client: Play, Update or the full installer
local function compare(data)
  if not launcher then return end
  if type(data) ~= "table" or type(data["files"]) ~= "table" or type(data["url"]) ~= 'string' or data["url"]:len() < 4 then
    return Updater.error(tr("Invalid data from the update server."))
  end

  local version = type(data["version"]) == 'string' and data["version"] or ""
  launcher.version:setText(tr("Client version %s", version))

  -- the game graphics live outside data.zip; the installer writes their version next to them
  local things = data["things"]
  if type(things) == "table" and type(things["folder"]) == 'string' then
    local marker = "/data/things/" .. things["folder"] .. "/version.txt"
    local installed = g_resources.fileExists(marker) and g_resources.readFileContents(marker):trim() or ""
    if installed ~= things["version"] then
      Updater.installer = data["installer"]
      return show(tr("New game graphics are out.\nDownload and run the new installer to keep playing."),
                  { play = false, download = true })
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

  if #files == 0 then
    update = nil
    return show(tr("Your client is up to date."), { play = true })
  end

  update = { url = data["url"], files = files, finalFiles = finalFiles, binary = binary }
  show(tr("An update is ready (%i files).\nUpdate the client to play.", #files), { play = false, update = true })
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
  if not logo then
    logo = g_ui.displayUI('/modules/client_entergame/forgottenl_logo')
  end
  if not launcher then
    launcher = g_ui.displayUI('updater')
    launcher:show()
    launcher:raise()
    launcher:focus()
  end
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
  Updater.abort()
end

function Updater.update()
  if not launcher or not update then return end
  local todo = update
  show(tr("Updating %i files", #todo.files), {}, true)
  launcher.mainProgress:setPercent(0)
  launcher.downloadProgress:setPercent(0)
  downloadFiles(todo.url, todo.files, 1, 0, function()
    show(tr("Installing the update, the client restarts..."), {}, false)
    scheduledEvent = scheduleEvent(function()
      g_resources.updateData(todo.finalFiles, false)
      if todo.binary then
        g_resources.updateExecutable(todo.binary)
      end
      g_app.restart()
    end, 100)
  end)
end

-- the game graphics changed: the download page of the full installer
function Updater.download()
  g_platform.openUrl(Updater.installer or (Services.website .. "/downloads/ForgottenL-Client-Setup.exe"))
end

function Updater.error(message)
  removeEvent(scheduledEvent)
  if not launcher then return end
  update = nil
  show(message, { play = true, retry = true })
end
