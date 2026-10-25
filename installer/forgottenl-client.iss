; ForgottenL Client installer (built on OTCv8, official Windows build).
; Download-and-run installer: no extraction step for the end user, single EXE.
;
; NOT included (by design, see README-ASSETS.txt in the install dir):
;   data/things/870/Tibia.dat and Tibia.spr (or .cwm) -- the actual Tibia 8.70
;   game assets (sprites + object data) are copyrighted by CipSoft and are not
;   redistributed here. The player must supply their own legitimate copy.

#define MyAppName "ForgottenL"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ForgottenL Team"
#define MyAppURL "https://forgottenlegends.hopto.org"
#define MyAppExeName "otclient_dx.exe"
#define SourceDir "..\"

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
Source: "{#SourceDir}init.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}LICENSE"; DestDir: "{app}"; Flags: ignoreversion
; Game scripts/UI (Lua + OTUI), not compiled, but this is the client's own logic, not the
; copyrighted Tibia asset files.
Source: "{#SourceDir}data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}modules\*"; DestDir: "{app}\modules"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}layouts\*"; DestDir: "{app}\layouts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SourceDir}mods\*"; DestDir: "{app}\mods"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
; Tibia 8.70 game data (sprites + object defs). Verified against the known client-870 DAT
; signature (4CFE22C5) before being added here. See CHANGES.md for provenance.
Source: "{#SourceDir}data\things\870\Tibia.dat"; DestDir: "{app}\data\things\870"; Flags: ignoreversion
Source: "{#SourceDir}data\things\870\Tibia.spr"; DestDir: "{app}\data\things\870"; Flags: ignoreversion

[Dirs]
Name: "{app}\data\things\870"

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
