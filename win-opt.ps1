# win-opt.ps1 - Windows Optimizer Wizard, v0.2.0 (Apprentice + Wizard)
# Windows 10 and Windows 11. PowerShell 5.1 only. Run as administrator.
# What it does: Apprentice (light tune-up) + Wizard (monthly pass: drive
# health, DISM health check, SFC, chkdsk scan, Defender check, Windows
# Update check, problem devices, Reliability Monitor). Repairs run only
# if a check flags a problem - nothing is repaired "just in case".
# What it never does: no registry edits, no cleanmgr auto-run, no network
# reset, no driver/app updates, no disabling of anything. Repairs run
# only if a check flags a problem - never "just in case".
# Archmage mode is NOT implemented in v0.2.0 (coming in v0.3.0).

$Script:Version = "0.2.0"
$Script:Results = @()
$Script:LogFile = $null
$Script:StepNo = 0
$Script:TotalSteps = 8
$Script:ModeName = "Apprentice"
$Script:ModeLabel = "Pick a mode"
$Script:RestartNeeded = $false
$Script:DriveBad = $false
$Script:ChkdskFlagged = $false

function Write-Log {
    # Manual file logging: Start-Transcript is not implemented in the
    # PS2EXE console host, so the log is written line by line instead.
    # Never breaks the run: every write is wrapped in try/catch.
    param([string]$Message)
    if (-not $Script:LogFile) { return }
    try {
        $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $Script:LogFile -Value "[$stamp] $Message" -ErrorAction Stop
    } catch { }
}

# --- System drive (H2): resolved once, never assumed to be C: ---
$sysDrive = $env:SystemDrive
if (-not $sysDrive) { $sysDrive = "C:" }
$sysDriveLetter = $sysDrive.TrimEnd(':')
$sysDrivePath = $sysDrive + "\"
$chkDrive = $sysDriveLetter + ":"
$winTemp = Join-Path $env:SystemRoot "Temp"

function Write-Banner {
    # Original block-letter "WIN-OPT" banner (own letter art, pure ASCII).
    # "WIN-" prints in the console default colour, "OPT" in red; the tagline
    # is red too. No white/grey/cyan anywhere, so it stays readable on a
    # light terminal (H4).
    $banner = @(
        "#   # ##### #   #        ###  ####  #####",
        "#   #   #   ##  #       #   # #   #   #  ",
        "# # #   #   # # # ##### #   # ####    #  ",
        "# # #   #   #  ##       #   # #       #  ",
        " # #  ##### #   #        ###  #       #  "
    )
    foreach ($line in $banner) {
        Write-Host $line.Substring(0, 24) -NoNewline
        Write-Host $line.Substring(24) -ForegroundColor Red
    }
    Write-Host "WINDOWS OPTIMIZER WIZARD" -ForegroundColor Red
    Write-Host "  win-opt v$Script:Version  |  $Script:ModeLabel"
    Write-Host ""
}

function Write-Header {
    Clear-Host
    Write-Banner
}

function Write-ProgressBar {
    param([int]$Done, [int]$Total)
    $width = 20
    $filled = 0
    $percent = 0
    if ($Total -gt 0) {
        $filled = [math]::Floor($Done / $Total * $width)
        $percent = [math]::Floor($Done / $Total * 100)
    }
    if ($filled -gt $width) { $filled = $width }
    $bar = "[" + ("#" * $filled) + ("-" * ($width - $filled)) + "] " + $percent + "%"
    Write-Host $bar
}

function Write-Step {
    param([int]$Number, [int]$Total, [string]$Title, [string]$Info)
    $num = "{0:D2}" -f $Number
    $tot = "{0:D2}" -f $Total
    Write-Host ""
    Write-Log "Step $Number/$Total - $Title"
    Write-Host $num -ForegroundColor Red -NoNewline
    Write-Host " / $tot - $Title"
    Write-ProgressBar -Done ($Number - 1) -Total $Total
    if ($Info) { Write-Host $Info }
}

function Step-Next {
    # Next step in the run: numbers itself, so the step count stays right
    # in every mode (Apprentice 8, Wizard 16, Archmage 25).
    param([string]$Title, [string]$Info)
    $Script:StepNo++
    Write-Step -Number $Script:StepNo -Total $Script:TotalSteps -Title $Title -Info $Info
}

function Show-Command {
    param([string]$Command)
    Write-Host "  Command: $Command"
}

function Write-Notice {
    # Pre-open notice (v0.2.0): printed in Magenta right before an external
    # window opens (Settings, Task Manager, Reliability Monitor...), so it
    # never pops up without warning. Magenta is for these lines only.
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Magenta
}

function Read-NumberMode {
    # Number-input mode picker, used when the host has no console keys
    # (ISE, redirected input). Returns 1 for Apprentice, 2 for Wizard,
    # or $null to quit. Archmage is not in v0.2.0 yet.
    # Question text is Yellow (v0.1.5): the whole prompt, options included.
    Write-Host "Modes:" -ForegroundColor Yellow
    Write-Host "  [1] Apprentice  - light tune-up, ~5-10 min" -ForegroundColor Yellow
    Write-Host "  [2] Wizard      - monthly pass, ~15-25 min, one restart" -ForegroundColor Yellow
    Write-Host "  [3] Archmage    - coming in v0.3.0" -ForegroundColor Yellow
    Write-Host "  [Q] Quit" -ForegroundColor Yellow
    while ($true) {
        Write-Host "Pick a mode: " -ForegroundColor Yellow -NoNewline
        $choice = Read-Host
        if ($choice -eq "Q" -or $choice -eq "q") { return $null }
        if ($choice -eq "1") { return 1 }
        if ($choice -eq "2") { return 2 }
        if ($choice -eq "3") {
            Write-Host "Archmage is coming in v0.3.0." -ForegroundColor Yellow
            Write-Host "Press Enter to run Wizard, or close this window." -ForegroundColor Yellow
            Read-Host | Out-Null
            return 2
        }
        Write-Host "Pick 1, 2 or 3." -ForegroundColor Yellow
    }
}

function Read-ModeMenu {
    # Arrow-key mode menu (Up/Down to move, Enter to confirm, Esc or Q to
    # quit). Apprentice and Wizard are selectable in this version; Archmage
    # is shown as coming soon and is skipped by the arrow keys.
    # Falls back to number input when console keys are unavailable.
    # No $Host.Name check here on purpose: the PS2EXE host reports
    # "PSRunspace-Host", not "ConsoleHost", so a host-name gate would kill
    # the arrow keys in the .exe. ReadKey is tried instead, and any failure
    # falls back to number input.
    # The menu repaints in place (v0.1.5): the banner prints once, then each
    # keypress only rewrites the item lines via cursor positioning. The old
    # code ran Clear-Host + full banner on every keypress, and Clear-Host in
    # PS 5.1 is slow - that was the sluggish menu. If cursor positioning is
    # unavailable, it falls back to the old Clear-Host repaint per keypress.
    # Returns 1 for Apprentice, 2 for Wizard, or $null to quit.
    try { $null = [Console]::KeyAvailable } catch { return Read-NumberMode }
    $items = @("Apprentice", "Wizard", "Archmage")
    $enabled = @($true, $true, $false)
    $details = @("light tune-up, ~5-10 min", "monthly pass, ~15-25 min, one restart", "coming in v0.3.0")
    $selected = 0
    try {
        Clear-Host
        Write-Banner
        Write-Host "Modes:  (Up/Down, Enter, Q to quit)" -ForegroundColor Yellow
        $menuTop = -1
        $padWidth = 80
        try { $menuTop = [Console]::CursorTop } catch { $menuTop = -1 }
        try { $w = [Console]::WindowWidth; if ($w -gt 10) { $padWidth = $w - 1 } } catch { }
        while ($true) {
            if ($menuTop -ge 0) {
                try { [Console]::SetCursorPosition(0, $menuTop) } catch { $menuTop = -1 }
            }
            if ($menuTop -lt 0) {
                Clear-Host
                Write-Banner
                Write-Host "Modes:  (Up/Down, Enter, Q to quit)" -ForegroundColor Yellow
            }
            for ($i = 0; $i -lt $items.Count; $i++) {
                $marker = "   "
                if ($i -eq $selected) { $marker = " > " }
                $line = "$marker[$($i + 1)] $($items[$i])  - $($details[$i])"
                $line = $line.PadRight($padWidth)
                if ($i -eq $selected) { Write-Host $line -ForegroundColor Green }
                else { Write-Host $line }
            }
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::DownArrow) {
                $next = $selected
                do { $next = ($next + 1) % $items.Count } while ((-not $enabled[$next]) -and ($next -ne $selected))
                $selected = $next
            } elseif ($key.Key -eq [ConsoleKey]::UpArrow) {
                $next = $selected
                do { $next = ($next - 1 + $items.Count) % $items.Count } while ((-not $enabled[$next]) -and ($next -ne $selected))
                $selected = $next
            } elseif ($key.Key -eq [ConsoleKey]::Enter) {
                return ($selected + 1)
            } elseif ($key.Key -eq [ConsoleKey]::Escape) {
                return $null
            } elseif (($key.KeyChar -eq 'q') -or ($key.KeyChar -eq 'Q')) {
                return $null
            }
        }
    } catch {
        return Read-NumberMode
    }
    return 1
}

function Add-Result {
    param([string]$Step, [string]$Status)
    $Script:Results += [PSCustomObject]@{ Step = $Step; Status = $Status }
    Write-Log "[$Step] $Status"
}

function Read-YesNo {
    # Question text is Yellow (v0.1.5). Read-Host takes no colour, so the
    # question is printed first and Read-Host reads with no prompt of its own.
    param([string]$Question)
    while ($true) {
        Write-Host "$Question (Y/N): " -ForegroundColor Yellow -NoNewline
        $answer = Read-Host
        if ($answer -match '^[Yy]') { return $true }
        if ($answer -match '^[Nn]') { return $false }
        Write-Host "Please type Y or N." -ForegroundColor Yellow
    }
}

# --- Admin check: relaunch as administrator if needed ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Needs administrator rights. Relaunching as administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- PowerShell version guard (H1): the restore cmdlets exist only in 5.1 ---
# Placed after the admin relaunch, so a non-admin PowerShell 7 user is still
# relaunched into powershell.exe (5.1) first.
if ($PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host "Needs Windows PowerShell 5.1. Run Start-WinOpt.bat instead - it uses powershell.exe (5.1), not PowerShell 7." -ForegroundColor Yellow
    exit 1
}

# --- Per-run log in %TEMP%\win-opt\ (manual file logging, see Write-Log) ---
$logDir = Join-Path $env:TEMP "win-opt"
$logFile = $null
try {
    New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
    $Script:LogFile = Join-Path $logDir ("win-opt-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
    Set-Content -Path $Script:LogFile -Value "win-opt v$Script:Version - started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ErrorAction Stop
    $logFile = $Script:LogFile
    Write-Log "Log started."
} catch {
    $Script:LogFile = $null
    $logFile = $null
}

Write-Header

# --- Windows version (10 and 11 both supported) ---
$os = Get-CimInstance Win32_OperatingSystem
$build = [System.Environment]::OSVersion.Version.Build
if ($build -ge 22000) { $winLabel = "Windows 11" } else { $winLabel = "Windows 10" }
Write-Host "Windows: $($os.Caption)  ($winLabel, build $build)"
if ($winLabel -eq "Windows 10") {
    Write-Host "Note: Windows 10 support ended 14 Oct 2025. Later versions cannot"
    Write-Host "restore routine Windows 10 updates; win-opt runs the same on 10 and 11."
}
if ($logFile) { Write-Host "Log file: $logFile" }
Write-Host ""
Write-Host "Light tune-up for PCs that never get maintained."
Write-Host "Only safe built-in commands, each shown before it runs."
Write-Host ""

# --- Mode picker ---
$mode = Read-ModeMenu
if ($null -eq $mode) {
    Write-Host "Bye."
    Write-Log "Quit at the mode picker."
    exit
}
if ($mode -eq 2) {
    $Script:ModeName = "Wizard"
    $Script:ModeLabel = "Wizard  |  ~15-25 min  |  One restart at the end"
    $Script:TotalSteps = 16
} else {
    $Script:ModeName = "Apprentice"
    $Script:ModeLabel = "Apprentice  |  ~5-10 min  |  No restart"
    $Script:TotalSteps = 8
}

Write-Header

# --- Step: internet check (silent - no questions here) ---
Step-Next -Title "Internet check" -Info "Silent - no questions. A failed ping is only logged; no reset, no internet needed."
Show-Command "Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet"
try {
    $pingOk = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction Stop
} catch {
    $pingOk = $false
}
if ($pingOk) {
    Write-Host "  Internet reachable (ping 8.8.8.8 worked)." -ForegroundColor Green
    Add-Result "Internet check" "Done (reachable)"
} else {
    Write-Host "  Ping to 8.8.8.8 failed - logged only." -ForegroundColor Yellow
    Add-Result "Internet check" "Done (unreachable, noted only)"
}

# --- Step: restore point (safety net - abort if it cannot be made) ---
Step-Next -Title "Restore point" -Info "A snapshot so changes can be undone. NOT a backup - your files are not protected."
Show-Command "Enable-ComputerRestore -Drive `"$sysDrivePath`""
try {
    Enable-ComputerRestore -Drive $sysDrivePath -ErrorAction Stop
    Write-Host "  System Protection is on for $sysDrive." -ForegroundColor Green
} catch {
    Write-Host "  Could not confirm System Protection: $($_.Exception.Message)" -ForegroundColor Yellow
}
$desc = "win-opt before $Script:ModeName " + (Get-Date -Format "yyyy-MM-dd HH:mm")
Show-Command "Checkpoint-Computer -Description ""$desc"" -RestorePointType MODIFY_SETTINGS"
$restoreOk = $false
try {
    Checkpoint-Computer -Description $desc -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $restoreOk = $true
    Write-Host "  Restore point created." -ForegroundColor Green
} catch {
    Write-Host "  Could not create a restore point: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Checking for a restore point from today (one per day max)..."
    Show-Command "Get-ComputerRestorePoint"
    $todayPoint = $null
    try {
        $todayPoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime.Date -eq (Get-Date).Date } | Select-Object -First 1
    } catch {
        $todayPoint = $null
    }
    if ($todayPoint) {
        Write-Host "  Today's restore point already exists ($($todayPoint.Description)) - continuing with it." -ForegroundColor Green
        $restoreOk = $true
    }
}
if (-not $restoreOk) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "  STOPPED: no restore point." -ForegroundColor Red
    Write-Host "  No repair or cleanup without a safety net." -ForegroundColor Red
    Write-Host "  Turn on System Protection for $sysDrive in System Properties," -ForegroundColor Red
    Write-Host "  then run win-opt again." -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Add-Result "Restore point" "FAILED - aborted"
    Write-Host "Press Enter to close."
    Read-Host | Out-Null
    exit 1
}
$points = @()
try { $points = Get-ComputerRestorePoint -ErrorAction SilentlyContinue } catch { $points = @() }
Write-Host "  Restore points on this PC: $(@($points).Count)"
Add-Result "Restore point" "Done"

# ================= WIZARD (monthly pass) =================
if ($mode -ge 2) {

    # --- Step: drive health (read-only) ---
    Step-Next -Title "Drive health" -Info "Read-only: disk status + SMART summary. If a drive is not Healthy, back up first."
    Show-Command "Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus"
    try {
        $disks = @(Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus)
        if ($disks.Count -gt 0) { $disks | Format-Table -AutoSize | Out-String | Write-Host }
        else { Write-Host "  No physical disks found." }
        $badHealth = @($disks | Where-Object { $_.HealthStatus -eq "Warning" -or $_.HealthStatus -eq "Unhealthy" })
    } catch {
        Write-Host "  Could not read disk health: $($_.Exception.Message)" -ForegroundColor Yellow
        $badHealth = @()
    }
    Show-Command "Get-CimInstance Win32_DiskDrive | Select-Object Model, Status"
    try {
        $drives = @(Get-CimInstance Win32_DiskDrive -ErrorAction Stop | Select-Object Model, Status)
        if ($drives.Count -gt 0) { $drives | Format-Table -AutoSize | Out-String | Write-Host }
        $predFail = @($drives | Where-Object { $_.Status -eq "Pred Fail" })
    } catch {
        Write-Host "  Could not read drive status: $($_.Exception.Message)" -ForegroundColor Yellow
        $predFail = @()
    }
    if (($badHealth.Count -gt 0) -or ($predFail.Count -gt 0)) {
        $Script:DriveBad = $true
        Write-Host "  WARNING: a drive is not Healthy - back up your files BEFORE any repair." -ForegroundColor Yellow
        Write-Host "  Disk repairs are skipped in this run." -ForegroundColor Yellow
        Add-Result "Drive health" "Done (WARNING: drive not Healthy - back up first)"
    } else {
        Write-Host "  All drives look Healthy." -ForegroundColor Green
        Add-Result "Drive health" "Done (Healthy)"
    }

    # --- Step: DISM health check (ladder: CheckHealth -> ScanHealth -> RestoreHealth) ---
    Step-Next -Title "DISM health check" -Info "Read-only first: CheckHealth (seconds), ScanHealth only if flagged. Repair runs only if a check finds corruption."
    Show-Command "DISM /Online /Cleanup-Image /CheckHealth"
    dism.exe /Online /Cleanup-Image /CheckHealth 2>&1 | Tee-Object -Variable dismCheck
    $dismTxt = ($dismCheck -join "`n")
    $dismFlagged = $false
    if ($dismTxt -match "No component store corruption detected") {
        Write-Host "  Component store looks clean." -ForegroundColor Green
    } elseif ($dismTxt -match "repairable") {
        $dismFlagged = $true
        Write-Host "  CheckHealth flagged the component store - running the deep scan."
    } else {
        # Unreadable output (e.g. non-English Windows) - scan deeper to decide.
        $dismFlagged = $true
        Write-Host "  Could not read the CheckHealth result - running the deep scan."
    }
    $dismRepaired = $false
    $dismFailed = $false
    if ($dismFlagged) {
        Show-Command "DISM /Online /Cleanup-Image /ScanHealth"
        Write-Host "  This takes several minutes - do not close the window."
        dism.exe /Online /Cleanup-Image /ScanHealth 2>&1 | Tee-Object -Variable dismScan
        $scanTxt = ($dismScan -join "`n")
        if ($scanTxt -match "No component store corruption detected") {
            $dismFlagged = $false
            Write-Host "  Deep scan is clean - no repair needed." -ForegroundColor Green
        } elseif ($scanTxt -match "repairable") {
            if (-not $pingOk) {
                Write-Host "  Corruption found, but RestoreHealth needs internet - skipped (no internet)." -ForegroundColor Yellow
                $dismFailed = $true
            } else {
                Show-Command "DISM /Online /Cleanup-Image /RestoreHealth"
                Write-Host "  Repairing - this takes 10-30 min. Do not close the window."
                dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | Tee-Object -Variable dismFix
                $fixTxt = ($dismFix -join "`n")
                if (($LASTEXITCODE -eq 0) -and ($fixTxt -match "completed successfully")) {
                    $dismRepaired = $true
                    Write-Host "  Component store repaired." -ForegroundColor Green
                } else {
                    $dismFailed = $true
                    Write-Host "  RestoreHealth failed - SFC may still help. See the log." -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  Could not read the ScanHealth result - no repair run." -ForegroundColor Yellow
            $dismFlagged = $false
        }
    }
    if ($dismFailed) {
        Add-Result "DISM health check" "Failed (repair did not finish)"
    } elseif ($dismRepaired) {
        $Script:RestartNeeded = $true
        Add-Result "DISM health check" "Done (repaired - restart needed)"
    } else {
        Add-Result "DISM health check" "Done (clean)"
    }

    # --- Step: system files (SFC ladder: verifyonly -> scannow only if indicated) ---
    Step-Next -Title "System files (SFC)" -Info "Read-only verify first. Repairs only if it finds corruption (DISM already ran first)."
    Show-Command "sfc /verifyonly"
    sfc /verifyonly 2>&1 | Tee-Object -Variable sfcVerify
    $sfcTxt = ($sfcVerify -join "`n")
    if ($sfcTxt -match "did not find any integrity violations") {
        Write-Host "  System files look clean." -ForegroundColor Green
        Add-Result "System files (SFC)" "Done (clean)"
    } elseif ($sfcTxt -match "found integrity violations") {
        Show-Command "sfc /scannow"
        Write-Host "  Repairing - this takes 10-30 min. Do not close the window."
        sfc /scannow 2>&1 | Tee-Object -Variable sfcFix
        $sfcFixTxt = ($sfcFix -join "`n")
        if ($sfcFixTxt -match "successfully repaired them") {
            $Script:RestartNeeded = $true
            Write-Host "  Corrupt files repaired - a restart finishes the job." -ForegroundColor Green
            Add-Result "System files (SFC)" "Done (repaired - restart needed)"
        } elseif ($sfcFixTxt -match "did not find any integrity violations") {
            Write-Host "  System files look clean." -ForegroundColor Green
            Add-Result "System files (SFC)" "Done (clean)"
        } elseif ($sfcFixTxt -match "unable to fix some of them") {
            Write-Host "  SFC could not fix some files - see %windir%\Logs\CBS\CBS.log" -ForegroundColor Yellow
            Write-Host "  Run Archmage (v0.3.0) for the deeper pass." -ForegroundColor Yellow
            Add-Result "System files (SFC)" "Failed (some files unfixable)"
        } else {
            Write-Host "  Could not read the SFC result - check %windir%\Logs\CBS\CBS.log" -ForegroundColor Yellow
            Add-Result "System files (SFC)" "Done (result unclear - check CBS.log)"
        }
    } else {
        Write-Host "  Could not read the verify result - check %windir%\Logs\CBS\CBS.log" -ForegroundColor Yellow
        Add-Result "System files (SFC)" "Done (result unclear - check CBS.log)"
    }

    # --- Step: disk scan (chkdsk /scan -> /spotfix only if flagged) ---
    Step-Next -Title "Disk scan (chkdsk)" -Info "Online scan, read-only. Fixes only the problems it logs."
    Show-Command "chkdsk $chkDrive /scan"
    chkdsk $chkDrive /scan 2>&1 | Tee-Object -Variable chkScan
    $chkTxt = ($chkScan -join "`n")
    if ($chkTxt -match "found no problems") {
        Write-Host "  File system looks clean." -ForegroundColor Green
        Add-Result "Disk scan (chkdsk)" "Done (clean)"
    } else {
        $Script:ChkdskFlagged = $true
        if ($Script:DriveBad) {
            Write-Host "  Scan flagged errors, but the drive is not Healthy - back up first, no spot-fix." -ForegroundColor Yellow
            Add-Result "Disk scan (chkdsk)" "Done (errors flagged - skipped, drive not Healthy)"
        } else {
            Show-Command "chkdsk $chkDrive /spotfix"
            chkdsk $chkDrive /spotfix 2>&1 | Tee-Object -Variable chkFix
            $chkFixTxt = ($chkFix -join "`n")
            if ($chkFixTxt -match "restart|scheduled") {
                $Script:RestartNeeded = $true
                Write-Host "  Spot-fix needs a restart - it runs before Windows loads." -ForegroundColor Yellow
                Add-Result "Disk scan (chkdsk)" "Done (fixed - restart needed)"
            } elseif ($chkFixTxt -match "found no problems") {
                Write-Host "  File system looks clean." -ForegroundColor Green
                Add-Result "Disk scan (chkdsk)" "Done (clean)"
            } else {
                Write-Host "  Spot-fix done - see the output above." -ForegroundColor Green
                Add-Result "Disk scan (chkdsk)" "Done (spot-fix ran)"
            }
        }
    }

    # --- Step: Defender check (verify, do NOT force a full scan) ---
    Step-Next -Title "Defender check" -Info "Verifies real-time protection, definitions, and a recent quick scan. No full scan here."
    Show-Command "Get-MpComputerStatus"
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $rtp = $mp.RealTimeProtectionEnabled
        $sigDate = $mp.AntivirusSignatureLastUpdated
        $qsAge = $mp.QuickScanAge
        $qsDays = $null
        if ($qsAge -is [TimeSpan]) { $qsDays = $qsAge.Days }
        elseif ($qsAge -is [int]) { $qsDays = $qsAge }
        Write-Host "  Real-time protection: $(if ($rtp) { 'On' } else { 'Off' })"
        if ($sigDate) { Write-Host "  Definitions last updated: $sigDate" }
        if ($qsDays -ne $null) { Write-Host "  Last quick scan: $qsDays day(s) ago" }
        if (-not $rtp) {
            Write-Host "  WARNING: real-time protection is Off - turn it on in Windows Security." -ForegroundColor Yellow
            Add-Result "Defender check" "Done (WARNING: real-time protection Off)"
        } elseif ($sigDate -and ($sigDate -lt (Get-Date).AddDays(-7))) {
            Write-Host "  WARNING: definitions are older than 7 days - update them in Windows Security." -ForegroundColor Yellow
            Add-Result "Defender check" "Done (WARNING: definitions stale)"
        } elseif (($qsDays -ne $null) -and ($qsDays -gt 7)) {
            Write-Host "  No quick scan in the last 7 days - running one now (5-15 min)."
            Show-Command "Start-MpScan -ScanType QuickScan"
            try {
                Start-MpScan -ScanType QuickScan -ErrorAction Stop
                Write-Host "  Quick scan finished." -ForegroundColor Green
                Add-Result "Defender check" "Done (quick scan ran)"
            } catch {
                Write-Host "  Quick scan failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Add-Result "Defender check" "Failed (quick scan failed)"
            }
        } else {
            Write-Host "  Protection On, definitions current, quick scan recent." -ForegroundColor Green
            Add-Result "Defender check" "Done (healthy)"
        }
    } catch {
        Write-Host "  Could not read Defender status - another antivirus may be in charge." -ForegroundColor Yellow
        Add-Result "Defender check" "Skipped - Defender not readable"
    }

    # --- Step: Windows Update check (opens Settings, no install from the script) ---
    Step-Next -Title "Windows Update check" -Info "Opens Windows Update - install offered updates, check Optional updates for drivers."
    Write-Notice "Windows Update will open now - check it after the wizard finishes."
    Show-Command "Start-Process ms-settings:windowsupdate"
    try { Start-Process ms-settings:windowsupdate -ErrorAction Stop } catch { Write-Host "  Could not open Windows Update - open it by hand: Settings > Windows Update." -ForegroundColor Yellow }
    if ($winLabel -eq "Windows 10") {
        Write-Host "  Windows 10 support ended - updates may no longer arrive. Consider Windows 11."
    }
    Add-Result "Windows Update check" "Done"

    # --- Step: problem devices (list only, act only on listed devices) ---
    Step-Next -Title "Problem devices" -Info "Lists devices Windows flags as not OK. Only a listed device gets attention - never bulk driver updates."
    Show-Command "Get-PnpDevice | Where-Object { Status -ne 'OK' } | Select-Object FriendlyName, Class, Status"
    try {
        $badDevs = @(Get-PnpDevice -ErrorAction Stop | Where-Object { $_.Status -ne "OK" } | Select-Object FriendlyName, Class, Status)
        if ($badDevs.Count -eq 0) {
            Write-Host "  No problem devices." -ForegroundColor Green
            Add-Result "Problem devices" "Done (none)"
        } else {
            $badDevs | Format-Table -AutoSize | Out-String | Write-Host
            Write-Host "  Update that device via Windows Update > Optional updates."
            Add-Result "Problem devices" "Done ($($badDevs.Count) problem device(s) - see above)"
        }
    } catch {
        Write-Host "  Could not list devices: $($_.Exception.Message)" -ForegroundColor Yellow
        Add-Result "Problem devices" "Failed"
    }

    # --- Step: Reliability Monitor (opens the crash timeline) ---
    Step-Next -Title "Reliability Monitor" -Info "Opens the crash timeline. Red events = what broke, and when."
    Write-Notice "Reliability Monitor will open now - look for red critical events."
    Show-Command "Start-Process perfmon.exe /rel"
    try { Start-Process perfmon.exe -ArgumentList "/rel" -ErrorAction Stop } catch { Write-Host "  Could not open Reliability Monitor - run perfmon /rel by hand." -ForegroundColor Yellow }
    Write-Host "  If you see red events, note the date, then check Event Viewer at that time."
    Add-Result "Reliability Monitor" "Done"
}

# --- Step: flush DNS ---
Step-Next -Title "Flush the DNS cache" -Info "Clears remembered website addresses. Fast and harmless."
Show-Command "ipconfig /flushdns"
try {
    $dnsOut = ipconfig /flushdns 2>&1 | Out-String
    Write-Host $dnsOut
    Write-Host "  DNS cache flushed." -ForegroundColor Green
    Add-Result "Flush DNS" "Done"
} catch {
    Write-Host "  Flush failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Add-Result "Flush DNS" "Failed"
}

# --- Step: temp cleanup - ALWAYS asks first ---
Step-Next -Title "Clean old temp files" -Info "Only files older than 7 days, only folder contents (never the folders), locked files skipped. Frees space - no speed-up on a healthy PC."
$cutoff = (Get-Date).AddDays(-7)
$tempPaths = @($env:TEMP, $winTemp)
$tempSummary = @()
$tempFiles = @{}
foreach ($tp in $tempPaths) {
    Show-Command "Get-ChildItem $tp -Recurse -Force | Where-Object { LastWriteTime -lt (7 days ago) }"
    Write-Host "  Scanning $tp ..."
    $oldFiles = @(Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff })
    $tempFiles[$tp] = $oldFiles
    $count = $oldFiles.Count
    $bytes = 0
    foreach ($f in $oldFiles) { $bytes += $f.Length }
    $mb = [math]::Round($bytes / 1MB, 1)
    Write-Host "  $tp : $count files older than 7 days, ~$mb MB"
    $tempSummary += [PSCustomObject]@{ Path = $tp; Count = $count; MB = $mb }
}
$totalTempCount = ($tempSummary | Measure-Object -Property Count -Sum).Sum
if ($totalTempCount -eq 0) {
    Write-Host "  Nothing older than 7 days - skipping." -ForegroundColor Green
    Add-Result "Temp cleanup" "Skipped - nothing old"
} elseif (Read-YesNo "Delete these $totalTempCount old temp files?") {
    # Reuses the file lists from the scan above (v0.1.5) - no second full
    # recursive scan, so the delete starts at once. Missing files (deleted
    # between scan and confirm) just fail inside try/catch and are skipped.
    $deleted = 0
    foreach ($tp in $tempPaths) {
        foreach ($f in $tempFiles[$tp]) {
            try { Remove-Item -Path $f.FullName -Force -ErrorAction Stop; $deleted++ } catch { }
        }
    }
    Write-Host "  Deleted $deleted of $totalTempCount files (locked ones skipped)." -ForegroundColor Green
    Add-Result "Temp cleanup" "Done ($deleted files)"
} else {
    Write-Host "  Skipped - nothing deleted."
    Add-Result "Temp cleanup" "Skipped - user said no"
}

# --- Step: Storage Sense guidance (opens Settings, no registry edits) ---
Step-Next -Title "Storage Sense" -Info "Windows' own automatic cleaner. win-opt changes nothing - it opens Settings so you can turn it on yourself."
Write-Notice "Settings will open now - check it after the wizard finishes."
Show-Command "Start-Process ms-settings:storage"
Write-Host "  Opening Settings > System > Storage..."
Write-Host "  Turn on Storage Sense, then 'Configure Storage Sense or run it now'."
Write-Host "  Do NOT turn on automatic Downloads cleanup - it deletes old downloads by itself."
try { Start-Process ms-settings:storage -ErrorAction Stop } catch { Write-Host "  Could not open Settings - open it by hand: Settings > System > Storage." -ForegroundColor Yellow }
Write-Host "  Settings is open - look at it after the wizard finishes."
Add-Result "Storage Sense guidance" "Done"

# --- Step: optimize the system drive (media-aware) ---
Step-Next -Title "Optimize drive $sysDrive" -Info "Media-aware: TRIM on SSDs (fast), defrag on hard drives (slower). Nothing forced onto the wrong type."
Show-Command "Optimize-Volume -DriveLetter $sysDriveLetter"
try {
    Optimize-Volume -DriveLetter $sysDriveLetter -ErrorAction Stop | Out-String | Write-Host
    Write-Host "  Drive $sysDrive optimized." -ForegroundColor Green
    Add-Result "Optimize drive $sysDrive" "Done"
} catch {
    Write-Host "  Optimize failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Add-Result "Optimize drive $sysDrive" "Failed"
}

# --- Step: power plan (record original, user chooses) ---
Step-Next -Title "Power plan" -Info "Faster = more power, heat, fan noise; shorter laptop battery. Your current plan is recorded so you can go back."
$balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
$highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
Show-Command "powercfg /list"
$planList = powercfg /list | Out-String
Write-Host $planList
$hasHighPerf = $planList -match $highPerfGuid
Show-Command "powercfg /getactivescheme"
$activeScheme = powercfg /getactivescheme
Write-Host "  Current plan: $activeScheme"
Write-Host "  Recorded - you can switch back any time."
Write-Host ""
# Question text is Yellow (v0.1.5): the option lines and the prompt itself.
Write-Host "  [1] Keep my current plan" -ForegroundColor Yellow
Write-Host "  [2] Balanced (best for most PCs)" -ForegroundColor Yellow
if ($hasHighPerf) {
    Write-Host "  [3] High Performance (desktop - more power, heat, noise)" -ForegroundColor Yellow
} else {
    Write-Host "  [3] High Performance - not available on this PC" -ForegroundColor Yellow
}
Write-Host "Pick a power plan (1/2/3): " -ForegroundColor Yellow -NoNewline
$planChoice = Read-Host
if ($planChoice -eq "2") {
    Show-Command "powercfg /setactive $balancedGuid"
    powercfg /setactive $balancedGuid
    $setOk = ($LASTEXITCODE -eq 0)
    $activeAfter = powercfg /getactivescheme
    if ($setOk -and ($activeAfter -match $balancedGuid)) {
        Write-Host "  Switched to Balanced." -ForegroundColor Green
        Add-Result "Power plan" "Done (Balanced)"
    } else {
        Write-Host "  Could not switch to Balanced - plan unchanged." -ForegroundColor Yellow
        Add-Result "Power plan" "Failed"
    }
} elseif ($planChoice -eq "3") {
    if (-not $hasHighPerf) {
        Write-Host "  High Performance is not available here - keeping your plan." -ForegroundColor Yellow
        Add-Result "Power plan" "Skipped - High Performance not available"
    } else {
        Write-Host "  High Performance uses more power and shortens laptop battery." -ForegroundColor Yellow
        if (Read-YesNo "Switch to High Performance anyway?") {
            Show-Command "powercfg /setactive $highPerfGuid"
            powercfg /setactive $highPerfGuid
            $setOk = ($LASTEXITCODE -eq 0)
            $activeAfter = powercfg /getactivescheme
            if ($setOk -and ($activeAfter -match $highPerfGuid)) {
                Write-Host "  Switched to High Performance." -ForegroundColor Green
                Add-Result "Power plan" "Done (High Performance)"
            } else {
                Write-Host "  Could not switch - plan unchanged." -ForegroundColor Yellow
                Add-Result "Power plan" "Failed"
            }
        } else {
            Write-Host "  Kept your current plan."
            Add-Result "Power plan" "Skipped - kept current"
        }
    }
} else {
    Write-Host "  Kept your current plan."
    Add-Result "Power plan" "Skipped - kept current"
}

# --- Step: startup apps (list only - NO disable code in v1.0) ---
Step-Next -Title "Startup apps" -Info "Programs that start at sign-in. win-opt only lists them - never turns anything off. Disable in Task Manager; it is not uninstall."
Show-Command "Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User"
try {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction Stop |
        Select-Object Name, Command, Location, User
    if ($startup) { $startup | Format-Table -AutoSize | Out-String | Write-Host }
    else { Write-Host "  No startup programs found." }
} catch {
    Write-Host "  Could not list startup programs: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host "  Keep enabled: antivirus and cloud storage you need at sign-in."
Write-Host "  Do not switch off what you do not recognise - look it up first."
Write-Notice "Task Manager will open now - review it after the wizard finishes."
Show-Command "Start-Process taskmgr"
try { Start-Process taskmgr -ErrorAction Stop } catch { Write-Host "  Could not open Task Manager - press Ctrl+Shift+Esc." -ForegroundColor Yellow }
Write-Host "  In Task Manager: Startup apps, sort by impact, right-click > Disable."
Write-Host "  Task Manager is open - review it after the wizard."
Add-Result "Startup list" "Done"

# --- Summary ---
Write-Host ""
Write-Host "=================================================="
Write-Host "  win-opt $Script:ModeName - done"
Write-Host "=================================================="
Write-ProgressBar -Done $Script:TotalSteps -Total $Script:TotalSteps
Write-Host ""
foreach ($r in $Script:Results) {
    $tag = "  OK  "
    if ($r.Status -match '^Failed') { $tag = " FAIL " }
    elseif ($r.Status -match '^Skipped') { $tag = " SKIP " }
    $detail = ($r.Status -replace '^(Done|Failed|Skipped)\s*', '')
    $line = "  [$tag]  $($r.Step)"
    if ($detail) { $line += "  $detail" }
    Write-Host $line
}
Write-Host ""
Write-Host "What happened:"
Write-Host "  - Restore point made (or today's one used)."
Write-Host "  - Internet: $(if ($pingOk) { 'reachable' } else { 'not reachable (logged only)' })"
if ($mode -eq 1) {
    Write-Host "  - Deeper modes: Wizard (monthly), Archmage (quarterly)."
} elseif ($mode -eq 2) {
    Write-Host "  - Deeper pass: Archmage (quarterly) in v0.3.0."
} else {
    Write-Host "  - Run Wizard monthly, Archmage quarterly."
}
Write-Host ""
if ($Script:RestartNeeded) {
    Write-Host "  Some repairs finish only after a restart." -ForegroundColor Yellow
    if (Read-YesNo "Restart now? Save your work first") {
        Write-Host "  Restarting..."
        Write-Log "Restarting now (user chose restart)."
        Restart-Computer
        exit
    } else {
        Write-Host "  OK - restart later yourself. The repairs finish after a restart."
    }
} else {
    Write-Host "  - No restart needed."
}
Write-Host ""
Write-Log "$Script:ModeName finished."
if ($logFile) { Write-Host "Full log: $logFile" }
Write-Host "Press Enter to close."
Read-Host | Out-Null
