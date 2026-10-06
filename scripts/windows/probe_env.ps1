# Windows build/test environment probe for the Zhibo Talk PC client.
# Usage (inside the Windows VM or via `prlctl exec`):
#   powershell -NoProfile -ExecutionPolicy Bypass -File probe_env.ps1
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads BOM-less files as ANSI.
$ErrorActionPreference = 'Continue'

function Section($title) { Write-Output ""; Write-Output "=== $title ===" }

Section "User / OS"
whoami
$os = Get-CimInstance Win32_OperatingSystem
"Caption=$($os.Caption) Version=$($os.Version) OSArchitecture=$($os.OSArchitecture)"
"PROCESSOR_ARCHITECTURE=$env:PROCESSOR_ARCHITECTURE PROCESSOR_ARCHITEW6432=$env:PROCESSOR_ARCHITEW6432"
"PowerShell=$($PSVersionTable.PSVersion)"

Section "Disk"
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
  "{0}: free={1}GB used={2}GB" -f $_.Name, [math]::Round($_.Free / 1GB, 1), [math]::Round($_.Used / 1GB, 1)
}

Section "Tools on PATH"
foreach ($c in 'flutter', 'dart', 'git', 'cmake', 'msbuild', 'winget', 'choco', 'python', 'node', '7z', 'curl', 'iscc') {
  $p = Get-Command $c -ErrorAction SilentlyContinue
  "{0,-8} {1}" -f $c, $(if ($p) { $p.Source } else { '(not installed)' })
}

Section "Visual Studio (vswhere)"
$vsw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsw) {
  & $vsw -all -products * -format json | Out-String
} else {
  "vswhere.exe not found: Visual Studio / Build Tools not installed"
}

Section "Developer Mode (needed for Flutter plugin symlinks)"
$dev = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
"AllowDevelopmentWithoutDevLicense=$($dev.AllowDevelopmentWithoutDevLicense)"

Section "Parallels shared folders"
foreach ($p in '\\Mac\Home', '\\Mac\Home\WebstormProjects\zhiboImWin') {
  "{0} -> {1}" -f $p, (Test-Path $p)
}

Section "Internet reachability"
foreach ($u in 'https://pub.flutter-io.cn', 'https://storage.flutter-io.cn', 'https://github.com', 'https://storage.googleapis.com', 'https://aka.ms', 'https://api.coze.cn') {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -Method Head
    "{0,-36} HTTP {1}" -f $u, $r.StatusCode
  } catch {
    $code = $null
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code) { "{0,-36} HTTP {1} (reachable)" -f $u, $code } else { "{0,-36} FAILED: {1}" -f $u, $_.Exception.Message.Split("`n")[0] }
  }
}
