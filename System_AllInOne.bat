@echo off
title System Maintenance
color 0A
echo.
echo  Starting full maintenance (admin + user tasks)...
echo  A UAC prompt will appear for administrator tasks.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ". 'C:\SystemMaintenance\scripts\System_WingetHelpers.ps1'; Save-UpgradeScanSnapshot | Out-Null"
powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c \"\"C:\SystemMaintenance\System_Admin.bat\"\"' -Verb RunAs -Wait"
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\SystemMaintenance\scripts\System_User.ps1"
exit /b 0