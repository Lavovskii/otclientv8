-- CONFIG
APP_NAME = "ForgottenL"  -- important, change it, it's name for config dir and files in appdata
APP_VERSION = 1         -- client version for updater and login to identify outdated client
-- ForgottenL: raise CLIENT_BUILD with every client update (tools/build_release.py --publish), then the server's
-- minClientBuild (config.lua): the login sends it as its OS value, 1000 + CLIENT_BUILD, and the server refuses older ones
CLIENT_BUILD = 30
DEFAULT_LAYOUT = "reborn" -- on android it's forced to "mobile", check code bellow

-- updater: the update manifest of the website (tools/build_release.py --publish); the installed client (data.zip)
-- updates itself before the login (modules/updater). No stats/crash-report service: leave those empty.
Services = {
  website = "https://forgottenl.me",
  updater = "https://forgottenl.me/downloads/updater/manifest.json",
  stats = "",
  crash = "",
  feedback = "",
  status = ""
}

-- Servers accept http login url, websocket login url or ip:port:version
-- 870 = Tibia client 8.70, the protocol version ForgottenL (TFS 0.4) speaks.
Servers = {
  ForgottenL = "forgottenl.me:7171:870"
}

--Server = "ws://otclient.ovh:3000/"
--Server = "ws://127.0.0.1:88/"
--USE_NEW_ENERGAME = true -- uses entergamev2 based on websockets instead of entergame
ALLOW_CUSTOM_SERVERS = false -- ForgottenL-only client: hide the "Another" / custom-server option
-- ForgottenL's own login RSA key (public modulus; the server holds the private half in config.rsa.lua): the login
-- and the game encrypt the session key with it instead of the OTServ key every OT shares
LOGIN_RSA = "142089274808214602192718996701985977544815118934103087023353988931701626703839098582822341854974483921307046731084103287968781596792441110944341962800495285525543652649723795170499999043067960421524405721761450863961993953614195270111816988879317977203262337700660761031214395996112303994816771231378543741567"

g_app.setName("ForgottenL")
-- CONFIG END

-- print first terminal message
g_logger.info(os.date("== application started at %b %d %Y %X"))
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' .. g_app.getBuildCommit() .. ') made by ' .. g_app.getAuthor() .. ' built on ' .. g_app.getBuildDate() .. ' for arch ' .. g_app.getBuildArch())

if not g_resources.directoryExists("/data") then
  g_logger.fatal("Data dir doesn't exist.")
end

if not g_resources.directoryExists("/modules") then
  g_logger.fatal("Modules dir doesn't exist.")
end

-- settings
g_configs.loadSettings("/config.otml")

-- set layout
local settings = g_configs.getSettings()
-- Reborn became the default in build 30. The options save the layout even when nobody chose it, so whoever has the old
-- default saved moves once; picking Retro again afterwards sticks.
if not settings:exists('rebornLayoutSeen') then
  if settings:exists('layout') and tostring(settings:getValue('layout')):lower() == 'retro' then
    settings:setValue('layout', DEFAULT_LAYOUT)
  end
  settings:setValue('rebornLayoutSeen', 'true')
end
local layout = DEFAULT_LAYOUT
if g_app.isMobile() then
  layout = "mobile"
elseif settings:exists('layout') then
  layout = settings:getValue('layout')
end
g_resources.setLayout(layout)

-- load mods
g_modules.discoverModules()
g_modules.ensureModuleLoaded("corelib")
  
local function loadModules()
  -- libraries modules 0-99
  g_modules.autoLoadModules(99)
  g_modules.ensureModuleLoaded("gamelib")

  -- client modules 100-499
  g_modules.autoLoadModules(499)
  g_modules.ensureModuleLoaded("client")

  -- game modules 500-999
  g_modules.autoLoadModules(999)
  g_modules.ensureModuleLoaded("game_interface")

  -- mods 1000-9999
  g_modules.autoLoadModules(9999)
end

-- report crash
if type(Services.crash) == 'string' and Services.crash:len() > 4 and g_modules.getModule("crash_reporter") then
  g_modules.ensureModuleLoaded("crash_reporter")
end

-- run updater, must use data.zip
if type(Services.updater) == 'string' and Services.updater:len() > 4 
  and g_resources.isLoadedFromArchive() and g_modules.getModule("updater") then
  g_modules.ensureModuleLoaded("updater")
  return Updater.init(loadModules)
end
loadModules()
