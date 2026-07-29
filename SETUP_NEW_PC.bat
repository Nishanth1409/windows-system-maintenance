@echo off
setlocal EnableExtensions
title System Maintenance - Setup New PC
color 0B

set "SRC=%~dp0"
set "DEST=C:\SystemMaintenance"

:: Must run as Administrator (registry + copy to C:\)
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  Administrator approval required...
    echo.
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%SRC%.'"
    exit /b 0
)

echo.
echo  ============================================
echo   System Maintenance - One-Click Setup
echo  ============================================
echo.
echo  Source : %SRC%
echo  Install: %DEST%
echo.

:: On the authoring PC, DEST is a junction back to SRC. Copying would have the
:: package overwrite its own source, so resolve the junction and compare targets.
set "SAMEDIR=0"
for /f "usebackq delims=" %%R in (`powershell -NoProfile -Command "$s=(Resolve-Path '%SRC%.').Path.TrimEnd('\'); $d='%DEST%'; if(Test-Path $d){$i=Get-Item $d -Force; if($i.LinkType){$d=@($i.Target)[0]}; $d=(Resolve-Path $d).Path.TrimEnd('\')}; if($s -ieq $d){'1'}else{'0'}"`) do set "SAMEDIR=%%R"

if "%SAMEDIR%"=="1" (
    echo  [1/3] %DEST% already points at this folder - skipping copy.
) else (
    echo  [1/3] Copying all files to %DEST% ...
    if not exist "%DEST%" mkdir "%DEST%"
    robocopy "%SRC%." "%DEST%" /E /XD PortablePackage /XF RAMMap_Empty.log /R:2 /W:2 /NFL /NDL /NJH /NJS /NP
    if errorlevel 8 (
        echo  ERROR: Copy failed.
        pause
        exit /b 1
    )
    echo       Done.
)

echo.
echo  [2/3] Installing desktop menu ^(icons, registry, NVIDIA de-duplicate^) ...
call "%DEST%\Install_Menu.bat"

echo.
echo  [3/3] Registering NVIDIA duplicate-menu guard task ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%DEST%\scripts\Install_NvidiaMenuGuard.ps1" -Silent -Elevated

echo.
echo  Verifying key files ...
set "MISSING=0"
if not exist "%DEST%\app\RAMMap64.exe" (
    echo  WARNING: app\RAMMap64.exe missing - RAM Map Empty will not work.
    set "MISSING=1"
)
if not exist "%DEST%\Add_Desktop_Menu.reg" set "MISSING=1"
if not exist "%DEST%\System_AllInOne.bat" set "MISSING=1"
if not exist "%DEST%\scripts\System_UpdateApps.ps1" set "MISSING=1"

echo.
echo  ============================================
echo   Setup complete!
echo  ============================================
echo.
echo  Right-click desktop - Show more options - System Maintenance
echo  Full guide: %DEST%\GUIDE.md
echo.

powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show('System Maintenance is installed on this PC.`n`nFolder: C:\SystemMaintenance`n`nRight-click desktop - Show more options - System Maintenance`n`nRead GUIDE.md for the schedule.','Setup Complete','OK','Information')"

if "%MISSING%"=="1" (
    echo  Some files may be missing. Re-copy the full package and run again.
    pause
)

exit /b 0
