@echo off
chcp 936 >nul
title Import hive-format power plan (admin)
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo ============================================================
echo   Import a REGISTRY-HIVE power plan (the two "zhiyu" files)
echo   These are NOT powercfg XML; powercfg /import cannot read them.
echo   This tool parses the hive and writes the whole tree into
echo   HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes
echo   All existing plans are backed up to tools\backup\ first.
echo   No existing plan is deleted.
echo ============================================================
echo.
echo Hive-format .pow files found in the plans folder:
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath (Join-Path '%~dp0..' 'plans') -Filter *.pow -ErrorAction SilentlyContinue | Where-Object { [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($_.FullName),0,4) -eq 'regf' } | ForEach-Object { '    ' + $_.Name }"
echo.
echo Known GUIDs (see README):
echo     AMD   desktop  (AMD zhiyu)     d301d1cd-43d3-41ca-be87-b5859eab3cff
echo     Intel desktop  (Intel zhiyu)   ca9b706f-4c28-4c2f-ac50-99c79eb9d7f8
echo.
echo NOTE: the GUID is stored inside the file itself; pressing Enter
echo       at the next prompt uses that value (recommended).
echo.
set "HFILE="
set /p "HFILE=Full path of the hive .pow file: "
if not defined HFILE (
  echo.
  echo [X] Nothing entered. Nothing changed.
  echo Press any key to close...
  pause >nul
  exit /b
)
echo.
set "HGUID="
set /p "HGUID=Target GUID (Enter = auto from file): "
echo.
if defined HGUID (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import-hive-plan.ps1" -HiveFile "%HFILE%" -TargetGuid "%HGUID%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0import-hive-plan.ps1" -HiveFile "%HFILE%"
)
echo.
echo Press any key to close...
pause >nul
