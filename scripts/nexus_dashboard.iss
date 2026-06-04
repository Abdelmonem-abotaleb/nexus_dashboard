#define AppName "Nexus Dashboard"
#define AppVersion "1.0.0"

#ifndef ProjectDir
#define ProjectDir ".."
#endif

#ifndef SourceDir
#define SourceDir "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "..\dist"
#endif

[Setup]
AppId={{8F7F3E32-3FA1-4A3E-9E32-DA4F9CF8897A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Nexus
DefaultDirName={localappdata}\Programs\Nexus Dashboard
DefaultGroupName=Nexus Dashboard
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=nexus_dashboard_setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#ProjectDir}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\nexus_dashboard.exe
ArchitecturesAllowed=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcut options:"; Flags: unchecked
Name: "startup"; Description: "Start Nexus Dashboard when I sign in"; GroupDescription: "Startup options:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Nexus Dashboard"; Filename: "{app}\nexus_dashboard.exe"
Name: "{autodesktop}\Nexus Dashboard"; Filename: "{app}\nexus_dashboard.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "NexusDashboard"; ValueData: """{app}\nexus_dashboard.exe"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\nexus_dashboard.exe"; Description: "Launch Nexus Dashboard"; Flags: nowait postinstall skipifsilent
