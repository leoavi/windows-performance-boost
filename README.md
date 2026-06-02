# Windows Performance Boost

Opinionated Windows 11 tuning scripts for **developer machines**. Removes bloatware, kills telemetry, ships an aggressive Microsoft Defender exclusion profile, and tunes the OS for SSD + dev workloads.

Tested on Windows 11 24H2 on a Dell laptop (Core 7 150U, 16 GB RAM, NVMe SSD), but should work on any Win11 with the relevant features.

> ⚠️ **Read [the disclaimer](#disclaimer) before running anything.** These scripts make destructive system changes. Reverting is supported but a clean OS install is always safer if something breaks.

---

## What it does

Four scripts, all in [`scripts/`](./scripts):

| Script | Purpose |
|---|---|
| [`add-defender-exclusions.ps1`](./scripts/add-defender-exclusions.ps1) | Adds ~40 folder, ~30 process and 16 extension exclusions to Microsoft Defender, plus engine tweaks to minimize I/O overhead. Effectively narrows Defender's active surface to `%USERPROFILE%\Downloads` and new processes. |
| [`tune-performance.ps1`](./scripts/tune-performance.ps1) | Disables SysMain, Fast Startup, telemetry services (DiagTrack, dmwappushservice), 16+ junk scheduled tasks, Edge background tasks, NTFS last-access timestamps, WinSAT. Activates Ultimate Performance power plan. Pins pagefile to 8-16 GB. Enables HAGS. Sets the WSAIFabricSvc AI service to Manual, applies a preventive Recall block, and disables residual telemetry/tracking toggles (ads, activity history, app-launch tracking). |
| [`deep-clean.ps1`](./scripts/deep-clean.ps1) | Recovers disk space — DISM component store cleanup, Temp folders, Windows Update cache, Delivery Optimization cache, crash dumps, thumbnail cache, Recycle Bin. Run periodically (monthly/quarterly). |
| [`revert-all.ps1`](./scripts/revert-all.ps1) | Reverts everything to Windows defaults. |

### Performance changes at a glance

- **SysMain disabled** — Superfetch wastes I/O on SSDs.
- **Fast Startup off** — root cause of many Windows Update and driver bugs; saves only 2-3s of boot time anyway.
- **HAGS on** — GPU schedules its own work, freeing CPU cycles.
- **Pagefile fixed 8192-16384 MB** — sized for a 16 GB machine that was exhausting an 8 GB cap (observed pagefile peak ~8.6 GB). Less SSD wear than fully dynamic.
- **Ultimate Performance power plan** — disables aggressive throttling on laptops.

### Privacy changes at a glance

- **DiagTrack + dmwappushservice disabled** — last two residual telemetry services.
- **CEIP, Compatibility Appraiser, OneDrive Reporting** — disabled.
- **Defender MAPS cloud reporting off**, sample submission set to "never".
- **Edge background update tasks disabled**, services demoted to Manual.
- **WSAIFabricSvc (on-device AI) → Manual**, **Windows Recall blocked** via preventive policy (no-op on non-Copilot+ hardware, blocks future activation), and residual **targeted ads / activity history / app-launch tracking** toggles off — all reversible, zero UX impact.

### Deliberately excluded — popular tweaks that are placebo or harmful

These circulate widely in "Windows optimization" guides and YouTube videos. An adversarial research pass (24 sources, claims confirmed/killed by majority vote against primary docs and reputable debloaters) found them to be measurably useless or actively harmful, so this repo intentionally does **not** apply them:

- **`DisablePagingExecutive` / disabling the pagefile** — no measurable benefit; can *degrade* performance or trigger OOM on a 16 GB machine. The fixed pagefile this repo sets is the correct approach; don't disable it.
- **`NetworkThrottlingIndex`, `SystemResponsiveness`, `Win32PrioritySeparation`** — not used by any reputable debloater (winutil applies none of them). The "unlocks ~15 MB/s" claim was refuted: the MMCSS packet cap only applies while a multimedia stream is active, not to general networking.
- **Disabling Nagle's algorithm (`TcpNoDelay`)** — only helps chatty interactive RDP/SSH; modern dev libraries already set `TCP_NODELAY` per-socket, so it's placebo for local dev.
- **Disabling Windows Search (`WSearch`)** — *degrades* file access and search speed. Do **not** disable on a dev machine.
- **Removing built-in Appx apps for speed** — near-zero measurable RAM/CPU gain (Tiny11 vs vanilla benchmarks fall within margin of error). Worth doing for disk/privacy, not performance.
- **`DISM /Remove` of optional features to reclaim disk** — on client Windows the payload is retained for Push-button reset, so it frees no meaningful space (per Microsoft Learn). Disabling a feature that runs background services (e.g. Hyper-V) has runtime value; removing one "to clean disk" does not.

**Rule of thumb:** once the changes in this repo are applied, the biggest remaining risk to performance is **regression from over-tweaking**, not a missing tweak. The "make Windows as fast as Linux" gap that remains is architectural (filesystem, process model, real-time AV), not something another registry key closes.

### Defender impact

The default Defender posture is "scan everything everywhere, all the time". This profile inverts that:

- **Excluded:** entire `%USERPROFILE%` except `Downloads`, all of `AppData`, `C:\Windows`, `C:\ProgramData`, `Program Files`, `Program Files (x86)`, all major browser caches, OneDrive, Google Drive, common dev tool folders (Node, Git, VS Code, Python, PHP, Rust, Go, etc.).
- **Process exclusions:** node, npm, php, python, git, code, sqlservr, ssms, chrome, msedge, OneDrive, Office, Acrobat, archivers, OpenVPN, etc.
- **Extension exclusions:** `.log .tmp .cache .lock .iso .vhd .vhdx .vmdk .bak .dump .sql .zip .7z .rar .tar .gz`
- **Engine tweaks:** disables IOAV scan, AMSI script scan, archive scan, email scan, removable drive auto-scan, scheduled scans, catchup scans, and all cloud telemetry/sample submission.

**Real-time monitoring stays on** — Defender still acts when something *runs*, just doesn't scan its way through your entire filesystem on idle.

---

## Recommended setup before running

### Enable `sudo` (Windows 11 24H2+)

Highly recommended. Lets you run elevated commands from any terminal **without spawning a new admin window**, which is essential if you want to drive this with an AI agent (Claude Code, Cursor, Codex, etc.) or just keep your shell history coherent.

1. **Settings → System → For developers**
2. Toggle **Enable sudo** on
3. Set sudo mode to **Inline** (not "New window" — inline captures stdout in your current shell)

After enabling, you can run any command elevated like this:

```powershell
sudo .\scripts\tune-performance.ps1
```

The first call triggers a UAC prompt; once approved, subsequent calls in the same session are seamless.

### Enable Developer Mode (optional but useful)

Same settings page, toggle **Developer Mode** on. Unlocks:

- Running unsigned PowerShell scripts more easily (no `Set-ExecutionPolicy` dance)
- Symbolic links without admin
- Better integration with Windows Subsystem for Linux (WSL) if you use it

If you don't enable it, you'll need `Set-ExecutionPolicy -Scope Process Bypass -Force` once per PowerShell session to run the scripts.

---

## Quickstart

### 1. Clone

```powershell
git clone https://github.com/<you>/windows-performance-boost.git
cd windows-performance-boost
```

### 2. Open PowerShell as Administrator

`Win + X` → **Terminal (Admin)** or **Windows PowerShell (Admin)**.

### 3. Run the scripts

With `sudo` enabled (recommended):

```powershell
sudo .\scripts\add-defender-exclusions.ps1
sudo .\scripts\tune-performance.ps1
sudo .\scripts\deep-clean.ps1   # optional, recovers disk space
```

Without `sudo` — open PowerShell as Admin and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\add-defender-exclusions.ps1
.\scripts\tune-performance.ps1
.\scripts\deep-clean.ps1   # optional
```

### 4. Manual step — clean up startup apps

`Ctrl + Shift + Esc` → **Startup apps** tab → disable anything tagged "High impact" that you don't need at boot. The performance script prints your current startup list for reference.

### 5. Reboot

Pagefile and HAGS changes require a reboot.

### 6. Verify

After reboot, check that your critical apps work: VPN, database tools, IDEs, browsers, sync clients. If something broke, run the revert script (see below).

---

## Reverting

```powershell
.\scripts\revert-all.ps1
```

Then reboot. This restores everything to Windows defaults: re-enables services, removes all Defender exclusions, switches back to Balanced power plan, restores automatic pagefile, disables HAGS, re-enables all disabled scheduled tasks.

If you want to revert *just one piece*, see [REVERT.md](./REVERT.md) for granular commands.

---

## Running it via Claude / AI agents

The whole thing was originally built in a Claude Code session. See [CLAUDE.md](./CLAUDE.md) for the prompts that drove the work — useful if you want to:

- Have Claude run the scripts on your own machine
- Have Claude customize the exclusion list for your specific dev stack
- Replicate or extend this work in your own environment

---

## Tamper Protection

Three Defender engine tweaks (`DisableIOAVProtection`, `DisableScriptScanning`, `DisableArchiveScanning`) are blocked by Windows Tamper Protection. The script handles this gracefully — it logs which ones were blocked and continues. To apply all of them:

1. **Settings → Privacy & Security → Windows Security → Virus & threat protection → Manage settings**
2. Toggle off **Tamper Protection**
3. Re-run `add-defender-exclusions.ps1`

Honestly, with the path exclusions this aggressive, those three toggles are marginal. Recommended: leave Tamper Protection on.

---

## What this does NOT do

- **Doesn't remove bloatware Appx packages.** That's a separate task — use [WinUtil](https://christitus.com/win) or `Get-AppxPackage | Where-Object { $_.Name -match 'X' } | Remove-AppxPackage` manually.
- **Doesn't tweak the registry for visual effects.** Use `sysdm.cpl ,3` → Performance Settings.
- **Doesn't disable Microsoft Defender entirely.** Real-time monitoring stays on. If you want to fully replace Defender, install a third-party AV (ESET, Bitdefender Total Security, etc.) and Windows will deactivate Defender automatically.
- **Doesn't touch graphics drivers, BIOS, or firmware.** Use vendor tools (Dell SupportAssist, Lenovo Vantage, etc.) for those.

---

## Disclaimer

These scripts make changes that affect security, privacy, performance, and battery life. They are designed for:

- A single-user developer machine
- An owner who understands what they're doing
- A machine where the user is willing to accept slightly increased malware risk in exchange for raw performance

They are **not appropriate** for:

- Shared / corporate / managed devices (likely violates MDM policy)
- Machines that store credentials for high-value accounts without strong compensating controls
- Users who are uncomfortable reading and understanding PowerShell

The author and contributors are not responsible for any damage, data loss, or security incidents resulting from running these scripts. **Read the code before running it.**

---

## License

MIT — see [LICENSE](./LICENSE).

---

## Credits

Built collaboratively with [Claude](https://claude.ai) in a long Claude Code session. The conversation is reproduced in [CLAUDE.md](./CLAUDE.md) as a guide for replicating or extending this work.
