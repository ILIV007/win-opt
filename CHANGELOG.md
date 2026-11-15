# Changelog

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

- v0.2.0 — Wizard mode (DISM Check/Scan, SFC, chkdsk /scan).
- v0.3.0 — Archmage mode (DISM RestoreHealth, chkdsk /f, gated network and
  Windows Update branches, reviewed winget upgrade).
- v1.0.0 — Polish and full Windows 10 + 11 test matrix.
