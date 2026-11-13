param([switch]$Run)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$nvcc = (Get-Command nvcc -ErrorAction Stop).Source
$vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat'
if (!(Test-Path -LiteralPath $vcvars)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
}
# CUDA 13.1 supports MSVC 14.44; select it explicitly on newer VS installs.
$nativeCommand = '"' + $vcvars + '" -vcvars_ver=14.44 && "' + $nvcc + '" -shared -O3 -std=c++17 -arch=sm_75 -gencode=arch=compute_75,code=compute_75 -Xcompiler "/MD /openmp /utf-8" --cudart static native\Watercolor.cu -o native\WatercolorCuda.dll'
$originalPath = $env:PATH
try {
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot;" + (Split-Path -Parent $nvcc)
    & cmd.exe /d /s /c $nativeCommand
    $nativeExit = $LASTEXITCODE
} finally { $env:PATH = $originalPath }
if ($nativeExit -ne 0) { throw 'CUDA build failed.' }
$env:DOTNET_CLI_HOME = Join-Path $PSScriptRoot '.dotnet'
if (Test-Path -LiteralPath 'C:\Users\alfre\.nuget\packages') { $env:NUGET_PACKAGES = 'C:\Users\alfre\.nuget\packages' }
$msbuild = Join-Path (Split-Path (Split-Path (Split-Path (Split-Path $vcvars)))) 'MSBuild\Current\Bin\MSBuild.exe'
& dotnet restore WatercolorStudio/WatercolorStudio.csproj -p:Platform=x64 --ignore-failed-sources
if ($LASTEXITCODE -ne 0) { throw 'Package restore failed.' }
& $msbuild WatercolorStudio/WatercolorStudio.csproj /p:Configuration=Release /p:Platform=x64 /v:minimal
if ($LASTEXITCODE -ne 0) { throw 'WinUI build failed.' }
if ($Run) { & "$PSScriptRoot\Run.ps1" }
