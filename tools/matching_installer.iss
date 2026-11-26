[Setup]
AppId=ExplApp.Matching.Windows
AppName=Matching - Professional Accountant
AppVersion=1.2.5
AppPublisher=Professional Accountant
AppPublisherURL=https://acc.explapp.com
DefaultDirName={localappdata}\Programs\ExplApp\Matching
DefaultGroupName=Matching
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=Matching-Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\matching.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Matching"; Filename: "{app}\matching.exe"
Name: "{autodesktop}\Matching"; Filename: "{app}\matching.exe"

[Run]
Filename: "{app}\matching.exe"; Description: "Launch Matching"; Flags: nowait postinstall skipifsilent
