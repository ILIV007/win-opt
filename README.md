# win-opt — Windows Optimizer Wizard

A simple terminal wizard that raises your Windows health a bit. For people who
never maintain their system: it runs real, safe, built-in Windows commands,
step by step, shows you each command first, and shows you its result.

No install. No third-party tools. No registry edits.

Terminal: black / white / red look — block ASCII banner, numbered sections,
arrow-key mode menu, and a progress bar on every step.

## How to use

1. Download the latest release zip from the
   [Releases page](https://github.com/ILIV007/win-opt/releases) and unzip it.
2. Double-click `Start-WinOpt.bat` (or right-click it and choose
   **Run as administrator**).
3. Pick a mode. The wizard asks only when it needs a decision (temp
   cleanup, power plan) — each step shows its command before it runs.

Requirements: Windows 10 or Windows 11, PowerShell 5.1, administrator rights.

## Modes

| Mode | Time | Restart | Status |
| --- | --- | --- | --- |
| **Apprentice** | ~5–10 min | No | Available in v0.1.0 |
| **Wizard** | ~15–25 min | One at the end | Coming in v0.2.0 |
| **Archmage** | ~30–60 min | One at the end | Coming in v0.3.0 |

Times are estimates for a healthy modern SSD PC. The wizard shows a progress
step, never a countdown.

## What Apprentice (v0.1.3) does

1. Checks the internet quietly in the background (no questions) and notes
   the result in the log. Nothing is changed here.
2. Creates a restore point first. If none can be created, it stops — no
   repair or cleanup runs without a safety net. Exception: if a restore point
   from today already exists (only one per day is allowed), it uses that one.
   A restore point is **not** a backup: your personal files are not protected
   by it.
3. Flushes the DNS cache (`ipconfig /flushdns`).
4. Cleans old temp files — **only after asking you first** and showing what
   will be deleted. Only files older than 7 days, only the contents of the
   temp folders (never the folders themselves), locked files are skipped.
5. Opens Settings so you can turn on Storage Sense and run it yourself.
6. Optimizes the system drive (`Optimize-Volume`, media-aware: TRIM
   on SSDs, defrag on hard drives).
7. Shows your power plans, records your current one, and offers Balanced or
   High Performance — your choice, with a laptop battery warning.
8. Lists your startup apps and opens Task Manager so you can review them
   yourself. win-opt never turns anything off in v0.1.0.

Every run writes a log to `%TEMP%\win-opt\`.

## Safety rules

- Only safe built-in commands. Anything dangerous gets a warning and needs
  your explicit yes.
- No registry edits. No cleanmgr auto-run. No DISM, SFC, or chkdsk in
  Apprentice. No network reset, no driver or app updates, no disabling of
  Defender or Windows services.
- Nothing is deleted blindly: temp cleanup always asks first and shows
  counts and sizes before deleting.

## Files

- `win-opt.ps1` — the wizard (PowerShell 5.1)
- `Start-WinOpt.bat` — double-click launcher (asks for admin if needed)
- `docs/plans/2026-11-15-win-opt-design.md` — the design

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
