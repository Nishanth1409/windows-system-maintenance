@echo off
setlocal EnableExtensions
title System Maintenance - Install Desktop Menu
color 0A

:: Registry import requires Administrator
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Administrator approval required for desktop menu...
    echo.
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0.'"
    exit /b 0
)

echo.
echo  Installing desktop right-click menu...
echo.
echo  [1/3] Refreshing icons...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Extract_NVIDIA_Icons.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Extract_FileExplorer_Icon.ps1"
echo.
echo  [2/3] Applying registry...
reg import "%~dp0Add_Desktop_Menu.reg"
if errorlevel 1 (
    echo  ERROR: Registry import failed.
    pause
    exit /b 1
)
echo.
echo  [3/3] Hiding NVIDIA duplicate desktop menu entries...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\System_HideNvidiaDesktopMenu.ps1" -Silent -Elevated
echo.
echo  Done. Desktop menu installed. NVIDIA duplicates hidden — use NVIDIA submenu only.
echo  Right-click desktop - Show more options - System Maintenance
echo.
pause
exit /b 0
