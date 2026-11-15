# win-opt.ps1 - Windows Optimizer Wizard, v0.1.0 (Apprentice only)
# Windows 10 and Windows 11. PowerShell 5.1 only. Run as administrator.
# What it does: asks 2 start questions, creates a restore point, flushes DNS,
# cleans old temp files (only after you say yes), opens Storage Sense guidance,
# optimizes the C: drive, offers a power-plan change, and lists startup apps.
# What it never does: no registry edits, no DISM/SFC/chkdsk, no cleanmgr auto-run,
# no network reset, no driver/app updates, no disabling of anything.
# Wizard and Archmage modes are NOT implemented in v0.1.0.

$Script:Version = "0.1.0"
$Script:Results = @()

function Write-Header {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  win-opt  -  Windows Optimizer Wizard  v$Script:Version" -ForegroundColor Cyan
    Write-Host "  Apprentice mode  |  ~5-10 minutes  |  No restart needed" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Number, [int]$Total, [string]$Title, [string]$Info)
    Write-Host ""
    Write-Host "--- Step $Number of $Total : $Title ---" -ForegroundColor Yellow
    if ($Info) { Write-Host $Info -ForegroundColor Gray }
}

function Show-Command {
    param([string]$Command)
    Write-Host "  Command: $Command" -ForegroundColor DarkCyan
}

function Add-Result {
    param([string]$Step, [string]$Status)
    $Script:Results += [PSCustomObject]@{ Step = $Step; Status = $Status }
}

function Read-YesNo {
    param([string]$Question)
    while ($true) {
        $answer = Read-Host "$Question (Y/N)"
        if ($answer -match '^[Yy]') { return $true }
        if ($answer -match '^[Nn]') { return $false }
        Write-Host "Please type Y or N." -ForegroundColor Yellow
    }
}

# --- Admin check: relaunch as administrator if needed ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "win-opt needs administrator rights. Asking Windows to relaunch it as administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Per-run log in %TEMP%\win-opt\ ---
$logDir = Join-Path $env:TEMP "win-opt"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir ("win-opt-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")
try { Start-Transcript -Path $logFile -ErrorAction Stop | Out-Null } catch { }

Write-Header

# --- Windows version (10 and 11 both supported) ---
$os = Get-CimInstance Win32_OperatingSystem
$build = [System.Environment]::OSVersion.Version.Build
if ($build -ge 22000) { $winLabel = "Windows 11" } else { $winLabel = "Windows 10" }
Write-Host "Windows: $($os.Caption)  ($winLabel, build $build)" -ForegroundColor Gray
if ($winLabel -eq "Windows 10") {
    Write-Host "Note: Windows 10 support ended 14 Oct 2025. Update-related steps in later" -ForegroundColor Gray
    Write-Host "versions cannot restore routine Windows 10 updates. Everything in Apprentice" -ForegroundColor Gray
    Write-Host "runs the same on Windows 10 and Windows 11." -ForegroundColor Gray
}
Write-Host "Log file: $logFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Apprentice is a light tune-up for PCs that never get maintained." -ForegroundColor White
Write-Host "It only runs safe built-in commands, and it shows you each one first." -ForegroundColor White
Write-Host ""

# --- Mode picker: only Apprentice exists in v0.1.0 ---
Write-Host "Modes:" -ForegroundColor White
Write-Host "  [1] Apprentice  - light tune-up, ~5-10 minutes (this version)" -ForegroundColor Green
Write-Host "  [2] Wizard      - coming in v0.2.0" -ForegroundColor DarkGray
Write-Host "  [3] Archmage    - coming in v0.3.0" -ForegroundColor DarkGray
Write-Host "  [Q] Quit" -ForegroundColor White
$choice = Read-Host "Pick a mode"
if ($choice -eq "Q" -or $choice -eq "q") {
    Write-Host "Bye." -ForegroundColor Gray
    try { Stop-Transcript | Out-Null } catch { }
    exit
}
if ($choice -ne "1") {
    Write-Host "That mode is not in v0.1.0 yet. Apprentice is the only mode in this version." -ForegroundColor Yellow
    Write-Host "Press Enter to run Apprentice, or close this window to quit." -ForegroundColor Yellow
    Read-Host | Out-Null
}

Write-Header
$TotalSteps = 8

# --- Step 1: two start questions (recorded for later phases, not acted on yet) ---
Write-Step -Number 1 -Total $TotalSteps -Title "Two quick questions" -Info "Your answers are saved in the log for the later Wizard and Archmage modes. Nothing is changed here."
$wuFailing = Read-YesNo "Is Windows Update failing on this PC (updates stuck or erroring)?"
$netBroken = Read-YesNo "Is your internet broken on this PC (websites will not load at all)?"
Write-Host "  Recorded: Windows Update failing = $wuFailing ; Internet broken = $netBroken" -ForegroundColor Gray
Show-Command "Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet"
try {
    $pingOk = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction Stop
} catch {
    $pingOk = $false
}
if ($pingOk) { Write-Host "  Result: internet reachable (ping to 8.8.8.8 worked)." -ForegroundColor Green }
else { Write-Host "  Result: ping to 8.8.8.8 failed. This is only a note for now - Apprentice does not reset the network." -ForegroundColor Yellow }
Add-Result "Start questions + ping check" "Done"

# --- Step 2: restore point (safety net - abort if it cannot be made) ---
Write-Step -Number 2 -Total $TotalSteps -Title "Restore point (safety net)" -Info "Before anything changes, Windows takes a snapshot so system changes can be undone. A restore point is NOT a backup - your personal files are not protected by it."
Show-Command 'Enable-ComputerRestore -Drive "C:\"'
try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
    Write-Host "  Result: System Protection is on for C:." -ForegroundColor Green
} catch {
    Write-Host "  Note: could not confirm System Protection: $($_.Exception.Message)" -ForegroundColor Yellow
}
$desc = "win-opt before Apprentice " + (Get-Date -Format "yyyy-MM-dd HH:mm")
Show-Command "Checkpoint-Computer -Description ""$desc"" -RestorePointType MODIFY_SETTINGS"
$restoreOk = $false
try {
    Checkpoint-Computer -Description $desc -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $restoreOk = $true
    Write-Host "  Result: restore point created." -ForegroundColor Green
} catch {
    Write-Host "  Warning: creating a new restore point failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Checking whether a restore point from today already exists (only one per day is allowed)..." -ForegroundColor Gray
    Show-Command "Get-ComputerRestorePoint"
    $todayPoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime.Date -eq (Get-Date).Date } | Select-Object -First 1
    if ($todayPoint) {
        Write-Host "  Result: a restore point from today already exists ($($todayPoint.Description)). Continuing with it." -ForegroundColor Green
        $restoreOk = $true
    }
}
if (-not $restoreOk) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "  STOPPED: no restore point could be created." -ForegroundColor Red
    Write-Host "  win-opt will not run any repair or cleanup without" -ForegroundColor Red
    Write-Host "  a safety net. Turn on System Protection for C: in" -ForegroundColor Red
    Write-Host "  System Properties, then run win-opt again." -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Add-Result "Restore point" "FAILED - aborted"
    try { Stop-Transcript | Out-Null } catch { }
    Write-Host "Press Enter to close." -ForegroundColor Gray
    Read-Host | Out-Null
    exit 1
}
$points = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
Write-Host "  Restore points on this PC: $(@($points).Count)" -ForegroundColor Gray
Add-Result "Restore point" "Done"

# --- Step 3: flush DNS ---
Write-Step -Number 3 -Total $TotalSteps -Title "Flush the DNS cache" -Info "Clears old website addresses Windows remembered, so it asks the DNS server again. Fast and harmless."
Show-Command "ipconfig /flushdns"
try {
    $dnsOut = ipconfig /flushdns 2>&1 | Out-String
    Write-Host $dnsOut -ForegroundColor Gray
    Write-Host "  Result: DNS cache flushed." -ForegroundColor Green
    Add-Result "Flush DNS" "Done"
} catch {
    Write-Host "  Result: flush failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Add-Result "Flush DNS" "Failed"
}

# --- Step 4: temp cleanup - ALWAYS asks first ---
Write-Step -Number 4 -Total $TotalSteps -Title "Clean old temp files (asks first)" -Info "Only files older than 7 days are touched, only the contents of the temp folders (never the folders themselves), and locked files are skipped. This frees space - it does not speed up a healthy PC by itself."
$cutoff = (Get-Date).AddDays(-7)
$tempPaths = @($env:TEMP, "C:\Windows\Temp")
$tempSummary = @()
foreach ($tp in $tempPaths) {
    Show-Command "Get-ChildItem $tp -Recurse -Force | Where-Object { LastWriteTime -lt (7 days ago) }"
    $oldFiles = Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff }
    $count = @($oldFiles).Count
    $bytes = 0
    foreach ($f in $oldFiles) { $bytes += $f.Length }
    $mb = [math]::Round($bytes / 1MB, 1)
    Write-Host "  $tp : $count files older than 7 days, about $mb MB" -ForegroundColor White
    $tempSummary += [PSCustomObject]@{ Path = $tp; Count = $count; MB = $mb }
}
$totalTempCount = ($tempSummary | Measure-Object -Property Count -Sum).Sum
if ($totalTempCount -eq 0) {
    Write-Host "  Result: nothing older than 7 days to clean. Skipping." -ForegroundColor Green
    Add-Result "Temp cleanup" "Skipped - nothing old"
} elseif (Read-YesNo "Delete these $totalTempCount old temp files?") {
    $deleted = 0
    foreach ($tp in $tempPaths) {
        Get-ChildItem -Path $tp -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                try { Remove-Item -Path $_.FullName -Force -ErrorAction Stop; $deleted++ } catch { }
            }
    }
    Write-Host "  Result: deleted $deleted of $totalTempCount old temp files (locked files were skipped)." -ForegroundColor Green
    Add-Result "Temp cleanup" "Done ($deleted files)"
} else {
    Write-Host "  Result: skipped - you said no. Nothing was deleted." -ForegroundColor Gray
    Add-Result "Temp cleanup" "Skipped - user said no"
}

# --- Step 5: Storage Sense guidance (opens Settings, no registry edits) ---
Write-Step -Number 5 -Total $TotalSteps -Title "Storage Sense" -Info "Windows has its own automatic cleaner. win-opt does not change its settings - it opens Settings so you can turn it on and press 'Run now' yourself."
Show-Command "Start-Process ms-settings:storage"
Write-Host "  Opening Settings > System > Storage..." -ForegroundColor Gray
Write-Host "  In that page: turn on Storage Sense, then use 'Configure Storage Sense" -ForegroundColor White
Write-Host "  or run it now'. Do NOT turn on automatic Downloads cleanup unless you" -ForegroundColor White
Write-Host "  want Windows to delete old downloads by itself." -ForegroundColor White
try { Start-Process ms-settings:storage -ErrorAction Stop } catch { Write-Host "  Could not open Settings automatically - open it by hand: Settings > System > Storage." -ForegroundColor Yellow }
Write-Host "  Press Enter when you are done in Settings (or right away to skip this step)." -ForegroundColor Gray
Read-Host | Out-Null
Add-Result "Storage Sense guidance" "Done"

# --- Step 6: optimize the C: drive (media-aware) ---
Write-Step -Number 6 -Total $TotalSteps -Title "Optimize drive C:" -Info "Media-aware: on an SSD this sends TRIM hints (fast), on a hard drive it defragments (can take a while). Nothing is forced onto the wrong drive type."
Show-Command "Optimize-Volume -DriveLetter C"
try {
    Optimize-Volume -DriveLetter C -ErrorAction Stop | Out-String | Write-Host -ForegroundColor Gray
    Write-Host "  Result: drive C: optimized." -ForegroundColor Green
    Add-Result "Optimize drive C:" "Done"
} catch {
    Write-Host "  Result: optimize failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Add-Result "Optimize drive C:" "Failed"
}

# --- Step 7: power plan (record original, user chooses) ---
Write-Step -Number 7 -Total $TotalSteps -Title "Power plan" -Info "A faster plan uses more power and makes more heat and fan noise. On a laptop it shortens battery life. Your current plan is recorded so you can go back."
Show-Command "powercfg /list"
powercfg /list
Show-Command "powercfg /getactivescheme"
$activeScheme = powercfg /getactivescheme
Write-Host "  Current plan: $activeScheme" -ForegroundColor White
Write-Host "  Recorded as your original plan - you can switch back any time." -ForegroundColor Gray
Write-Host ""
Write-Host "  [1] Keep my current plan" -ForegroundColor White
Write-Host "  [2] Balanced (best for most PCs and laptops)" -ForegroundColor White
Write-Host "  [3] High Performance (desktop recommended - more power, heat, fan noise)" -ForegroundColor White
$planChoice = Read-Host "Pick a power plan (1/2/3)"
if ($planChoice -eq "2") {
    Show-Command "powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e"
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    Write-Host "  Result: switched to Balanced." -ForegroundColor Green
    Add-Result "Power plan" "Done (Balanced)"
} elseif ($planChoice -eq "3") {
    Write-Host "  Warning: High Performance uses more power and shortens laptop battery life." -ForegroundColor Yellow
    if (Read-YesNo "Switch to High Performance anyway?") {
        Show-Command "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-Host "  Result: switched to High Performance." -ForegroundColor Green
        Add-Result "Power plan" "Done (High Performance)"
    } else {
        Write-Host "  Result: kept your current plan." -ForegroundColor Gray
        Add-Result "Power plan" "Skipped - kept current"
    }
} else {
    Write-Host "  Result: kept your current plan." -ForegroundColor Gray
    Add-Result "Power plan" "Skipped - kept current"
}

# --- Step 8: startup apps (list only - NO disable code in v1.0) ---
Write-Step -Number 8 -Total $TotalSteps -Title "Startup apps (list only)" -Info "These programs start when you sign in. win-opt only lists them - it never turns anything off. You can switch one off yourself in Task Manager. Disable is not uninstall, and you can turn it back on."
Show-Command "Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location, User"
try {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction Stop |
        Select-Object Name, Command, Location, User
    if ($startup) { $startup | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Gray }
    else { Write-Host "  No startup programs found." -ForegroundColor Gray }
} catch {
    Write-Host "  Could not list startup programs: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host "  Keep enabled: your antivirus and cloud storage you need at sign-in." -ForegroundColor White
Write-Host "  Do not switch off something you do not recognise - look it up first." -ForegroundColor White
Write-Host "  Opening Task Manager so you can review Startup apps yourself..." -ForegroundColor Gray
Show-Command "Start-Process taskmgr"
try { Start-Process taskmgr -ErrorAction Stop } catch { Write-Host "  Could not open Task Manager - press Ctrl+Shift+Esc to open it by hand." -ForegroundColor Yellow }
Write-Host "  In Task Manager: Startup apps, sort by Startup impact, right-click > Disable." -ForegroundColor White
Write-Host "  Press Enter when you are done (or right away to finish)." -ForegroundColor Gray
Read-Host | Out-Null
Add-Result "Startup list" "Done"

# --- Summary ---
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  win-opt Apprentice - done" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
$Script:Results | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor White
Write-Host "What happened:" -ForegroundColor White
Write-Host "  - A restore point was made (or today's existing one was used)." -ForegroundColor Gray
Write-Host "  - Your answers: Windows Update failing = $wuFailing ; Internet broken = $netBroken" -ForegroundColor Gray
Write-Host "  - No restart is needed for Apprentice." -ForegroundColor Gray
Write-Host "  - Wizard (v0.2.0) and Archmage (v0.3.0) are coming next." -ForegroundColor Gray
Write-Host ""
Write-Host "Full log: $logFile" -ForegroundColor Gray
try { Stop-Transcript | Out-Null } catch { }
Write-Host "Press Enter to close." -ForegroundColor Gray
Read-Host | Out-Null
