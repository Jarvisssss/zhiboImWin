# Sync the project (and its sibling path-dependencies) from the Parallels shared
# folder into a native NTFS directory, then build the Windows Release exe.
#
# Why not build directly on \\Mac\Home\...?
#   Flutter's Windows build creates symlinks under windows\flutter\ephemeral\.plugin_symlinks.
#   The Parallels shared-folder filesystem does not support CreateSymbolicLink
#   (fails with ERROR_INVALID_FUNCTION), even with Developer Mode enabled.
#   So the project must live on a real local drive (C:\dev) to build.
#
# Why CL=/utf-8?
#   Some third-party Flutter Windows plugins (e.g. just_audio_windows) ship
#   UTF-8-without-BOM C++ headers. On a zh-CN (code page 936) Windows image,
#   cl.exe misreads them and raises C4819, which this project's generated
#   vcxproj escalates to a hard error (C2220). Setting the CL env var is the
#   standard MSVC-documented fix (cl.exe appends it to every invocation) and
#   avoids editing vendored plugin source.
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
Sync-Dir 'study_app\chat-uikit-flutter' @('.git', '.dart_tool')
Sync-Dir 'study_app\shared_video_player' @('.git', '.dart_tool')

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

$env:CL = '/utf-8'
Set-Location $projectDir

$flutterBat = Join-Path $FlutterRoot 'bin\flutter.bat'
& $flutterBat pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

$buildArgs = @('build', 'windows', '--dart-define-from-file=config\env.local.json')
if ($Release) { $buildArgs += '--release' }
& $flutterBat @buildArgs
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }

Write-Output 'DONE'
Write-Output (Join-Path $LocalRoot 'zhiboImWin\build\windows\x64\runner\Release\zhibo_im_win.exe')
