[Setup]
AppId={{EcolePrimaireGestionScolaire}}
AppName=Ecole Primaire
AppVersion=1.0.0
AppPublisher=Ecole Primaire
DefaultDirName={autopf}\Ecole Primaire
DefaultGroupName=Ecole Primaire
OutputDir=dist\installer
OutputBaseFilename=ecole_primaire-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ecole_primaire.exe

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Creer une icone sur le Bureau"; GroupDescription: "Icones supplementaires :"

[Files]
Source: "dist\windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Ecole Primaire"; Filename: "{app}\ecole_primaire.exe"
Name: "{commondesktop}\Ecole Primaire"; Filename: "{app}\ecole_primaire.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\ecole_primaire.exe"; Description: "Lancer Ecole Primaire"; Flags: nowait postinstall skipifsilent
