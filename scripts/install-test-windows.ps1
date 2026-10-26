$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$setup = Join-Path $root 'dist\Automatic-Mouse-Mover-1.0.0-windows-x64-setup.exe'
$installed = Join-Path $env:LOCALAPPDATA 'Programs\Automatic Mouse Mover'
$reports = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Force $reports | Out-Null
$p = Start-Process $setup -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Installer failed: $($p.ExitCode)" }
$exe = Join-Path $installed 'AutomaticMouseMover.exe'
if (-not (Test-Path $exe)) { throw 'Installed executable missing' }
$shortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Automatic Mouse Mover\Automatic Mouse Mover.lnk'
$uninstall = Join-Path $installed 'unins000.exe'
$hash = (Get-FileHash $exe -Algorithm SHA256).Hash
$buildHash = (Get-FileHash (Join-Path $root 'build\windows-x64\AutomaticMouseMover.exe') -Algorithm SHA256).Hash
@{ installed = (Test-Path $exe); startMenuShortcut = (Test-Path $shortcut); uninstaller = (Test-Path $uninstall); binaryMatchesBuild = ($hash -eq $buildHash); installerExitCode = $p.ExitCode } | ConvertTo-Json | Set-Content (Join-Path $reports 'windows-installation.json')
$action = New-ScheduledTaskAction -Execute $exe -Argument ('--self-test "' + (Join-Path $reports 'windows-installed-self-test.json') + '"')
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'AutomaticMouseMover-Native-Test' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'AutomaticMouseMover-Native-Test'
