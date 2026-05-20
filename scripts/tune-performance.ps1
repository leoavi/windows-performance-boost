# =============================================================================
# Windows Performance Tuning
# =============================================================================
# Optimizes a Windows 11 machine with SSD + 8GB+ RAM by:
#   - Disabling SysMain (Superfetch, useless on SSDs)
#   - Disabling Fast Startup (causes Windows Update / driver bugs)
#   - Disabling telemetry services (DiagTrack, dmwappushservice)
#   - Activating the hidden "Ultimate Performance" power plan
#   - Fixing the pagefile to 4096-8192 MB (via registry, applies after reboot)
#   - Enabling HAGS (Hardware-accelerated GPU Scheduling)
#   - Disabling Edge background scheduled tasks and demoting Edge update services
#   - Disabling ~16 telemetry/junk scheduled tasks
#
# After running, REBOOT for pagefile + HAGS to take effect.
#
# Run as Administrator.
# =============================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "ERROR: must run as Administrator." -ForegroundColor Red
  exit 1
}

# =============================================================================
# 1. Disable SysMain (Superfetch)
# =============================================================================
Write-Host "==> Disabling SysMain (useless on SSDs)" -ForegroundColor Cyan
try {
  Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
  Set-Service -Name SysMain -StartupType Disabled -ErrorAction Stop
  Write-Host "  OK SysMain stopped and disabled" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 2. Disable Fast Startup
# =============================================================================
Write-Host ""
Write-Host "==> Disabling Fast Startup" -ForegroundColor Cyan
try {
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -Value 0 -Type DWord -Force
  Write-Host "  OK Fast Startup disabled" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 3. Disable telemetry services
# =============================================================================
Write-Host ""
Write-Host "==> Disabling telemetry services" -ForegroundColor Cyan
foreach ($svc in @('DiagTrack', 'dmwappushservice')) {
  try {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
    Write-Host "  OK $svc" -ForegroundColor Green
  } catch { Write-Host "  FAIL $svc -> $($_.Exception.Message)" -ForegroundColor Red }
}

# =============================================================================
# 4. Activate Ultimate Performance power plan
# =============================================================================
Write-Host ""
Write-Host "==> Creating/activating Ultimate Performance power plan" -ForegroundColor Cyan
try {
  $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-String
  if ($out -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
    $guid = $matches[1]
    powercfg -setactive $guid
    Write-Host "  OK Plan created and activated: $guid" -ForegroundColor Green
  } else {
    powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61
    Write-Host "  OK Plan already existed, activated" -ForegroundColor Green
  }
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 5. Pagefile: fixed 4096-8192 MB (registry approach, applies after reboot)
# =============================================================================
Write-Host ""
Write-Host "==> Setting pagefile to fixed 4096-8192 MB" -ForegroundColor Cyan
try {
  # Disable automatic management
  $cs = Get-CimInstance Win32_ComputerSystem
  if ($cs.AutomaticManagedPagefile) {
    Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile = $false } | Out-Null
  }
  # Write directly to registry (CIM has type quirks)
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
    -Name PagingFiles -Value "C:\pagefile.sys 4096 8192" -Type MultiString -Force
  Write-Host "  OK Pagefile set (applies after reboot)" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 6. Enable HAGS (Hardware-accelerated GPU Scheduling)
# =============================================================================
Write-Host ""
Write-Host "==> Enabling HAGS (Hardware-accelerated GPU Scheduling)" -ForegroundColor Cyan
try {
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
    -Name HwSchMode -Value 2 -Type DWord -Force
  Write-Host "  OK HAGS enabled (applies after reboot)" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 7. Disable Edge background tasks and demote Edge update services
# =============================================================================
Write-Host ""
Write-Host "==> Disabling Edge background tasks" -ForegroundColor Cyan
$edgeTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Edge*" -or $_.Path -like "*Edge*" }
foreach ($task in $edgeTasks) {
  try {
    Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
    Write-Host "  OK $($task.TaskPath)$($task.TaskName)" -ForegroundColor Green
  } catch { Write-Host "  FAIL $($task.TaskName)" -ForegroundColor Red }
}
foreach ($svc in @('edgeupdate', 'edgeupdatem', 'MicrosoftEdgeElevationService')) {
  try {
    Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    Set-Service -Name $svc -StartupType Manual -ErrorAction Stop
    Write-Host "  OK service $svc -> Manual" -ForegroundColor Green
  } catch { Write-Host "  SKIP service $svc (not found)" -ForegroundColor DarkGray }
}

# =============================================================================
# 8. Disable junk/telemetry scheduled tasks
# =============================================================================
Write-Host ""
Write-Host "==> Disabling junk/telemetry scheduled tasks" -ForegroundColor Cyan
$junkTasks = @(
  @{Path = '\'; Name = 'Adobe Acrobat Update Task' },
  @{Path = '\Microsoft\Office\'; Name = 'Office Actions Server' },
  @{Path = '\Microsoft\Office\'; Name = 'Office Background Push Maintenance' },
  @{Path = '\Microsoft\Office\'; Name = 'Office Feature Updates' },
  @{Path = '\Microsoft\Office\'; Name = 'Office Feature Updates Logon' },
  @{Path = '\Microsoft\Office\'; Name = 'Office Performance Monitor' },
  @{Path = '\Microsoft\Office\'; Name = 'Office Startup Maintenance' },
  @{Path = '\Microsoft\Windows\Application Experience\'; Name = 'MareBackup' },
  @{Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser Exp' },
  @{Path = '\Microsoft\Windows\Application Experience\'; Name = 'PcaPatchDbTask' },
  @{Path = '\Microsoft\Windows\Application Experience\'; Name = 'SdbinstMergeDbTask' },
  @{Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' },
  @{Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' },
  @{Path = '\Microsoft\Windows\Maps\'; Name = 'MapsToastTask' },
  @{Path = '\Microsoft\Windows\PerformanceTrace\'; Name = 'ShowFeedbackToast' },
  @{Path = '\Microsoft\Windows\Sustainability\'; Name = 'SustainabilityTelemetry' }
)
$onedriveReporting = Get-ScheduledTask | Where-Object { $_.TaskName -like 'OneDrive Reporting Task*' }
foreach ($t in $onedriveReporting) {
  $junkTasks += @{Path = $t.TaskPath; Name = $t.TaskName }
}
foreach ($t in $junkTasks) {
  try {
    Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction Stop | Out-Null
    Write-Host "  OK   $($t.Path)$($t.Name)" -ForegroundColor Green
  } catch { Write-Host "  FAIL $($t.Name) -> $($_.Exception.Message)" -ForegroundColor Red }
}

# =============================================================================
# 9. Disable NTFS last-access timestamp updates
# =============================================================================
Write-Host ""
Write-Host "==> Disabling NTFS last-access timestamp updates" -ForegroundColor Cyan
try {
  fsutil behavior set DisableLastAccess 1 | Out-Null
  Write-Host "  OK NTFS lastaccess disabled (less SSD wear)" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 10. Disable WinSAT (weekly disk benchmark, pointless on modern SSDs)
# =============================================================================
Write-Host ""
Write-Host "==> Disabling WinSAT scheduled task" -ForegroundColor Cyan
try {
  Disable-ScheduledTask -TaskPath '\Microsoft\Windows\Maintenance\' -TaskName 'WinSAT' -ErrorAction Stop | Out-Null
  Write-Host "  OK WinSAT disabled" -ForegroundColor Green
} catch { Write-Host "  FAIL $($_.Exception.Message)" -ForegroundColor Red }

# =============================================================================
# 11. List startup programs (informational only)
# =============================================================================
Write-Host ""
Write-Host "==> Current startup programs (disable manually with Ctrl+Shift+Esc):" -ForegroundColor Cyan
Get-CimInstance Win32_StartupCommand | ForEach-Object {
  Write-Host ("  [{0}] {1}" -f $_.Location, $_.Name) -ForegroundColor Yellow
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host ""
Write-Host "==> SUMMARY" -ForegroundColor Cyan
Write-Host "  - SysMain: $((Get-Service SysMain).Status) / $((Get-Service SysMain).StartType)" -ForegroundColor Yellow
Write-Host "  - DiagTrack: $((Get-Service DiagTrack -EA SilentlyContinue).StartType)" -ForegroundColor Yellow
Write-Host "  - Active power plan:" -ForegroundColor Yellow
powercfg -getactivescheme
Write-Host ""
Write-Host "REBOOT REQUIRED for pagefile and HAGS to take effect." -ForegroundColor Magenta
Write-Host ""
Write-Host "Done." -ForegroundColor Green
