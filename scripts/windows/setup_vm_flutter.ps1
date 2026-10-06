# Install Flutter 3.35.0 (x64 Dart SDK) inside the Windows 11 ARM64 Parallels VM.
#
# Why x64 on an ARM64 VM?
#   The Tencent Cloud IM Windows SDK shipped in tencent_cloud_chat_sdk (ImSDK.dll,
#   dart_native_imsdk.dll) is x64-only. Flutter builds for the architecture of the
#   Dart executable running the tool (Abi.current()), so we must use the x64 Dart SDK.
#   The x64 build then runs on Windows 11 ARM64 through the built-in x64 emulation.
#
# Usage (from macOS):
#   prlctl exec "Windows 11" --current-user powershell -NoProfile -ExecutionPolicy Bypass `
#     -File '\\Mac\Home\WebstormProjects\zhiboImWin\scripts\windows\setup_vm_flutter.ps1'
#
# NOTE: keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
param(
  [string]$FlutterVersion = '3.35.0',
  [string]$InstallDir = "$env:USERPROFILE\dev\flutter-3.35.0"
)

$ErrorActionPreference = 'Stop'

# China-friendly mirrors, same as the macOS host.
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'

# Force the x64 Dart SDK download (update_dart_sdk.ps1 picks arm64 when this is ARM64).
$env:PROCESSOR_ARCHITECTURE = 'AMD64'

git config --global core.longpaths true
git config --global --add safe.directory '*'

if (-not (Test-Path "$InstallDir\bin\flutter.bat")) {
  if (Test-Path $InstallDir) {
    Write-Output "Removing incomplete clone at $InstallDir ..."
    Remove-Item -Recurse -Force $InstallDir
  }
  Write-Output "Cloning Flutter $FlutterVersion into $InstallDir ..."
  git clone --depth 1 --branch $FlutterVersion https://github.com/flutter/flutter.git $InstallDir
  if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }
} else {
  Write-Output "Flutter already present at $InstallDir"
}

Write-Output "Running flutter --version (downloads the x64 Dart SDK on first run) ..."
& "$InstallDir\bin\flutter.bat" --version

& "$InstallDir\bin\flutter.bat" config --enable-windows-desktop --no-enable-android --no-enable-web --no-analytics

# Verify the Dart SDK architecture.
$dart = "$InstallDir\bin\cache\dart-sdk\bin\dart.exe"
$fs = [System.IO.File]::OpenRead($dart)
try { $buf = New-Object byte[] 4096; [void]$fs.Read($buf, 0, 4096) } finally { $fs.Close() }
$pe = [BitConverter]::ToInt32($buf, 0x3c)
$machine = [BitConverter]::ToUInt16($buf, $pe + 4)
$arch = switch ($machine) { 0x8664 { 'x64' } 0xAA64 { 'ARM64' } default { ('0x{0:x}' -f $machine) } }
Write-Output "dart.exe architecture: $arch (expected x64)"
if ($arch -ne 'x64') { throw "Dart SDK is not x64; delete $InstallDir\bin\cache and re-run." }

Write-Output "Done."
