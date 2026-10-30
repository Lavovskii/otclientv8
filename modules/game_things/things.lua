filename =  nil
loaded = false

function setFileName(name)
  filename = name
end

function isLoaded()
  return loaded
end

-- the folder of data/things a client version reads: ForgottenL speaks protocol 8.70 but draws with the the860 assets
-- (game_features turns on their extensions)
function getFolder(version)
  return version == 870 and 860 or version
end

function load()
  local version = g_game.getClientVersion()
  local things = g_settings.getNode('things')
  
  local datPath, sprPath
  if things and things["data"] ~= nil and things["sprites"] ~= nil then
    datPath = resolvepath('/things/' .. things["data"])
    sprPath = resolvepath('/things/' .. things["sprites"])
  else
    if filename then
      datPath = resolvepath('/things/' .. filename)
      sprPath = resolvepath('/things/' .. filename)
    else
      datPath = resolvepath('/things/' .. getFolder(version) .. '/Tibia')
      sprPath = resolvepath('/things/' .. getFolder(version) .. '/Tibia')
    end
  end

  local errorMessage = ''
  if not g_things.loadDat(datPath) then
    if not g_game.getFeature(GameSpritesU32) then
      g_game.enableFeature(GameSpritesU32)
      if not g_things.loadDat(datPath) then
        errorMessage = errorMessage .. tr("Unable to load dat file, please place a valid dat in '%s'", datPath) .. '\n'
      end
    else
      errorMessage = errorMessage .. tr("Unable to load dat file, please place a valid dat in '%s'", datPath) .. '\n'
    end
  end
  if not g_sprites.loadSpr(sprPath) then
    errorMessage = errorMessage .. tr("Unable to load spr file, please place a valid spr in '%s'", sprPath)
  end

  loaded = (errorMessage:len() == 0)

  if errorMessage:len() > 0 then
    local messageBox = displayErrorBox(tr('Error'), errorMessage)
    addEvent(function() messageBox:raise() messageBox:focus() end)

    g_game.setClientVersion(0)
    g_game.setProtocolVersion(0)
  end
end
