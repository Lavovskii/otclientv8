; ForgottenL Client installer (built on OTCv8, official Windows build).
; Download-and-run installer: no extraction step for the end user, single EXE.
;
; Build it with tools/build_release.py --installer: the client runs from ..\dist\data.zip (scripts, UI, images), so
; its launcher (modules/updater) can update itself from the website; the game graphics (data/things/860) go to the
; user's folder of the client ({userappdata}\OTClientV8\ForgottenL, where the updates go too) with their version.txt.

#define MyAppName "ForgottenL"
#define MyAppVersion "1.0.7"
#define MyAppPublisher "ForgottenL Team"
#define MyAppURL "https://forgottenl.me"
#define MyAppExeName "otclient_dx.exe"
#define SourceDir "..\"
#define UserDir "{userappdata}\OTClientV8\ForgottenL"

[Setup]
AppId={{B6C2F6A2-6B2B-4C1E-9C2A-5F6E6E8F2A11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=ForgottenL-Client-Setup
SetupIconFile=..\forgottenl.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ChangesAssociations=no
DisableWelcomePage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; modules removed from the client are removed from old installs too
Type: filesandordirs; Name: "{app}\modules\game_hotkeys"
Type: filesandordirs; Name: "{app}\modules\game_cooldown"
Type: filesandordirs; Name: "{app}\modules\game_bot"
Type: filesandordirs; Name: "{app}\modules\game_shop"
; the old health and mana arcs (replaced by *_back, *_fill and *_frame)
Type: files; Name: "{app}\data\images\game\circle\*_empty.png"
Type: files; Name: "{app}\data\images\game\circle\*_full.png"
; the Tibia 8.70 game data, replaced by the the860 assets (data\things\860) in 1.0.4
Type: filesandordirs; Name: "{app}\data\things\870"
; 1.0.6 runs from data.zip: the loose files of the older versions go (a left init.lua would keep the client off
; data.zip and its updates), and so do the updates of an older install (their data.zip and binaries in the user's
; folder would hide the ones of this installer)
Type: files; Name: "{app}\init.lua"
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\modules"
Type: filesandordirs; Name: "{app}\layouts"
Type: filesandordirs; Name: "{app}\mods"
Type: files; Name: "{#UserDir}\data.zip"
Type: files; Name: "{#UserDir}\otclient_*.exe"

[Files]
; Microsoft's own Visual C++ 2015-2022 x86 runtime (official, Authenticode-signed by Microsoft).
; otclient_dx.exe/otclient_gl.exe are 32-bit builds and crash with 0xC000007B on a clean machine
; without it, so it is a required prerequisite, not optional.
Source: "redist\vc_redist.x86.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
; Windows binaries (official OTCv8 build, DirectX + OpenGL variants) and their runtime DLLs.
Source: "{#SourceDir}otclient_dx.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}otclient_gl.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}d3dcompiler_47.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}libEGL.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}libGLESv2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}LICENSE"; DestDir: "{app}"; Flags: ignoreversion
; the client itself (init.lua, data without the graphics, modules, layouts, mods), made by tools/build_release.py
Source: "{#SourceDir}dist\data.zip"; DestDir: "{app}"; Flags: ignoreversion
; the860 game data (sprites + object defs): the 8.60 dat layout (signature 4C2C7993, spr 4C220594) with the OTClient
; extensions of its Tibia.otfi (extended sprite ids, frame durations, frame groups), read with protocol 8.70. Outside
; data.zip (which the client reads whole into memory), in the user's folder, which the client reads too; version.txt
; tells the launcher whether they are the ones of the update manifest.
Source: "{#SourceDir}data\things\860\Tibia.dat"; DestDir: "{#UserDir}\data\things\860"; Flags: ignoreversion
Source: "{#SourceDir}data\things\860\Tibia.spr"; DestDir: "{#UserDir}\data\things\860"; Flags: ignoreversion
Source: "{#SourceDir}dist\things-version.txt"; DestDir: "{#UserDir}\data\things\860"; DestName: "version.txt"; Flags: ignoreversion

[UninstallDelete]
Type: filesandordirs; Name: "{#UserDir}\data"
Type: files; Name: "{#UserDir}\data.zip"
Type: files; Name: "{#UserDir}\otclient_*.exe"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Code]
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  // Minimal runtime key check; if missing or unreadable, just run the (fast, no-op-if-present) installer.
  if not RegQueryDWordValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86', 'Installed', Installed) then
    Result := True
  else
    Result := (Installed <> 1);
end;

[Run]
Filename: "{tmp}\vc_redist.x86.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime (one-time, required)..."; Check: VCRedistNeedsInstall; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent unchecked
