param([string]$Path = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build\windows-x64\AutomaticMouseMover.exe'))
$ErrorActionPreference = 'Stop'
$bytes = [IO.File]::ReadAllBytes($Path)
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
$machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
$subsystem = [BitConverter]::ToUInt16($bytes, $pe + 24 + 68)
if ($machine -ne 0x8664) { throw 'Expected native x64 executable' }
if ($subsystem -ne 2) { throw 'Expected Windows GUI subsystem (no console)' }
Write-Host 'PASS: x64 PE executable, Windows GUI subsystem, no console window'
