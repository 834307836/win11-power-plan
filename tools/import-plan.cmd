@echo off
chcp 936 >nul
title Import power plan (admin)
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo ============================================================
echo   Import a .pow power plan, write every setting, verify it
echo   Backs up all existing plans to tools\backup\ first.
echo   No existing plan is deleted.
echo ============================================================
echo.
echo .pow files in this repo (plans folder):
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath (Join-Path '%~dp0..' 'plans') -Filter *.pow -ErrorAction SilentlyContinue | ForEach-Object { '    ' + $_.Name }"
echo.
echo NOTE: the two 'zhiyu' (depression album) files are registry hives,
echo       NOT XML - this tool cannot import them. See the README.
echo.
set "PFILE="
set /p "PFILE=Full path of the .pow file: "
if not defined PFILE (
  echo.
  echo [X] Nothing entered. Nothing changed.
  echo Press any key to close...
  pause >nul
  exit /b
)
echo.
echo GUIDs (see README):
echo     Intel desktop (lntel xin)      ff1f4777-af38-40e7-80be-1664c5a71f34
echo     AMD   desktop (zhiyu)          d301d1cd-43d3-41ca-be87-b5859eab3cff
echo     Intel laptop                  64877623-6e57-4bf4-8229-224ab01ed9f5
echo     AMD   laptop                  a4720da6-34e3-4ad1-ba2c-b7cece8f506b
echo.
set "PGUID="
set /p "PGUID=Target GUID: "
if not defined PGUID (
  echo.
  echo [X] Nothing entered. Nothing changed.
  echo Press any key to close...
  pause >nul
  exit /b
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import-plan.ps1" -PlanFile "%PFILE%" -TargetGuid "%PGUID%"
echo.
echo Press any key to close...
pause >nul
