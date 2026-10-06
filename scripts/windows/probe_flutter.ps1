# Probe the Flutter SDK + Visual Studio C++ components inside the Windows VM.
# ASCII-only on purpose (Windows PowerShell 5.1 reads BOM-less files as ANSI).
$ErrorActionPreference = 'Continue'

function Section($title) { Write-Output ""; Write-Output "=== $title ===" }

function Get-PeMachine($path) {
  if (-not (Test-Path $path)) { return "(missing: $path)" }
  $fs = [System.IO.File]::OpenRead($path)
  try {
    $buf = New-Object byte[] 4096
    [void]$fs.Read($buf, 0, 4096)
  } finally { $fs.Close() }
  $pe = [BitConverter]::ToInt32($buf, 0x3c)
  $machine = [BitConverter]::ToUInt16($buf, $pe + 4)
  switch ($machine) {
    0x8664 { 'x64' }
    0xAA64 { 'ARM64' }
    0x14c  { 'x86' }
    default { ('0x{0:x}' -f $machine) }
  }
}

$flutterRoot = if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT } else { 'C:\Users\atticus\dev\flutter' }

Section "Flutter SDK"
"FLUTTER_ROOT=$flutterRoot"
if (Test-Path "$flutterRoot\version") { "version file: " + (Get-Content "$flutterRoot\version" -Raw).Trim() }
"dart.exe arch: " + (Get-PeMachine "$flutterRoot\bin\cache\dart-sdk\bin\dart.exe")
"flutter engine stamp: " + $(if (Test-Path "$flutterRoot\bin\cache\engine.stamp") { (Get-Content "$flutterRoot\bin\cache\engine.stamp" -Raw).Trim() } else { '(none)' })
Get-ChildItem "$flutterRoot\bin\cache\artifacts\engine" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "engine artifact dir: " + $_.Name }
"PUB_HOSTED_URL=$env:PUB_HOSTED_URL"
"FLUTTER_STORAGE_BASE_URL=$env:FLUTTER_STORAGE_BASE_URL"

Section "Visual Studio components"
$vsw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$components = @(
  'Microsoft.VisualStudio.Workload.NativeDesktop',
  'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  'Microsoft.VisualStudio.Component.VC.Tools.ARM64',
  'Microsoft.VisualStudio.Component.VC.CMake.Project',
  'Microsoft.VisualStudio.Component.Windows11SDK.22621',
  'Microsoft.VisualStudio.Component.Windows11SDK.26100',
  'Microsoft.VisualStudio.Component.Windows10SDK.19041'
)
foreach ($c in $components) {
  $r = & $vsw -all -products * -requires $c -property installationPath 2>$null
  "{0,-62} {1}" -f $c, $(if ($r) { 'INSTALLED' } else { 'missing' })
}
$vcDir = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC"
if (Test-Path $vcDir) {
  Get-ChildItem $vcDir -Directory | ForEach-Object {
    $v = $_.FullName
    "MSVC toolset: $($_.Name)"
    Get-ChildItem "$v\bin" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $host_ = $_.Name
      Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object { "   $host_ -> $($_.Name)" }
    }
  }
}

Section "Windows SDK"
Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
