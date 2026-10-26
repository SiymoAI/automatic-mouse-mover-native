$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $root 'build-tools'
$compiler = Join-Path $toolsDir 'InnoSetup643\ISCC.exe'
if (Test-Path $compiler) { Write-Host 'Inno Setup 6.4.3 is ready'; exit 0 }
New-Item -ItemType Directory -Force $toolsDir | Out-Null
$installer = Join-Path $toolsDir 'innosetup-6.4.3.exe'
Invoke-WebRequest 'https://github.com/jrsoftware/issrc/releases/download/is-6_4_3/innosetup-6.4.3.exe' -OutFile $installer
if ((Get-FileHash $installer -Algorithm SHA256).Hash -ne 'F3C42116542C4CC57263C5BA6C4FEABFC49FE771F2F98A79D2F7628B8762723B') { throw 'Inno Setup checksum mismatch' }
$target = Join-Path $toolsDir 'InnoSetup643'
$p = Start-Process $installer -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', ('/DIR="' + $target + '"')) -Wait -PassThru
if ($p.ExitCode -ne 0 -or -not (Test-Path $compiler)) { throw 'Inno Setup preparation failed' }
