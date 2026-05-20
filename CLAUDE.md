# Running this via Claude / AI agents

This whole project was built in a Claude Code session. The conversation followed a pretty natural rhythm — *"my Windows feels slow, help me fix it"* — that you can replicate or extend on your own machine.

This file gives you the prompt structure that worked, plus suggestions for how to use Claude (or any capable agentic AI with shell access) to apply this profile to **your** machine, not just blindly copy this one.

## Why use an AI agent

The scripts in this repo are **opinionated for one specific dev stack** (Node, PHP/Herd, Python, SQL Server, Obsidian, OpenVPN). If your stack is different — Docker-heavy, Java, Rust-only, gaming-focused, video editing — you want the exclusion list and tweaks tailored. An AI agent with shell access can:

1. Inspect your installed apps and dev tools
2. Build an exclusion list that matches *your* paths
3. Apply only the tweaks relevant to your hardware (laptop vs desktop, SSD vs HDD, etc.)
4. Walk you through Tamper Protection and HAGS toggles
5. Verify after reboot and revert pieces that broke something

## Prerequisites

- **Claude Code** (or Codex, Cursor agent mode, or any AI with PowerShell execution)
- **Windows 11** (most tweaks work on Win10 too)
- **Admin password** — you'll need to accept UAC prompts
- **Sudo for Windows** enabled (`Settings → System → For developers → Enable sudo → Inline mode`) so the agent can run elevated commands inline. This is the single biggest QoL improvement.

## Suggested prompt sequence

You don't have to follow this exact order. The key insight is **one chunk at a time, verify before moving on**. Don't dump the whole list into one prompt.

### Phase 1 — Reconnaissance

```
Inspect my Windows machine. I want to know:
- Hardware (CPU, RAM, disk type, chassis)
- Installed Appx packages (filter out system framework ones)
- Installed Win32 programs
- Current scheduled tasks that look like junk/telemetry
- Current startup programs
```

The agent should produce a categorized list. Push back on anything it removes from the list — *"why are you keeping X?"* is a useful question.

### Phase 2 — Bloatware removal

```
Remove the following Appx packages: [list].
Then list any Win32 programs I should consider uninstalling. Don't remove anything from Win32 without my confirmation.
```

Always confirm Win32 uninstalls individually. Some look like bloatware but are actually dependencies of something you use (e.g., Dell SupportAssist components).

### Phase 3 — Defender exclusions

```
Build a Defender exclusion profile for my dev stack. My tools are: [list].
Aggressive but not insane — I want path/process/extension exclusions covering my dev folders, browsers, AppData, but keep Downloads under scan.
Also tune the engine to minimize I/O overhead but keep real-time monitoring on.
```

This is where you'd typically get something close to `add-defender-exclusions.ps1`. The agent should generate it custom to your installed tools.

### Phase 4 — Performance tweaks

```
Apply Windows performance tweaks for a [laptop/desktop] with [RAM] GB RAM and SSD:
- Disable SysMain (Superfetch)
- Disable Fast Startup
- Create and activate the Ultimate Performance power plan
- Fix the pagefile size
- Enable HAGS
- Disable telemetry services and junk scheduled tasks
- Disable Edge background tasks
- List my startup apps for me to decide what to disable
```

### Phase 5 — Verification

After running everything and rebooting:

```
Verify the changes took effect. Check:
- Defender exclusion count
- SysMain service state
- Active power plan
- Pagefile state
- HAGS registry key
- That my critical apps still work: [list them]
```

### Phase 6 — Iteration

After a few days of use, ask:

```
Anything new in my startup, scheduled tasks, or installed apps that wasn't there last time? I want to keep this clean.
```

## What to tell the agent up front

Things that materially change the recommendations:

| Context | Why it matters |
|---|---|
| Laptop vs desktop | Power plan choice, sleep tweaks |
| SSD vs HDD | SysMain, Storage Sense, defrag |
| RAM amount | Pagefile sizing |
| Primary use (dev, gaming, video, office) | Which apps to exclude, which services to keep |
| Dev stack (Node, .NET, Python, etc.) | Exclusion list customization |
| Cybersecurity comfort level | How aggressive to be with Defender |
| Whether you have another AV | If yes, Defender can be more aggressively disabled |
| Corporate policy (MDM, BitLocker, etc.) | Some changes may be reverted by policy or break compliance |

## What to *not* let the agent do

- **Don't let it disable Microsoft Defender entirely without replacement.** "Disable Defender" is a popular YouTube tweak that leaves you completely exposed. If you want it off, install ESET/Bitdefender first.
- **Don't let it touch `C:\Windows` aggressively without backup.** Restore Point first.
- **Don't run unverified third-party debloat tools.** WinUtil from chrisTitusTech is OK and audited; random "Windows Optimizer 2024.exe" downloads are not.
- **Don't blindly accept exclusion lists.** Read what's being added. The agent might exclude something that should be scanned for your threat model.

## Replicating the original conversation

The original Claude session that built this repo went roughly like this:

1. Bloatware listing → user approves removal lists per category
2. Anti-ad / sugestion registry tweaks applied
3. Win32 program review
4. Defender exclusion conversation (escalating from "dev folders only" to "everything except Downloads")
5. Performance tweak proposal → user approves selectively
6. Scripts written to Desktop, run via `sudo`
7. Pagefile and HAGS issues debugged via registry
8. Startup app cleanup
9. Repo extracted

If you want to reproduce or extend, start a fresh agent session and feed it the prompts in Phase 1 onwards. The agent will adapt to your machine.
