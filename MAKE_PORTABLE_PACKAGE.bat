@echo off
setlocal EnableExtensions
title System Maintenance - Make Portable Package
color 0E

set "SRC=C:\SystemMaintenance"
set "OUT=%SRC%\PortablePackage\SystemMaintenance_Setup"

echo.
echo  ============================================
echo   Refresh portable package from live install
echo  ============================================
echo.
echo  From : %SRC%
echo  To   : %OUT%
echo.
pause

if not exist "%OUT%" mkdir "%OUT%"

echo.
echo  Copying files...
robocopy "%SRC%" "%OUT%" /E /XD PortablePackage Win11Debloat-master .vscode /XF logs\RAMMap_Empty.log _DiagnoseShare.ps1 _DiagnoseShare2.ps1 _ScanNvidiaMenu.ps1 _RemoveNvTest.ps1 tools\_ReorganizeFolders.ps1 /R:2 /W:2
if errorlevel 8 (
    echo  ERROR: Copy failed.
    pause
    exit /b 1
)

:: Remove any leftover Nilesoft maintenance files (app is not managed here)
if exist "%OUT%\Nilesoft" rd /s /q "%OUT%\Nilesoft"
del /Q "%OUT%\System_NilesoftThemeGuard.ps1" 2>nul
del /Q "%OUT%\Nilesoft*.ps1" 2>nul
del /Q "%OUT%\System_HideExplorerShare.ps1" 2>nul
del /Q "%OUT%\System_HideExplorerShare.reg" 2>nul
del /Q "%OUT%\System_RestoreExplorerShare.ps1" 2>nul
del /Q "%OUT%\System_RestoreExplorerShare.reg" 2>nul
del /Q "%OUT%\System_RemoveShareCommandBar.cmd" 2>nul
del /Q "%OUT%\_DiagnoseShare*.ps1" 2>nul

echo.
echo  ============================================
echo   Package ready!
echo  ============================================
echo.
echo  Folder: %OUT%
echo  Give SystemMaintenance_Setup to another PC, then run SETUP_NEW_PC.bat
echo.

explorer.exe "%OUT%"

pause
exit /b 0
