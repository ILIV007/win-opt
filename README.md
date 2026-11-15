# win-opt — Windows Optimizer Wizard

🌐 Website: https://iliv007.github.io/win-opt/

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
| **Wizard** | ~15–25 min | One at the end | Available in v0.2.0 |
| **Archmage** | ~30–60 min | One at the end | Coming in v0.3.0 |

Times are estimates for a healthy modern SSD PC. The wizard shows a progress
step, never a countdown.

## What Apprentice does

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

## What Wizard adds (v0.2.0)

Everything in Apprentice, plus the monthly pass:

1. Drive health — `Get-PhysicalDisk` + `Get-CimInstance Win32_DiskDrive`
   (read-only). If a drive is not Healthy, it warns to back up first and
   skips disk repairs.
2. DISM health check — `CheckHealth`, then `ScanHealth` only if flagged,
   then `RestoreHealth` only if corruption is found (needs internet).
3. System files — `sfc /verifyonly`, then `sfc /scannow` only if it finds
   corruption (DISM runs first, per Microsoft Support).
4. Disk scan — `chkdsk /scan`, then `/spotfix` only if it logs problems.
5. Defender check — real-time protection On, definitions current, a quick
   scan ran in the last 7 days (runs one if it missed). No full scan here.
6. Windows Update check — opens Windows Update; install offered updates,
   check Optional updates for drivers.
7. Problem devices — lists devices Windows flags as not OK; only a listed
   device gets attention, never bulk driver updates.
8. Reliability Monitor — opens the crash timeline (`perfmon /rel`).

If a repair happened, the wizard offers a restart at the end.

## Safety rules

- Only safe built-in commands. Anything dangerous gets a warning and needs
  your explicit yes.
- No registry edits. No cleanmgr auto-run. No DISM, SFC, or chkdsk in
  Apprentice. Wizard runs DISM/SFC/chkdsk checks and repairs only if a
  check flags a problem. No network reset, no driver or app updates, no
  disabling of Defender or Windows services.
- Nothing is deleted blindly: temp cleanup always asks first and shows
  counts and sizes before deleting.

## SmartScreen warning

The .exe is not code-signed (no certificate), so Windows SmartScreen may
show "Windows protected your PC". Click "More info", then "Run anyway".
The code is open source (see `win-opt.ps1`) and every release lists its
SHA-256 — check the file hash before running.

## Files

- `win-opt.ps1` — the wizard (PowerShell 5.1)
- `Start-WinOpt.bat` — double-click launcher (asks for admin if needed)
- `docs/plans/2026-11-15-win-opt-design.md` — the design

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).
