@echo off
rem Pause the power plan watchdog (no admin needed).
rem Creates watchdog-hold.txt; while it exists the watchdog skips.
cd /d "%~dp0"
if exist watchdog-hold.txt (
  echo [OK] Watchdog is ALREADY PAUSED ^(watchdog-hold.txt exists^).
) else (
  type nul > watchdog-hold.txt
  echo [OK] Watchdog PAUSED. You can switch power plans freely now.
)
echo Press any key to close...
pause >nul
