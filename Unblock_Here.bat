@echo off
:: One-shot: stop the Run/Cancel Security Warning loop on this folder.
:: Double-click this first on a new PC if Install_Menu keeps asking Run again.
title Unblock System Maintenance
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-ChildItem -LiteralPath '%~dp0.' -Recurse -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host 'All files in this folder are unblocked.'; Write-Host 'Now open Install_Menu.bat or SETUP_NEW_PC.bat — you should only see UAC (Yes), not Run/Cancel again.'"
echo.
pause
