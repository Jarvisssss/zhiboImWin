# Sync the project (and its sibling path-dependencies) from the Parallels shared
# folder into a native NTFS directory, then build the Windows Release exe.
#
# Why not build directly on \\Mac\Home\...?
#   Flutter's Windows build creates symlinks under windows\flutter\ephemeral\.plugin_symlinks.
#   The Parallels shared-folder filesystem does not support CreateSymbolicLink
#   (fails with ERROR_INVALID_FUNCTION), even with Developer Mode enabled.
#   So the project must live on a real local drive (C:\dev) to build.
#
# MSVC UTF-8 charset flags are set in windows/CMakeLists.txt (see comment there re
# tencent_cloud_chat_sdk / D8016).
#
# Usage (from macOS):
#   prlctl exec "Windows 11" --current-user powershell -NoProfile -ExecutionPolicy Bypass `
#     -File '\\Mac\Home\WebstormProjects\zhiboImWin\scripts\windows\sync_and_build.ps1'
#
# NOTE: keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
param(
  [string]$FlutterRoot = 'C:\Users\atticus\dev\flutter-3.35.0',
  [string]$LocalRoot = 'C:\dev',
  [string]$SharedRoot = '\\Mac\Home\WebstormProjects',
  [switch]$Release = $true
)

$ErrorActionPreference = 'Stop'

function Sync-Dir($name, [string[]]$excludeDirs) {
  $src = Join-Path $SharedRoot $name
  $dst = Join-Path $LocalRoot $name
  robocopy $src $dst /E /XD $excludeDirs /NP /NFL /NDL | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $name (exit $LASTEXITCODE)" }
}

New-Item -ItemType Directory -Force -Path $LocalRoot | Out-Null
Sync-Dir 'zhiboImWin' @('.git', 'build', '.dart_tool', 'ephemeral')

$projectDir = Join-Path $LocalRoot 'zhiboImWin'

# Release exe / prior `flutter run` may still hold plugin metadata files open.
foreach ($procName in @('zhibo_im_win', 'dart')) {
  Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
}

# robocopy may copy hidden `.flutter-plugins*` from the Mac share; Flutter then fails
# to overwrite them ("cannot access the file or directory"). Regenerate on pub get.
foreach ($leaf in @('.flutter-plugins-dependencies', '.flutter-plugins')) {
  $p = Join-Path $projectDir $leaf
  if (Test-Path $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
}

Set-Location $projectDir

$cmakeLists = Join-Path $projectDir 'windows\CMakeLists.txt'
$cmakeCache = Join-Path $projectDir 'build\windows\x64\CMakeCache.txt'
if ((Test-Path $cmakeLists) -and (Test-Path $cmakeCache)) {
  if ((Get-Item $cmakeLists).LastWriteTime -gt (Get-Item $cmakeCache).LastWriteTime) {
    Write-Output 'windows/CMakeLists.txt is newer than CMake cache; removing build\windows'
    Remove-Item -Recurse -Force (Join-Path $projectDir 'build\windows') -ErrorAction SilentlyContinue
  }
}

$flutterBat = Join-Path $FlutterRoot 'bin\flutter.bat'
& $flutterBat pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

$buildArgs = @('build', 'windows', '--dart-define-from-file=config\env.local.json')
if ($Release) { $buildArgs += '--release' }
$buildLog = Join-Path $projectDir 'build\windows\flutter_build_last.log'
New-Item -ItemType Directory -Force -Path (Split-Path $buildLog) | Out-Null
# Flutter writes NuGet progress to stderr; with $ErrorActionPreference=Stop that aborts the script.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & $flutterBat @buildArgs 2>&1 | Tee-Object -FilePath $buildLog
  $buildExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $prevEap
}
if ($buildExit -ne 0) {
  Write-Error 'flutter build windows failed. Recent compiler errors:'
  Select-String -Path $buildLog -Pattern 'error C|error D|error LNK|fatal error' |
    Select-Object -Last 15 |
    ForEach-Object { Write-Output $_.Line }
  throw 'flutter build windows failed'
}

Write-Output 'DONE'
Write-Output (Join-Path $LocalRoot 'zhiboImWin\build\windows\x64\runner\Release\zhibo_im_win.exe')
