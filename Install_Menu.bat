@echo off
setlocal EnableExtensions
title System Maintenance - Install Desktop Menu
color 0A

REM Unblock download marks BEFORE elevate. Clicking Run does not clear MOTW;
REM without this, the admin re-launch shows the same Run/Cancel dialog again.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%~dp0.' -Recurse -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1

REM Registry import requires Administrator
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Administrator approval required for desktop menu...
    echo.
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0.' -ArgumentList '%*'"
    exit /b 0
)

echo.
echo  Installing desktop right-click menu...
echo.
echo  [0/5] Detecting this PC...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\System_OemProfile.ps1" -Print
echo.
echo  [1/5] Refreshing icons...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Extract_DesktopMenuIcons.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Extract_NVIDIA_Icons.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Extract_FileExplorer_Icon.ps1"
echo.
echo  [2/5] Applying registry for this PC...
set "GENREG=%TEMP%\SM_Add_Desktop_Menu.reg"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Build_DesktopMenuReg.ps1" -Root "%~dp0." -OutFile "%GENREG%"
if errorlevel 1 (
    echo  ERROR: Could not build the menu registry for this folder.
    if /i not "%~1"=="-NoPause" pause
    exit /b 1
)
reg import "%GENREG%"
if errorlevel 1 (
    echo  ERROR: Registry import failed.
    if /i not "%~1"=="-NoPause" pause
    exit /b 1
)
del "%GENREG%" >nul 2>&1
echo.
echo  [3/5] Brand-specific guards...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\System_ApplyOemGuards.ps1" -Root "%~dp0." -Silent
echo.
echo  [4/5] Keeping menu icons through Nilesoft Shell...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install_NilesoftMenuIcons.ps1" -Root "%~dp0." -RestartExplorer
echo.
echo  Done. Desktop menu installed for this PC.
echo  Right-click desktop - Show more options - System Maintenance
echo.
if /i not "%~1"=="-NoPause" pause
exit /b 0
