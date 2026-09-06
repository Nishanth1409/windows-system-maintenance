@echo off
setlocal EnableExtensions
REM One-shot: clear download marks so Run/Cancel does not repeat on elevate.
REM Double-click this first on a new PC if Install_Menu keeps asking Run again.
title Unblock System Maintenance
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-ChildItem -LiteralPath '%~dp0.' -Recurse -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host 'All files in this folder are unblocked.'; Write-Host 'Now open Install_Menu.bat or SETUP_NEW_PC.bat — you should only see UAC Yes, not Run/Cancel again.'"
echo.
pause
