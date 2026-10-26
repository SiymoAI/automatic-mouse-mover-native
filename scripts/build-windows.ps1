$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $dotnet = if (Test-Path (Join-Path $root 'build-tools\dotnet\dotnet.exe')) { Join-Path $root 'build-tools\dotnet\dotnet.exe' } else { 'dotnet' }
    if (Test-Path build/windows-x64) { Remove-Item build/windows-x64 -Recurse -Force }
    & $dotnet publish windows/SiymoMouseMover/SiymoMouseMover.csproj -c Release -r win-x64 --self-contained true -o build/windows-x64 -p:DebugType=None -p:DebugSymbols=false
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    Copy-Item LICENSE build/windows-x64/LICENSE.txt
    Copy-Item windows/PORTABLE.txt build/windows-x64/README.txt
    $iscc = Join-Path $root 'build-tools\InnoSetup643\ISCC.exe'
    if (-not (Test-Path $iscc)) { throw 'Run scripts/prepare-windows-tools.ps1 first (pinned Inno Setup 6.4.3)' }
    & $iscc windows/installer.iss
    if ($LASTEXITCODE -ne 0) { throw 'Installer build failed' }
    Compress-Archive -Path build/windows-x64/* -DestinationPath dist/SiymoAI-Mouse-Mover-1.0.1-windows-x64-portable.zip -Force
} finally { Pop-Location }
