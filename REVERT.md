# Reverting changes

The simplest path is the script:

```powershell
.\scripts\revert-all.ps1
```

But you can also revert individual pieces manually. Below are the granular commands. All require **Administrator** PowerShell.

---

## Defender exclusions

### Remove all exclusions at once

```powershell
$pref = Get-MpPreference
$pref.ExclusionPath      | ForEach-Object { Remove-MpPreference -ExclusionPath $_ }
$pref.ExclusionProcess   | ForEach-Object { Remove-MpPreference -ExclusionProcess $_ }
$pref.ExclusionExtension | ForEach-Object { Remove-MpPreference -ExclusionExtension $_ }
```

### Or remove one exclusion at a time

```powershell
Remove-MpPreference -ExclusionPath "C:\Windows"
Remove-MpPreference -ExclusionProcess "node.exe"
Remove-MpPreference -ExclusionExtension ".zip"
```

### Restore engine defaults

```powershell
Set-MpPreference -DisableIOAVProtection $false
Set-MpPreference -DisableScriptScanning $false
Set-MpPreference -DisableArchiveScanning $false
Set-MpPreference -DisableRemovableDriveScanning $false
Set-MpPreference -DisableEmailScanning $false
Set-MpPreference -MAPSReporting 2                # Advanced
Set-MpPreference -SubmitSamplesConsent 1         # Send safe samples
Set-MpPreference -DisableCatchupQuickScan $false
Set-MpPreference -DisableCatchupFullScan $false
```

### GUI alternative

`Settings` → `Privacy & Security` → `Windows Security` → `Virus & threat protection` → `Manage settings` → scroll to `Exclusions` → `Add or remove exclusions`.

---

## SysMain (Superfetch)

```powershell
Set-Service -Name SysMain -StartupType Automatic
Start-Service SysMain
```

---

## Fast Startup

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
  -Name HiberbootEnabled -Value 1
```

---

## Telemetry services

```powershell
Set-Service -Name DiagTrack -StartupType Automatic
Start-Service DiagTrack
Set-Service -Name dmwappushservice -StartupType Manual
```

---

## Power plan

Back to Balanced:

```powershell
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e
```

Other built-in plan GUIDs:
- `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c` — High Performance
- `a1841308-3541-4fab-bc81-f71556f20b4a` — Power Saver

To delete the Ultimate Performance plan you created:

```powershell
powercfg -delete e9a42b02-d5df-448d-aa00-03f14749eb61
```

---

## Pagefile

Back to automatic management:

```powershell
$cs = Get-CimInstance Win32_ComputerSystem
Set-CimInstance -InputObject $cs -Property @{AutomaticManagedPagefile=$true}
```

Then reboot.

---

## HAGS (Hardware-accelerated GPU Scheduling)

Disable:

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
  -Name HwSchMode -Value 1
```

Then reboot.

---

## Edge services / tasks

```powershell
Set-Service -Name edgeupdate -StartupType Automatic
Set-Service -Name edgeupdatem -StartupType Manual
Set-Service -Name MicrosoftEdgeElevationService -StartupType Manual

# Re-enable Edge scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Edge*' -and $_.State -eq 'Disabled' } |
  Enable-ScheduledTask
```

---

## Junk scheduled tasks

Re-enable all disabled scheduled tasks:

```powershell
Get-ScheduledTask | Where-Object { $_.State -eq 'Disabled' } | Enable-ScheduledTask
```

Or a specific one:

```powershell
Enable-ScheduledTask -TaskPath '\Microsoft\Office\' -TaskName 'Office Feature Updates'
```

---

## Startup apps (HKCU\Run)

To restore a startup entry, you'd need to know its original command. The most reliable source is the program itself — reinstall or open its settings and re-enable "Start with Windows". If you only need to re-add an entry whose command you remember:

```powershell
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
  -Name 'Teams' -Value '"C:\Path\To\Teams.exe"'
```

---

## Full revert in one shot

Just run `revert-all.ps1` (in this repo's `scripts/` folder). It does everything above except restoring deleted startup entries (those have to come from the original app).
