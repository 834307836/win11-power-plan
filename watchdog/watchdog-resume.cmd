@echo off
rem Resume the power plan watchdog (no admin needed).
rem Deletes watchdog-hold.txt so the watchdog enforces the plan again.
cd /d "%~dp0"
if exist watchdog-hold.txt (
  del watchdog-hold.txt
  echo [OK] Watchdog RESUMED. The locked plan will be enforced again.
) else (
  echo [OK] Watchdog was not paused - nothing to do.
)
echo Press any key to close...
pause >nul
