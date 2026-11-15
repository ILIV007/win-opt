# Changelog

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
