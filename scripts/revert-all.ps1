# =============================================================================
# Revert ALL changes made by add-defender-exclusions.ps1 and tune-performance.ps1
# =============================================================================
# Restores Windows to default behavior:
#   - Removes all custom Defender exclusions and re-enables engine features
#   - Re-enables SysMain, Fast Startup, DiagTrack, dmwappushservice
#   - Switches power plan back to Balanced
#   - Sets pagefile back to automatic management
#   - Disables HAGS
#   - Re-enables Edge update services
#   - Re-enables all disabled scheduled tasks
#
# Run as Administrator.
# =============================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "ERROR: must run as Administrator." -ForegroundColor Red
  exit 1
}

# =============================================================================
# 1. Remove all Defender exclusions and restore engine
# =============================================================================
Write-Host "==> Removing all Defender exclusions" -ForegroundColor Cyan
$pref = Get-MpPreference
$pathCount = $pref.ExclusionPath.Count
$procCount = $pref.ExclusionProcess.Count
$extCount  = $pref.ExclusionExtension.Count

$pref.ExclusionPath      | ForEach-Object { try { Remove-MpPreference -ExclusionPath $_ -EA Stop } catch {} }
$pref.ExclusionProcess   | ForEach-Object { try { Remove-MpPreference -ExclusionProcess $_ -EA Stop } catch {} }
$pref.ExclusionExtension | ForEach-Object { try { Remove-MpPreference -ExclusionExtension $_ -EA Stop } catch {} }
Write-Host "  OK Removed $pathCount paths, $procCount processes, $extCount extensions" -ForegroundColor Green

Write-Host ""
Write-Host "==> Restoring Defender engine" -ForegroundColor Cyan
try { Set-MpPreference -DisableIOAVProtection $false -EA Stop;             Write-Host "  OK IOAV scan re-enabled" -ForegroundColor Green }            catch {}
try { Set-MpPreference -DisableScriptScanning $false -EA Stop;             Write-Host "  OK Script scan re-enabled" -ForegroundColor Green }         catch {}
try { Set-MpPreference -DisableArchiveScanning $false -EA Stop;            Write-Host "  OK Archive scan re-enabled" -ForegroundColor Green }        catch {}
try { Set-MpPreference -DisableRemovableDriveScanning $false -EA Stop;     Write-Host "  OK Removable drive scan re-enabled" -ForegroundColor Green } catch {}
try { Set-MpPreference -DisableEmailScanning $false -EA Stop;              Write-Host "  OK Email scan re-enabled" -ForegroundColor Green }          catch {}
try { Set-MpPreference -MAPSReporting 2 -EA Stop;                          Write-Host "  OK MAPS reporting -> Advanced" -ForegroundColor Green }     catch {}
try { Set-MpPreference -SubmitSamplesConsent 1 -EA Stop;                   Write-Host "  OK Sample submission -> Auto Safe" -ForegroundColor Green } catch {}
try { Set-MpPreference -DisableCatchupQuickScan $false -EA Stop;           Write-Host "  OK Catchup quick scan re-enabled" -ForegroundColor Green }  catch {}
try { Set-MpPreference -DisableCatchupFullScan $false -EA Stop;            Write-Host "  OK Catchup full scan re-enabled" -ForegroundColor Green }   catch {}

# =============================================================================
# 2. Restore services
# =============================================================================
Write-Host ""
Write-Host "==> Re-enabling services" -ForegroundColor Cyan
$services = @{
  SysMain                       = 'Automatic'
  DiagTrack                     = 'Automatic'
  dmwappushservice              = 'Manual'
  edgeupdate                    = 'Automatic'
  edgeupdatem                   = 'Manual'
  MicrosoftEdgeElevationService = 'Manual'
}
foreach ($svc in $services.Keys) {
  try {
    Set-Service -Name $svc -StartupType $services[$svc] -EA Stop
    Write-Host "  OK $svc -> $($services[$svc])" -ForegroundColor Green
  } catch { Write-Host "  SKIP $svc (not found)" -ForegroundColor DarkGray }
}
try { Start-Service SysMain -EA SilentlyContinue } catch {}

# =============================================================================
# 3. Restore Fast Startup
# =============================================================================
Write-Host ""
Write-Host "==> Re-enabling Fast Startup" -ForegroundColor Cyan
try {
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -Value 1 -Type DWord -Force
  Write-Host "  OK Fast Startup enabled" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 4. Restore Balanced power plan
# =============================================================================
Write-Host ""
Write-Host "==> Switching to Balanced power plan" -ForegroundColor Cyan
try {
  powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e
  Write-Host "  OK Active plan: Balanced" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 5. Restore automatic pagefile management
# =============================================================================
Write-Host ""
Write-Host "==> Restoring automatic pagefile" -ForegroundColor Cyan
try {
  $cs = Get-CimInstance Win32_ComputerSystem
  Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile = $true } | Out-Null
  Write-Host "  OK Automatic pagefile re-enabled (applies after reboot)" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 6. Disable HAGS
# =============================================================================
Write-Host ""
Write-Host "==> Disabling HAGS" -ForegroundColor Cyan
try {
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode -Value 1 -Type DWord -Force
  Write-Host "  OK HAGS disabled (applies after reboot)" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 7. Restore NTFS last-access timestamp updates
# =============================================================================
Write-Host ""
Write-Host "==> Restoring NTFS last-access updates" -ForegroundColor Cyan
try {
  fsutil behavior set DisableLastAccess 2 | Out-Null
  Write-Host "  OK NTFS lastaccess restored to system-managed" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 8. Re-enable all disabled scheduled tasks
# =============================================================================
Write-Host ""
Write-Host "==> Re-enabling all disabled scheduled tasks" -ForegroundColor Cyan
$disabledTasks = Get-ScheduledTask | Where-Object { $_.State -eq 'Disabled' }
foreach ($t in $disabledTasks) {
  try {
    Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -EA Stop | Out-Null
    Write-Host "  OK   $($t.TaskPath)$($t.TaskName)" -ForegroundColor Green
  } catch { Write-Host "  FAIL $($t.TaskName)" -ForegroundColor Red }
}

Write-Host ""
Write-Host "==> Revert complete. REBOOT to apply pagefile and HAGS changes." -ForegroundColor Green
