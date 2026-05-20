# =============================================================================
# Windows Defender - Aggressive exclusions for developer machines
# =============================================================================
# Excludes the entire user profile (except Downloads), system folders, dev tools,
# browsers, cloud sync, and common dev processes/extensions from Defender scans.
# Also tunes the engine to minimize I/O overhead while keeping real-time on.
#
# WARNING: This is an aggressive configuration. After running:
#   - Defender effectively only scans %USERPROFILE%\Downloads and new processes.
#   - Anything dropped into C:\Windows, C:\ProgramData, AppData, or Program Files
#     will NOT be scanned.
# Acceptable for cautious users; NOT recommended for shared machines.
#
# Run as Administrator.
# =============================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "ERROR: must run as Administrator." -ForegroundColor Red
  exit 1
}

$u = $env:USERPROFILE

# =============================================================================
# PATHS
# =============================================================================
$paths = @(
  # --- Dev tools / projects ---
  "$u\Documents\Obsidian", "C:\xampp",
  "$u\AppData\Local\Herd", "$u\AppData\Roaming\Herd", "$u\.config\herd",
  "$u\AppData\Roaming\npm", "$u\AppData\Roaming\npm-cache", "$u\AppData\Local\npm-cache", "$u\.npm",
  "C:\Program Files\nodejs",
  "$u\AppData\Local\pip", "$u\AppData\Roaming\Python", "$u\AppData\Local\Programs\Python",
  "$u\.composer", "$u\AppData\Roaming\Composer",
  "C:\Program Files\Git", "$u\.gitconfig",
  "$u\AppData\Roaming\Code", "$u\.vscode",
  "$u\AppData\Local\GitHubDesktop", "$u\AppData\Local\GitHub CLI",
  "$u\AppData\Local\Docker", "$u\AppData\Local\JetBrains",
  "$u\AppData\Local\Programs\cursor", "$u\.cache",
  "$u\AppData\Local\Microsoft\SQL Server Management Studio",
  "$u\AppData\Local\Yarn", "$u\AppData\Local\pnpm",
  "$u\.cargo", "$u\.rustup", "$u\go",

  # --- System folders (HIGH RISK assumed) ---
  "C:\Program Files",
  "C:\Program Files (x86)",
  "C:\ProgramData",
  "C:\Windows",

  # --- Browsers ---
  "$u\AppData\Local\Google\Chrome\User Data",
  "$u\AppData\Local\Microsoft\Edge\User Data",
  "$u\AppData\Local\Mozilla",
  "$u\AppData\Local\BraveSoftware",
  "$u\AppData\Roaming\Mozilla",

  # --- Cloud sync ---
  "$u\OneDrive",
  "$u\Google Drive",
  "$u\AppData\Local\Microsoft\OneDrive",

  # --- Temp ---
  "$u\AppData\Local\Temp",
  "C:\Windows\Temp",

  # --- User profile (except Downloads, intentionally NOT in this list) ---
  "$u\Desktop",
  "$u\Documents",
  "$u\Pictures",
  "$u\Videos",
  "$u\Music",
  "$u\AppData\Local",
  "$u\AppData\Roaming",
  "$u\AppData\LocalLow",

  # --- Credentials / config ---
  "$u\.ssh",
  "$u\.aws",
  "$u\.azure"
)
$existing = $paths | Where-Object { Test-Path $_ } | Sort-Object -Unique

# =============================================================================
# PROCESSES
# =============================================================================
$processes = @(
  # Dev
  'node.exe', 'npm.exe', 'yarn.exe', 'pnpm.exe',
  'php.exe', 'composer.exe', 'herd.exe',
  'python.exe', 'pythonw.exe', 'pip.exe',
  'git.exe', 'gh.exe',
  'Code.exe', 'cursor.exe',
  'sqlservr.exe', 'sqlcmd.exe', 'Ssms.exe',
  'mysqld.exe', 'httpd.exe',
  'Obsidian.exe',
  # Browsers
  'chrome.exe', 'msedge.exe', 'firefox.exe', 'brave.exe',
  # Cloud
  'OneDrive.exe', 'GoogleDriveFS.exe',
  # Office / Adobe
  'WINWORD.EXE', 'EXCEL.EXE', 'OUTLOOK.EXE', 'POWERPNT.EXE', 'ONENOTE.EXE',
  'Acrobat.exe', 'AcroRd32.exe',
  # Archivers
  'WinRAR.exe', '7zG.exe', '7zFM.exe',
  # Communication
  'Teams.exe', 'Slack.exe', 'Discord.exe', 'Spotify.exe',
  # VPN
  'openvpn.exe', 'openvpn-gui.exe'
)

# =============================================================================
# EXTENSIONS
# =============================================================================
$extensions = @(
  '.log', '.tmp', '.cache', '.lock',
  '.iso', '.vhd', '.vhdx', '.vmdk',
  '.bak', '.dump', '.sql',
  '.zip', '.7z', '.rar', '.tar', '.gz'
)

# =============================================================================
# APPLY
# =============================================================================
Write-Host ""
Write-Host "==> Folder exclusions" -ForegroundColor Cyan
foreach ($p in $existing) {
  try { Add-MpPreference -ExclusionPath $p -ErrorAction Stop; Write-Host "  OK   $p" -ForegroundColor Green }
  catch { Write-Host "  FAIL $p" -ForegroundColor Red }
}

Write-Host ""
Write-Host "==> Process exclusions" -ForegroundColor Cyan
foreach ($proc in $processes) {
  try { Add-MpPreference -ExclusionProcess $proc -ErrorAction Stop; Write-Host "  OK   $proc" -ForegroundColor Green }
  catch { Write-Host "  FAIL $proc" -ForegroundColor Red }
}

Write-Host ""
Write-Host "==> Extension exclusions" -ForegroundColor Cyan
foreach ($ext in $extensions) {
  try { Add-MpPreference -ExclusionExtension $ext -ErrorAction Stop; Write-Host "  OK   $ext" -ForegroundColor Green }
  catch { Write-Host "  FAIL $ext" -ForegroundColor Red }
}

# =============================================================================
# ENGINE TWEAKS
# Some of these are blocked by Tamper Protection. Disable it manually first
# if you want all of them to apply:
#   Settings > Privacy & Security > Windows Security > Virus & threat protection
#   > Manage settings > Tamper Protection > Off
# =============================================================================
Write-Host ""
Write-Host "==> Engine tweaks (some may be blocked by Tamper Protection)" -ForegroundColor Cyan
try { Set-MpPreference -DisableIOAVProtection $true             -EA Stop; Write-Host "  OK   DisableIOAVProtection" -ForegroundColor Green }            catch { Write-Host "  FAIL DisableIOAVProtection (Tamper Protection)" -ForegroundColor Yellow }
try { Set-MpPreference -DisableScriptScanning $true             -EA Stop; Write-Host "  OK   DisableScriptScanning" -ForegroundColor Green }            catch { Write-Host "  FAIL DisableScriptScanning (Tamper Protection)" -ForegroundColor Yellow }
try { Set-MpPreference -DisableArchiveScanning $true            -EA Stop; Write-Host "  OK   DisableArchiveScanning" -ForegroundColor Green }           catch { Write-Host "  FAIL DisableArchiveScanning (Tamper Protection)" -ForegroundColor Yellow }
try { Set-MpPreference -DisableRemovableDriveScanning $true     -EA Stop; Write-Host "  OK   DisableRemovableDriveScanning" -ForegroundColor Green }    catch { Write-Host "  FAIL DisableRemovableDriveScanning" -ForegroundColor Red }
try { Set-MpPreference -DisableEmailScanning $true              -EA Stop; Write-Host "  OK   DisableEmailScanning" -ForegroundColor Green }             catch { Write-Host "  FAIL DisableEmailScanning" -ForegroundColor Red }
try { Set-MpPreference -MAPSReporting 0                         -EA Stop; Write-Host "  OK   MAPSReporting = 0 (no cloud telemetry)" -ForegroundColor Green }       catch { Write-Host "  FAIL MAPSReporting" -ForegroundColor Red }
try { Set-MpPreference -SubmitSamplesConsent 2                  -EA Stop; Write-Host "  OK   SubmitSamplesConsent = 2 (never)" -ForegroundColor Green }             catch { Write-Host "  FAIL SubmitSamplesConsent" -ForegroundColor Red }
try { Set-MpPreference -ScanScheduleDay 8                       -EA Stop; Write-Host "  OK   ScanScheduleDay = 8 (no scheduled scan)" -ForegroundColor Green }      catch { Write-Host "  FAIL ScanScheduleDay" -ForegroundColor Red }
try { Set-MpPreference -DisableCatchupQuickScan $true           -EA Stop; Write-Host "  OK   DisableCatchupQuickScan" -ForegroundColor Green }          catch { Write-Host "  FAIL DisableCatchupQuickScan" -ForegroundColor Red }
try { Set-MpPreference -DisableCatchupFullScan $true            -EA Stop; Write-Host "  OK   DisableCatchupFullScan" -ForegroundColor Green }           catch { Write-Host "  FAIL DisableCatchupFullScan" -ForegroundColor Red }

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host ""
Write-Host "==> SUMMARY" -ForegroundColor Cyan
$pref = Get-MpPreference
Write-Host ("  Path exclusions:      {0}" -f $pref.ExclusionPath.Count) -ForegroundColor Yellow
Write-Host ("  Process exclusions:   {0}" -f $pref.ExclusionProcess.Count) -ForegroundColor Yellow
Write-Host ("  Extension exclusions: {0}" -f $pref.ExclusionExtension.Count) -ForegroundColor Yellow
Write-Host ""
Write-Host ("  Real-time monitoring: {0}" -f (-not $pref.DisableRealtimeMonitoring)) -ForegroundColor Yellow
Write-Host ("  IOAV scan:            {0}" -f (-not $pref.DisableIOAVProtection)) -ForegroundColor Yellow
Write-Host ("  Script scan (AMSI):   {0}" -f (-not $pref.DisableScriptScanning)) -ForegroundColor Yellow
Write-Host ("  Archive scan:         {0}" -f (-not $pref.DisableArchiveScanning)) -ForegroundColor Yellow
Write-Host ""
Write-Host "Done." -ForegroundColor Green
