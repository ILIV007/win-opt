# Changelog

## v0.2.0 — 2026-11-15

Wizard mode (the monthly pass, ~15–25 min, one restart at the end if a
repair happened).

- Everything in Apprentice, plus 8 new steps: drive health
  (`Get-PhysicalDisk` + `Win32_DiskDrive`, read-only — warns and skips disk
  repairs if a drive is not Healthy), DISM health check (CheckHealth, then
  ScanHealth only if flagged, then RestoreHealth only if corruption is
  found), SFC (`/verifyonly`, then `/scannow` only if it finds corruption —
  DISM always first), `chkdsk /scan` (then `/spotfix` only if it logs
  problems), Defender check (real-time protection, definitions, quick scan
  in the last 7 days — runs one if it missed; no full scan), Windows Update
  check (opens Settings), problem-device list (act only on listed devices),
  Reliability Monitor (`perfmon /rel`).
- Repairs run only if a check flags a problem — nothing is repaired "just
  in case". DISM/SFC/chkdsk output shows live while it runs (Tee-Object)
  and is parsed for the result; unreadable output (e.g. non-English
  Windows) falls back to the deeper check instead of guessing.
- Pre-open notices in Magenta (new colour, for these lines only): before
  Settings, Windows Update, Reliability Monitor, or Task Manager opens, the
  wizard prints a `>> ... will open now` line so no window pops up without
  warning. No extra pause.
- Step numbering is automatic now (`Step-Next` counter), so the step count
  stays right in every mode (Apprentice 8, Wizard 16).
- Restart offer at the end of Wizard only if a repair needs it (DISM/SFC
  repaired files, spot-fix needs a restart). Apprentice never asks.
- SmartScreen note in the README: the unsigned .exe may trigger "Windows
  protected your PC" — click "More info", then "Run anyway".
- Step logic, safety rules, the just-in-time prompt rule, and the H1–H4
  fixes are unchanged. No command from the myths/excluded lists.

## v0.1.5 — 2026-11-15

Faster terminal updates, and questions print in yellow.

- Terminal updates: the arrow-key menu no longer repaints the whole screen
  (Clear-Host + full banner) on every keypress — Clear-Host in PS 5.1 is
  slow, and that was the lag. The banner prints once and each keypress only
  rewrites the menu lines in place via cursor positioning, with the old
  Clear-Host repaint as fallback if cursor positioning is unavailable.
- Temp cleanup no longer scans the temp folders twice: the scan prints a
  short "Scanning ..." line per folder and the file lists are reused for
  deletion, so the delete starts at once instead of after a second silent
  scan. (There is no Write-Progress and no Start-Sleep anywhere in the
  script — the menu repaint was the actual bottleneck.)
- Questions print in yellow now (Iliya's order): the mode-picker prompt and
  its options, the temp cleanup confirm, the power-plan choice and its
  options, and the High Performance safety confirm. Body text stays the
  console default colour and status stays green/yellow/red. This overrides
  the light-theme H4 rule for question text only.
- Step logic, safety rules, the just-in-time prompt rule, and the H1–H4
  fixes are unchanged.

## v0.1.4 — 2026-11-15

PS2EXE compatibility: the script now works the same inside a packaged .exe.

- Arrow-key mode menu: the `$Host.Name` gate is gone. The menu tries
  `[Console]::ReadKey` and falls back to number input only if console keys
  really fail — so it works in the PS2EXE exe (host name "PSRunspace-Host")
  exactly like in a normal PowerShell console.
- Logging is manual now: `Start-Transcript`/`Stop-Transcript` are gone (the
  PS2EXE console host does not implement them, so no log file was ever
  written). A small `Write-Log` appends timestamped lines to
  `%TEMP%\win-opt\win-opt-YYYYMMDD-HHmmss.log`; every step result and the
  final summary are logged, and the "Log file:" line points at the real file.
- All user-visible texts shortened — step headers, explanations, prompts,
  summary lines. Same meaning, fewer words.
- `Start-WinOpt.bat` sets the console title (`WIN-OPT`) and a fixed size
  (`mode con cols=100 lines=35`) before launching PowerShell.
- Step logic, safety rules, the just-in-time prompt rule, and the H1–H4
  fixes are unchanged.

## v0.1.3 — 2026-11-15

Prompt redesign: questions are just-in-time now, not upfront.

- The two start questions (is Windows Update failing? is the internet broken?)
  are gone — they were recorded but never acted on. The ping check is now a
  silent background check; if it fails, it is only noted in the log.
- The only questions left in a run: the mode picker at the start, the temp
  cleanup confirm (right before deleting, after showing counts and sizes),
  and the power-plan choice (right before applying, plus a confirm for the
  risky High Performance switch).
- The "press Enter when you are done" pauses in the Storage Sense and startup
  steps are gone — Settings and Task Manager open and the wizard continues;
  review them after the run. The single pause before closing stays.
- Step logic, safety rules, and the H1–H4 fixes are unchanged.

## v0.1.2 — 2026-11-15

Terminal redesign: new black / white / red terminal look.

- Block ASCII "WIN-OPT" banner (original letter art) with a red tagline, plus
  a version/mode line.
- Numbered sections: every step header is "01 / 08 - Title" with an ASCII
  progress bar and percent.
- Arrow-key mode menu (Up/Down + Enter, Esc/Q to quit) with a number-input
  fallback when console keys are unavailable.
- Final summary as a fixed-width table with [  OK  ] / [ FAIL ] / [ SKIP ]
  tags.
- Palette unchanged for light themes: default body text, red accents, green
  success, yellow warnings.

## v0.1.1 — 2026-11-15

Patch for the four high-severity issues found in the v0.1.0 checkup.

- H1: PowerShell 7 guard — the wizard now stops with a clear message when
  run under PowerShell 7 (restore cmdlets exist only in 5.1), and the
  `Get-ComputerRestorePoint` calls are wrapped so a missing cmdlet can no
  longer kill the script without the abort banner.
- H2: System drive is resolved from `$env:SystemDrive` instead of assuming
  C: — restore point, drive optimize, Windows temp path, and messages all
  use the real system drive.
- H3: Power-plan switch is verified — High Performance is offered only when
  `powercfg /list` shows it, and after every `powercfg /setactive` the
  script checks the exit code and re-reads the active scheme before
  reporting success.
- H4: Light-theme readable — body, info, menu and command text now use the
  console default colour; colours remain only for status (green success,
  yellow warning, red error).

## v0.1.0 — 2026-11-15

Apprentice mode, the first usable version.

- Terminal wizard in PowerShell 5.1 + `Start-WinOpt.bat` launcher.
- Two start questions (Windows Update failing? internet broken?) + ping check,
  recorded for later modes.
- Restore point first (abort with a clear screen if none can be created,
  except when today's point already exists).
- `ipconfig /flushdns`, temp cleanup (asks first, >7-day filter, skip locked),
  Storage Sense guidance via Settings, media-aware `Optimize-Volume -DriveLetter C`,
  power-plan choice with original plan recorded, startup list (no disable code).
- Windows 10 and Windows 11 supported. No registry edits, no cleanmgr auto-run.

## Unreleased

- v0.3.0 — Archmage mode (component store, drive wear, diagnostics
  report, driver audit, battery report, gated Full Scan, gated chkdsk /f,
  gated memory test, system-image guidance).
- v1.0.0 — Polish and full Windows 10 + 11 test matrix.
