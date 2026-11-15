# win-opt — Windows Optimizer Wizard: Design

Date: 2026-11-15
Status: APPROVED by Iliya 2026-11-15 (with Win10 support + simplicity + temp-confirm modifications below) — build Phase 0 + Phase 1 now
Repo (planned): ILIV007/win-opt
Approach: A — PowerShell single script + .bat launcher
Research base: `~/workspace/research_notes/win-opt-commands-20261115-0456/report.md` (deep research 2026-11-15, Microsoft Learn/Support primary sources, SFC page verified live) + interactive page `win-opt-commands-research` (42 commands, 11 categories)

## Intent and why

A terminal wizard for people who never maintain their Windows and don't care about it. It raises the health of their Windows a bit — not a miracle, not a deep tune-up. It runs real built-in Windows commands, step by step, showing each command briefly and showing its result, in a professional and interesting terminal environment — not a plain black CMD screen.

The user opens it, picks a mode based on how much time they have, watches what happens, and ends with a healthier system and a restore point to undo system changes.

## Goals

- Real execution, not a demo: every listed command actually runs (with admin).
- Step-by-step transparency: each step shows a short description, the exact command, then its result.
- Safe by default: only safe built-in commands; any dangerous step carries a warning and needs explicit consent.
- Three time-based modes, best effort in each: a short mode is not a weak version, it is the best possible within its time.
- No-install distribution: double-click and run as admin, no Python, no third-party tools.
- Reversible where possible: restore point first in every mode, original power plan recorded for one-click revert, startup changes are Disable (reversible), never delete.
- Simple, not complicated (Iliya, 2026-11-15): keep it simple — no extra complexity, no clever extras. Every step must be obvious to a non-technical user.
- Temp cleanup always asks first (Iliya, 2026-11-15): before deleting any temp files, the wizard must ask the user for confirmation and show what will be deleted.

## Non-goals

- Not a registry cleaner, not a driver updater, not an antivirus, not a gaming FPS booster.
- Not unattended automation: no silent run, no auto-disable of startup apps, no auto network reset.
- Not a Windows reinstall / reset tool.
- No exact-minute promises: durations are estimates, shown as ranges with a progress bar, never a countdown.

## Anti-goals (failure even if it technically works)

- It looks like a plain black CMD dump.
- It runs a dangerous command silently, or deletes user files (Downloads, Windows.old, personal files).
- It promises "no restart" when Standard/Full need one restart at the end.
- It claims a speed-up a healthy PC cannot get from temp cleanup alone.
- It leaves update services stopped, or leaves the user with no way back.

## Constraints

- Windows 10 AND Windows 11 both supported (Iliya, 2026-11-15 — Win10 added, not Win11-only). PowerShell 5.1 (Checkpoint-Computer cmdlets are 5.1, not PS7). Windows 10 support ended 14 Oct 2025, so update-related steps cannot restore routine Win10 updates — on Win10 those steps are degraded/skipped with a plain note, everything else runs the same. Test matrix covers Win10 + Win11.
- Admin required for almost every command (DISM, SFC, chkdsk, Optimize-Volume, cleanmgr system categories, power plan change, network reset, restore point).
- Internet required for DISM RestoreHealth and winget; DISM RestoreHealth is 10–30 min typical, up to 45+ min on old/damaged PCs.
- Restore point: only 1 checkpoint per day via script; System Protection is NOT on by default — enable first, verify with Get-ComputerRestorePoint. A restore point is NOT a backup (no personal files).
- No registry edits in the wizard (including the restore-point frequency bypass), no Defender / core-service disabling, no WinSxS manual deletion.
- README English-only (Iliya's standing rule, 2026-11-12). Usable versions ship as GitHub Releases.
- Testing: Nova has no Windows machine — live verification must happen on a real Windows 10/11 PC (Iliya's), like his other products. Local syntax check alone is never proof.

## Approaches considered

- **A — PowerShell single script + .bat launcher (CHOSEN by Iliya, 2026-11-15):** no install, runs on any Win10/11 with PS 5.1+, all commands are native, coloured UI + progress + menus are possible, easiest to distribute as a Release zip. One file to audit.
- **B — Python with Rich/Textual (rejected):** prettiest terminal UI, but the user must have Python installed and packaging to .exe is heavy. Loses the no-install goal.
- **C — Batch only (rejected):** simplest and most compatible, but the UI is ugly and limited and error handling / progress is hard. Loses the professional/interesting goal.

## Decisions Iliya made

- Terminal-based, professional and interesting environment (2026-11-15).
- Step-by-step: show each command briefly, show its result (2026-11-15).
- Real commands must execute (2026-11-15).
- Audience: people who don't maintain their system; problem: raise Windows health a bit (2026-11-15).
- Three modes divided by time, best effort in every mode (2026-11-15).
- Only safe commands; dangerous work gets a warning (2026-11-15).
- Mode division and mode names delegated to Nova, based on the extracted commands (2026-11-15).
- Approach A (2026-11-15). Repo name win-opt, usable versions in GitHub Releases (2026-11-15). Deeper command research first, then phasing + execution (2026-11-15).

## Builder-check answers (approved by Iliya 2026-11-15 — his 6 proposals confirmed, with Win10 added)

1. Restore point fails → abort with a clear failure screen, no repairs without a safety net. Exception: if a restore point already exists today (1-per-day limit), verify it with Get-ComputerRestorePoint and continue with that existing point.
2. Windows 10 also supported (see Constraints).
3. cleanmgr: dropped from auto-run — no registry exception. Apprentice uses Storage Sense "Run now" + temp cleanup (confirm first, see Goals). cleanmgr GUI is an optional manual step only, where the wizard shows exactly what to tick.
4. Startup: list only + open Task Manager/Settings for the user to review; no disable code in v1.0.
5. Wizard SFC unfixable → stop, report, suggest Archmage; do not escalate to RestoreHealth in-place.
6. Gated branches: wizard asks 2 quick questions at the start (is Windows Update failing? is the internet broken?) + a simple ping check; drivers = open the Optional updates page only, no auto-install. (v0.1.3: the two upfront questions are removed from Apprentice — the ping runs silently; Wizard/Archmage will ask their gated-branch questions just-in-time, right before the related step, not at the start.)
7. Keep it simple, don't overcomplicate (Iliya). Temp cleanup must ask the user first (Iliya).

## Modes (Nova's call, from the research)

Names are wizard tiers — Apprentice / Wizard / Archmage.

### Apprentice — ~5–10 min, no restart required
Restore point (0a–0c) → `ipconfig /flushdns` → temp cleanup (confirm first, >7-day age filter, skip locked) + Storage Sense "Run now" → `Optimize-Volume -DriveLetter C` (media-aware: SSD ReTrim, HDD analyse/defrag only if advised) → `powercfg /list` + record original plan, offer Balanced/High Performance (user choice) → startup list (`Get-CimInstance Win32_StartupCommand`) + open Task Manager/Settings for the user to review. No DISM/SFC here. cleanmgr is NOT auto-run (see builder-check answers).

### Wizard — ~15–25 min, one restart at the end
Everything in Apprentice, plus: `DISM /CheckHealth` → `/ScanHealth` (only if
flagged) → `/RestoreHealth` (only if corruption is found, needs internet) →
`sfc /verifyonly` → `sfc /scannow` (only if indicated; DISM first, per
Microsoft Support) → `chkdsk C: /scan` → `/spotfix` (only if it logs
problems) → drive health (`Get-PhysicalDisk` + `Get-CimInstance
Win32_DiskDrive`, never WMIC) → Defender verification (real-time protection
On, definitions current, quick scan in the last 7 days — run one if missed,
never force a full scan) → Windows Update check (opens Settings) →
problem-device check (`Get-PnpDevice`, act only on listed devices) →
`perfmon /rel` guidance. Repairs run only if a check flags a problem.
Implemented in v0.2.0 (monthly pass from research round 2, §5).
Change from the original plan: gated `RestoreHealth` now lives in Wizard
(round-2 §5 — repair only if a check flags it), not only in Archmage;
Archmage keeps the deeper quarterly items.

### Archmage — ~30–60 min, one restart at the end (+ scheduled `chkdsk /f` restart if consented)
Everything in Wizard, plus: `DISM /RestoreHealth` (internet, 15–30 min — this is what pushes Wizard into Archmage) → `StartComponentCleanup` if recommended → `chkdsk C: /f` scheduled at next restart, explicit consent only → Windows Update limited component reset only if updates still fail after troubleshooter + DISM/SFC → full network reset sequence only if network is broken → `winget upgrade` review then `winget upgrade --all` (reviewed list only; downloads can push it over — say so upfront) → driver Optional updates via Windows Update, driver backup first.

Times are estimates for a healthy modern SSD PC, excluding downloads and the `chkdsk /f` restart pass. Show a progress bar, never a countdown; DISM/SFC progress can sit at one % for a long time.

## Fixed run order (from research — do not reorder)

1. Restore point first. If Checkpoint-Computer fails (protection off / already one today), fix or warn — do not silently continue into repairs.
2. Read-only checks before any change: power plan record, startup inventory, DISM Check/Scan, Optimize-Volume -Analyze, chkdsk /scan, winget list only.
3. Repair before deep cleanup: temp/cleanmgr (space) → DISM Check/Scan → DISM RestoreHealth → SFC → StartComponentCleanup only if recommended → chkdsk /f (scheduled) → Windows Update reset only if still failing → network reset only if broken.
4. DISM before SFC — always. If SFC reports unfixable files, run DISM RestoreHealth, then SFC again — once. Do not loop SFC alone.
5. Drivers last, after restore point and system repair. `winget upgrade --all` only after the user reviewed `winget upgrade`.
6. One restart at the end of a mode covers SFC repairs, DISM, network reset and driver installs. `chkdsk /f` needs its own restart.

## Command catalogue (summary — full table is in the research report)

- Safety net: `Enable-ComputerRestore -Drive "C:\"`, `Checkpoint-Computer -Description "Before optimizer" -RestorePointType MODIFY_SETTINGS`, `Get-ComputerRestorePoint`.
- Repair: DISM CheckHealth / ScanHealth / RestoreHealth / AnalyzeComponentStore / StartComponentCleanup, `sfc /scannow`.
- Disk: `chkdsk C:` / `/scan` / `/f`, `Optimize-Volume -DriveLetter C` (no switch = media-aware default), `-ReTrim` SSD only, `-Defrag` HDD only with ≥15% free.
- Cleanup: `cleanmgr /sageset:1` (setup, curated tick-list — never Downloads / Windows.old blindly) + `/sagerun:1`, temp contents only with >7-day age filter and skip-locked, Storage Sense via Settings.
- Network: `ipconfig /flushdns`, `/release` + `/renew` as a pair only (never alone, never over RDP), `netsh winsock reset`, `netsh int ip reset` — both need restart, only if broken, in the order winsock → int ip → release → renew → flushdns → restart.
- Power: `powercfg /list`, `/getactivescheme`, `/setactive <GUID>` (Balanced 381b4222-f694-41f0-9685-ff5bb260df2e, High Performance 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c), Ultimate via `-duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61` then activate the RETURNED GUID (new each run, never the template). Ultimate is desktop/workstation only, not on Modern Standby laptops, not an overclock.
- Windows Update: troubleshooter first, then DISM+SFC, then limited reset only (stop bits/wuauserv/cryptsvc → rename SoftwareDistribution/catroot2 to timestamped .bak → start all services again, even on failure).
- Drivers/apps: `winget upgrade` (list/review) then `winget upgrade --all` (apps, NOT drivers, Full only, reviewed), drivers via Windows Update Optional updates, `pnputil /export-driver` backup before any driver change.
- Startup: `Get-CimInstance Win32_StartupCommand` (read-only) + Task Manager Startup apps by impact (High = >1s CPU or >3MB disk). Show the list, let the user choose; never auto-disable. Keep antivirus / cloud storage enabled.

## Excluded — never include (17 items, from research)

`DISM /ResetBase` and `/SPSuperseded` (irreversible); manual WinSxS / Windows.old / `C:\Windows\Temp` deletion; any registry cleaner or bulk registry edits (incl. restore-point bypass, Storage Sense registry, Defender DisableAntiSpyware); disabling Defender / WinDefend / Tamper Protection or core services; forced SSD defrag; Prefetch deletion; `chkdsk /r` as routine (hours on large HDD — opt-in "run overnight" diagnostic only); netsh resets as routine; `ipconfig /release` alone; Settings Network reset automated; full WU reset (`sc.exe sdset`, bulk regsvr32, `rd /s /q SoftwareDistribution` as first step); `winget --all` unattended / as driver updater, any third-party driver updater; deleting startup entries with `Remove-CimInstance`; `powercfg /hibernate off` as routine; `sfc /scanboot`, `/purgecache`, DISM `/Source` without a verified local source.

## Phases

- **Phase 0 — Scaffold (v0.0):** create ILIV007/win-opt, README (EN), LICENSE, `docs/plans/` with this design, `.gitignore`, Release process (zip of `win-opt.ps1` + `Start-WinOpt.bat`). No optimizer code yet.
- **Phase 1 — Apprentice MVP (v0.1.0):** menu + mode picker, admin check + self-elevate prompt, restore-point step, Apprentice steps only, per-step show command + result, summary screen, log file. Test on real Win11.
- **Phase 2 — Wizard (v0.2.0):** add DISM Check/Scan + gated RestoreHealth + SFC verifyonly/scannow + chkdsk /scan + gated /spotfix + drive health + Defender verification + Windows Update check + problem-device check + perfmon /rel, one restart at end with consent, progress handling for long steps. DONE 2026-11-15.
- **Phase 3 — Archmage (v0.3.0):** add DISM RestoreHealth, chkdsk /f scheduling with consent, WU limited reset (gated), network reset branch (gated, only if broken), winget review + upgrade (gated), driver Optional updates + backup.
- **Phase 4 — Polish + Release (v1.0.0):** colours / ASCII header / progress polish, EN UI copy review, error-code parsing for SFC/DISM, full test matrix (Win10 + Win11, SSD + HDD, laptop + desktop), Release with zip + checksums + changelog.

Each phase ships only when its mode is verified live on a real Windows PC; CI is not proof for this project (no Windows runner in this workspace).

## Nova's calls (marked — Iliya can override)

- Mode names Apprentice / Wizard / Archmage (wizard tiers, fits the project name).
- UI language English (matches IVAI default English and Proxiv3 English; Windows command names are English anyway). Persian UI later only if he asks.
- File layout: `win-opt.ps1` + `Start-WinOpt.bat` at repo root, `docs/plans/` for designs, `CHANGELOG.md` for releases.
- Versioning: v0.1.0 Apprentice, v0.2.0 Wizard, v0.3.0 Archmage, v1.0.0 polish.
- Log file: per-run transcript in `%TEMP%\win-opt\` so a failed step can be shown, not just "error".
- No auto-update / no telemetry in v1.0.

## Terminal style (v0.1.2)

Black / white / red terminal look with square corners, numbered sections, and a clean mono style. The banner art and all code are original win-opt work.

- Block ASCII "WIN-OPT" banner: "WIN-" in the console default colour, "OPT" in red, tagline "WINDOWS OPTIMIZER WIZARD" in red.
- Numbered sections "01 / 08 - Title" with an ASCII progress bar `[####----]` + percent on every step.
- Arrow-key mode menu (Up/Down, Enter, Esc/Q), with a number-input fallback in hosts without console keys (ISE).
- Summary table with fixed-width `[  OK  ]` / `[ FAIL ]` / `[ SKIP ]` tags.
- Palette: default body text (light-theme readable, H4), red accents, green success, yellow warnings. No grey / white / cyan anywhere.

## Prompt rule (v0.1.3)

Just-in-time, minimal, organized (Iliya, 2026-11-15 — runtime questions are annoying).

- No upfront Q&A phase. The wizard asks only when a decision is needed, right before the related command.
- The only questions in Apprentice: the mode picker at the start, the temp cleanup confirm (after the scan shows counts/sizes, right before deleting), the power-plan choice (right before applying, with an extra confirm only for the risky High Performance switch).
- Everything else runs without asking: the internet check runs silently and is only noted in the log; Settings and Task Manager open and the wizard continues without waiting for the user to finish in them.
- One pause at the very end before closing. Step logic, safety rules, and the H1–H4 fixes are unchanged.

## PS2EXE compatibility (v0.1.4)

- No `$Host.Name` checks anywhere: the packaged .exe runs under a different
  host name, so capability is probed by trying (ReadKey) with a fallback,
  never by checking the host name.
- No transcript logging: `Write-Log` appends timestamped lines to a file in
  `%TEMP%\win-opt\`; every `Add-Result` is logged, so the summary and the
  log always agree.
- Terse text (v0.1.4): every user-visible message is as short as possible —
  step headers, one-line explanations, prompts, summary lines. Cut words,
  keep the meaning.
- `Start-WinOpt.bat` sets `title WIN-OPT` and `mode con cols=100 lines=35`
  before launching PowerShell.

## Speed + yellow questions (v0.1.5)

- Fast updates: the arrow-key menu repaints in place (cursor back to the
  first item row, only the item lines rewritten). Clear-Host on every
  keypress was the bottleneck — it is slow in PS 5.1. Fallback: the old
  Clear-Host repaint if cursor positioning fails.
- Temp cleanup scans once: a short "Scanning ..." line per folder, file
  lists cached and reused for deletion (no second recursive scan).
- Questions are Yellow (Iliya's order, overrides H4 for question text
  only): mode-picker prompt + options, temp confirm, power-plan choice +
  options, High Performance confirm. Body text stays default, status stays
  green/yellow/red.

## Pre-open notices (v0.2.0)

- Before any external window opens (Settings, Windows Update, Reliability
  Monitor, Task Manager, and any Wizard/Archmage window after them), the
  wizard prints a `>> ... will open now` notice line in Magenta, so no
  window pops up without warning. Magenta is for these lines only
  (overrides H4 for them only, like Yellow for questions). No extra pause
  — the prompt rule stands.

## What's left to the builder

- Exact colour scheme, ASCII header art, progress-bar implementation, menu navigation keys — settled in v0.1.2 (see Terminal style above).
- How SFC/DISM exit codes and partial output are parsed into pass / repaired / needs-retry / failed.
- How the "restart now / later" consent flow works across the three modes.
- Test matrix details and who runs each Windows test (Iliya's PC).
