# Debug `flutter run` on C:\dev\zhiboImWin (Parallels VM local NTFS copy).
# Sync from Mac first: scripts/windows/sync_and_build.ps1 (or robocopy zhiboImWin).
#
# NOTE: ASCII-only (PowerShell 5.1 reads BOM-less files as ANSI).
param(
  [string]$FlutterRoot = 'C:\Users\atticus\dev\flutter-3.35.0',
  [string]$ProjectDir = 'C:\dev\zhiboImWin'
)

$ErrorActionPreference = 'Stop'

function Remove-StaleWindowsBuildCache {
  param([string]$Root)
  $cmakeLists = Join-Path $Root 'windows\CMakeLists.txt'
  $cmakeCache = Join-Path $Root 'build\windows\x64\CMakeCache.txt'
  if (-not (Test-Path $cmakeLists)) { return }
  if (-not (Test-Path $cmakeCache)) { return }
  if ((Get-Item $cmakeLists).LastWriteTime -gt (Get-Item $cmakeCache).LastWriteTime) {
    Write-Output 'windows/CMakeLists.txt is newer than CMake cache; removing build\windows'
    Remove-Item -Recurse -Force (Join-Path $Root 'build\windows') -ErrorAction SilentlyContinue
  }
}

foreach ($procName in @('zhibo_im_win', 'dart')) {
  Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
}

foreach ($leaf in @('.flutter-plugins-dependencies', '.flutter-plugins')) {
  $p = Join-Path $ProjectDir $leaf
  if (Test-Path $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
}

Remove-StaleWindowsBuildCache -Root $ProjectDir

Set-Location $ProjectDir
$flutterBat = Join-Path $FlutterRoot 'bin\flutter.bat'
$runLog = Join-Path $ProjectDir 'build\windows\flutter_run_last.log'
New-Item -ItemType Directory -Force -Path (Split-Path $runLog) | Out-Null

& $flutterBat pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

$runArgs = @(
  'run', '-d', 'windows',
  '--dart-define-from-file=config\env.local.json'
)

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & $flutterBat @runArgs 2>&1 | Tee-Object -FilePath $runLog
  $runExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $prevEap
}

if ($runExit -ne 0) {
  if (Test-Path $runLog) {
    Write-Error 'flutter run failed. Recent compiler errors (if any):'
    Select-String -Path $runLog -Pattern 'error C|error D|error LNK|fatal error' |
      Select-Object -Last 15 |
      ForEach-Object { Write-Output $_.Line }
  }
  throw 'flutter run failed'
}
