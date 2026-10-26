$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $env:LOCALAPPDATA 'Programs\SiymoAI Mouse Mover'
$exe = Join-Path $dir 'SiymoMouseMover.exe'
$p = Start-Process (Join-Path $dir 'unins000.exe') -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Uninstaller failed' }
$removed = -not (Test-Path $exe)
$setup = Join-Path $root 'dist\SiymoAI-Mouse-Mover-1.0.1-windows-x64-setup.exe'
$p = Start-Process $setup -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Reinstaller failed' }
@{uninstallRemovedExecutable=$removed; reinstallSucceeded=(Test-Path $exe); binaryMatchesBuild=((Get-FileHash $exe).Hash -eq (Get-FileHash (Join-Path $root 'build\windows-x64\SiymoMouseMover.exe')).Hash)} | ConvertTo-Json | Set-Content (Join-Path $root 'artifacts\windows-install-roundtrip.json')
$action = New-ScheduledTaskAction -Execute $exe -Argument ('--self-test "' + (Join-Path $root 'artifacts\windows-final-self-test.json') + '"')
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'SiymoMouseMover-Native-Test' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'SiymoMouseMover-Native-Test'
