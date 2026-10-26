#define AppName "SiymoAI Mouse Mover"
#define AppVersion "1.0.1"
[Setup]
AppId={{C7C871C6-F16C-43D6-BD21-76B8BF1DAF77}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=SiymoAI
AppPublisherURL=https://github.com/SiymoAI/siymo-mouse-mover
AppSupportURL=https://github.com/SiymoAI/siymo-mouse-mover/issues
DefaultDirName={localappdata}\Programs\SiymoAI Mouse Mover
UsePreviousAppDir=no
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=SiymoAI-Mouse-Mover-1.0.1-windows-x64-setup
SetupIconFile=SiymoMouseMover\AppIcon.ico
UninstallDisplayIcon={app}\SiymoMouseMover.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
LicenseFile=..\LICENSE
[Files]
Source: "..\build\windows-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSE"; DestDir: "{app}"
[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\SiymoMouseMover.exe"
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
[Icons]
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\SiymoMouseMover.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\SiymoMouseMover.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "SiymoAI.MouseMover"; Flags: uninsdeletevalue
