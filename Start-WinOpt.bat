@echo off
REM win-opt launcher — double-click this file.
REM It asks Windows for administrator rights if needed,
REM then runs win-opt.ps1 with PowerShell 5.1.
title WIN-OPT
mode con cols=100 lines=35
net session >nul 2>&1
if %errorlevel%==0 (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0win-opt.ps1"
) else (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0win-opt.ps1\"' -Verb RunAs"
)
pause
