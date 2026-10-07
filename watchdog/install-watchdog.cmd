@echo off
chcp 936 >nul
title Install power plan watchdog (admin)
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo ============================================================
echo   Install "PowerPlanWatchdog" scheduled task
echo   Runs as SYSTEM: at startup + at logon + every 5 minutes.
echo   If the active power plan is not the target one, it is
echo   switched back automatically.
echo ============================================================
echo.
echo Power plans on this machine:
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "powercfg /list"
echo.
echo Paste the GUID of the plan you want to LOCK IN, then press Enter.
set "PGUID="
set /p "PGUID=GUID: "
if not defined PGUID (
  echo.
  echo [X] No GUID entered. Nothing changed.
  echo Press any key to close...
  pause >nul
  exit /b
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-watchdog.ps1" -TargetGuid "%PGUID%"
echo.
echo Press any key to close...
pause >nul
