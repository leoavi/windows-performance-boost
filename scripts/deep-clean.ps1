# =============================================================================
# Deep disk cleanup
# =============================================================================
# Recovers gigabytes typically wasted on:
#   - Old Windows Update component store entries (WinSxS)
#   - User and system Temp folders
#   - Windows Update download cache
#   - Delivery Optimization cache
#   - Old crash dumps
#   - Thumbnail cache
#
# Run periodically (monthly or quarterly). Run as Administrator.
# =============================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "ERROR: must run as Administrator." -ForegroundColor Red
  exit 1
}

function Get-FolderSizeMB($path) {
  if (-not (Test-Path $path)) { return 0 }
  try {
    $items = Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
    if (-not $items) { return 0 }
    $sum = ($items | Measure-Object -Property Length -Sum).Sum
    return [math]::Round($sum / 1MB, 1)
  } catch { return 0 }
}

$beforeFree = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
Write-Host "Free space on C: before cleanup: $beforeFree GB" -ForegroundColor Yellow
Write-Host ""

# =============================================================================
# 1. DISM component store cleanup (the big one)
# =============================================================================
Write-Host "==> DISM component store cleanup (may take 5-15 min)" -ForegroundColor Cyan
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
Write-Host ""

# =============================================================================
# 2. Clean Temp folders
# =============================================================================
$tempPaths = @(
  "$env:TEMP",
  "$env:WINDIR\Temp",
  "$env:LOCALAPPDATA\Temp"
)
Write-Host "==> Cleaning Temp folders" -ForegroundColor Cyan
foreach ($p in $tempPaths) {
  if (Test-Path $p) {
    $size = Get-FolderSizeMB $p
    try {
      Get-ChildItem $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "  OK   $p (was $size MB)" -ForegroundColor Green
    } catch { Write-Host "  PARTIAL $p (some files locked)" -ForegroundColor Yellow }
  }
}
Write-Host ""

# =============================================================================
# 3. Windows Update download cache
# =============================================================================
Write-Host "==> Cleaning Windows Update cache" -ForegroundColor Cyan
$wuPath = "$env:WINDIR\SoftwareDistribution\Download"
if (Test-Path $wuPath) {
  $size = Get-FolderSizeMB $wuPath
  try {
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    Get-ChildItem $wuPath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service wuauserv -ErrorAction SilentlyContinue
    Write-Host "  OK Windows Update cache (was $size MB)" -ForegroundColor Green
  } catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }
}
Write-Host ""

# =============================================================================
# 4. Delivery Optimization cache
# =============================================================================
Write-Host "==> Cleaning Delivery Optimization cache" -ForegroundColor Cyan
$doPath = "$env:WINDIR\SoftwareDistribution\DeliveryOptimization"
if (Test-Path $doPath) {
  $size = Get-FolderSizeMB $doPath
  try {
    Get-ChildItem $doPath -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  OK Delivery Optimization cache (was $size MB)" -ForegroundColor Green
  } catch { Write-Host "  PARTIAL (some files locked)" -ForegroundColor Yellow }
}
Write-Host ""

# =============================================================================
# 5. Crash dumps / memory.dmp / minidumps
# =============================================================================
Write-Host "==> Removing old crash dumps" -ForegroundColor Cyan
$dumpPaths = @(
  "$env:WINDIR\Memory.dmp",
  "$env:WINDIR\Minidump",
  "$env:LOCALAPPDATA\CrashDumps"
)
foreach ($p in $dumpPaths) {
  if (Test-Path $p) {
    $size = Get-FolderSizeMB $p
    try {
      Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host "  OK   $p ($size MB)" -ForegroundColor Green
    } catch { Write-Host "  FAIL $p" -ForegroundColor Red }
  }
}
Write-Host ""

# =============================================================================
# 6. Thumbnail cache
# =============================================================================
Write-Host "==> Clearing thumbnail cache" -ForegroundColor Cyan
$thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbPath) {
  try {
    Get-ChildItem $thumbPath -Filter "thumbcache_*.db" -Force | Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem $thumbPath -Filter "iconcache_*.db" -Force | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "  OK Thumbnail and icon cache cleared" -ForegroundColor Green
  } catch { Write-Host "  PARTIAL (Explorer may have locks)" -ForegroundColor Yellow }
}
Write-Host ""

# =============================================================================
# 7. Empty Recycle Bin (all drives)
# =============================================================================
Write-Host "==> Emptying Recycle Bin" -ForegroundColor Cyan
try {
  Clear-RecycleBin -Force -ErrorAction Stop
  Write-Host "  OK Recycle Bin emptied" -ForegroundColor Green
} catch { Write-Host "  SKIP (already empty or no access)" -ForegroundColor DarkGray }

# =============================================================================
# SUMMARY
# =============================================================================
$afterFree = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$freed = [math]::Round($afterFree - $beforeFree, 2)
Write-Host ""
Write-Host "==> RESULT" -ForegroundColor Cyan
Write-Host "  Free space before: $beforeFree GB" -ForegroundColor Yellow
Write-Host "  Free space after:  $afterFree GB" -ForegroundColor Yellow
Write-Host "  Recovered:         $freed GB" -ForegroundColor Green
Write-Host ""
Write-Host "Done." -ForegroundColor Green
