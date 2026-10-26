param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$reports = Join-Path $Root 'artifacts'
New-Item -ItemType Directory -Force $reports | Out-Null
$exe = Join-Path $Root 'build\windows-x64\SiymoMouseMover.exe'
$report = Join-Path $reports 'windows-self-test.json'
$action = New-ScheduledTaskAction -Execute $exe -Argument ('--self-test "' + $report + '"')
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName 'SiymoMouseMover-Native-Test' -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'SiymoMouseMover-Native-Test'
