$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot 'WatercolorStudio\bin\x64\Release\net10.0-windows10.0.19041.0\win-x64\WatercolorStudio.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Build the studio first with .\Build.ps1' }
Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe) -WindowStyle Normal
